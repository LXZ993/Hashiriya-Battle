#!/usr/bin/env python3
"""Schreibt CHANGELOG.md als aufklappbare Versionen (<details>) ins Handbuch (Abschnitt "Changelog").

Aufruf (im Mod-Ordner):  python3 tools/changelog_handbuch.py
Ersetzt in docs/handbuch.html alles zwischen <!-- CHANGELOG-START --> und <!-- CHANGELOG-ENDE -->.
Jede "## <Version>"-Überschrift wird ein eigener Spoiler, neueste oben.
"""
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
START, ENDE = '<!-- CHANGELOG-START -->', '<!-- CHANGELOG-ENDE -->'


def inline(text):
    t = html.escape(text, quote=False)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', t)
    return t


def section_html(body):
    out, in_list = [], False
    for raw in body.splitlines():
        line = raw.strip()
        if line.startswith('- '):
            if not in_list:
                out.append('<ul>')
                in_list = True
            out.append('<li>' + inline(line[2:]) + '</li>')
            continue
        if in_list:
            out.append('</ul>')
            in_list = False
        if line.startswith('### '):
            out.append('<h4>' + inline(line[4:]) + '</h4>')
        elif line:
            out.append('<p>' + inline(line) + '</p>')
    if in_list:
        out.append('</ul>')
    return '\n'.join(out)


def main():
    md = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    parts = re.split(r'(?m)^## ', md)[1:]
    blocks = []
    for part in parts:
        head, _, body = part.partition('\n')
        m = re.match(r'(.*?)\s*\((.*)\)\s*$', head.strip())
        ver, info = (m.group(1), m.group(2)) if m else (head.strip(), '')
        summary = '<b>' + inline(ver) + '</b>' + (' <small>' + inline(info) + '</small>' if info else '')
        blocks.append('<details class="cl">\n<summary>' + summary + '</summary>\n<div>\n' + section_html(body) + '\n</div>\n</details>')
    hb_path = ROOT / 'docs' / 'handbuch.html'
    hb = hb_path.read_text(encoding='utf-8')
    if START not in hb or ENDE not in hb:
        sys.exit('Marker CHANGELOG-START/ENDE fehlen in docs/handbuch.html')
    a, b = hb.index(START) + len(START), hb.index(ENDE)
    hb = hb[:a] + '\n' + '\n'.join(blocks) + '\n' + hb[b:]
    hb_path.write_text(hb, encoding='utf-8')
    print(f'{len(blocks)} Versionen ins Handbuch geschrieben')


if __name__ == '__main__':
    main()
