"""Schreibt die Listen im Google-Script wanderer-formular.gs neu (Crews, Leader, Wanderer, Bosse, Avatar-Teile).

Nach Änderungen am Roster (rivals.json) oder an den Teilen des Silhouetten-Tools ausführen:
    python3 tools/community/build_form_lists.py
Danach das Script in Google Apps Script ersetzen und "formularAnlegen" erneut ausführen (neues Formular).
"""
import json, os, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RIVALS = os.path.join(ROOT, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data', 'rivals.json')
GS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wanderer-formular.gs')

# Avatar-Teile aus tools/silhouette/silhouetten.html (Slot-Schlüssel und Teil-IDs müssen dort existieren).
# Englischer Text fürs Formular. "w" = nur für Frauen, "m" = nur für Männer.
# Crew-Teile (Crewfarbe, Crew-Zeichen) fehlen absichtlich: Wanderer gehören zu keiner Crew.
AVATAR = [
    ('kopf', 'Head shape', [
        ('rund', 'Bob (standard)'), ('oval', 'Egg'), ('kantig', 'Angular'), ('breit', 'Wide'),
        ('schmal', 'Narrow'), ('kinn', 'Pointed chin')]),
    ('gesicht', 'Face (eyes on the visor display)', [
        ('normal', 'Normal'), ('grimmig', 'Grim'), ('muede', 'Bored'), ('fokus', 'Focused'),
        ('grinsen', 'Grin ^^'), ('traurig', 'Sad'), ('zwinkern', 'Wink'), ('zyklop', 'One eye'), ('aus', 'Display off')]),
    ('haare', 'Hair or hat', [
        ('bobcut', 'Bob cut', 'w'), ('hime', 'Long with bangs', 'w'), ('wellen', 'Long waves', 'w'),
        ('zoepfe', 'Two pigtails', 'w'), ('kahl', 'Bald', 'm'), ('kurz', 'Short'), ('scheitel', 'Side parting'),
        ('stachel', 'Spiky'), ('tolle', 'Pompadour'), ('lang', 'Long'), ('zopf', 'Ponytail'), ('dutt', 'Bun'),
        ('irokese', 'Mohawk'), ('cap', 'Cap'), ('capback', 'Cap backwards'), ('muetze', 'Beanie'),
        ('stirnband', 'Headband'), ('bandana', 'Bandana')]),
    ('haarfarbe', 'Hair colour', [
        ('schwarz', 'Black'), ('braun', 'Dark brown'), ('rotbraun', 'Auburn'), ('blond', 'Bleached blond'),
        ('silber', 'Silver grey')]),
    ('brille', 'Glasses', [
        ('keine', 'None'), ('sonne', 'Sunglasses'), ('wrap', 'Sports glasses'), ('rund', 'Round glasses'),
        ('halb', 'Half-rim glasses'), ('goggles', 'Goggles on the forehead'), ('klappe', 'Eye patch')]),
    ('jacke', 'Top / jacket', [
        ('sukajan', 'Sukajan (souvenir jacket)'), ('hawaii', 'Hawaiian shirt'), ('jeans', 'Denim jacket'),
        ('weste', 'Shirt with vest'), ('warnweste', 'Work jacket with hi-vis vest'), ('militaer', 'Military jacket'),
        ('windbreaker', 'Windbreaker'), ('strick', 'Cardigan'), ('polo', 'Polo shirt'),
        ('bluse', 'Blouse with bow', 'w'), ('kostuem', 'Blazer', 'w'), ('pelz', 'Coat with fur collar'),
        ('rollkragen', 'Turtleneck'), ('hoodie', 'Hoodie'), ('bomber', 'Bomber jacket'), ('leder', 'Leather jacket'),
        ('anzug', 'Suit and tie', 'm'), ('training', 'Track jacket'), ('tshirt', 'T-shirt'),
        ('overall', 'Mechanic overalls'), ('mantel', 'Coat with high collar'),
        ('tokko', 'Tokkō coat (long embroidered coat)'), ('racing', 'Racing jacket')]),
    ('ton', 'Clothing colour', [
        ('graphit', 'Graphite'), ('nachtblau', 'Navy'), ('braun', 'Brown'), ('oliv', 'Olive'),
        ('hell', 'Light grey'), ('weinrot', 'Burgundy')]),
    ('extra', 'Extra on the head', [
        ('keins', 'None'), ('spange', 'Hair clip', 'w'), ('zigarette', 'Cigarette'), ('zahnstocher', 'Toothpick'),
        ('maske', 'Face mask'), ('headset', 'Headset'), ('ohrring', 'Earrings'), ('kratzer', 'Scratches'),
        ('pflaster', 'Plaster')]),
    ('hals', 'Extra around the neck', [
        ('keins', 'None'), ('kopfhoerer', 'Headphones'), ('kette', 'Necklace'), ('schal', 'Scarf'),
        ('handtuch', 'Towel'), ('hundemarke', 'Dog tag'), ('halstuch', 'Neckerchief')]),
    ('patch', 'Patch on the jacket', [
        ('keiner', 'None'), ('nummer', 'Race number'), ('sponsor', 'Sponsor patch'), ('kanji', 'Kanji stripe')]),
]


def js(v):
    return json.dumps(v, ensure_ascii=False)


def main():
    d = json.load(open(RIVALS, encoding='utf-8'))
    teams = [[t['id'], t['name']] for t in d['teams']]
    tname = dict(teams)
    rivals = d['rivals']
    leaders = [[r['id'], r['name'] + ' – ' + tname.get(r.get('team'), '')] for r in rivals if r.get('leader')]
    members = [[r['id'], r['name'], tname.get(r.get('team'), '')] for r in rivals if r.get('team')]
    wanderers = [[r['id'], r['name']] for r in rivals if r.get('wanderer') and not r.get('community')]
    bosses = [[r['id'], r['name']] for r in rivals if r.get('boss')]
    avatar = []
    for key, title, parts in AVATAR:
        opts = []
        for p in parts:
            label = p[1] + {'w': ' (women)', 'm': ' (men)'}.get(p[2] if len(p) > 2 else '', '')
            opts.append([p[0], label] + ([p[2]] if len(p) > 2 else []))
        avatar.append({'key': key, 'title': 'Avatar: ' + title, 'opts': opts})

    out = ['// --- ERZEUGT von tools/community/build_form_lists.py aus rivals.json, nicht von Hand ändern ---']
    out.append('var TEAMS = ' + js(teams) + ';')
    out.append('var LEADERS = ' + js(leaders) + ';')
    out.append('// Alle Crew-Mitglieder (id, Name, Crew) für die Namenssuche beim Export')
    out.append('var MEMBERS = ' + js(members) + ';')
    out.append('var WANDERERS = ' + js(wanderers) + ';')
    out.append('var BOSSES = ' + js(bosses) + ';')
    out.append('// Avatar-Teile (Slot im Silhouetten-Tool, Titel, [Teil-ID, Text, nur w/m])')
    out.append('var AVATAR = ' + js(avatar) + ';')
    out.append('// --- ENDE ERZEUGT ---')
    block = '\n'.join(out)

    gs = open(GS, encoding='utf-8').read()
    gs, n = re.subn(r'// --- ERZEUGT.*?// --- ENDE ERZEUGT ---', lambda m: block, gs, flags=re.S)
    if n != 1:
        raise SystemExit('Markierung "// --- ERZEUGT" im Script nicht gefunden')
    open(GS, 'w', encoding='utf-8').write(gs)
    print(f'{len(teams)} Crews, {len(leaders)} Leader, {len(members)} Mitglieder, {len(wanderers)} Wanderer, '
          f'{len(bosses)} Bosse, {len(avatar)} Avatar-Felder -> {os.path.relpath(GS, ROOT)}')


if __name__ == '__main__':
    main()
