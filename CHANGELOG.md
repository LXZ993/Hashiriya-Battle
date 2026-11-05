# Changelog Hashiriya Battle

## Alpha 0.9.2 (Stand 04.11.2026)

### Neue Haupt-PAs und Reisen
- Neu: zwei Haupt-PAs, gesetzt von JDMArsch (LXZ aka. LXZockt): **Heiwajima PA** und **Oi PA (Westbound)**, je mit 16 Parkbuchten. Dort parken Autos, Fahrer stehen zum Reden bereit, Rivalen warten, und man kann im Auto ein Nickerchen machen.
- Alle Haupt-PAs (auch Shibaura und Tatsumi) stehen jetzt auf der großen Karte (M), mit Name, Beschreibung und Vorschaubild. Die Bilder sind noch Platzhalter in `art/pa/`.
- Dev-Version: auf der großen Karte gibt es bei den Haupt-PAs den Knopf Quick Travel, im Dev-Menü bringt „Hin“ dich zum Ankunftspunkt der PA.
- Neu: Reisen. Fährst du an einer Ausfahrt langsam vom C1 ab, kannst du im Menü links ein Ziel wählen: die Garage oder eine Haupt-PA, an der du schon warst. Die Reise spult die Uhr vor und kostet Sprit.
- Start-PA: in der Garage (Reiter Service) unter „Losfahren ab …“ an einer besuchten Haupt-PA starten, mit denselben Kosten.
- Heiwajima PA hat einen Shop für alle Teile (reinfahren und anhalten öffnet das Teile-Terminal) und eine Tankstelle.
- Alle 66 Auf- und Ausfahrten von JDMArsch sind übernommen. Die Auffahrten sind für den Map-Wechsel nach 1.0 vorbereitet.

### Lackierbare Japan-Liveries
- Neu: 4 moderne Werks-Tech-Stile nach neuen Vorlagen von JDMArsch (LXZ aka. LXZockt): Keil mit Schrägschnitten, Schicht-Balken, Pfeilband und Zielflagge. Zu finden auf Pessima Mk2, Covet, Sunburst und SBR4.
- Neu: 5 Stile mit echten BeamNG-Lore-Logos als Sponsoren: Sponsor-Rennwagen (JGTC-Stil), D1-Profi-Drift, Tuning-Shop-Demo-Car, Rallye Gruppe A und Firmenwagen (Pigeon/Hopper). Je Auto nur, wo es zu Baujahr und Antrieb passt; insgesamt 16 Stile und 67 Lackdesigns. Jedes Auto hat bei diesen Stilen ein eigenes Layout und einen eigenen Hauptsponsor, keine Kopie.
- Neu: 6 aufwendigere Stile mit anderen Vorbildern: Wa-Muster (Seigaiha, Asanoha, Kikkō, Hanko-Stempel), Manga-Speed (Raster, Speedlines, Soundwörter), Splitter-Tarn, Gruppe C Retro, JGTC-Wellen und Kanjo-Zoku. Jedes Auto mit eigenem Layout, insgesamt 95 Lackdesigns.
- Neu: Liveries können jetzt auch feste, nicht einfärbbare Farben haben (Gold, Stempel, Warnstreifen, Sponsoren in Originalfarbe).
- Geändert: Die älteren Sponsor-, Rallye-, Drift-, Shop-Demo-, Rennteam- und Firmen-Stile nutzen jetzt auch feste Farben: weiße Nummernfelder und Rallyeschilder, kleine Sponsoren als Aufkleber in Markenfarbe, Firmenlogos in fester Firmenfarbe.
- Geändert: Jedes Auto hat nur noch die Stile, die zu Baujahr und Antrieb passen. Kein Drift auf Fronttrieblern, kein Bosozoku, Kaido oder Zweifarben auf modernen Autos, dafür Drift auf dem Sunburst.
- Neu: 63 Lackdesigns für alle 9 Japan-Autos (Pessima Mk1 und Mk2, 200BX, Covet, Hopper, Miramar, Pigeon, Sunburst, SBR4) in 7 Stilen: Street-Drift Flammen, Street-Drift Team, Werks-Sportstreifen, Bosozoku, Kaido-Racer, Werks-Zweifarben und Werks-Rennteam.
- Alle Entwürfe sind in VectorCraft nach den Vorlagen von JDMArsch (LXZ aka. LXZockt) gezeichnet und laufen sauber über Säule, Dach und Haube.
- Lackierbar wie der Vanilla-Skin „Custom“: Farbe 1 ist der Grundlack, Farbe 2 und Farbe 3 färben die Livery. Zu finden im Konfigurator unter Lackdesign als „Hashiriya: … (Colorable)“. Alle Sponsoren sind erfunden oder BeamNG-Lore.
- Jeder Stil hat 3 Formvarianten, verteilt auf die Autos. Jedes Auto trägt seine eigene Marke (Ibishu oder Hirochi), eigene Texte, Teams und Nummern, und als Sponsoren die BeamNG-Lore-Logos aus dem Spiel (DriftGear, Okudai, Wangan, GripAll und andere).
- Zu jeder Lackierung gibt es eine .vectorcraft-Datei und eine PSD mit Ebenen zum Feinjustieren (Details im Handbuch, Kapitel 12g).

### Blitzer und Polizei
- Neu: Tagsüber gelten Tempolimits. Blitzer sind die 45 festen Radarfallen der C1, dazu macht die Polizei ab und an Laserkontrollen. Nachts wird nicht gemessen.
- Blitzer: wer zu schnell an einer Radarfalle vorbeifährt, wird geblitzt und zahlt ein Bußgeld, je schneller desto teurer. Gezählt wird pro Spieltag: 1. und 2. Mal nur Geld, ab dem 3. Mal kommt zusätzlich die Polizei.
- Laserkontrolle: an ein paar Polizeistellen steht pro Tag für ein paar Stunden ein Streifenwagen. Wer dort zu schnell ist, wird sofort verfolgt. Am Anfang sind es 1 bis 2 Kontrollen am Tag, mit steigendem Rang werden es mehr, weil sich die nächtlichen Rennen herumsprechen.
- Minimap und Radar zeigen eine Kontrolle erst, wenn du sie an dem Tag schon gesehen hast. Streifenwagen einer Fahndung blinken dort rot, Kontrollen sind weißgrau. Alles Polizeilicht ist rot wie in Japan, auch die Blitzlichter am Sunburst-Streifenwagen und „POLIZEI“ im Status.
- Fahndung mit 1 bis 3 Sternen oben rechts im Status. 1 Stern: die Polizei fährt hinterher und will, dass du anhältst (Strafzettel). 2 Sterne (weiter geflohen, Unfälle, noch mal geblitzt oder heute schon einen Strafzettel): sie überholt dich und bremst dich aus. 3 Sterne: sie rammt dich. Anhalten bei 3 Sternen = Festnahme, hohe Strafe und Abschleppen zur Garage.
- Entkommen: bleib lange genug außer Sicht, dann gibt die Polizei auf. Das bringt etwas Ruf (weniger als ein Rivalensieg, nur 3 Mal pro Tag).
- Während einer Fahndung gehen Speichern, Nickerchen, Abschleppen, Parkplatz-Menüs und Herausfordern nicht.
- Polizeistellen setzt du im Dev-Menü (Typ „Polizei / Messstelle“: Laser oder eigener Blitzer, Tempolimit, Richtung, „immer besetzt“ zum Testen; der Dienstplan von heute steht unter Werkzeuge). Alle Werte in data\police.json, Testknöpfe im Dev-Menü unter Werkzeuge.

### Aufkleber
- Neu in der Garage: Reiter „Aufkleber“. Klebe die Logos aus deiner Trophäenwand auf dein Auto, wie die Sticker in TXR: Crew-Logos und -Symbole (auch in Leader-Gold), Wanderer-Siegel, Boss-Embleme und das 走.
- Ansicht wählen, Größe, Drehung und Lage einstellen, dann aufkleben. Jeder Aufkleber kostet 3.000 ¥, Entfernen ist kostenlos.
- Die Aufkleber bleiben dauerhaft auf dem Auto und lassen sich später weiter bearbeiten.

### Aura
- Neu wie in TXR: Rivalen haben nachts eine Aura in ihrer Farbe, ein weicher Schein unter dem Auto. Crews in Crew-Farbe, Leader mit goldenem Saum, Wanderer und Bosse in der Farbe ihres Siegels.
- Im Battle wird die Aura heller, pulsiert und bekommt einen Leuchtsaum um die Karosserie. Je weniger SP der Fahrer hat, desto schwächer leuchtet sie.
- Deine eigene Aura bekommst du nur von dem Gegner, dem sie gehört, nach dem Sieg gegen ihn. In der Trophäenwand im neuen Reiter „Auren“ legst du sie an, wählst wann (nachts immer, nur im Battle, aus) und wie stark.
- Effekte wie Gewitterwolken, Blitze oder Regen ums Auto kommen nach 1.0.

### Schwarzes Brett (HashiNet-Forum)
- Neu: Im Garagen-PC gibt es den Reiter „Schwarzes Brett“, das Forum der Szene. Die Zahl am Reiter zeigt neue Beiträge.
- Gerüchte über Wanderer und Bosse, die du bald treffen kannst. Jeden Tag verrät ein Gerücht etwas anderes (Uhrzeit, Automarke, gesuchtes Teil, welche Crew erst fallen muss), nie die ganze Bedingung. Wer mitliest, kann sich den Rest zusammenreimen. Gekaufte Tipps bleiben trotzdem genauer.
- Crew-News: wie viele Fahrer einer Crew du schon geschlagen hast, wann der Leader selbst rausfährt, wer gerade besiegt wurde und welche Crew neu in der Szene ist (mit Crew-Logo).
- Nachtbericht: wen du in der letzten Nacht geschlagen hast. Dazu Szene-Beiträge, Wissen über Japan und die C1, Kleinanzeigen und Anzeigen zu den heutigen Nebenjobs.
- Filter: Alle, Gerüchte, Crews, Szene, Jobs, dazu die Suche oben im Terminal.
- Auch an den PAs lesbar: Mit dem neuen Ort-Typ „Schwarzes Brett (Aushang)“ im Dev-Menü setzt du Aushänge. Dort steht „[T] Schwarzes Brett lesen“ (zu Fuß oder im stehenden Auto), das Brett öffnet sich im Menü links. Weggehen schließt es.
- Alle Texte und Einstellungen in data\board.json.

### Neue Nebenjobs: Taxischicht und Lieferrunde
- Neu am Jobbrett: die Taxischicht. Ein Firmentaxi (Pessima mit Shinonome- oder Gekkō-Lackierung) steht neben dir, dein Auto bleibt stehen. Drei Fahrgäste abholen und hinbringen, danach das Taxi zurück zum Depot.
- Bezahlt wird per Taxameter (Grundpreis + Kilometer) plus Trinkgeld. Trinkgeld kosten: zu schnell fahren (Tempolimit 80 km/h, die Statusanzeige warnt), ruckartiges Bremsen und Beschleunigen, Schaden und Verspätung. Jede Fahrt bekommt 1 bis 5 Sterne, und der Fahrgast sagt dir seine Meinung.
- Zu viel Schaden in einer Fahrt: der Fahrgast steigt aus und zahlt nichts. Die Reparatur des Taxis zieht die Firma am Schichtende vom Lohn ab. Abbrechen zahlt aus, was du bis dahin verdient hast.
- Das Taxi zählt nicht als dein Auto: dein Tank, Schaden und Zustand bleiben unberührt, Battles gibt es im Taxi nicht.
- Neu: die Lieferrunde. Mit dem eigenen Auto 3 bis 4 Stopps nacheinander anfahren, eine Gesamtzeit. Läuft die Zeit ab, werden nur die gelieferten Stopps bezahlt.
- Jetzt fünf Aufträge pro Tag am Brett (höchstens vier erledigen). Neue Ort-Typen im Dev-Menü: „Taxi: Fahrgast-Punkt“ und „Taxi-Depot“.
### Crew-Battles, Ablehnen und Wetten
- Neu wie in TXR 2025: Leader und Bosse fahren mit zwei Begleitern im Konvoi. Forderst du einen aus der Gruppe heraus, fährst du nacheinander gegen alle: erst die Begleiter von hinten nach vorne, zuletzt der Leader oder Boss. Oben steht „KETTE 1/3“. Nach jedem Sieg wartet der nächste auf dich.
- Eine Niederlage (oder ein Frühstart) lässt die Kette reißen: die Gruppe fährt wieder zusammen, beim nächsten Mal geht es von vorn los. Leader nehmen Leute aus ihrer Crew mit, Bosse die Leader der Crews, die du vorher schlagen musstest.
- Crew-Taktik: Während du gegen jemanden aus der Gruppe fährst, blocken die anderen Begleiter für ihn. Sie setzen sich knapp vor dich, bremsen mit und machen die Linie zu. Gegen einen Leader blocken auch seine Crew-Mitglieder, die gerade unterwegs sind. Unten steht dann „BLOCKT“.
- Rivalen lehnen jetzt sichtbar ab: will einer nicht (gerade erst gegen dich gefahren, Nacht-Limit erreicht oder einfach keine Lust), setzt er den Blinker und in der Bildschirmmitte erscheint ein Stopp-Zeichen mit Kreuz und dem Grund. Lehnst du selbst ab, kommt das Zeichen in Orange.
- Wetten: Beim Tempo-Angleichen bietet der Rivale manchmal eine Wette in Yen an. Warnblinker = annehmen, Lichthupe = Einsatz erhöhen (bis dreifach), nichts tun = keine Wette. Sieg = Einsatz obendrauf, Niederlage = Einsatz weg. Nie mehr als die Hälfte deines Geldes, nicht bei Pink Slip.
- Alles einstellbar in der neuen Datei data/crewbattle.json (siehe Handbuch „Crew-Battles, Ablehnen und Wetten“).
### Spitznamen, Trophäen und Handy-Nachrichten
- 20 Ränge statt 15: fünf neue Zwischenränge (Spurwechsler, Mitternachtsklinge, Ringbrecher, Sturmläufer, Phantom des Rings). Alles andere wird beim gleichen Ruf frei wie vorher, du steigst nur öfter auf. Alte Spielstände passen von selbst.
- 89 Spitznamen statt 7, in den Gruppen Battle, Fahrstil, Straße und Leben & Garage: z. B. Querfahrer (50 Drifts), Windschatten, Haarscharf, Geisterstunde (Siege zwischen 2 und 4 Uhr), Kamikaze, Kilometerfresser, Radarschreck, Schrauber, Plaudertasche. Viele in mehreren Stufen.
- Neu: Titel pro Automodell wie in TXR 2025, z. B. „Covet-Fahrer“ nach 10 Siegen mit dem Covet, dann Kenner (25), Meister (50) und Legende (100).
- Jeder verdiente Spitzname bleibt und ist wählbar: Trophäenwand > Reiter „Spitznamen“ (oder deinen Spitznamen auf der Karte im Menü antippen). „Automatisch“ trägt immer den neuesten. Offene zeigen ihren Fortschritt, z. B. 13 / 25.
- Neu in der Trophäenwand: Reiter „Trophäen“. Jeder besiegte Crew-Leader gibt eine Plakette, jeder Boss einen Pokal, der Endboss den großen Pokal. Antippen zeigt Tag, Auto und Battle-Zeit des Siegs.
- Handy-Nachrichten sind jetzt klar zu erkennen: grüner Reiter „Handy-Nachricht“ mit Handy-Symbol an der Sprechblase und ein klingelndes Handy am Porträt.

### Mehr Bedingungen für Wanderer
- 23 neue Bedingungsarten für Rivalen und Wanderer (wie in TXR): Siegesserie, Geldstand, Anzahl Autos, höchstens X Niederlagen, nur Saugmotor oder nur mit Turbo/Kompressor, nur Schaltgetriebe, Antrieb (Front, Heck, Allrad), bestimmtes Teil nicht verbaut, Lackfarbe, Zeichen im Kennzeichen, Leistung und Gewicht, Kilometerstand des Autos, schon erreichtes Höchsttempo, Spiel-Wochentag, aktiver Spitzname, gewähltes Logo, Tage ohne Niederlage, Auto fast unbeschädigt, besuchte PAs und jeder Wert aus der Statistik (z. B. gewonnene Pink Slips oder erledigte Nebenjobs).
- Alle Bedingungen samt Beispielen stehen im Handbuch unter „Bedingungen (conditions)“. Der Rivalen-Builder im Dev-Menü behält die neuen Bedingungen beim Bearbeiten bei.

### Rivalen-Autos kaufen
- Neu: Besiegst du einen Crew-Leader, Boss oder Wanderer, steht sein Auto danach beim Autohändler unter „Rivalen-Autos“, mit seinem Lack, Bild und Vorbesitzer. Eine Meldung nach dem Sieg sagt Bescheid.
- Jedes Auto gibt es nur einmal und es ist teuer: Leader 5-fach, Wanderer 7-fach, Boss 10-fach des BeamNG-Preises. Einstellbar in dealer.json („rivalCars“), pro Rivale auch eigener Faktor oder gar nicht zu kaufen.

### Wartung: Öl, Kühlwasser, Reifen
- Neu: Jedes Auto hat Motoröl, Kühlwasser und Reifen von 100 % bis 0 %. Die Werte sinken mit jedem Kilometer.
- In der Garage (Reiter Service) siehst du alle drei mit Balken und Preis und machst einzeln oder komplett Service.
- Unter 50 % merkst du es: altes Öl kostet Leistung, wenig Kühlwasser lässt den Motor schneller überhitzen, abgefahrene Reifen haben weniger Grip. Unter 20 % kommt unterwegs eine Warnung.
- Gebrauchte Autos starten mit 35 bis 90 %, Rivalen-Autos frisch. Neue Reifen aus dem Shop zählen als frisch. Alles einstellbar in maintenance.json.

### Trophäenwand (Logo-Sammlung)
- Neu, wie in TXR: Besiegst du den Leader einer Crew, bekommst du das Crew-Logo. Besiegst du einen Wanderer oder Boss, bekommst du sein Siegel oder Emblem. Nach dem Sieg sagt eine Meldung, welches Logo neu ist.
- Neue Kachel „Trophäenwand“ im Menü links (unterwegs und zuhause) mit deinem aktuellen Logo und wie viele du schon hast (z. B. 16 / 73). Darin alle Logos nach Crews, Wanderern und Bossen. Gesperrte Crew-Logos sind grau, Siegel und Embleme bleiben „?“, bis du sie geschlagen hast. Antippen zeigt, was du dafür tun musst.
- Ein freies Logo antippen macht es zu deinem Logo: es steht dann im Battle oben links in der SP-Anzeige statt dem Hashiriya-Zeichen 走. Zurück geht es mit „Standard“.
- Jeder Spielstand hat seine eigene Sammlung und Wahl. Alte Spielstände bekommen alle Logos der schon besiegten Gegner sofort.

### Tastenbelegung übersichtlich
- Der Tasten-Check beim neuen Spielstand zeigt jetzt alle Tasten der Mod, sortiert nach Battle, Hashiriya Battle, Unterwegs und Entwickler. Neu dabei: Musik überspringen, Aussteigen/Einsteigen und (nur in der Dev-Version) Titelbild-Kamera und Dev-Menü.
- Rot heißt: wird gebraucht und fehlt. Grau heißt: nur praktisch, darf frei bleiben.
- Neu im Pausenmenü: Esc > Mods > Hashiriya Battle hat jetzt die Reiter „Tasten“ und „Musik“. Unter „Tasten“ siehst du jederzeit alle Belegungen, „Belegen“ öffnet die BeamNG-Steuerung direkt für diese Taste.

### Drei Spielstände
- Neu: Bis zu drei Spielstände nebeneinander. „Neues Spiel“ fragt jetzt zuerst nach einem Platz (1 bis 3). Ein belegter Platz wird nur nach Rückfrage überschrieben, und erst wenn du den Assistenten abschließt.
- Neuer Punkt „Spielstand laden“ im Titel: alle Plätze mit Fahrername, Rang, Auto, Tag, Geld und letzter Speicherung. „Weiterspielen“ lädt direkt den zuletzt gespielten Platz.
- Spielstände lassen sich im Titel löschen (mit Rückfrage). Wechselst du mitten im Spiel den Platz, wird der laufende Spielstand vorher gespeichert.
- Dein bisheriger Spielstand ist automatisch Platz 1.

### Befreien, wenn man festhängt
- Neu: „Befreien“ mit Shift + U oder als Kachel im Menü links. Wer mit dem Auto oder zu Fuß in einer Leitplanke oder einem Objekt hängen bleibt (manche sind auf der C1 nicht ganz fest und halten fest wie ein Magnet), wird 0,5 m auf dem eigenen Weg zurückgesetzt, in der Richtung von damals und ohne Schwung.
- Hängt man danach immer noch, bringt ein weiterer Druck kurz danach einen größeren Schritt zurück (1,5 m, 3 m, 6 m).
- Schaden und Tank bleiben, es kostet nichts. Gesperrt im Battle, im Gespräch, im Shop, über 15 km/h und wenn das Auto auf dem Dach liegt (dann abschleppen). Kurze Wartezeit zwischen zwei Benutzungen. Alles einstellbar in world.json ("unstuck").

### Wanderer-Builder zum Verschicken
- Neuer Wanderer-Builder: eine einzige HTML-Datei, die Helfer und Tester per Doppelklick im Browser öffnen (offline, Englisch und Deutsch). Damit bauen sie ihren eigenen Wanderer und schicken eine Datei zurück.
- Drin: Name, japanischer Name, Spitzname, Geschichte, Zeichen fürs Wanderer-Siegel, der neue Bob-Avatar mit allen Teilen inklusive Bärten und eigener Farbe, die Auto-Config (.pc einfach hineinziehen), japanisches Kennzeichen mit Vorschau, Fahrstil, Stärke, Bedingungen und drei Sprüche.
- Eingesendete Wanderer kommen mit Avatar, Siegel, Kennzeichen, Config und Credits-Eintrag ins Spiel, genau so, wie der Builder sie zeigt.
- Der Wanderer-Builder kennt jetzt alle 30 Bedingungsarten (Wochentag, Saugmotor/Turbo, Schaltgetriebe, Antrieb FF/FR/Allrad, Lackfarbe, PS, Gewicht, Kilometerstand, Siegesserie, Geld, Spitzname, Wappen, Statistik, besuchte PAs und mehr), sortiert in fünf Gruppen. Unten steht das Baudatum der Datei.
- Handbuch: Alle Verweise auf das alte Wanderer-Formular zeigen jetzt auf den Wanderer-Builder. Das alte Google-Formular ist als veraltet markiert und nur noch zum Nachschlagen eingeklappt.
- Wanderer-Builder nach Alex' Feedback überarbeitet: Hals bei Hoodie, Pelzmantel und Parka wieder sichtbar; Kopfhörerbügel und Handtuch liegen hinter dem Hals; Brillenbügel gehen zum Kopfrand statt in die Augen; die Kammspuren bei „Zurückgegelt“ bleiben im Haar; der Pferdeschwanz fällt näher am Hals.
- Neue Avatar-Teile: Kimono mit Obi, Happi (Festjacke), Frisuren Riesen-Regent (Bōsōzoku), Pompadour (Elvis) und Punch-Perm, Visier-Augen gekreuzt (X X), Herzen, Sterne und zugekniffen, dazu die Mundform (gerade, Grinsen, Schmunzeln, schief, grimmig, Zähne), auch zusammen mit Zigarette oder Zahnstocher. „Kostüm“ heißt jetzt „Damen-Anzug (Blazer)“.
- Alle Stofffarben gehen bei allen Oberteilen. Gesperrte Teile zeigen den Grund direkt darunter (z. B. Feldmütze braucht die Feldjacke, Hut braucht elegante Kleidung).
- Kennzeichen: Bei „Art“ stehen nur Arten, die es in der gewählten Region wirklich gibt; Okinawa ist eine eigene Region nur mit US Air Force.
- Fahrstil einheitlich als Knöpfe mit Erklärung (Aggression 1 bis 8, Reisetempo, Stärke mit „ab Rang X“). Die Spitznamen-Bedingung zeigt alle Spitznamen mit Beschreibung. Neues Feld „Sonst noch was?“ für Wünsche und spätere Änderungen.

### Menü links neu
- Das linke Menü (Pos1) ist aufgeräumt: oben eine Karte mit Geld, Uhrzeit, Rang und Ruf-Balken, darunter kleine Felder für Bilanz und „In der Nähe“. Die Hauptpunkte (Speichern, Lexikon, Autohändler, Statistik, Nickerchen, Abschleppen) sind Kacheln statt einer langen Liste.
- Selten gebrauchte Punkte (Musik überspringen, Parkplatz-Markierung, Fehlerbericht, Dev-Menü, Modus beenden) liegen unter „Werkzeuge“ zum Aufklappen.
- Zuhause genauso: „Schlafen“ als breite Kachel mit Hinweis, darunter Speichern, Lexikon, Jobbrett und Tutorial.
- Rivalen-Lexikon neu: alle Crews als kompakte Liste mit Logo und Fortschrittsbalken, eine Crew klappt auf. Rivalen stehen in einer Zeile (Name, Spitzname, Auto, Fahrstil), Beschreibung und Spruch erst beim Anklicken.
- Im Lexikon gibt es eine Suche (Name, Auto oder Crew) und Filter: Alle, Offen, Besiegt, Merkliste. Auf die Merkliste setzt du jetzt mit dem Stern vor dem Namen. Ein Punkt rechts zeigt offen (Ring) oder besiegt (orange).

### Porträts: Bärte
- Die Bob-Porträts können jetzt Bärte tragen (Idee von Henry): Dreitagebart, Schnurrbart, Kinnbart, Spitzbart, Koteletten, Vollbart, Ziegenbart, Konturbart, Kinnriemen, Ankerbart und kurzer Vollbart, in vielen Farben (Haarfarben plus Grau, Weiß, Rotblond, Pfeffer-Salz).
- 49 Gegner und 20 PA-Fahrer haben jetzt einen Bart, darunter einige Wanderer. Boss Mugen trägt einen silbernen Spitzbart, Boss Shirotora einen platinblonden Kinnbart. Alle anderen Figuren sehen aus wie vorher.
- Im Silhouetten-Tool gibt es unter „Extras“ die Felder „Bart“ und „Bartfarbe“.

### Speichern am Standort
- Laden bringt dich nicht mehr immer nach Hause. Du startest dort, wo du ordentlich gespeichert hast: zu Hause (Speichern oder Schlafen) und in der Garage wie bisher in der Garage, unterwegs genau an der Stelle, mit derselben Richtung, Uhrzeit, Tank und Schaden.
- Unterwegs geht Speichern nur, wenn das Auto steht und der Motor aus ist: an den Fahrbahnrand oder in eine PA fahren, anhalten, Zündung aus, im Menü „Hier parken & speichern“. Wer mitten auf der Strecke parkt, startet auch dort. Ein Nickerchen im Auto zählt als geparkt.
- Speichern mit laufendem Motor bringt einen Hinweis „MOTOR AUS!“ mit einem Umwelt-Spruch aus dem Jahr 2026. Wer es öfter probiert, bekommt einen Extra-Spruch.
- Spiel beendet, ohne ordentlich zu parken (oder Absturz)? Fortschritt geht nie verloren, der Standort wird alle 30 Sekunden mitgeschrieben. Standardmäßig wurde dein Auto dann von der Autobahnpolizei zur Garage geschleppt (Abschleppgebühr plus Bußgeld). Das Bußgeld verdoppelt sich jedes Mal: 20.000 ¥, dann 40.000, 80.000 und so weiter, damit Abschleppen keine Abkürzung ist, du startest zu Hause. In world.json (saving.unsavedExit) lässt sich stattdessen „am letzten Zwischenstand weiter“ einstellen.
- Im Menü steht unter „Speichern“, wo du gerade gespeichert bist, und rot, wenn du gerade nicht geparkt bist.

### Team-Logos (Entwürfe)
- Jede Crew hat jetzt ein eigenes Logo im Stil eines freigestellten Vinyl-Aufklebers (nur Motiv und Schriftzug), Leader haben dieselbe Version mit Goldrand. Jeder Wanderer hat ein eigenes Siegel mit seinem Zeichen, die drei Bosse haben eigene Embleme. Alles eigene Entwürfe.
- Die Logos stehen im Duell fest in der SP-Anzeige (links dein Zeichen 走, rechts das Crew-Symbol), als Sticker auf dem Porträt in der Sprechblase bei Herausforderung, Sieg und Niederlage, in PA-Gesprächen mit Rivalen und im Rivalen-Lexikon bei jeder Crew. Siegel von Wanderern und Bossen siehst du im Lexikon erst, wenn du sie geschlagen hast.

### Verkehr und PA-Fahrer
- Der Verkehr nutzt jetzt wirklich alle 152 japanischen Fahrzeuge der Agent-Traffic-Mod. Vorher kamen immer nur die ersten paar Autos aus Agents Liste. Jetzt wird die Liste nach Häufigkeit gemischt, schon gezogene Autos werden seltener, und zusätzliche versteckte Autos wechseln sich mit den fahrenden ab. Auch die geparkten Autos sind jetzt viel bunter gemischt.
- Mechaniker, Lkw-Fahrer, Kurier, Taxifahrer, Studentin und Angestellter fahren an den PAs passende Autos aus Agent Traffic JP (Kei-Laster, Dutro, JPN Taxi, Crown usw.) mit Agents Lackierungen. Ohne die Agent-Mod kommen die alten Autos.
- 10 neue Leute an den PAs: Postbote, Müllwerker, Straßenarbeiter, Elektriker, Wachmann, Reinigungskraft, Familienvater, Rentner im Camper, Otaku und Kartenfahrer, jeder mit eigenem Auto, Porträt, Smalltalk und meist einer Wissens-Geschichte.
- Die Taxi-Configs (Shinonome, Gekko) und die Polizei-Configs (Pessima Mk2, Sunburst) sind jetzt Teil der Mod. Die Taxis stehen bei den Taxifahrern an den PAs.

### PA-Rivalen
- Rivalen an den PAs fahren jetzt sichtbar los: Nach dem Annehmen steigt der Rivale in sein Auto, startet den Motor, macht nachts das Licht an und rollt langsam aus der PA auf den C1. Dort ist er ein ganz normaler Rivale auf dem Radar. Er bummelt erst etwas, damit du hinterherkommst. Er fährt dabei eine Ausfahrt-Route ab, die im Dev-Menü pro PA einmal aufgenommen wird (Orte > PA-Ausfahrt aufnehmen), und steht dafür immer rückwärts eingeparkt mit der Nase zur Gasse. Ohne Route oder wenn er nicht durchkommt, wartet er wie früher vor dir.

### Liveries
- Neue japanische Lackierungen (eigene, erfundene Firmen) als Lackdesign im Konfigurator: zwei Taxis auf der Pessima Mk1 (Shinonome Kotsu, Gekko), Polizei 首都警察 auf Pessima Mk2 und Sunburst, sowie Werkstatt, Spedition, Kurier und Krankenwagen auf Gavril D-Series und H-Series. Die Configs für die Fahrer an den PAs folgen.

### Startautos
- Der Pool der Startautos ist jetzt fest: 34 Serien-Configs von Ibishu Covet, Ibishu Miramar, Hirochi Sunburst, Ibishu 200BX/Diana, Pessima Mk1 und Pessima Mk2 (Schalter und Automatik). Andere Autos gibt es zum Start nicht mehr (z. B. Covet DX und Miramar Export fallen weg).
- Sunburst, Pessima Mk1 und Pessima Mk2 haben jetzt denselben Zustandsbereich wie 200BX und Diana: 180.000 bis 290.000 km und mehr Motorverschleiß.
- Die angebotenen Startautos sind jetzt nach ihrem echten Kaufpreis sortiert, günstigstes zuerst.

### HUD
- Rivalen auf der Minimap unten links haben jetzt dieselben Farben wie im Radar oben rechts: orange Rivale, gelb Leader, lila Wanderer, rot Boss, grau besiegt, blau verloren. Der Rivale im laufenden Battle pulsiert leicht.
- Dein eigener Pfeil auf der Minimap ist jetzt weiß (wie dein Punkt in der Radar-Mitte) und hebt sich so von orangen Rivalen ab.

### Gegner-Garage (Entwickler-Werkzeug)
- Neu für die Dev-Version: Eintrag „Gegner-Garage (Dev)“ im BeamNG-Hauptmenü unter More, direkt neben Hashiriya Battle. Er startet die ganz normale BeamNG-Garage mit allen Funktionen (Teile, Tune, Lack, Decals, Fahrzeuge, Foto, Licht, Kamera) und legt rechts das Panel „Gegner-Garage“ darüber. Gegner suchen oder nach Crews, Leadern, Wanderern, Bossen, eigenen Configs und fehlenden Configs filtern, anklicken, und sein Auto wird mit seiner Config in der Garage geladen (wahlweise wie im Spiel mit Kennzeichen und festem Lack oder nur die Config).
- Neu: Stufen wie die Rückkampf-Versionen in TXR 2025. Ein Gegner kann in einem späteren Kapitel stärker zurückkommen, mit neuem Spitznamen, neuen Sprüchen, eigener Config und oft erst dann mit Aura. Genzō kündigt die Rückkehr per Handy an, auf der Straße steht „(Stufe 2)“.
- Mit Aura zurück kommen Kemuri und Kazekiri (ab Kapitel 4), Benikaze und Noir (ab Kapitel 5) sowie Gruppe Fünf und Fukurō (Epilog). Shinkirō, Tsukiyomi, Yūrei, Hotaru, Kaminari und Afterburner haben ihre Aura von Anfang an.
- Drei Crew-Mitglieder steigen in zwei Stufen zum Wanderer auf: Hinata Oda („Erbin der Laterne“), Tadashi Hirota („Der Aussteiger“) und Taiga Shimizu („Schneesturm“), Stufe 3 mit Aura.
- Reika Hoshino, die Leaderin der Neon-Crew, hat jetzt auch eine Aura, wie alle Gegner mit Powerglow-Lack. Damit gibt es schon früh eine Aura zum Freischalten.
- Gegner-Garage: Filter „Stufen“. Speichern auf einer Stufe legt eine eigene Config an und trägt sie bei der Stufe ein. Der Aura-Editor gilt pro Stufe.
- Wanderer-Builder: neue Auswahl „Rückkehr (Wunsch)“ mit dem Kapitel.
- Aura-Editor im Reiter „Aura“: pro Gegner Aura an/aus, Farbe (Hex-Feld und Regler) und Stärke, mit Live-Vorschau am Auto, gespeichert in rivals.json. Dazu Regler für Hülle, Nebel und Licht und die Regel, wer automatisch eine Aura hat, gespeichert in aura.json. Jeweils mit Sicherung.
- Wie in TXR 2025 tragen nur noch wenige Gegner eine Aura: die drei Bosse und 12 besondere Wanderer (unter anderem alle mit Powerglow-Lack: Shinkirō, Tsukiyomi, Yūrei, Hotaru). Weitere lassen sich im Editor dazuschalten. Crew-, Leader-, Wanderer- und Boss-Auren gibt es in der Trophäenwand nur noch von Gegnern, die selbst eine tragen.
- Der Leucht-Nebel wird im Battle mit sinkenden SP dünner und verschwindet bei fast leeren SP.
- Wanderer-Builder: neue Auswahl „Aura (Wunsch)“. Der Wunsch kommt mit der Avatar-Farbe in die Datei, das Import-Skript zeigt ihn an.
- Die Aura leuchtet jetzt wirklich ums Auto: weiche Flammen-Hülle in der Aura-Farbe, aufsteigender Leucht-Nebel und dazu das Bodenlicht. Im Battle wird sie höher, heller und pulsiert. Gilt für Rivalen, deine eigene Aura und die Vorschau in der Gegner-Garage. Einstellbar in aura.json (shell, haze).
- Beim Laden bekommt das Auto jetzt auch das Kennzeichen des Gegners (vorher blieb die Nummer des alten Autos stehen, nur das Design wechselte).
- Daneben stehen Beschreibung, Crew mit allen Mitgliedern und ihren Autos, Bedingungen in Klartext, Fahrstil, Belohnung und Sprüche. So bleibt ein Auto beim Anpassen beim Charakter, z. B. die Firmenwagen von Zangyō Express.
- „Auf Gegner speichern“ schreibt die angepasste Config zurück: eigene Mod-Configs werden überschrieben (mit Sicherung), BeamNG-Configs bleiben unangetastet und der Gegner bekommt eine eigene hashiriya_r_<id>.pc, rivals.json wird nur an dieser Stelle angepasst.
- Reiter „Aura“: die Aura eines Gegners direkt am Auto in der Garage ansehen (Boden, Battle, Stufe, SP), mit heller Vorschau und „aura.json neu laden“.
- Die originale BeamNG-Garage (More > Garage) bleibt komplett unverändert, das Panel erscheint nur über den eigenen Eintrag. Nicht im Release.

### Handbuch
- Jeder Datei- und Ordnername im Handbuch ist jetzt ein Link: Klick öffnet die Datei, das Ordner-Symbol dahinter den Ordner. Neu im Kapitel „Ordner und Dateien“: Schnellzugriff auf die wichtigsten Dateien und Ordner.
- Kapitel „Testen“ verlinkt die Testliste zum Abhaken, jetzt mit 114 neuen Tests zu allen Features vom 01. bis 04.11.2026.
- Links wahlweise im Browser, im Explorer oder direkt im Editor öffnen (Explorer/Editor einmal mit tools\Handbuch-Links-einrichten.bat einrichten).

### Fehler behoben
- Autos der Fahrer an den PAs (Rivalen und Info-Fahrer) steckten manchmal in einem Auto vom Parkverkehr. Ihre Parkbucht ist jetzt für den Parkverkehr reserviert, und ein Auto, das trotzdem darin landet, wird sofort woandershin gestellt.
- Die Autos der PA-Fahrer hatten das Standard-Kennzeichen statt eines japanischen Kennzeichens. Jetzt bekommen sie ein japanisches Kennzeichen-Design (Taxis und Lieferwagen grün), Rivalen ihr eigenes.

## Alpha 0.9.1 (Stand 02.11.2026)

### Nebenjobs
- Kurier, Express und Zerbrechlich: Die Ware wird erst abgeholt, dann geliefert. Die Zeit läuft ab dem Abholen.
- Abholpunkt, Ziel und Foto-Spot haben eine Bodenmarkierung wie die Parkplätze (orange, beim Fotojob grün). Dazu kommt eine Navi-Route auf der Minimap.
- Fotojob: Mit eigenen Foto-Spots stellst du das Auto genau dort ab. Beim Foto gibt es einen Verschluss-Sound und einen kurzen Blitz.
- Tipps: Es gibt nur noch Tipps zu Wanderern und Bossen, die du vom Fortschritt her schon treffen kannst. Sie sind viel teurer (ab 250.000 Yen, Bosse ab 750.000 Yen, je Rang 10 % mehr). Danach schickt Genzō dir den Hinweis als Handy-Nachricht.

### Garage und Händler
- In der Garage (Reiter Service) gibt es jetzt den Autohändler direkt im Menü.
- Der Verkaufspreis eines Autos hängt jetzt vom Wagenwert, den gekauften Teilen, dem Zustand und den gefahrenen Kilometern ab.
- „Nicht verbaut“ heißt jetzt „Ausgebaut“.

### Story und PAs
- Die Kapitelkarte wartet, bis das Battle und der Spruch des Gegners vorbei sind.
- Genzō hat jetzt ein Porträt.
- Dev-Menü, Orte: neue Typen „PA-Fahrer-Stehplatz“ und „Foto-Spot“. Gemerkte Stehplätze nutzen die PA-Fahrer statt zufälliger Plätze (kein Stehen mehr in Autos).
- Fahrer an den PAs können eine feste eigene Config bekommen (chat.json, cars[].config).
- Startmenü und neuer Spielstand: Hinweis, dass die Mod mit Hilfe der Community ausbalanciert wird, mit Bitte um Feedback im Forum-Thread.
- Die Bobs an den PAs haben jetzt die Farbe des Oberteils aus ihrem Porträt (vorher z. B. gelber Taxifahrer mit weinroter Weste im Porträt).
- Dev-Menü: einzelne Säulen und ganze Typen ausblendbar, dazu die Parkbuchten der Map als Markierung.
- Feste Stehplätze für die Fahrer an Tatsumi PA 1 und Shibaura PA (60 Plätze, von JDMArsch gesetzt).

## Alpha 0.9 (Stand 02.11.2026)

### Neu: Fahrcharakter der Rivalen
- Jeder Rivale hat jetzt einen Fahrstil: Fährt sauber, Blocker oder Rempler.
- Saubere Fahrer lassen dir Platz. Blocker machen dir vorne öfter die Linie zu. Rempler suchen neben dir kurz Kontakt und machen Bremstests.
- Wer keinen festen Stil hat, bekommt einen passend zu seiner Aggression. Bosse sind nie von selbst Rempler.
- Der Fahrstil steht im Rivalen-Lexikon, sobald du den Rivalen kennst (seit Alpha 0.9.2 als farbloses Symbol, der Text nur in der Dev-Version).

### Neu: Musik steuern
- Neue Musik: vier KI-Platzhalter-Songs (Full Throttle Soul, Kaze ni Nare, Midnight King, Moeagare) laufen vorerst in allen Situationen. Sie sind in den Credits als KI gekennzeichnet, lassen sich pro Situation abschalten und werden durch echte Tracks ersetzt. Die alten Kevin-MacLeod-Stücke sind raus.
- Eigene Musik: Lege deine Lieder in den Ordner hashiriya_musik im BeamNG-Benutzerordner, sortiert nach Situation (Titel, Tag, Nacht, Parkplatz, Garage, Shop, Battle, Boss, Wanderer, Pink Slip).
- Startmenü und neuer Spielstand zeigen einen Tipp, dass eigene Musik das beste Erlebnis bringt.
- Im Pausenmenü unter Esc > Mods > Hashiriya Battle wählst du für jede Situation, welche Songs laufen, Mod-Songs und eigene.
- Musik-Auswahl im Pausenmenü: Jeder Song, auch die KI-Songs und deine eigenen, lässt sich pro Situation an- und ausschalten. Dazu pro Situation die Quelle (Beides, Mod, Eigene, Aus), Nächster Song, Ordner öffnen, Neu einlesen und Alles auf Standard.
- Reihenfolge pro Situation einstellbar: zufällig oder feste Reihenfolge, die du selbst sortierst.
- Musik springt nicht mehr so oft: Ein Song läuft weiter, wenn er auch in der neuen Situation dabei ist, und in der freien Fahrt (PA, Garage, Zuhause, Shop) spielt er zu Ende. Battle-Wechsel blenden langsamer über.
- Neue Musik-Situationen: Parkplatz (PA), Garage und Zuhause, Battle gegen Leader und Bosse, gegen Wanderer und Pink Slip.
- Neuer Kamera-Sound beim Fotojob (camera_digital_shutter).
- Musik kann jetzt auch als WAV in voller Qualität laufen: Liegt eine WAV mit gleichem Namen neben der OGG, wird die WAV gespielt. Der Titelsong Daikoku läuft so in der neuen Version V3.
- Musik überspringen: Taste Ende oder im Hashiriya-Menü unter Werkzeuge. Dort steht auch, welches Stück gerade läuft.
- Für jedes Stück lässt sich festlegen, wann es kommt: Uhrzeit, Gegnerart (normal, Leader, Wanderer, Boss), Pink Slip, Rang, Parkplatz oder Karte (data/music.json, siehe Handbuch).
- Im Titelbildschirm ist der Verkehr jetzt leise, damit die Titelmusik zu hören ist.

### Fehler behoben
- Status-Anzeige oben rechts: Bei einem Foto-Auftrag (z. B. nach "zu früh") wurde der Text links abgeschnitten, auch die Kapitelzeile. Lange Zeilen brechen jetzt um, das Zeitfenster ist kürzer (07-09 h).
- Die Musik war stumm. Sie läuft jetzt über BeamNGs eigenen Musik-Kanal.
- Die BeamNG-Hauptmenü-Musik ist aus, sobald du Hashiriya Battle startest. Zurück im normalen Hauptmenü läuft sie wieder.
- Nach dem Titelbildschirm blieben Motor, Reifen und andere Fahrzeuggeräusche stumm. Sie kommen jetzt wieder auf die Lautstärke aus deinen Audio-Optionen.

## Alpha 0.8 (Stand 02.11.2026)

### Neu: Teile ausbauen und verkaufen
- Am Garagen-PC kannst du jetzt fast jedes Teil ausbauen („Ausgebaut“), auch Serienteile. Nur Pflicht-Teile, ohne die das Auto nicht existiert, bleiben drin.
- Im Teilelager hat jedes nicht verbaute Teil einen Knopf „Verkaufen“ mit Preis. Zweimal klicken, dann ist es weg. Ein Teil bringt 40 % seines Preises.
- Verkaufte Serienteile kannst du im Shop wieder kaufen.

### Neu: Autos verkaufen
- In der Garage hat jedes Auto außer dem aktiven einen Knopf „Verkaufen“ mit Preis. Ein Auto bringt die Hälfte seines Werts. Teile im Lager dieses Autos gehen mit.

### Neu: Game Over
- Verlierst du dein letztes Auto im Pink Slip, stehst du zu Fuß an der Garage. Reicht dein Geld für das billigste Angebot beim Händler, kaufst du dort ein neues Auto, und es steht gleich in der Garage.
- Reicht das Geld nicht, ist die Karriere vorbei: Game Over mit Rang, Tagen und Bilanz, danach eine neue Karriere.

## Alpha 0.7 (Stand 02.11.2026)

### Neu: Nebenjobs am Tag
- In der Garage und zuhause gibt es jetzt das Jobbrett. Jeden Tag stehen dort vier Aufträge, nur tagsüber.
- Kurier: Ladung zu einem Ziel bringen, mit Zeitlimit. Schaden am Auto wird vom Lohn abgezogen.
- Express: knapperes Zeitlimit, mehr Geld.
- Zerbrechlich: mehr Geld, aber Schaden zählt dreifach. Zu viel Schaden, und der Auftrag platzt.
- Fotojob: Sei zu Fuß an einer PA, solange das Zeitfenster der Fotografin offen ist.
- Während eines Auftrags zeigt die Statusanzeige Ziel, Richtung, Entfernung und Restzeit.
- Der Lohn steigt mit deinem Rang. Höchstens vier Aufträge pro Tag.

### Neu: Tipps kaufen
- Am Jobbrett kannst du Hinweise zu Wanderern und Bossen kaufen. Sie landen im Rivalen-Lexikon, genau wie die Hinweise aus den PA-Gesprächen.

## Alpha 0.6 (Stand 02.11.2026)

### Neu: Story und Kapitel
- Die Karriere hat jetzt eine Geschichte: Prolog, fünf Kapitel und ein Epilog. Du kommst neu nach Tokio und willst wissen, wer Mugen ist.
- Jedes Kapitel beginnt mit einer Kapitelkarte (Titel auf Deutsch und Japanisch, kurzer Text).
- Szenen laufen in der Sprechblase: in der Garage, zuhause beim Aufwachen, an den PAs und nach wichtigen Battles. Weiter mit T.
- Kurze Handy-Nachrichten kommen auch beim Fahren und laufen von selbst weiter.
- Das aktuelle Kapitelziel steht unter dem Geld und im Menü.
- Im Rivalen-Lexikon gibt es oben die Seite „Story“ mit allen Kapiteln und gesehenen Szenen zum Nachlesen.
- Alte Spielstände springen direkt ins passende Kapitel.
- Die Story-Texte sind noch ein Entwurf und werden mit JDMArsch abgestimmt.

## Alpha 0.5.1 (Stand 02.11.2026)

### Neu: Musik
- Eigene Musik je nach Situation: Titelbildschirm, Tagesfahrt, Nachtfahrt, Shops und Battles haben jeweils ihre eigene Playlist, mit weichem Überblenden.
- Titelmusik: „Daikoku“ von z3rdax, eigens für die Mod, danach läuft es als Schleife weiter.
- Die Lautstärke folgt den BeamNG-Reglern für Gesamt und Musik.
- In den Credits steht jetzt ein Abschnitt Musik mit allen Stücken und Lizenzhinweisen.

### Fehler behoben
- Unfallschaden wurde nicht gespeichert: Nach dem Neuladen war das Auto wieder heil, Beulen weg, abgefallene Teile wieder dran, Motor wie neu. Jetzt bleibt der Schaden im Spielstand (Beulen, gebrochene Teile, Motor- und Kühlerschaden) und der Reparaturpreis stimmt nach dem Laden. Erst eine Reparatur macht das Auto wieder heil.

## Alpha 0.5 (Stand 01.11.2026)

### Neu: Rivalen an den Parkplätzen
- Nachts stehen an Shibaura PA und Tatsumi PA jetzt auch Rivalen und Wanderer neben ihrem eigenen Auto, mit Porträt, Spitzname und ihrem Spruch. Bosse nicht.
- Geh hin und sprich sie mit T an. Danach T = Battle, weggehen = nein.
- Der Rivale fährt vor und wartet auf dem C1. Sobald du rausfährst, taucht er vor dir auf. Lichthupe, und das Battle läuft wie gewohnt.
- Wer an einer PA steht, taucht so lange nicht auf der Straße auf.

### Neu: Pink Slip
- Etwa jeder dritte Rivale fährt auch um die Papiere. Das geht ab Rang 3 und mit mindestens zwei Autos in der Garage. Annehmen mit G.
- Gewinnst du, gehört sein Auto dir: seine Config, sein Lack, sein Kennzeichen, direkt in deiner Garage.
- Verlierst du, nimmt er dein Auto mit allen Umbauten mit und fährt es ab jetzt selbst, auf der Straße und an der PA. Du fährst mit deinem nächsten Auto zuhause weiter.
- Mit jedem Sieg gegen ihn holst du dein Auto zurück. Er steht dann besonders oft an den PAs.
- Im SP-HUD steht während des Rennens „PINK SLIP“.
- Neue Taste „Reden: Pink Slip“ (Standard G), auch im Tasten-Check.

## Alpha 0.4.1 (Stand 01.11.2026)

### Neu: Mehr Gesprächsstoff an den PAs
- Die Fahrer an den Parkplätzen erzählen jetzt viel mehr: 77 Wissens-Texte über den Shutoko, den C1, Tokio, Japan, Autos und die Geschichte der Straßenrennen. Viele davon sind kleine Geschichten über zwei oder drei Sprechblasen.
- Beispiele: Wann das erste Stück Shutoko eröffnet wurde und was die Maut damals kostete, warum der C1 über Flüsse und alte Burggräben führt, warum die Nihonbashi der Kilometer null von Japan ist und bald wieder Himmel über sich hat, die Rainbow Bridge, die Szene der späten 80er, Kei-Cars und gelbe Kennzeichen.
- Jede PA hat eigene Fun Facts: An Shibaura PA erfährst du etwas über die Rainbow Bridge und die Schleife davor, an Tatsumi PA über das Viertel und die Wochenend-Sperrungen.
- Jeder Fahrer-Typ hat seine Lieblingsthemen. Der Alte Hase erzählt Geschichte, der Lkw-Fahrer vom Verkehr, die Studentin von Tokio.
- Wissens-Texte haben einen blauen Rand und zeigen unten das Thema, zum Beispiel „Wissen · Shutoko“.
- Sprichst du jemanden nochmal an, fällt ihm oft noch etwas ein, das du noch nicht kennst.
- 47 neue Sätze Smalltalk, 4 für jeden Fahrer-Typ.
- Die Fahrer sind Bobs und wissen das auch: 27 Wissens-Texte über BeamNG, zum Beispiel wo die Welt herkommt, wie Knoten und Balken jede Delle erzeugen, warum ein Bob 89 Kilo wiegt und welche Hersteller aus Japan kommen („Wissen · BeamNG“).
- Insgesamt jetzt 104 Wissens-Texte.

## Alpha 0.4 (Stand 01.11.2026)

### Neu: Gespräche an den Parkplätzen (PA)
- An Shibaura PA und Tatsumi PA stehen jetzt Fahrer neben ihren geparkten Autos: nachts 3 bis 6, tagsüber 1 bis 2. Es gibt 12 Typen, zum Beispiel Lkw-Fahrer, Fotografin, Alter Hase, Parkwächter und Drift-Fan. Jeder hat eigene Autos und drei Porträts.
- Steig aus und geh zu Fuß hin. Dann erscheint „[T] Reden“. Mit T redest du, ein weiterer Druck zeigt den nächsten Satz oder beendet das Gespräch.
- Was die Fahrer erzählen, hängt von deinem Fortschritt ab: Gerüchte über Crews ab dem passenden Rang, Gerüchte über Leader, wenn die Crew fast geschlagen ist, und wer heute Nacht auf dich wartet.
- Hinweise auf Wanderer und Bosse schalten den Hinweis im Rivalen-Lexikon frei. So erfährst du, wie man sie trifft.
- Dieselbe Nacht zeigt an einer PA immer dieselben Leute, in der nächsten Nacht stehen andere da. Sprichst du jemanden zweimal an, sagt er dir das auch.
- Fahrer drehen sich zu dir, wenn du näher kommst.
- Neue Taste „Reden“ (Standard T). Sie steht auch im Tasten-Check.

## Alpha 0.3.5 (Stand 01.11.2026)

### Fehler behoben
- Teile im Shop anzuprobieren hat das Auto komplett repariert. Jetzt muss ein beschädigtes Auto erst repariert werden, bevor du Teile anprobierst, umbaust oder das Setup übernimmst. Im Terminal steht dafür ein Reparieren-Knopf mit Preis. Lackieren geht weiterhin.
- Beim Teiletausch im Shop gingen Verschleiß und Laufleistung der Teile verloren. Sie bleiben jetzt erhalten.

## Alpha 0.3.4 (Stand 01.11.2026)

### Fehler behoben
- Im Release-Build ließ sich das Hashiriya-Menü links nicht anklicken. Ursache: Ein altes HUD-Layout aus der Entwicklung enthält noch den Builder als unsichtbare Vollbild-App, und BeamNG lässt Klicks dort nicht durch. Der Platzhalter ist jetzt als „nicht interaktiv“ markiert und lässt alle Klicks durch.

## Alpha 0.3.3 (Stand 01.11.2026)

### Fehler behoben
- Alpha 0.3.2: Im Spiel ließ sich nichts mehr anklicken (Menüs, Seitenmenü, Apps). Behoben.

### Neu
- Titelbildschirm: neuer Punkt „Changelog“. Dort kannst du alle Versionen aufklappen und nachlesen.

## Alpha 0.3.2 (Stand 01.11.2026)

Alle Änderungen seit Alpha 0.3 (die Test-ZIP Alpha 0.3.1 ist hier mit drin).

### HUD
- Eigene HUD-Apps im Hashiriya-Design: Meldungen, Aufgaben und Scoreboard oben links, Minimap im Querformat, Tacho, Ladedruck und Antrieb. Schlanker als vorher, ohne klobige Kästen.
- Gang-Anzeige zeigt keinen Fehlerwert mehr, die Minimap lädt zuverlässig.

### Tuning
- Teile sind jetzt auf 6 Stufen (LV1 bis LV6) verteilt statt auf 3, je nach Klasse und Preis. Du musst länger aufsteigen, bis die besten Teile frei sind.
- Wird eine neue Tuning-Stufe frei, erscheint eine Meldung mit den neuen Teilen. Das klappt auch, wenn du gerade zu Fuß unterwegs bist.

### Schlafen
- Nach dem Schlafen oder einem Nickerchen kannst du 6 Spielstunden lang nicht erneut schlafen.

### Release-Build
- Keine Schnellreise mehr über die große Karte: Die Quicktravel-Punkte fehlen, und kein Ort hat mehr den Knopf „Quick Travel“.
- Ein altes HUD-Layout aus der Entwicklung verdeckt nicht mehr den ganzen Bildschirm.
- Der Test für neue Teile aus dem Entwickler-Menü ist im Release gesperrt.

### Sonstiges
- Der Knopf im BeamNG-Hauptmenü (Seite „Mehr …“) zeigt jetzt das Hashiriya-Battle-Logo.
- Credits: neuer Abschnitt „Tests“ mit Slim Henry.

## Alpha 0.3 (Stand 30.10.2026)

Alle Änderungen seit Alpha 0.2 (29.10.2026, intern noch „Alpha 1“ genannt).

### Rivalen und Crews
- Großer Kader: 26 Crews mit Leader und 42 Wanderer, zusammen fast 300 Rivalen. Jeder Rivale hat ein eigenes japanisches Kennzeichen, manche eine feste Lackierung.
- Keine Markennamen mehr bei Rivalen. Alle haben stimmige japanische oder ausländische Namen und eine kurze Hintergrundgeschichte.
- Jeder Rivale hat eigene Sprüche beim Herausfordern, bei Sieg und bei Niederlage. Sie erscheinen in einer neuen Sprechblase mit Silhouetten-Porträt und im Rivalen-Lexikon.
- Neues Ranglisten-System mit 15 Rängen. Tuning-Stufen hängen jetzt am Rang.
- Hinweise auf Wanderer bleiben verborgen, bis man von ihnen gehört hat.
- Rang und Spitzname stehen im Status-HUD.

### Battles
- Eigene Rivalen-KI: Vorne fährt der Rivale wie ein echter Hashiriya durch den Verkehr, weicht aus und bremst trotzdem rechtzeitig. Hinten hängt er sich mit Gummiband an dich und bleibt dran.
- Beim Herausfordern steht der Spruch des Rivalen 6 Sekunden da, danach zählt der Countdown von 5 herunter. Das Ergebnis bleibt 9 Sekunden stehen.
- Nach einem Frühstart kann man denselben Rivalen nach 30 Sekunden erneut herausfordern.
- Rivalen spawnen zuverlässiger: richtige Fahrtrichtung auf Einbahnstraßen, keine Spawns an Straßenrändern oder in Lücken, bei Problemen neuer Versuch.

### Neues Spiel, Startauto und Händler
- Neuer Titelbildschirm mit eigener Kameraansicht, Uhrzeit und Verkehr schon im Hintergrund. Credits im Titelbildschirm.
- Japanische Kennzeichen (Region, Typ und Sonderkennzeichen) beim neuen Spiel, beim Händler und in der Garage wählbar.
- Startauto-Auswahl mit Kacheln für Leistung, Drehmoment und Gewicht sowie Balken für Zustand und Tank. Schwächere Startautos sind besser erhalten.
- Startautos kosten höchstens so viel wie das Startkapital.
- Farbwechsel im Showroom zeigt das Auto direkt in der neuen Farbe.
- Der Autohändler bietet nur Autos an, die zum Fortschritt passen (Leistungsgrenze nach den erreichbaren Rivalen). Händlerautos sind gebraucht, Importe sehr selten.

### Tag und Freizeit
- Tagesjobs: BeamNG-Missionen „Garage zu Garage“ bringen Yen. Time Trials sind ausgeblendet.
- Schlafen und Nickerchen mit schwarzem Bildschirm, die Uhr läuft im Zeitraffer bis zur Aufwachzeit.

### Fehlersuche
- Mod-Log in settings/hashiriya_battle/logs im BeamNG-Userordner (begrenzte Größe).
- Menü > Fehlerbericht erstellen schreibt alles Wichtige in eine Datei, die man dem Entwickler schicken kann.

### Release-Build
- Sperren wie in der offiziellen BeamNG-Karriere, nur der Node Grabber bleibt: keine Fahrzeugauswahl und Fahrzeug-Config, kein Reparieren, Recover, Flip oder Zurücksetzen, kein Wechsel zu anderen Autos, keine Konsole, kein Editor, keine Zeitlupe.
- ESC-Menü ohne Fahrzeug- und Umgebungs-Tab, der Freeroam-Tab heißt „Hashiriya Battle“ und hat keine Freeroam-Knöpfe mehr.
- Keine Schnellreise über die große Karte. Time Trials erscheinen auch nicht mehr bei den Points of Interest.
- Alle Dev- und Cheat-Werkzeuge im Hashiriya-Menü sind aus.

## Alpha 0.2 (Stand 29.10.2026, intern „Alpha 1“)

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
- HUD-Layout von JDMArsch übernommen (Schaden unten, Navigation).
- Status-App größer und unter den Hinweisen, nichts wird mehr oben abgeschnitten.
- „Position merken“ funktioniert auch an der Garage am Kartenursprung.

### Release-Vorbereitung (in der Alpha noch aus)
- Release-Schalter in data/build.json: sperrt Zurücksetzen, Konsole, Editor, Zeitlupe, Schnellreise über die Karte und Uhrzeit-Änderungen über Time & Weather.
- Node-Grabber bleibt erlaubt, mit fester Stärke.
