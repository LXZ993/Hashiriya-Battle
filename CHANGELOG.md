# Changelog Hashiriya Battle

## Alpha 1 (Stand 29.10.2026)

Alle Änderungen seit dem Testbuild von Henry (Stand 28.10.2026 vormittags, Commit 23d4ccd).

### Battles und Rivalen
- Mehrere Rivalen fahren gleichzeitig im Verkehr (bis zu 4). Geschlagene fahren weiter und kommen später als Revanche zurück.
- Rivalen fahren nachts mit Licht. Einzelne Rivalen können später ohne Licht als Markenzeichen fahren.
- Rivalen spawnen weiter weg, nicht mehr auf Auffahrten, und rollen direkt mit Reisetempo los. Festhängende werden neu angeschoben oder entfernt.
- Rivalen-Radar im HUD mit Farben: orange Rivale, gelb Leader, lila Wanderer, rot Boss, grau besiegt, blau verloren.
- Herausfordern ist gesperrt, wenn der Tempounterschied über 30 km/h liegt („Zu schnell“ / „Zu langsam“).
- Herausfordern geht nur noch bis 30 m hinter dem Gegner.
- Vor dem Countdown gleicht der Tempomat das Tempo an und holt zum Gegner auf. Der Countdown startet erst, wenn man nah genug dran ist.
- Im Countdown sperrt der Tempomat das Gas. Wer vorfährt oder zu schnell wird, macht einen Frühstart.
- Leader: Hinweis nach dem letzten Teammitglied. Manche Leader kommen noch in derselben Nacht, andere erst in der nächsten. Ein bereiter Leader wird bevorzugt gespawnt.
- Kein Battle-Limit mehr pro Nacht.
- Rivalen fordern dich jetzt auch selbst heraus: Fährt einer eine Weile hinter dir, gibt er Lichthupe. Warnblinker = annehmen, Blinker links oder rechts = ablehnen.

### Ruf, Serie und Combo
- Siegesserie: mehr Preisgeld und Ruf für Siege hintereinander. Sie endet bei einer Niederlage, in der Garage, zu Hause oder bei Tagesanbruch.
- Fahrstil-Combo nur während eines Battles in der Nacht: knapp vorbei, hauchdünn, knapp überholt, Windschatten, Drift, Vollgas im Verkehr. Ein Unfall löscht die Combo.
- Statistik-Seite im Menü.
- Radarfallen zählen nur, wenn man geblitzt wird. Wer alle auslöst, lockt einen Wanderer an.

### Rivalen-Lexikon
- Das Lexikon ist überall im Menü erreichbar.
- Merkliste mit bis zu 5 Rivalen, angezeigt im HUD. Nach einem Sieg wird der Rivale gestrichen.
- Beim Leader steht der Status (wartet auf Mitglieder, ab nächster Nacht, unterwegs).

### Neues Spiel und Startautos
- Tasten-Check vor dem Start: zeigt, ob Lichthupe, Warnblinker, Blinker links/rechts und das Hashiriya-Menü belegt sind. „Belegen“ öffnet die BeamNG-Steuerung direkt für die fehlende Taste.
- Auswahl Neuling oder Erfahren. Neulinge sehen das Tutorial mit 7 Seiten (Bilder folgen).
- Seed-System: Fahrername und Kennzeichen bestimmen, welche 3 von 13 Gebrauchtwagen angeboten werden. Laufleistung, Zustand und Tankfüllung werden gewürfelt.
- Startautos sind gebraucht: Laufleistung, Verschleiß und älterer Lack. Ein gebrauchter Motor setzt leicht aus und wird schneller warm, aber spielbar.
- Der Tank ist beim Kauf nie unter 25 %.
- Der Kaufpreis des Starterautos wird vom Startkapital abgezogen.
- Der Showroom ist jetzt die Werkstatt der C1-Map. Nach dem Kauf steht das Auto in der Garagenbucht.

### Tag, Nacht und Zuhause
- Ein Spieltag dauert jetzt 36 statt 24 Minuten, die Nacht (20 bis 6 Uhr) also 15 Minuten.
- HUD zeigt immer Uhrzeit, Wochentag und Datum.
- Die Spieluhr läuft immer weiter und bleibt nicht mehr stehen.
- Verkehr richtet sich nach der Uhrzeit: tagsüber voll, nachts weniger. Er wird beim Start auch eingeschaltet, wenn er im BeamNG-Hauptmenü aus war.
- Schlafen zu Hause: tagsüber bis 20 Uhr, zwischen 20 und 22 Uhr gesperrt, ab 22 Uhr bis 6 Uhr morgens.
- Nickerchen im Auto auf Parkplätzen (Shibaura PA, Tatsumi PA und an den Buchten): 0,5 bis 2 Stunden.

### Shop und Garage
- Shop zu Fuß: Menü am Eingang, Kamera vom Eingang aufs Auto. Während des Shoppens ist das Auto festgesetzt, ein Knopf „Shop verlassen“ beendet den Besuch.
- Öffnungszeiten 8 bis 20 Uhr. Außerhalb kommt ein Hinweis mit den Zeiten.
- Warenkorb mit Gesamtbetrag (einzeln entfernen, alles kaufen, leeren). Fahrzeugwerte zeigen Änderungen grün oder rot.
- Teile-Kategorien überarbeitet: Motor, Karosserie, Stoßstangen und Extras zeigen jetzt die richtigen Teile, auch beim 200BX.
- Die transparente Teileansicht verschwindet beim Verlassen.
- Der Tank ist im Garagen-Setup nicht mehr einstellbar. Der Tankinhalt bleibt bei Respawn, Reparatur und Zurücksetzen erhalten.

### Tanken
- Tanken mit gedrückter Taste funktioniert durchgehend. Der Tanksound stoppt sauber.

### HUD und Menü
- HUD-Layout von Alex übernommen (Schaden unten, Navigation).
- Status-App größer und unter den Hinweisen, nichts wird mehr oben abgeschnitten.
- „Position merken“ funktioniert auch an der Garage am Kartenursprung.

### Release-Vorbereitung (in der Alpha noch aus)
- Release-Schalter in data/build.json: sperrt Zurücksetzen, Konsole, Editor, Zeitlupe, Schnellreise über die Karte und Uhrzeit-Änderungen über Time & Weather.
- Node-Grabber bleibt erlaubt, mit fester Stärke.
