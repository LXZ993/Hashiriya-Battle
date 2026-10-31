#!/usr/bin/env python3
"""Hashiriya Battle - Sound-Effekte per Code erzeugen (Synthese, keine Samples, keine KI).

Jeder Sound ist ein kleines "Rezept" aus Oszillatoren, Hüllkurven und Filtern.
Werte ändern (Tonhöhe, Länge, Lautstärke) und neu ausführen:

    python tools/audio/sfx.py            # alle Sounds
    python tools/audio/sfx.py click win  # nur diese

Ausgabe: tools/audio/out/sfx/<name>.wav (44.1 kHz, 16 bit) und, falls ffmpeg da ist, .ogg.
Die WAVs lassen sich in jedem Audio-Editor / DAW (Audacity, FL Studio, LMMS ...) öffnen.
Braucht nur numpy.
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out', 'sfx')
rng = np.random.default_rng(1987)
MAX_RMS_DB = -14.0  # Lautheits-Obergrenze, damit Dauertöne nicht lauter wirken als Klicks  # fester Seed = jedes Mal derselbe Klang


# Bausteine ---------------------------------------------------------------------

def t_(dur):
    return np.arange(int(SR * dur)) / SR


def osc(freq, dur, kind='sine', phase=0.0):
    """freq: Zahl oder Array (Glide). kind: sine, square, saw, tri."""
    n = int(SR * dur)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, float)[:n]
    ph = 2 * np.pi * np.cumsum(f) / SR + phase
    if kind == 'sine':
        return np.sin(ph)
    x = (ph / (2 * np.pi)) % 1.0
    if kind == 'saw':
        return 2 * x - 1
    if kind == 'square':
        return np.where(x < 0.5, 1.0, -1.0)
    if kind == 'tri':
        return 4 * np.abs(x - 0.5) - 1
    raise ValueError(kind)


def glide(f0, f1, dur, curve=1.0):
    k = np.linspace(0, 1, int(SR * dur)) ** curve
    return f0 * (f1 / f0) ** k  # exponentiell = klingt natürlich


def env(dur, a=0.002, d=0.1, s=0.0, r=0.05, hold=0.0):
    """ADSR-Hüllkurve in Sekunden."""
    n = int(SR * dur)
    e = np.zeros(n)
    i = 0
    for seg, v0, v1 in ((a, 0, 1), (hold, 1, 1), (d, 1, s)):
        m = min(int(SR * seg), n - i)
        if m > 0:
            e[i:i + m] = np.linspace(v0, v1, m)
            i += m
    rn = min(int(SR * r), n - i)
    sus = n - i - rn
    if sus > 0:
        e[i:i + sus] = s
        i += sus
    if rn > 0:
        e[i:i + rn] = np.linspace(s, 0, rn)
    return e


def expdecay(dur, tau):
    return np.exp(-t_(dur) / tau)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    """Einfacher 1-Pol-Tiefpass; cutoff Zahl oder Array (Filter-Sweep)."""
    c = np.full(len(x), float(cutoff)) if np.isscalar(cutoff) else np.asarray(cutoff, float)
    a = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    z = 0.0
    for i in range(len(x)):
        z += a[i] * (x[i] - z)
        y[i] = z
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def delay(x, time, fb=0.35, mix=0.3, taps=4):
    d = int(SR * time)
    y = np.concatenate([x, np.zeros(d * taps)])
    out = y.copy()
    g = mix
    for k in range(1, taps + 1):
        out[d * k:] += g * y[:len(y) - d * k]
        g *= fb
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    y = np.zeros(n)
    for p in parts:
        y[:len(p)] += p
    return y


def at(x, start):
    return np.concatenate([np.zeros(int(SR * start)), x])


def note(n):
    """MIDI-Notennummer -> Hz (69 = A4 = 440 Hz)."""
    return 440.0 * 2 ** ((n - 69) / 12)


def tone(freq, dur, kind='square', a=0.002, d=0.08, s=0.0, r=0.03, lp=None, vol=1.0, detune=0.0):
    x = osc(freq, dur, kind)
    if detune:
        x = 0.5 * (x + osc(freq * (1 + detune), dur, kind))
    if lp:
        x = lowpass(x, lp)
    return vol * x * env(dur, a, d, s, r)


def fm(freq, dur, ratio=2.0, index=2.0, tau=0.15, a=0.001, vol=1.0, idx_tau=None):
    """FM-Glocke wie in japanischen Spielen der 90er/2000er (Yamaha-FM-Klang).
    ratio = Modulator/Träger, index = Helligkeit, tau = Ausklingzeit."""
    tt = t_(dur)
    ie = index * np.exp(-tt / (idx_tau or tau * 0.6))
    mod = ie * np.sin(2 * np.pi * freq * ratio * tt)
    car = np.sin(2 * np.pi * freq * tt + mod)
    e = np.exp(-tt / tau) * np.minimum(1, tt / a)
    return vol * car * e


def finish(x, peak_db=-1.0, fade=0.004):
    x = x - np.mean(x)
    f = int(SR * fade)
    if f and len(x) > 2 * f:
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * 10 ** (peak_db / 20)
    rms = np.sqrt(np.mean(x ** 2)) or 1.0
    lim = 10 ** (MAX_RMS_DB / 20)
    return x * min(1.0, lim / rms)  # Dauertöne nicht lauter als kurze Klicks wirken lassen


# Rezepte -----------------------------------------------------------------------
# Stil: kurz, digital, "Bordcomputer bei Nacht" - leise genug, damit sie nie nerven.

def s_click():  # Bestätigen: "Pi-kon" - zwei helle FM-Töne aufwärts (klassisch japanisches Menü)
    return mix(fm(note(88), 0.07, ratio=1.0, index=1.2, tau=0.03, vol=0.5),
               at(fm(note(95), 0.18, ratio=3.0, index=1.5, tau=0.06, vol=0.55), 0.045))


def s_hover():  # Cursor bewegen: kurzes "Pi"
    return fm(note(91), 0.05, ratio=2.0, index=0.8, tau=0.015, vol=0.35)


def s_back():  # Abbrechen/Zurück: "Pyu" abwärts
    return mix(fm(note(86), 0.07, ratio=1.0, index=1.0, tau=0.03, vol=0.5),
               at(fm(note(79), 0.14, ratio=1.0, index=1.0, tau=0.05, vol=0.5), 0.05))


def s_tab():  # Reiter wechseln: kurzer Swipe + Pi
    n = noise(0.08)
    sweep = lowpass(highpass(n, 1500), glide(2000, 9000, 0.08))
    return mix(0.35 * sweep * env(0.08, a=0.01, d=0.07), at(fm(note(93), 0.08, ratio=2.0, index=1.0, tau=0.025, vol=0.4), 0.03))


def s_denied():  # Geht nicht: dumpfer Doppel-Buzz
    b = tone(180, 0.09, 'square', d=0.0, s=1.0, r=0.02, lp=1200, vol=0.6)
    return mix(b, at(b, 0.12))


def s_challenge():  # Lichthupe / Herausforderung: Whoosh + aufsteigender Stinger
    dur = 0.9
    w = lowpass(noise(dur), glide(400, 7000, dur, 0.6)) * env(dur, a=0.55, d=0.3) * 0.8
    stab = mix(*[tone(note(n), 0.5, 'saw', a=0.005, d=0.45, lp=3500, vol=0.25, detune=0.006)
                 for n in (57, 64, 69, 72)])
    hit = lowpass(noise(0.25), 3000) * expdecay(0.25, 0.05)
    return mix(w, at(stab + 0 * stab, 0.55), at(hit * 0.7, 0.55))


def s_countdown():  # Countdown-Piep
    return tone(880, 0.16, 'square', a=0.002, d=0.0, s=1.0, r=0.03, lp=3500, vol=0.6)


def s_go():  # Los! - höherer, längerer Piep mit Oktave
    return mix(tone(1760, 0.45, 'square', d=0.0, s=1.0, r=0.2, lp=5000, vol=0.45),
               tone(880, 0.45, 'square', d=0.0, s=1.0, r=0.2, lp=3000, vol=0.35))


def s_sp_hit():  # SP-Balken verliert Punkte: kurzer tiefer Puls
    f = glide(320, 90, 0.12)
    return mix(osc(f, 0.12, 'sine') * expdecay(0.12, 0.035), 0.2 * tone(1200, 0.03, 'square', d=0.025, lp=3000))


def s_sp_low():  # SP fast leer: Warnton (2x)
    one = tone(1046, 0.12, 'square', d=0.0, s=1.0, r=0.03, lp=2500, vol=0.45)
    two = tone(784, 0.12, 'square', d=0.0, s=1.0, r=0.03, lp=2500, vol=0.45)
    return mix(one, at(two, 0.14), at(one, 0.32), at(two, 0.46))


def s_win():  # Sieg: Dur-Arpeggio mit Echo
    seq = [(64, 0.0), (68, 0.08), (71, 0.16), (76, 0.24), (80, 0.32)]
    parts = [at(tone(note(n), 0.35, 'saw', a=0.003, d=0.3, lp=4500, vol=0.35, detune=0.005), st) for n, st in seq]
    chord = at(mix(*[tone(note(n), 1.2, 'saw', a=0.01, d=1.1, lp=3000, vol=0.18, detune=0.007)
                     for n in (52, 64, 68, 71, 76)]), 0.42)
    return delay(mix(*parts, chord), 0.18, fb=0.3, mix=0.25)


def s_lose():  # Niederlage: absteigend, gedämpft
    seq = [(69, 0.0), (65, 0.16), (62, 0.32)]
    parts = [at(tone(note(n), 0.5, 'saw', a=0.005, d=0.45, lp=1800, vol=0.35, detune=0.01), st) for n, st in seq]
    low = at(tone(note(38), 1.2, 'saw', a=0.02, d=1.1, lp=600, vol=0.4), 0.45)
    return mix(*parts, low)


def s_info():  # Gegner gesichtet / Info: FM-Ping mit Echo
    return delay(mix(fm(note(84), 0.35, ratio=3.5, index=2.5, tau=0.12, vol=0.55),
                     at(fm(note(91), 0.35, ratio=3.5, index=2.0, tau=0.12, vol=0.45), 0.08)),
                 0.13, fb=0.4, mix=0.35, taps=3)


def s_unlock():  # Neue Teile freigeschaltet: FM-Glitzer aufwärts
    seq = [76, 79, 83, 88, 91, 95]
    parts = [at(fm(note(n), 0.4, ratio=3.0, index=2.0, tau=0.12, vol=0.4), i * 0.055) for i, n in enumerate(seq)]
    shine = at(highpass(noise(0.5), 6000) * env(0.5, a=0.05, d=0.45) * 0.12, 0.1)
    return delay(mix(*parts, shine), 0.11, fb=0.35, mix=0.3)


def s_buy():  # Kauf / Einbau: mechanisches Klack + Bestätigungston
    clack = lowpass(noise(0.05), 2500) * expdecay(0.05, 0.008)
    return mix(clack * 0.9, at(tone(1318, 0.12, 'square', d=0.1, lp=3500, vol=0.35), 0.03),
               at(tone(1760, 0.18, 'square', d=0.16, lp=4000, vol=0.35), 0.1))


def s_money():  # Geld erhalten: Kassen-/Münz-Kling (FM-Glocke)
    return mix(fm(note(93), 0.12, ratio=3.5, index=3.0, tau=0.05, vol=0.5),
               at(fm(note(100), 0.6, ratio=3.5, index=3.0, tau=0.2, vol=0.55), 0.07))


def s_terminal():  # HashiNet-Terminal startet: Modem-artiges Zirpen + Bestätigung
    chirps = [at(tone(f, 0.04, 'square', d=0.0, s=1.0, r=0.005, lp=5000, vol=0.25), i * 0.045)
              for i, f in enumerate((1200, 2100, 1600, 2400, 1900, 2800))]
    hum = tone(60, 0.35, 'saw', d=0.0, s=1.0, r=0.1, lp=300, vol=0.15)
    ok = at(tone(2093, 0.15, 'sine', d=0.14, vol=0.4), 0.3)
    return mix(hum, *chirps, ok)


def s_talk():  # Sprechblase / Textzeichen: weicher Blip
    return fm(note(79), 0.05, ratio=1.0, index=0.6, tau=0.02, vol=0.4)


def s_levelup():  # Rang / Stufe aufgestiegen
    seq = [(60, 0), (64, .07), (67, .14), (72, .21)]
    parts = [at(tone(note(n), 0.2, 'square', d=0.18, lp=4000, vol=0.3), st) for n, st in seq]
    pad = at(mix(*[tone(note(n), 0.9, 'saw', a=0.02, d=0.85, lp=2500, vol=0.15, detune=0.008) for n in (60, 67, 72, 76)]), 0.28)
    return delay(mix(*parts, pad), 0.14, fb=0.3, mix=0.2)


SOUNDS = {
    'click': s_click, 'hover': s_hover, 'back': s_back, 'tab': s_tab, 'denied': s_denied,
    'challenge': s_challenge, 'countdown': s_countdown, 'go': s_go,
    'sp_hit': s_sp_hit, 'sp_low': s_sp_low, 'win': s_win, 'lose': s_lose,
    'info': s_info, 'unlock': s_unlock, 'buy': s_buy, 'money': s_money,
    'terminal': s_terminal, 'talk': s_talk, 'levelUp': s_levelup,
}


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def to_ogg(wav):
    ogg = wav[:-4] + '.ogg'
    try:
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', ogg], check=True)
    except (OSError, subprocess.CalledProcessError):
        pass


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for name in names or SOUNDS:
        x = finish(SOUNDS[name]())
        p = os.path.join(OUT, name + '.wav')
        write_wav(p, x)
        to_ogg(p)
        print(f'{name:10s} {len(x) / SR:5.2f} s')


if __name__ == '__main__':
    main(sys.argv[1:])
