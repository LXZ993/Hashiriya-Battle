#!/usr/bin/env python3
"""Hashiriya Battle - Instrumental-Songs als MIDI (zum Bearbeiten) + Audio-Vorschau.

Die Songs sind hier als Noten aufgeschrieben (Akkorde, Bass, Melodie, Schlagzeug).
Daraus entstehen:
  tools/audio/music/<song>.mid            -> in FL Studio / LMMS / Reaper / Cubase öffnen,
                                             jede Spur = ein Instrument, eigene Synths drauflegen
  tools/audio/out/music/<song>.ogg        -> Vorschau, mit einem einfachen eingebauten Synth gerendert
  tools/audio/out/music/<song>_stems/     -> (mit --stems) jede Spur einzeln als WAV

    python tools/audio/music.py              # alle Songs
    python tools/audio/music.py midnight     # nur einen
    python tools/audio/music.py --stems      # zusätzlich Einzelspuren

Braucht numpy, scipy, mido (pip install numpy scipy mido) und ffmpeg für .ogg.
"""
import os
import subprocess
import sys
import wave

import mido
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
MIDI_DIR = os.path.join(HERE, 'music')
OUT = os.path.join(HERE, 'out', 'music')
rng = np.random.default_rng(1999)

NOTE_IDX = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
            'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def n(name):
    """'A4' -> 69"""
    p, o = name[:-1], int(name[-1])
    return 12 * (o + 1) + NOTE_IDX[p]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# Noten-Schreibweise ------------------------------------------------------------
# Melodie: "A5:2 G5:1 R:1" = Note:Länge in Achteln (R = Pause). Ein Takt = 8 Achtel.

class Song:
    def __init__(self, name, title, bpm):
        self.name, self.title, self.bpm = name, title, bpm
        self.tracks = {}  # track -> dict(program, channel, pan, notes=[(beat, dur, midi, vel)])

    def track(self, key, program, channel, pan=0.0, label=None):
        self.tracks[key] = dict(program=program, channel=channel, pan=pan, label=label or key, notes=[])

    def add(self, key, beat, dur, midi, vel=100):
        self.tracks[key]['notes'].append((beat, dur, midi, vel))

    def melody(self, key, bar, text, vel=100, octave_shift=0):
        b = bar * 4.0
        for tok in text.split():
            if tok == '|':
                continue
            nm, ln = tok.split(':')
            ln = float(ln) / 2  # Achtel -> Beats
            if nm != 'R':
                self.add(key, b, ln * 0.95, n(nm) + 12 * octave_shift, vel)
            b += ln

    @property
    def beats(self):
        return max(b + d for t in self.tracks.values() for b, d, _, _ in t['notes'])


def chord(root, kind):
    iv = {'m': [0, 3, 7], 'M': [0, 4, 7], 'm7': [0, 3, 7, 10], 'M7': [0, 4, 7, 11], '7': [0, 4, 7, 10],
          'sus4': [0, 5, 7], 'm9': [0, 3, 7, 10, 14], 'M9': [0, 4, 7, 11, 14], 'add9': [0, 4, 7, 14]}[kind]
    r = n(root)
    return [r + i for i in iv]


# Song 1: Nacht-Autobahn, Eurobeat ----------------------------------------------

def song_midnight():
    s = Song('midnight_line', 'Midnight Line (Eurobeat, Nacht)', 155)
    s.track('drums', 0, 9, 0.0, 'Drums')
    s.track('bass', 38, 0, 0.0, 'Bass (Oktav-Pumpe)')
    s.track('pad', 89, 1, 0.0, 'Pad / Akkorde')
    s.track('arp', 80, 2, 0.3, 'Arpeggio')
    s.track('lead', 81, 3, -0.1, 'Lead (Supersaw)')
    s.track('stab', 62, 4, -0.3, 'Brass-Stabs')

    # Akkordfolgen (je 2 Takte)
    verse = [('A3', 'm'), ('F3', 'M'), ('G3', 'M'), ('E3', 'm')]
    pre = [('D3', 'm'), ('E3', 'm'), ('F3', 'M'), ('G3', 'M')]
    cho = [('A3', 'm'), ('F3', 'M'), ('G3', 'M'), ('E3', 'M')]
    # Ablauf: (Teil, Takte, Akkorde)
    form = [('intro', 8, verse), ('verse', 8, verse), ('pre', 8, pre), ('chorus', 16, cho + cho),
            ('break', 8, verse), ('chorus', 16, cho + cho), ('outro', 4, [('A3', 'm'), ('A3', 'm')])]

    bar = 0
    for part, bars, chords in form:
        for i in range(bars):
            b = (bar + i) * 4.0
            root, kind = chords[(i // 2) % len(chords)]
            ch = chord(root, kind)
            last = i == bars - 1
            # Drums: 4-on-the-floor, Snare+Clap auf 2/4, offene HiHat auf Offbeats
            if part != 'break' or i >= 4:
                for q in range(4):
                    s.add('drums', b + q, 0.25, 36, 120)
            if part not in ('intro',) or i >= 4:
                for q in (1, 3):
                    s.add('drums', b + q, 0.25, 38, 105)
                    s.add('drums', b + q, 0.25, 39, 90)
            for q in range(4):
                s.add('drums', b + q + 0.5, 0.25, 46, 80)
                if part in ('chorus', 'pre'):
                    s.add('drums', b + q + 0.25, 0.1, 42, 55)
                    s.add('drums', b + q + 0.75, 0.1, 42, 55)
            if i == 0 and part in ('verse', 'chorus', 'outro'):
                s.add('drums', b, 1.0, 49, 110)
            if part == 'pre' and last:  # Snare-Wirbel vor dem Refrain
                for k in range(16):
                    s.add('drums', b + k * 0.25, 0.2, 38, 60 + k * 4)
            # Bass: Eurobeat-Oktavpumpe in Achteln
            if part != 'intro' or i >= 4:
                r = ch[0] - 12
                for e in range(8):
                    s.add('bass', b + e * 0.5, 0.4, r if e % 2 == 0 else r + 12, 110 if e % 2 == 0 else 95)
            # Pad
            if i % 2 == 0 and part != 'intro':
                for m in ch:
                    s.add('pad', b, 7.8, m + 12, 70)
            # Arpeggio (16tel, hoch-runter)
            if part in ('intro', 'verse', 'break', 'chorus'):
                pat = [ch[0], ch[1], ch[2], ch[0] + 12, ch[2] + 12, ch[0] + 12, ch[2], ch[1]]
                for k in range(16):
                    s.add('arp', b + k * 0.25, 0.2, pat[k % 8] + 24, 70 if k % 4 else 90)
            # Brass-Stabs im Pre-Chorus (synkopiert)
            if part == 'pre':
                for st in (0, 1.5, 3):
                    for m in ch:
                        s.add('stab', b + st, 0.4, m + 12, 95)
        # Melodien
        if part == 'verse':
            s.melody('lead', bar, 'E5:3 A4:3 C5:2 | D5:3 C5:3 B4:2 | C5:3 A4:3 F4:2 | G4:8 |'
                                  ' E5:3 A4:3 C5:2 | D5:3 E5:3 G5:2 | E5:6 D5:2 | B4:8', vel=85)
        if part == 'pre':
            s.melody('lead', bar, 'A4:2 D5:2 F5:2 A5:2 | G5:4 F5:4 | B4:2 E5:2 G5:2 B5:2 | A5:4 G5:4 |'
                                  ' C6:2 A5:2 F5:2 C5:2 | A5:6 F5:2 | D6:2 B5:2 G5:2 D5:2 | B5:8', vel=95)
        if part == 'chorus':
            phrase = ('A5:2 G5:1 A5:1 C6:2 B5:2 | A5:3 E5:5 | F5:2 E5:1 F5:1 A5:2 G5:2 | F5:3 C5:5 |'
                      ' D5:2 E5:1 F5:1 G5:2 A5:2 | B5:3 G5:3 D6:2 | C6:2 B5:2 A5:2 G#5:2 | B5:6 R:2')
            end = ('A5:2 G5:1 A5:1 C6:2 B5:2 | A5:3 E5:5 | F5:2 E5:1 F5:1 A5:2 G5:2 | F5:3 C5:5 |'
                   ' D5:2 E5:1 F5:1 G5:2 A5:2 | B5:3 C6:3 D6:2 | E6:2 D6:2 C6:2 B5:2 | A5:8')
            s.melody('lead', bar, phrase, vel=110)
            s.melody('lead', bar + 8, end, vel=110)
        if part == 'outro':
            s.add('lead', bar * 4.0, 8, n('A5'), 100)
            s.add('lead', bar * 4.0, 8, n('E5'), 90)
        bar += bars
    return s


# Song 2: Tag / Rennstrecke, GT-artiger Fusion-Rock ------------------------------

def song_sunlit():
    s = Song('sunlit_grid', 'Sunlit Grid (Fusion, Tag/Strecke)', 118)
    s.track('drums', 0, 9, 0.0, 'Drums')
    s.track('bass', 36, 0, 0.0, 'Bass (Slap/Finger)')
    s.track('keys', 4, 1, -0.25, 'E-Piano')
    s.track('pad', 50, 2, 0.15, 'Strings/Pad')
    s.track('lead', 81, 3, 0.1, 'Lead')

    A = [('D3', 'M9'), ('B2', 'm7'), ('G2', 'M7'), ('A2', '7')]
    B = [('E3', 'm7'), ('F#3', 'm7'), ('G3', 'M7'), ('A3', 'sus4')]
    form = [('intro', 4, A), ('A', 8, A + A), ('B', 8, B + B), ('A2', 8, A + A), ('outro', 4, [('D3', 'M9')] * 4)]
    bar = 0
    for part, bars, chords in form:
        for i in range(bars):
            b = (bar + i) * 4.0
            root, kind = chords[i % len(chords)]
            ch = chord(root, kind)
            # Drums: Rock-Groove mit Ghost-Notes
            for e in range(8):
                s.add('drums', b + e * 0.5, 0.2, 42, 85 if e % 2 == 0 else 60)
            for q, k in ((0, 36), (1, 38), (2.5, 36), (3, 38)):
                if part == 'intro' and k == 38 and i < 2:
                    continue
                s.add('drums', b + q, 0.25, k, 112 if k == 38 else 118)
            s.add('drums', b + 1.75, 0.1, 38, 40)
            s.add('drums', b + 3.75, 0.1, 38, 45)
            if i == 0 and part != 'intro':
                s.add('drums', b, 1.0, 49, 105)
            if i == bars - 1 and part in ('A', 'B', 'A2'):
                for k, t in enumerate((3, 3.25, 3.5, 3.75)):
                    s.add('drums', b + t, 0.2, (48, 47, 45, 43)[k], 100)
            # Bass: funky, synkopiert
            r = ch[0] - 12
            for t, iv, v in ((0, 0, 115), (0.75, 12, 90), (1.5, 0, 100), (2, 7, 95), (2.75, 12, 85), (3.5, 10 if '7' in kind else 7, 95)):
                if part == 'intro' and i < 2:
                    break
                s.add('bass', b + t, 0.35, r + iv, v)
            # E-Piano: synkopierte Akkorde
            for t, d in ((0, 0.9), (1.5, 0.4), (2.5, 1.2)):
                for m in ch[1:] + [ch[0] + 12]:
                    s.add('keys', b + t, d, m + 12, 80)
            if part in ('B', 'outro'):
                for m in ch:
                    s.add('pad', b, 3.9, m + 12, 60)
        if part in ('A', 'A2'):
            s.melody('lead', bar, 'F#5:3 E5:1 F#5:2 A5:2 | B5:4 A5:2 F#5:2 | G5:3 F#5:1 E5:2 D5:2 | E5:6 R:2 |'
                                  ' F#5:3 E5:1 F#5:2 A5:2 | D6:4 C#6:2 B5:2 | A5:2 G5:2 F#5:2 E5:2 | D5:6 R:2', vel=100)
        if part == 'B':
            s.melody('lead', bar, 'B5:2 G5:2 E5:4 | C#6:2 A5:2 F#5:4 | D6:3 C#6:1 B5:2 F#5:2 | E5:4 A5:4 |'
                                  ' B5:2 G5:2 E5:4 | C#6:2 A5:2 F#5:4 | D6:2 E6:2 F#6:2 E6:2 | C#6:6 A5:2', vel=105)
        if part == 'outro':
            s.melody('lead', bar, 'F#5:3 E5:1 F#5:2 A5:2 | D6:8 | R:8 | R:8', vel=95)
        bar += bars
    return s


SONGS = {'midnight': song_midnight, 'sunlit': song_sunlit}


# MIDI-Export -------------------------------------------------------------------

def write_midi(s, path):
    tpb = 480
    mf = mido.MidiFile(type=1, ticks_per_beat=tpb)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage('track_name', name=s.title, time=0))
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(s.bpm), time=0))
    meta.append(mido.MetaMessage('time_signature', numerator=4, denominator=4, time=0))
    mf.tracks.append(meta)
    for key, t in s.tracks.items():
        tr = mido.MidiTrack()
        tr.append(mido.MetaMessage('track_name', name=t['label'], time=0))
        if t['channel'] != 9:
            tr.append(mido.Message('program_change', program=t['program'], channel=t['channel'], time=0))
        ev = []
        for b, d, m, v in t['notes']:
            ev.append((int(round(b * tpb)), 1, m, v))
            ev.append((int(round((b + d) * tpb)), 0, m, 0))
        ev.sort(key=lambda e: (e[0], e[1]))
        now = 0
        for tick, on, m, v in ev:
            typ = 'note_on' if on else 'note_off'
            tr.append(mido.Message(typ, note=m, velocity=v, channel=t['channel'], time=tick - now))
            now = tick
        mf.tracks.append(tr)
    mf.save(path)


# Vorschau-Synth ----------------------------------------------------------------

def lp(x, fc, order=2):
    b, a = butter(order, min(fc, SR * 0.45) / (SR / 2), 'low')
    return lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = butter(order, fc / (SR / 2), 'high')
    return lfilter(b, a, x)


def bp(x, f1, f2):
    b, a = butter(2, [f1 / (SR / 2), f2 / (SR / 2)], 'band')
    return lfilter(b, a, x)


def saw(f, tt, ph=0.0):
    return 2 * ((f * tt + ph) % 1.0) - 1


def adsr(nsamp, a, d, s, r, gate):
    tt = np.arange(nsamp) / SR
    e = np.where(tt < a, tt / max(a, 1e-4), s + (1 - s) * np.exp(-(tt - a) / max(d, 1e-4)))
    rel = tt > gate
    e[rel] *= np.exp(-(tt[rel] - gate) / max(r, 1e-4))
    return e


def inst(key, song, m, dur, vel):
    v = vel / 127
    f = hz(m)
    if key == 'drums':
        return drum(m, v)
    tail = {'pad': 0.6, 'lead': 0.25, 'keys': 0.35}.get(key, 0.08)
    nsamp = int(SR * (dur + tail))
    tt = np.arange(nsamp) / SR
    if key == 'lead':
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * tt) * np.clip((tt - 0.15) * 4, 0, 1)
        x = sum(saw(f * vib * (1 + dt), tt, rng.random()) for dt in (-0.012, -0.006, 0, 0.006, 0.012)) / 3
        x = lp(x, 5500 if song == 'midnight' else 3200)
        return 0.32 * v * x * adsr(nsamp, 0.01, 0.4, 0.75, 0.18, dur)
    if key == 'pad':
        x = sum(saw(f * (1 + dt), tt, rng.random()) for dt in (-0.008, 0, 0.008)) / 3
        return 0.13 * v * lp(x, 1800) * adsr(nsamp, 0.35, 1.0, 0.8, 0.5, dur)
    if key == 'arp':
        x = np.sign(np.sin(2 * np.pi * f * tt)) * 0.6 + saw(f, tt) * 0.4
        return 0.12 * v * lp(x, 3500) * adsr(nsamp, 0.002, 0.08, 0.0, 0.05, dur)
    if key == 'stab':
        x = sum(saw(f * (1 + dt), tt) for dt in (-0.005, 0.005)) / 2
        return 0.16 * v * lp(x, 2600) * adsr(nsamp, 0.01, 0.15, 0.3, 0.08, dur)
    if key == 'bass':
        if song == 'midnight':
            x = saw(f, tt) * 0.7 + np.sign(np.sin(2 * np.pi * f / 2 * tt)) * 0.3
            return 0.42 * v * lp(x, 900) * adsr(nsamp, 0.002, 0.12, 0.35, 0.04, dur)
        x = saw(f, tt)
        return 0.5 * v * lp(x, 750) * adsr(nsamp, 0.002, 0.15, 0.25, 0.05, dur)
    if key == 'keys':  # FM-E-Piano
        ie = 1.6 * np.exp(-tt / 0.35)
        x = np.sin(2 * np.pi * f * tt + ie * np.sin(2 * np.pi * f * tt))
        x += 0.15 * np.sin(2 * np.pi * f * 14 * tt) * np.exp(-tt / 0.03)
        return 0.11 * v * x * adsr(nsamp, 0.002, 0.9, 0.3, 0.25, dur)
    raise KeyError(key)


def drum(m, v):
    if m == 36:  # Kick
        tt = np.arange(int(SR * 0.35)) / SR
        f = 45 + 110 * np.exp(-tt / 0.03)
        return 0.9 * v * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.12)
    if m in (38, 39):  # Snare / Clap
        ln = 0.22
        tt = np.arange(int(SR * ln)) / SR
        nz = rng.uniform(-1, 1, len(tt))
        if m == 38:
            body = np.sin(2 * np.pi * 190 * tt) * np.exp(-tt / 0.04)
            return 0.55 * v * (0.6 * bp(nz, 1200, 8000) * np.exp(-tt / 0.07) + 0.5 * body)
        env = sum(np.exp(-np.clip(tt - o, 0, None) / 0.012) * (tt >= o) for o in (0, 0.01, 0.02)) + np.exp(-tt / 0.06) * 0.5
        return 0.35 * v * bp(nz, 900, 4000) * env
    if m in (42, 46):  # HiHat
        ln = 0.05 if m == 42 else 0.22
        tt = np.arange(int(SR * ln)) / SR
        return 0.22 * v * hp(rng.uniform(-1, 1, len(tt)), 7000) * np.exp(-tt / (0.015 if m == 42 else 0.08))
    if m == 49:  # Crash
        tt = np.arange(int(SR * 1.6)) / SR
        return 0.25 * v * hp(rng.uniform(-1, 1, len(tt)), 4500) * np.exp(-tt / 0.5)
    if m in (43, 45, 47, 48):  # Toms
        tt = np.arange(int(SR * 0.3)) / SR
        f0 = {43: 90, 45: 110, 47: 135, 48: 165}[m]
        f = f0 * (1 + 0.5 * np.exp(-tt / 0.02))
        return 0.6 * v * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.12)
    return np.zeros(1)


# Lautstärke je Spur in der Vorschau (Mischpult)
GAIN = {('midnight_line', 'drums'): 0.7, ('midnight_line', 'lead'): 1.9, ('midnight_line', 'arp'): 4.0,
        ('midnight_line', 'pad'): 2.5, ('midnight_line', 'stab'): 3.5, ('midnight_line', 'bass'): 1.1,
        ('sunlit_grid', 'drums'): 0.75, ('sunlit_grid', 'lead'): 1.6, ('sunlit_grid', 'pad'): 2.2,
        ('sunlit_grid', 'keys'): 1.2}


def render(s, stems=False):
    spb = 60.0 / s.bpm
    total = int(SR * (s.beats * spb + 2.5))
    mixbuf = np.zeros((total, 2))
    stem_bufs = {}
    for key, t in s.tracks.items():
        buf = np.zeros(total)
        for b, d, m, v in t['notes']:
            x = inst(key, s.name.split('_')[0], m, d * spb, v)
            st = int(b * spb * SR)
            e = min(total, st + len(x))
            buf[st:e] += x[:e - st]
        if key == 'lead':  # Echo auf der Melodie
            dl = int(SR * spb * 0.75)
            echo = np.zeros(total)
            echo[dl:] = buf[:-dl] * 0.25
            echo[2 * dl:] += buf[:-2 * dl] * 0.1
            buf = buf + lp(echo, 3000)
        if key == 'pad' or key == 'stab':
            buf = buf + 0.3 * lp(np.concatenate([np.zeros(int(SR * 0.09)), buf[:-int(SR * 0.09)]]), 2500)
        buf = buf * GAIN.get((s.name, key), 1.0)
        pan = t['pan']
        mixbuf[:, 0] += buf * np.sqrt(0.5 * (1 - pan))
        mixbuf[:, 1] += buf * np.sqrt(0.5 * (1 + pan))
        if stems:
            stem_bufs[key] = buf
    # Sidechain-Pumpen (typisch Eurobeat/Dance) für Pad + leichtes Limiting
    peak = np.max(np.abs(mixbuf)) or 1
    mixbuf = np.tanh(mixbuf / peak * 1.3) / np.tanh(1.3) * 0.89
    return mixbuf, stem_bufs


def write_wav(path, x):
    x = np.atleast_2d(x.T).T if x.ndim == 1 else x
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(pcm.shape[1] if pcm.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main(args):
    stems = '--stems' in args
    names = [a for a in args if not a.startswith('--')] or list(SONGS)
    os.makedirs(MIDI_DIR, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for nm in names:
        s = SONGS[nm]()
        write_midi(s, os.path.join(MIDI_DIR, s.name + '.mid'))
        mixbuf, sb = render(s, stems)
        wav = os.path.join(OUT, s.name + '.wav')
        write_wav(wav, mixbuf)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5',
                        wav[:-4] + '.ogg'], check=False)
        if stems:
            d = os.path.join(OUT, s.name + '_stems')
            os.makedirs(d, exist_ok=True)
            pk = max(np.max(np.abs(b)) for b in sb.values()) or 1
            for k, b in sb.items():
                write_wav(os.path.join(d, f'{k}.wav'), b / pk * 0.9)
        print(f'{s.title}: {s.bpm} BPM, {len(mixbuf) / SR:.0f} s, {sum(len(t["notes"]) for t in s.tracks.values())} Noten')


if __name__ == '__main__':
    main(sys.argv[1:])
