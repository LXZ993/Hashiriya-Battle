# Wissen für die PA-Gespräche (kind "fact"): echte Fakten über Japan, Tokio, den Shutoko (Shuto Expressway),
# den C1 und die Geschichte der Straßenrennen. Recherchiert am 01.11.2026 (Quellen siehe Handbuch, Kapitel 12).
# Format: (speaker, topic, map, place, [(de, en), ...])
#   map   = Level-ID, auf der das gesagt wird (None = überall, z. B. allgemeines Japan-Wissen)
#   place = Teil des PA-Namens (z. B. 'shibaura'), dann nur an dieser PA; None = an jeder PA der Map
#   mehrere Zeilen = eine kleine Geschichte, jede Zeile ist ein eigener Satz in der Sprechblase.
# Regel: keine echten Marken- oder Modellnamen (wie bei den Rivalen), Zahlen nur, wenn sie belegt sind.

LORE = [
 # --- Shutoko: Geschichte ------------------------------------------------------------------------------
 ('veteran', 'shutoko', 'c1', None, [
  ('Weißt du, wann hier alles angefangen hat? Am 20. Dezember 1962. Das erste Stück Shutoko ging von Kyōbashi bis Shibaura, gerade mal 4,5 Kilometer.',
   'Know when all this started? 20 December 1962. The first piece of the Shutoko ran from Kyobashi to Shibaura, just 4.5 kilometres.'),
  ('Die Maut kostete damals 50 Yen. Heute kriegst du dafür nicht mal einen Kaffee aus dem Automaten.',
   'The toll back then was 50 yen. Today that won\'t even buy you a vending machine coffee.')]),
 ('veteran', 'shutoko', 'c1', None, [
  ('Der Shutoko wurde für die Olympischen Spiele 1964 gebaut. Tokio hatte nur ein paar Jahre Zeit.',
   'The Shutoko was built for the 1964 Olympics. Tokyo had only a few years.'),
  ('Land in der Innenstadt war unbezahlbar. Also haben sie die Straße über Flüsse, Kanäle und die alten Burggräben gelegt. Darum fährst du auf dem C1 dauernd über Wasser.',
   'Land in the centre was unaffordable. So they put the road over rivers, canals and the old castle moats. That\'s why you keep driving over water on the C1.')]),
 ('student', 'shutoko', 'c1', None, [
  ('Der erste Plan für eine Stadtautobahn in Tokio stammt von 1953. Gebaut wurde der Ring dann zwischen 1962 und 1967.',
   'The first plan for an urban expressway in Tokyo dates from 1953. The loop itself was built between 1962 and 1967.')]),
 ('student', 'c1', 'c1', None, [
  ('Bei Ginza liegt der C1 halb unter der Erde. Dort waren früher zwei Flüsse, der Kaede und der Tsukiji. Man hat sie zugeschüttet und die Straße hineingebaut.',
   'Near Ginza the C1 sits half below ground. Two rivers used to run there, the Kaede and the Tsukiji. They were filled in and the road was built into them.'),
  ('Ein paar der alten Brücken stehen heute noch. Sie führen jetzt nicht mehr über Wasser, sondern über die Autobahn.',
   'A few of the old bridges still stand. Now they don\'t cross water any more, they cross the expressway.')]),
 ('photo', 'c1', 'c1', None, [
  ('Kennst du die Nihonbashi? Die Steinbrücke von 1911 steht direkt unter dem C1. Fotografen hassen die Autobahn darüber seit Jahrzehnten.',
   'Know Nihonbashi? The 1911 stone bridge sits right under the C1. Photographers have hated the expressway above it for decades.'),
  ('Dabei ist das der Kilometer null von Japan. Alle Nationalstraßen messen ihre Entfernung von dieser Brücke aus.',
   'And it\'s Japan\'s kilometre zero. Every national road measures its distance from that bridge.'),
  ('Schon in der Edo-Zeit begannen dort die fünf großen Handelsstraßen. Nihonbashi war immer der Anfang von allem.',
   'Back in the Edo period the five great trade roads started there too. Nihonbashi was always where everything began.')]),
 ('salaryman', 'c1', 'c1', None, [
  ('Die Autobahn über der Nihonbashi kommt weg. Das Stück zwischen Kandabashi und Edobashi wird in einen Tunnel verlegt.',
   'The expressway over Nihonbashi is going away. The stretch between Kandabashi and Edobashi is being moved into a tunnel.'),
  ('Die Auffahrten Edobashi und Gofukubashi sind schon seit Mai 2021 zu. Der Tunnel soll um 2035 fertig sein, die Brücke oben bis 2040 abgerissen werden.',
   'The Edobashi and Gofukubashi ramps have been shut since May 2021. The tunnel should be done around 2035, the elevated road torn down by 2040.')]),
 ('mechanic', 'c1', 'c1', None, [
  ('Nach über 50 Jahren hat der Beton gelitten. Bei Prüfungen fand man Risse in den Fahrbahnplatten und Ermüdungsrisse an den Lagern. Auch deshalb wird umgebaut.',
   'After more than 50 years the concrete has suffered. Inspections found cracked deck slabs and fatigue cracks in the bearings. That\'s another reason for the rebuild.')]),
 ('trucker', 'c1', 'c1', None, [
  ('Der C1 ist nur 14,8 Kilometer lang. Wenn frei ist, bist du in einer Viertelstunde einmal rum.',
   'The C1 is only 14.8 kilometres long. When it\'s clear, you\'re round in a quarter of an hour.'),
  ('Er läuft durch drei Bezirke: Chiyoda, Chūō und Minato. Regierung, Banken und Hafen, alles an einem Ring.',
   'It runs through three wards: Chiyoda, Chuo and Minato. Government, banks and harbour, all on one loop.')]),
 ('taxi', 'c1', 'c1', None, [
  ('Merk dir: Außenring heißt soto-mawari und fährt im Uhrzeigersinn. Innenring heißt uchi-mawari, gegen den Uhrzeigersinn. Jeder Taxifahrer muss das im Schlaf können.',
   'Remember: the outer loop is soto-mawari and runs clockwise. The inner loop is uchi-mawari, anticlockwise. Every taxi driver knows that in their sleep.')]),
 ('courier', 'shutoko', 'c1', None, [
  ('Auf dem C1 gilt offiziell Tempo 50. Fast überall sonst auf dem Shutoko 60, nur auf dem Wangan 80.',
   'Officially the C1 limit is 50. Almost everywhere else on the Shutoko it\'s 60, only the Wangan allows 80.'),
  ('Eine Untersuchung von 2007 hat gezeigt, dass im Schnitt 30 bis 50 Prozent zu schnell gefahren wird. Überrascht dich das?',
   'A 2007 survey found people averaged 30 to 50 percent over the limit. Does that surprise you?')]),
 ('guard', 'c1', 'c1', None, [
  ('Lustig: Einen "C1" gibt es im Gesetz gar nicht. Offiziell besteht der Ring aus sechs verschiedenen Strecken mit eigenen Nummern.',
   'Funny thing: legally there is no "C1". Officially the loop is made of six different routes with their own numbers.')]),
 ('mechanic', 'c1', 'c1', None, [
  ('Wo die Pfeiler zwischen den Spuren stehen, darfst du nicht die Spur wechseln. Achte auf die durchgezogenen Linien, besonders bei Ginza und in den engen Kurven.',
   'Where the pillars stand between the lanes, you can\'t change lanes. Watch the solid lines, especially around Ginza and in the tight corners.')]),
 ('veteran', 'racing', 'c1', None, [
  ('Die Polizei hat einen eigenen Namen für die Leute, die hier Runden auf Zeit fahren: Roulette-zoku. Weil sie im Kreis fahren wie die Kugel im Roulette.',
   'The police have their own name for people who race laps here: roulette-zoku. Because they go round and round like the ball in a roulette wheel.'),
  ('Darum werden Parkplätze, an denen sich zu viele treffen, nachts gesperrt, und überall hängen Kameras. Die Autobahnpolizei kennt jede Kurve.',
   'That\'s why parking areas where too many gather get closed at night, and there are cameras everywhere. The expressway police know every corner.')]),
 ('veteran', 'racing', 'c1', None, [
  ('2008 hat die Polizei eine ganze Motorradgruppe festgenommen, die auf dem Ring Rennen fuhr. Die nannten sich nach den Schleifen, die sie gedreht haben.',
   'In 2008 the police arrested an entire motorcycle crew that raced on the loop. They named themselves after the laps they ran.')]),
 ('fan', 'shutoko', 'c1', None, [
  ('Früher war der C1 jeden Tag dicht, schon 1980 gab es ständig Stau. Darum hat man außen herum einen zweiten Ring gebaut, den C2.',
   'The C1 used to be jammed every day, there were constant traffic jams as early as 1980. So they built a second ring further out, the C2.'),
  ('Der C2 ist seit dem 7. März 2015 komplett. Seitdem fahren zwischen Tanimachi und Kasumigaseki etwa 20.000 Autos weniger am Tag.',
   'The C2 has been complete since 7 March 2015. Since then about 20,000 fewer cars a day use the stretch between Tanimachi and Kasumigaseki.')]),
 ('fan', 'shutoko', 'c1', None, [
  ('Im C2 steckt der Yamate-Tunnel, über 18 Kilometer lang. Das ist der längste Straßentunnel Japans.',
   'The C2 contains the Yamate Tunnel, over 18 kilometres long. That\'s the longest road tunnel in Japan.')]),
 ('trucker', 'shutoko', 'c1', None, [
  ('Über eine Million Fahrzeuge am Tag benutzen den Shutoko. Und gefühlt fahren die Hälfte davon gerade vor mir.',
   'Over a million vehicles a day use the Shutoko. And it feels like half of them are right in front of me.')]),
 ('courier', 'shutoko', 'c1', None, [
  ('Früher hat jede Fahrt auf dem Shutoko gleich viel gekostet. Seit 2012 zahlst du nach Strecke, mit dem ETC-Kästchen wird es automatisch abgebucht.',
   'Every trip on the Shutoko used to cost the same. Since 2012 you pay by distance, and the ETC box deducts it automatically.'),
  ('Seit 2022 kommst du an vielen Auffahrten nur noch mit ETC rauf. Und Maut kassieren dürfen sie laut Gesetz bis 2065.',
   'Since 2022 many on-ramps only let you in with ETC. And by law they can keep collecting tolls until 2065.')]),
 ('student', 'shutoko', 'c1', None, [
  ('Das ganze Netz ist inzwischen über 300 Kilometer lang. Und es gehört einer Firma, an der der Staat, Tokio und die Nachbarpräfekturen beteiligt sind.',
   'The whole network is over 300 kilometres long now. And it belongs to a company owned by the state, Tokyo and the neighbouring prefectures.')]),
 ('guard', 'shutoko', 'c1', None, [
  ('Der Shutoko hat ungefähr zwanzig Parkplätze wie diesen. Sie sind viel kleiner als die großen Raststätten an den Fernautobahnen.',
   'The Shutoko has about twenty parking areas like this one. They\'re much smaller than the big service areas on the intercity expressways.'),
  ('Wird gebaut, mache ich hier abends zu. Dann steht ein Schild an der Einfahrt, und ihr müsst weiterfahren.',
   'When there\'s construction, I close up here in the evening. Then there\'s a sign at the entrance and you lot have to keep driving.')]),
 ('taxi', 'shutoko', 'c1', None, [
  ('Auf dem C1 dürfen Motorräder keinen Sozius mitnehmen. Mit Beiwagen ist es erlaubt. Frag mich nicht, warum.',
   'Motorcycles can\'t carry a pillion passenger on the C1. With a sidecar it\'s allowed. Don\'t ask me why.')]),
 ('student', 'c1', 'c1', None, [
  ('Am Kreuz Edobashi beginnt der Asian Highway 1. Er führt von hier bis an die Grenze zwischen der Türkei und Bulgarien.',
   'Asian Highway 1 starts at Edobashi junction. It runs from here all the way to the border between Turkey and Bulgaria.'),
  ('Theoretisch könntest du also vom C1 bis nach Europa fahren. Praktisch ist da ein Meer im Weg.',
   'So in theory you could drive from the C1 to Europe. In practice there\'s a sea in the way.')]),
 ('salaryman', 'c1', 'c1', None, [
  ('Der Ring führt an Kasumigaseki vorbei, wo die Ministerien sitzen, und an Nagatachō, wo das Parlament ist. Wenn du schnell fährst, fährst du an der Regierung vorbei.',
   'The loop passes Kasumigaseki, where the ministries are, and Nagatacho, where parliament sits. Drive fast and you\'re driving right past the government.')]),
 ('veteran', 'c1', 'c1', None, [
  ('Der Kaiserpalast steht dort, wo früher die Burg von Edo war. Der Ring läuft an den alten Burggräben entlang.',
   'The Imperial Palace stands where Edo Castle used to be. The loop runs along the old castle moats.'),
  ('Um den Palast führt eine Laufstrecke von rund fünf Kilometern. Tagsüber joggen dort Tausende. Nachts fahren wir hier oben unsere Runden.',
   'There\'s a jogging route of about five kilometres around the palace. Thousands run there by day. At night we run our laps up here.')]),

 # --- Shibaura PA und Rainbow Bridge ---------------------------------------------------------------------
 ('photo', 'place', 'c1', 'shibaura', [
  ('Die Rainbow Bridge da drüben wurde am 26. August 1993 eröffnet. 798 Meter lang, die Türme 126 Meter hoch.',
   'The Rainbow Bridge over there opened on 26 August 1993. 798 metres long, the towers 126 metres tall.'),
  ('Den Namen haben die Leute ausgesucht, offiziell heißt sie ganz nüchtern Hafen-Verbindungsbrücke. Die Lampen an den Seilen laden sich tagsüber mit Sonnenstrom auf.',
   'The public picked the name, officially it\'s just called the harbour connector bridge. The lamps on the cables charge up from solar power during the day.')]),
 ('trucker', 'place', 'c1', 'shibaura', [
  ('Auf der Shibaura-Seite fährt man in einer großen Schleife zur Brücke hoch. Mit dem Lkw fühlt sich das an wie ein Karussell.',
   'On the Shibaura side you climb to the bridge in a big loop. In a truck it feels like a merry-go-round.')]),
 ('student', 'place', 'c1', 'shibaura', [
  ('Odaiba heißt so wegen der "Daiba", das sind Kanonenbatterien. Die wurden 1853 und 1854 ins Meer gebaut, nachdem die schwarzen Schiffe der Amerikaner aufgetaucht waren.',
   'Odaiba is named after the "daiba", cannon batteries. They were built out in the bay in 1853 and 1854, after the American black ships showed up.'),
  ('Zwei davon gibt es heute noch, kleine Inseln mit Bäumen. Von der Brücke aus kannst du sie sehen.',
   'Two of them are still there, little islands with trees. You can see them from the bridge.')]),
 ('fan', 'place', 'c1', 'shibaura', [
  ('Shibaura war früher ein Strand. Heute ist alles aufgeschüttetes Land mit Hafenmolen. Wir stehen sozusagen im Meer.',
   'Shibaura used to be a beach. Now it\'s all reclaimed land and piers. We\'re basically standing in the sea.'),
  ('Diese PA ist klein, aber hier haben sich in den Neunzigern und Zweitausendern die besten Autos der Stadt getroffen.',
   'This PA is small, but back in the nineties and two-thousands the best cars in town met right here.')]),
 ('guard', 'place', 'c1', 'shibaura', [
  ('Diese PA liegt auf der Strecke über die Rainbow Bridge. Wenn dort gebaut wird, sperre ich abends ab fünf zu.',
   'This PA sits on the route over the Rainbow Bridge. When there\'s work on it, I close up from five in the evening.')]),
 ('veteran', 'shutoko', 'c1', 'shibaura', [
  ('Das allererste Stück Shutoko endete hier in Shibaura. 1963 ging es dann weiter Richtung Flughafen Haneda.',
   'The very first stretch of the Shutoko ended right here in Shibaura. In 1963 it was extended towards Haneda airport.')]),

 # --- Tatsumi PA -------------------------------------------------------------------------------------------
 ('student', 'place', 'c1', 'tatsumi', [
  ('Tatsumi bedeutet "Drache und Schlange". Auf dem alten japanischen Kompass mit den Tierkreiszeichen ist das die Richtung Südosten.',
   'Tatsumi means "dragon and snake". On the old Japanese compass using the zodiac animals, that\'s the south-east.'),
  ('Von der alten Stadt Edo aus lag das hier im Südosten. Die Namen sind geblieben, auch wenn das Land erst später aus dem Meer gewonnen wurde.',
   'Seen from old Edo, this was the south-east. The names stuck, even though the land was only reclaimed from the sea later.')]),
 ('fan', 'place', 'c1', 'tatsumi', [
  ('Tatsumi hat zwei Parkplätze, einen pro Richtung. Dieser hier ist seit Jahren ein Treffpunkt für Leute mit besonderen Autos.',
   'Tatsumi has two parking areas, one per direction. This one has been a meeting spot for people with special cars for years.'),
  ('Wenn es zu voll wird, macht die Autobahngesellschaft am Wochenende einfach zu. Darum fahren alle hier hin, bevor es sich herumspricht.',
   'When it gets too busy, the expressway company just closes it on weekends. So everyone comes here before word gets out.')]),
 ('courier', 'place', 'c1', 'tatsumi', [
  ('Tatsumi liegt in Kōtō, auf aufgeschüttetem Land in der Bucht. Ringsum nur Lagerhallen, Kanäle und Autobahnkreuze.',
   'Tatsumi is in Koto, on reclaimed land in the bay. All around it: warehouses, canals and interchanges.')]),
 ('trucker', 'place', 'c1', 'tatsumi', [
  ('Von hier bist du schnell auf dem Wangan. Breit, gerade, 80 erlaubt. Darum war der Wangan früher die Strecke für Höchstgeschwindigkeit.',
   'From here you\'re on the Wangan in no time. Wide, straight, 80 allowed. That\'s why the Wangan used to be the top-speed course.')]),

 # --- Geschichte der Straßenrennen ---------------------------------------------------------------------------
 ('veteran', 'racing', None, None, [
  ('Es gab mal einen Club, der nur nachts auf dem Wangan fuhr. Gegründet Ende der Achtziger. Reinkommen war fast unmöglich.',
   'There was once a club that only drove the Wangan at night. Founded in the late eighties. Getting in was almost impossible.'),
  ('Ihre Regel: Wer schnell fährt, gefährdet niemanden. Bei viel Verkehr wurde langsam gemacht. Wer sich nicht dran hielt, flog raus.',
   'Their rule: drive fast, but never endanger anyone. In heavy traffic you slowed down. Break the rule and you were out.'),
  ('1999 wollte sich eine Motorradgang bei einer Fahrt anhängen. Es kam zu einem schweren Unfall, zwei Motorradfahrer starben. Der Club hat sich noch am selben Tag aufgelöst.',
   'In 1999 a motorcycle gang tried to tag along on a run. There was a terrible crash and two riders died. The club dissolved the same day.')]),
 ('veteran', 'racing', None, None, [
  ('Die Bōsōzoku, die Motorradgangs, gibt es seit den Fünfzigern. 1982 waren es über 42.000 Mitglieder in ganz Japan.',
   'The bosozoku, the biker gangs, have been around since the fifties. In 1982 there were over 42,000 members across Japan.'),
  ('2004 wurde das Verkehrsgesetz verschärft, gemeinsames gefährliches Fahren kann seitdem viel leichter bestraft werden. Heute sind es nur noch ein paar Tausend.',
   'In 2004 the traffic law was tightened, and dangerous group riding became much easier to punish. Today there are only a few thousand left.')]),
 ('drifter', 'racing', None, None, [
  ('Weißt du, wo Drift herkommt? Von den Bergpässen, den Touge. In den Siebzigern und Achtzigern sind die Leute nachts die Pässe hoch und quer wieder runter.',
   'Know where drifting comes from? The mountain passes, the touge. In the seventies and eighties people drove up the passes at night and came back down sideways.'),
  ('Aus der Straße wurde später ein Sport mit eigener Profiserie. Die gibt es seit 2001.',
   'Later the street thing became a sport with its own pro series. That has existed since 2001.')]),
 ('mechanic', 'racing', None, None, [
  ('Von 1989 bis 2004 hatten die japanischen Hersteller eine Abmachung: Kein Auto wird mit mehr als 280 PS verkauft.',
   'From 1989 to 2004 Japanese makers had an agreement: no car would be sold with more than 280 PS.'),
  ('Auf dem Papier hielten sich alle dran. Auf dem Prüfstand hatten manche Autos deutlich mehr. Du verstehst schon.',
   'On paper everyone stuck to it. On the dyno some cars had a lot more. You get the idea.')]),
 ('mechanic', 'cars', None, None, [
  ('Japanische Autos regeln bei 180 km/h ab, so ist es bei den Herstellern üblich. Wer schneller will, muss etwas umbauen.',
   'Japanese cars are limited to 180 km/h, that\'s the makers\' custom. If you want more, you have to modify something.')]),
 ('veteran', 'racing', None, None, [
  ('In den Achtzigern gab es die Kaidō-Racer: tiefe Autos, riesige Spoiler, Auspuffrohre, die senkrecht in den Himmel zeigten. Sie haben die Rennwagen der Siebziger nachgebaut.',
   'In the eighties there were the kaido racers: slammed cars, huge spoilers, exhaust pipes pointing straight up at the sky. They copied the race cars of the seventies.')]),
 ('fan', 'racing', None, None, [
  ('In Osaka gab es Leute, die auf dem Stadtring Rennen fuhren, mit kleinen, lauten Kompaktwagen. Man nannte sie Kanjō-zoku, "Ring-Gang".',
   'In Osaka there were people racing the city loop in small, loud hatchbacks. They were called kanjo-zoku, the "loop gang".'),
  ('Nach einer großen Razzia sind fast alle Gruppen verschwunden. Tokio hat seinen eigenen Ring, und du stehst gerade an seinem Rand.',
   'After a big crackdown almost all of the groups disappeared. Tokyo has its own loop, and you\'re standing right next to it.')]),
 ('fan', 'racing', None, None, [
  ('In den Achtzigern und Neunzigern war "Zero-Yon" groß: 0 auf 400 Meter, Beschleunigungsrennen. Die Automagazine haben jede Woche Zeiten veröffentlicht.',
   'In the eighties and nineties "zero-yon" was huge: zero to 400 metres, drag racing. The car magazines published times every week.')]),
 ('courier', 'racing', None, None, [
  ('Vor den Blitzern auf der Autobahn steht immer ein Warnschild. Die Kästen heißen hier Orbis. Wer das Schild übersieht, ist selbst schuld.',
   'There\'s always a warning sign before the speed cameras on the expressway. The boxes are called Orbis here. Miss the sign and it\'s your own fault.')]),
 ('taxi', 'racing', None, None, [
  ('Die Autobahnpolizei fährt auch Zivilwagen, ganz normale Limousinen. Wenn hinter dir plötzlich ein rotes Licht aus dem Dach kommt, ist der Spaß vorbei.',
   'The expressway police drive unmarked cars too, ordinary saloons. If a red light suddenly pops out of a roof behind you, the fun is over.')]),
 ('photo', 'racing', None, None, [
  ('Der berühmteste Parkplatz Japans ist der Daikoku in Yokohama. Eine Insel, um die sich die Rampen schrauben wie ein Korkenzieher.',
   'The most famous parking area in Japan is Daikoku in Yokohama. An island with ramps spiralling around it like a corkscrew.'),
  ('Inzwischen kommen Touristen sogar zu Fuß über den Zaun. Die Polizei sperrt ihn deshalb immer öfter. Fahr hin, solange es noch geht.',
   'Now tourists even climb the fence to get in on foot. That\'s why the police close it more and more often. Go while you still can.')]),
 ('veteran', 'racing', None, None, [
  ('Früher gab es viel mehr junge Leute mit schnellen Autos. Heute haben viele gar keinen Führerschein. Teure Prüfungen, teure Parkplätze, und die Bahn fährt überall hin.',
   'There used to be many more young people with fast cars. Today plenty don\'t even have a licence. Expensive inspections, expensive parking, and the trains go everywhere.')]),

 # --- Autos und Verkehr in Japan ----------------------------------------------------------------------------
 ('mechanic', 'cars', None, None, [
  ('In Japan muss dein Auto alle zwei Jahre zur großen Prüfung, dem Shaken. Ein neues Auto erst nach drei Jahren.',
   'In Japan your car goes for the big inspection, the shaken, every two years. A new car after its first three.'),
  ('Das kostet richtig Geld. Darum verkaufen viele ihr Auto lieber, bevor es fällig wird. Deshalb gibt es so viele gute Gebrauchte aus Japan.',
   'It costs real money. So many people sell their car before it\'s due. That\'s why there are so many good used cars from Japan.')]),
 ('salaryman', 'cars', None, None, [
  ('Bevor du in Tokio ein Auto anmelden kannst, musst du beweisen, dass du einen Stellplatz hast. Ohne Parkplatz-Bescheinigung kein Auto.',
   'Before you can register a car in Tokyo, you have to prove you have a parking space. No parking certificate, no car.'),
  ('Mein Stellplatz kostet im Monat mehr als die Rate für das Auto. Und er ist so eng, dass ich auf der Beifahrerseite aussteigen muss.',
   'My parking space costs more per month than the car payment. And it\'s so tight I have to get out on the passenger side.')]),
 ('rookie', 'cars', None, None, [
  ('Im ersten Jahr nach dem Führerschein muss ich das grün-gelbe Blatt aufs Auto kleben, das Wakaba-Zeichen. Alle sehen sofort, dass ich neu bin.',
   'For the first year after getting my licence I have to stick the green and yellow leaf on my car, the wakaba mark. Everyone can tell I\'m new.'),
  ('Ältere Fahrer haben auch ein eigenes Zeichen, ein Blatt mit vier Farben. Mein Opa fährt damit schneller als ich.',
   'Older drivers have their own mark too, a four-coloured leaf. My grandpa drives faster with his than I do.')]),
 ('courier', 'cars', None, None, [
  ('Siehst du die gelben Nummernschilder? Das sind Kei-Cars. Höchstens 660 Kubik, und die Hersteller bauen sie mit maximal 64 PS.',
   'See the yellow number plates? Those are kei cars. 660 cc at most, and the makers build them with no more than 64 PS.'),
  ('Billiger in Steuer und Versicherung. Mein Lieferwagen ist einer. Bergauf hasse ich ihn, im Gassengewirr liebe ich ihn.',
   'Cheaper tax and insurance. My delivery van is one. I hate it uphill, I love it in the back alleys.')]),
 ('taxi', 'cars', None, None, [
  ('Wenn dich jemand reinlässt, sag kurz mit dem Warnblinker danke. Zweimal blinken reicht. So macht man das hier.',
   'When someone lets you in, say thanks with your hazards. Two blinks is enough. That\'s how it\'s done here.')]),
 ('fan', 'cars', None, None, [
  ('Auf den Nummernschildern kommt nie das Zeichen "shi" vor. Das klingt wie das Wort für Tod.',
   'You\'ll never see the character "shi" on a number plate. It sounds like the word for death.'),
  ('Und steht "wa" oder "re" drauf, ist es ein Mietwagen. Dann weißt du, der Fahrer kennt die Strecke vielleicht nicht.',
   'And if it says "wa" or "re", it\'s a rental. Then you know the driver might not know the road.')]),
 ('veteran', 'cars', None, None, [
  ('In Japan fährt man links. Auf Okinawa fuhr man nach dem Krieg rechts, wie die Amerikaner. Am 30. Juli 1978 wurde über Nacht umgestellt.',
   'Japan drives on the left. After the war Okinawa drove on the right, like the Americans. On 30 July 1978 they switched overnight.'),
  ('Den Tag nennen sie dort heute noch "730", nach dem Datum.',
   'They still call that day "730" there, after the date.')]),
 ('trucker', 'cars', None, None, [
  ('Auf den Fernautobahnen sind meist 100 erlaubt, auf ein paar neuen Strecken seit einigen Jahren sogar 120. Ich fahr trotzdem 80. Mein Lkw ist da ehrlich.',
   'Most intercity expressways allow 100, and a few newer sections have allowed 120 for some years now. I still do 80. My truck is honest about that.')]),
 ('mechanic', 'cars', None, None, [
  ('An der Tankstelle: rot ist Normal, gelb ist Super, grün ist Diesel. Wer grün in einen Benziner tankt, ruft danach mich an.',
   'At the pump: red is regular, yellow is high octane, green is diesel. Put green in a petrol car and you\'ll be calling me afterwards.')]),
 ('taxi', 'cars', None, None, [
  ('Viele Taxis in Japan fahren mit Autogas statt Benzin. Und die hintere Tür geht von selbst auf, ich mache das mit einem Hebel.',
   'Lots of taxis in Japan run on LPG instead of petrol. And the rear door opens by itself, I work it with a lever.'),
  ('Nach Mitternacht, wenn die letzten Bahnen weg sind, ist meine beste Zeit. Dann winkt die ganze Stadt.',
   'After midnight, when the last trains are gone, is my best time. Then the whole city is waving.')]),
 ('courier', 'shutoko', None, None, [
  ('Das ETC-System gibt es in Japan seit 2001. Seitdem rollst du mit 20 durch die Mautstelle, statt anzuhalten.',
   'Japan has had the ETC system since 2001. Since then you roll through the toll gate at 20 instead of stopping.')]),

 # --- Tokio und die Gegend -----------------------------------------------------------------------------------
 ('student', 'tokyo', None, None, [
  ('Tokio hieß früher Edo. Erst 1868, als der Kaiser hierher zog, wurde daraus Tokio, die "östliche Hauptstadt".',
   'Tokyo used to be called Edo. Only in 1868, when the emperor moved here, did it become Tokyo, the "eastern capital".')]),
 ('student', 'tokyo', None, None, [
  ('Der Großraum Tokio hat ungefähr 37 Millionen Einwohner. Das ist die größte Metropolregion der Welt.',
   'Greater Tokyo has around 37 million people. That\'s the biggest metropolitan area in the world.')]),
 ('veteran', 'tokyo', None, None, [
  ('1923 hat das große Kantō-Erdbeben halb Tokio zerstört, 1945 kamen die Bomben. Die Stadt wurde zweimal fast komplett neu gebaut.',
   'In 1923 the Great Kanto earthquake destroyed half of Tokyo, and in 1945 came the bombs. The city was rebuilt almost completely, twice.')]),
 ('photo', 'tokyo', None, None, [
  ('Der Tokyo Tower ist von 1958 und 333 Meter hoch. Der Skytree kam 2012 und ist 634 Meter hoch.',
   'Tokyo Tower dates from 1958 and is 333 metres tall. The Skytree came in 2012 and is 634 metres tall.'),
  ('Die 634 haben sie mit Absicht gewählt. Man kann die Zahl als "Musashi" lesen, so hieß die alte Provinz hier.',
   'They picked 634 on purpose. You can read the number as "Musashi", the name of the old province here.')]),
 ('salaryman', 'tokyo', 'c1', None, [
  ('Ginza heißt eigentlich "Silbermünze". In der Edo-Zeit wurden dort die Silbermünzen geprägt. Heute ist das Geld immer noch da, nur in den Läden.',
   'Ginza actually means "silver mint". In the Edo period the silver coins were struck there. The money is still there today, just in the shops.')]),
 ('salaryman', 'tokyo', 'c1', None, [
  ('Shinbashi ist das Viertel der Angestellten. Nach Feierabend sitzen alle unter den Bahnbögen und trinken.',
   'Shinbashi is the office workers\' district. After work everyone sits under the railway arches and drinks.'),
  ('Von dort fuhr 1872 die erste Eisenbahn Japans nach Yokohama. Wir trinken also an einem historischen Ort.',
   'In 1872 Japan\'s first railway ran from there to Yokohama. So we\'re drinking at a historic site.')]),
 ('trucker', 'tokyo', 'c1', None, [
  ('Den alten Fischmarkt von Tsukiji gibt es nicht mehr. Seit Oktober 2018 ist der Großmarkt in Toyosu, gleich hier in der Bucht.',
   'The old Tsukiji fish market is gone. Since October 2018 the wholesale market has been in Toyosu, just across the bay.'),
  ('Um vier Uhr morgens ist da mehr los als hier. Thunfisch wartet auf niemanden.',
   'At four in the morning it\'s busier there than here. Tuna waits for no one.')]),
 ('student', 'tokyo', None, None, [
  ('Der rote Backsteinbau vom Bahnhof Tokio ist von 1914. Im Krieg wurde das Dach zerstört, erst 2012 hat man ihn wieder so aufgebaut, wie er war.',
   'Tokyo Station\'s red brick building is from 1914. The roof was destroyed in the war, and it was only restored to its original look in 2012.')]),
 ('fan', 'tokyo', None, None, [
  ('Die Aqua-Line über die Bucht ist von 1997: erst ein Tunnel unter dem Meer, dann eine lange Brücke. In der Mitte ist ein Parkplatz auf einer künstlichen Insel.',
   'The Aqua-Line across the bay dates from 1997: first a tunnel under the sea, then a long bridge. In the middle there\'s a parking area on an artificial island.')]),
 ('trucker', 'tokyo', None, None, [
  ('Die Bay Bridge in Yokohama ist von 1989. Unter der Autobahn hängt noch eine zweite Fahrbahn. Zwei Brücken in einer.',
   'Yokohama\'s Bay Bridge is from 1989. Under the expressway hangs a second roadway. Two bridges in one.')]),
 ('drifter', 'tokyo', None, None, [
  ('Weißt du, warum es in Tokio kaum Parkplätze gibt? Weil jeder Quadratmeter so viel kostet wie bei dir zu Hause ein Gebrauchtwagen.',
   'Know why there\'s hardly any parking in Tokyo? Because every square metre costs as much as a used car back home.')]),

 # --- Japan allgemein ---------------------------------------------------------------------------------------
 ('rookie', 'japan', None, None, [
  ('In Japan gibt es über zwei Millionen Getränkeautomaten. Ich glaube, die Hälfte davon steht an Parkplätzen wie diesem.',
   'Japan has over two million drink vending machines. I think half of them are at parking areas like this one.'),
  ('Trick: Rot unter dem Knopf heißt heiß, blau heißt kalt. Im Winter gibt es heißen Kaffee aus der Dose.',
   'Tip: red under the button means hot, blue means cold. In winter you get hot coffee in a can.')]),
 ('student', 'japan', None, None, [
  ('In Japan gibt es über 50.000 Konbinis, kleine Läden, die rund um die Uhr offen haben. Für Nachtfahrer sind die überlebenswichtig.',
   'Japan has over 50,000 konbini, small stores open round the clock. For night drivers they\'re essential.')]),
 ('salaryman', 'japan', None, None, [
  ('Japan hat 47 Präfekturen. Tokio ist eine davon, auch wenn sich Tokio wie ein eigenes Land anfühlt.',
   'Japan has 47 prefectures. Tokyo is one of them, even though Tokyo feels like a country of its own.')]),
 ('guard', 'japan', None, None, [
  ('Fundsachen kommen in Japan fast immer zurück. Letzte Woche hat jemand hier sein Portemonnaie liegen lassen. Am nächsten Tag lag es bei mir, mit allem Geld drin.',
   'Lost things almost always come back in Japan. Last week someone left their wallet here. The next day it was with me, every yen still inside.')]),
 ('photo', 'japan', None, None, [
  ('Im Frühling blühen die Kirschbäume nur ein, zwei Wochen. Die Wetterdienste sagen die Blüte voraus wie ein Unwetter.',
   'In spring the cherry trees only bloom for a week or two. The weather services forecast the blossom like a storm.')]),
 ('veteran', 'japan', None, None, [
  ('Japan bebt jeden Tag irgendwo ein bisschen. Darum stehen die Autobahnstützen hier auf besonderen Lagern. Nach dem großen Beben 1995 in Kōbe wurden viele verstärkt.',
   'Somewhere in Japan the ground shakes a little every day. That\'s why the expressway pillars sit on special bearings. After the big 1995 Kobe earthquake many were reinforced.')]),
 ('courier', 'japan', None, None, [
  ('In Japan gibt es kaum Straßennamen, nur Blöcke mit Nummern. Ohne Navi findest du hier keine Adresse. Mit Navi übrigens auch nicht immer.',
   'Japan barely uses street names, just numbered blocks. You can\'t find an address without sat-nav. And not always with it either.')]),
 ('drifter', 'japan', None, None, [
  ('Der Fuji ist 3.776 Meter hoch. Bei klarer Sicht siehst du ihn sogar von Tokio aus, meistens im Winter, früh am Morgen.',
   'Mount Fuji is 3,776 metres high. On a clear day you can even see it from Tokyo, mostly in winter, early in the morning.')]),
 ('rookie', 'japan', None, None, [
  ('Hier mit 18 den Führerschein zu machen, kostet in der Fahrschule locker 300.000 Yen. Darum fahre ich so vorsichtig. Das Auto war billiger als der Schein.',
   'Getting a licence at 18 here easily costs 300,000 yen at driving school. That\'s why I drive so carefully. The car was cheaper than the licence.')]),
]

# Mehr Smalltalk (kind small): (speaker, de, en)
SMALL_MORE = [
 ('trucker', 'Nachts gehört die Stadtautobahn uns Lkw-Fahrern und euch Verrückten. Die Pendler schlafen noch.', 'At night the city expressway belongs to us truckers and you lunatics. The commuters are still asleep.'),
 ('trucker', 'Ich hab hinten 20 Tonnen Klopapier. Wenn ich bremse, hört man es rascheln.', 'I\'ve got 20 tonnes of toilet paper in the back. When I brake you can hear it rustle.'),
 ('trucker', 'Mein Rücken kennt jede Fuge in der Fahrbahn zwischen Hamazakibashi und Edobashi.', 'My back knows every joint in the road between Hamazakibashi and Edobashi.'),
 ('trucker', 'Wenn du in der Kurve neben mir bist, bleib nicht im toten Winkel. Ich seh dich da nicht, auch wenn du noch so laut bist.', 'If you\'re next to me in a corner, don\'t sit in my blind spot. I can\'t see you there, however loud you are.'),
 ('taxi', 'Ein Fahrgast wollte, dass ich "schnell" fahre. Ich bin 62 gefahren. Er hat sich angeschnallt.', 'A fare asked me to go "fast". I did 62. He put his seatbelt on.'),
 ('taxi', 'Weiße Handschuhe, gebügeltes Hemd, Spitzendeckchen auf den Sitzen. Taxi fahren ist hier eine Kunst.', 'White gloves, ironed shirt, lace covers on the seats. Driving a taxi here is an art.'),
 ('taxi', 'Ich kenne jede Abkürzung in Minato. Leider kennt die das Navi meines Fahrgasts auch.', 'I know every shortcut in Minato. Unfortunately so does my fare\'s phone.'),
 ('taxi', 'Die Lichter der Stadt sind schön, bis du sie zwölf Stunden am Stück siehst.', 'The city lights are beautiful until you\'ve looked at them for twelve hours straight.'),
 ('photo', 'Lange Belichtung, und dein Auto wird ein roter Strich über die Brücke. Mehr braucht ein gutes Foto nicht.', 'Long exposure, and your car becomes a red streak across the bridge. A good photo needs nothing more.'),
 ('photo', 'Ich fotografiere Autos, nicht Leute. Autos blinzeln nie.', 'I photograph cars, not people. Cars never blink.'),
 ('photo', 'Regen ist mein Lieblingswetter. Nasse Straße spiegelt alles doppelt.', 'Rain is my favourite weather. A wet road reflects everything twice.'),
 ('photo', 'Wenn du nachher gewinnst, fahr bitte langsam an mir vorbei. Ich will den Moment haben.', 'If you win later, please drive past me slowly. I want the moment.'),
 ('fan', 'Ich höre am Auspuff, welcher Motor kommt, bevor ich das Auto sehe. Das ist mein einziges Talent.', 'I can tell which engine is coming from the exhaust before I see the car. It\'s my only talent.'),
 ('fan', 'Ich hab eine Liste aller Autos, die ich hier je gesehen habe. Sie ist länger als meine Kontaktliste.', 'I keep a list of every car I\'ve ever seen here. It\'s longer than my contacts list.'),
 ('fan', 'Ich fahre selbst Bahn. Aber ich komme jede Nacht mit dem letzten Zug hierher und gehe mit dem ersten zurück.', 'I take the train myself. But I come here on the last train every night and leave on the first.'),
 ('fan', 'Sag mal, was hast du unter der Haube? Nein, sag nichts. Lass mich raten. Ich liege eh falsch.', 'So what\'s under the bonnet? No, don\'t tell me. Let me guess. I\'ll be wrong anyway.'),
 ('mechanic', 'Leute bauen 500 PS ein und sparen bei den Bremsen. Dann landen sie bei mir. Oder in der Wand.', 'People fit 500 PS and save money on the brakes. Then they end up with me. Or in the wall.'),
 ('mechanic', 'Ich hab Öl unter den Fingernägeln, seit ich zwölf bin. Meine Frau hat es aufgegeben.', 'I\'ve had oil under my fingernails since I was twelve. My wife gave up.'),
 ('mechanic', 'Wenn dein Motor im Leerlauf so klingt wie meiner gerade, fahr heute lieber nicht mehr.', 'If your engine idles the way mine sounds right now, better not drive any more tonight.'),
 ('mechanic', 'Reifendruck prüfen kostet nichts. Trotzdem macht es keiner.', 'Checking tyre pressure costs nothing. And still nobody does it.'),
 ('veteran', 'Früher hatten wir keine Navis. Wir hatten Karten und Instinkt. Und meistens nur Instinkt.', 'We didn\'t have sat-navs. We had maps and instinct. Mostly just instinct.'),
 ('veteran', 'Junge Leute fragen mich nach Tipps. Mein Tipp: Erst bremsen, dann lenken, dann Gas. In dieser Reihenfolge.', 'Young people ask me for tips. My tip: brake first, then steer, then throttle. In that order.'),
 ('veteran', 'Ich bin nicht mehr der Schnellste. Aber ich bin noch da. Das schaffen nicht alle.', 'I\'m not the fastest any more. But I\'m still here. Not everyone manages that.'),
 ('veteran', 'Die Nacht ist das Einzige hier, was sich in dreißig Jahren nicht verändert hat.', 'The night is the only thing here that hasn\'t changed in thirty years.'),
 ('rookie', 'Ich habe heute zum ersten Mal den ganzen Ring geschafft, ohne mich zu verfahren. Ich bin richtig stolz.', 'Today I made it round the whole loop for the first time without getting lost. I\'m really proud.'),
 ('rookie', 'Mein Auto ist eigentlich das Auto meiner Mutter. Sie denkt, ich bin in der Bibliothek.', 'My car is actually my mum\'s car. She thinks I\'m at the library.'),
 ('rookie', 'Wie kommt man eigentlich in eine Crew? Gibt es da ein Formular?', 'How do you actually get into a crew? Is there a form?'),
 ('rookie', 'Ich habe gespart, um mir einen Spoiler zu kaufen. Jetzt habe ich kein Geld mehr für Benzin.', 'I saved up to buy a spoiler. Now I have no money left for petrol.'),
 ('guard', 'Ich zähle jede Nacht die Autos. Gestern waren es 47. Heute sind es mehr, und die Nacht ist noch jung.', 'I count the cars every night. Yesterday it was 47. Tonight it\'s more, and the night is young.'),
 ('guard', 'Mein Lieblingsplatz ist da hinten am Automaten. Der summt so schön.', 'My favourite spot is over there by the vending machine. It hums so nicely.'),
 ('guard', 'Wer hier Müll liegen lässt, den finde ich. Ich habe Zeit.', 'If you leave rubbish here, I will find you. I have time.'),
 ('guard', 'Bitte Motor aus, wenn ihr hier steht. Die Anwohner hinter der Schallschutzwand schlafen.', 'Engines off while you\'re parked, please. The neighbours behind the noise barrier are asleep.'),
 ('courier', 'Mein Rekord: 64 Pakete in einer Schicht. Danach habe ich zwei Tage nicht mehr geredet.', 'My record: 64 parcels in one shift. Afterwards I didn\'t speak for two days.'),
 ('courier', 'Die schlimmsten Adressen sind die im zwölften Stock ohne Aufzug. Und immer ist es Wasser in Kisten.', 'The worst addresses are twelfth floor, no lift. And it\'s always crates of water.'),
 ('courier', 'Ich kenne die Ampelphasen in Kōtō auswendig. Grüne Welle ab 2 Uhr, wenn du 48 fährst.', 'I know the light cycles in Koto by heart. Green wave from 2 am if you do 48.'),
 ('courier', 'Kaffee Nummer vier für heute. Der Automat kennt mich schon.', 'Coffee number four tonight. The machine knows me already.'),
 ('student', 'Ich lerne gerade für Geschichte. Das hier ist besser als jedes Buch, die Fahrer erzählen mehr.', 'I\'m studying history right now. This is better than any book, the drivers tell you more.'),
 ('student', 'Meine Freundinnen gehen in Clubs. Ich sitze nachts auf einem Autobahnparkplatz. Ich glaube, ich habe gewonnen.', 'My friends go to clubs. I sit in an expressway parking area at night. I think I won.'),
 ('student', 'Wusstest du, dass man hier mehr Sterne sieht als in der Stadt? Zwei. Statt keinem.', 'Did you know you can see more stars here than in the city? Two. Instead of none.'),
 ('salaryman', 'Morgen um neun habe ich eine Präsentation. Ich kenne die Folien nicht, aber ich kenne jede Kurve vom C1.', 'I have a presentation at nine tomorrow. I don\'t know the slides, but I know every corner of the C1.'),
 ('salaryman', 'Mein Kollege fährt einen Kombi und hält ihn für einen Sportwagen. Ich habe ihm nie widersprochen.', 'My colleague drives an estate and thinks it\'s a sports car. I\'ve never contradicted him.'),
 ('salaryman', 'Überstunden bis elf, dann eine Runde auf dem Ring. Das ist mein Ausgleichssport.', 'Overtime till eleven, then a lap of the loop. That\'s my way of unwinding.'),
 ('salaryman', 'Mein Chef hat gefragt, warum ich morgens so müde bin. Ich habe gesagt: Familie. Das stimmt nicht ganz.', 'My boss asked why I\'m so tired in the mornings. I said: family. That\'s not quite true.'),
 ('drifter', 'Auf dem C1 driften? Nein. Viel zu viele Wände. Ich übe hier nur das Aussteigen mit Stil.', 'Drifting on the C1? No. Far too many walls. I just practise getting out of the car with style.'),
 ('drifter', 'Meine Reifen sind wieder fertig. Ich nehme jetzt nur noch gebrauchte, die halten genauso kurz.', 'My tyres are done again. I only buy used ones now, they last just as short.'),
 ('drifter', 'Ein guter Drift ist wie ein guter Witz. Timing ist alles, und meistens lacht keiner.', 'A good drift is like a good joke. Timing is everything, and usually nobody laughs.'),
 ('drifter', 'Siehst du die Delle hinten links? Da war eine Leitplanke schneller als ich.', 'See the dent at the back left? A guardrail was quicker than me.'),
]
