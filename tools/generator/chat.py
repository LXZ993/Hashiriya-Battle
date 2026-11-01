# PA-Gespräche (Texte + Figuren an den Parkplätzen, System: talk.lua). Erzeugt data/chat.json.
import json

SPEAKERS = [
 ('fan', 'Ring-Fan', 'Loop fan'), ('mechanic', 'Mechaniker', 'Mechanic'), ('trucker', 'Lkw-Fahrer', 'Trucker'),
 ('taxi', 'Taxifahrer', 'Taxi driver'), ('photo', 'Fotografin', 'Photographer'), ('veteran', 'Alter Hase', 'Old hand'),
 ('rookie', 'Neuling', 'Rookie'), ('guard', 'Parkwächter', 'Car park attendant'), ('courier', 'Kurier', 'Courier'),
 ('student', 'Studentin', 'Student'), ('salaryman', 'Angestellter', 'Office worker'), ('drifter', 'Drift-Fan', 'Drift fan'),
]

# Belangloses (kind small): (speaker, de, en)
SMALL = [
 ('trucker', 'Ich fahr seit 20 Jahren nachts. Die Autos werden schneller, der Kaffee hier nicht besser.', 'Been driving nights for 20 years. The cars get faster, the coffee here doesn\'t get better.'),
 ('trucker', 'Wenn ihr Jungs mich überholt, dann bitte nicht rechts. Mein Spiegel hat schon genug gesehen.', 'When you lot overtake me, please not on the right. My mirror has seen enough.'),
 ('taxi', 'Mein Fahrgast hat mich gefragt, ob ich auch so schnell fahren kann. Ich hab gesagt, nur ohne Taxameter.', 'My fare asked if I could drive that fast too. I said only with the meter off.'),
 ('taxi', 'Die beste Zeit zum Fahren? Zwei Uhr. Da schlafen sogar die Ampeln.', 'Best time to drive? Two am. Even the traffic lights are asleep.'),
 ('photo', 'Ich warte auf den perfekten Moment: Neonlicht, nasser Asphalt, ein Auto, das quer kommt.', 'I\'m waiting for the perfect shot: neon, wet asphalt, a car coming sideways.'),
 ('photo', 'Dein Auto sieht im Laternenlicht gut aus. Darf ich ein Foto machen? Nur eins. Okay, fünf.', 'Your car looks good under the street lights. Can I take a photo? Just one. Okay, five.'),
 ('fan', 'Ich hab kein Auto, aber ich kenne jedes Auto, das hier jemals stand.', 'I don\'t own a car, but I know every car that has ever parked here.'),
 ('fan', 'Hast du schon mal einen Sonnenaufgang von der Brücke gesehen? Lohnt sich. Wenn du so lange durchhältst.', 'Ever seen a sunrise from the bridge? Worth it. If you last that long.'),
 ('mechanic', 'Hörst du das Klackern? Nein? Dann ist ja gut. Ich höre es trotzdem.', 'Hear that rattle? No? Good. I still hear it.'),
 ('mechanic', 'Die meisten Unfälle passieren nicht in der Kurve, sondern beim Ausparken. Glaub mir.', 'Most crashes don\'t happen in corners, they happen pulling out of a parking space. Trust me.'),
 ('veteran', 'Früher gab es hier nur Automaten und Benzingeruch. Heute gibt es Automaten, Benzingeruch und Handys.', 'Back in the day there were only vending machines and petrol fumes. Now it\'s vending machines, petrol fumes and phones.'),
 ('veteran', 'Ich bin hier schon gefahren, als die Leitplanken noch neu waren. Die Hälfte der Dellen sind von mir.', 'I raced here when the guardrails were new. Half the dents are mine.'),
 ('rookie', 'Ich hab heute zum ersten Mal Lichthupe gegeben. Der andere hat einfach weitergefahren. War das ein Taxi?', 'I flashed my lights for the first time tonight. The other car just kept going. Was it a taxi?'),
 ('rookie', 'Ist das hier immer so voll? Ich dachte, nachts schlafen alle.', 'Is it always this busy here? I thought everyone sleeps at night.'),
 ('guard', 'Parken ja, Burnouts nein. Ich hab das Schild selbst gemalt.', 'Parking yes, burnouts no. I painted the sign myself.'),
 ('guard', 'Nachts ist es hier ruhig. Bis um elf. Dann kommen die mit den lauten Auspuffen.', 'It\'s quiet here at night. Until eleven. Then the loud exhausts arrive.'),
 ('courier', 'Ich hab noch zwölf Pakete. Wenn du schneller bist als ich, nimmst du drei?', 'I\'ve got twelve parcels left. If you\'re faster than me, will you take three?'),
 ('courier', 'Mein Navi sagt, ich soll wenden. Mein Navi sagt das seit drei Stunden.', 'My sat-nav says turn around. It\'s been saying that for three hours.'),
 ('student', 'Morgen ist Prüfung. Ich lerne hier, weil das Licht am Automaten besser ist als zu Hause.', 'Exam tomorrow. I study here because the vending machine light is better than at home.'),
 ('student', 'Mein Freund fährt Rennen. Ich warte hier und tue so, als wäre das romantisch.', 'My boyfriend races. I wait here and pretend it\'s romantic.'),
 ('salaryman', 'Ich bin nur kurz hier, um nicht nach Hause zu müssen. Sag es nicht meiner Frau.', 'I\'m only here so I don\'t have to go home yet. Don\'t tell my wife.'),
 ('salaryman', 'Mein Chef hat heute gesagt, ich soll mehr Gas geben. Ich glaube, er meinte die Arbeit.', 'My boss told me today to step on it. I think he meant work.'),
 ('drifter', 'Siehst du die schwarzen Streifen dort? Das war ich. Und dort. Und da auch.', 'See those black marks over there? That was me. And there. And there too.'),
 ('drifter', 'Grip ist für Leute, die Angst haben.', 'Grip is for people who are scared.'),
 ('fan', 'Die Melonenbrot-Taste am Automaten ist seit Wochen leer. Das ist das wahre Drama hier.', 'The melon bread button on the vending machine has been empty for weeks. That\'s the real drama here.'),
 ('trucker', 'Mein Lkw hat 500 PS. Leider auch 40 Tonnen.', 'My truck has 500 hp. Sadly it also weighs 40 tonnes.'),
 ('veteran', 'Ein gutes Auto verzeiht Fehler. Ein schnelles nicht.', 'A good car forgives mistakes. A fast one doesn\'t.'),
 ('photo', 'Wenn du heute gewinnst, schick mir deine Rundenzeit. Ich schreib was dazu.', 'If you win tonight, send me your time. I\'ll write something about it.'),
 ('taxi', 'Ich hab heute einen Fahrgast gehabt, der wollte unbedingt zum Ring. Ich hab ihn hierher gebracht. Er war glücklich.', 'Had a fare tonight who wanted the loop, no matter what. I brought him here. He was happy.'),
 ('mechanic', 'Neue Reifen fühlen sich am besten an, bis du die Rechnung siehst.', 'New tyres feel best until you see the bill.'),
 ('rookie', 'Mein Onkel sagt, früher gab es hier echte Legenden. Gibt es die noch?', 'My uncle says there used to be real legends here. Are there still?'),
 ('guard', 'Ich hab hier schon alles gesehen. Ein Auto mit Lichterkette, einen Mann im Pelzmantel, einen Bus mit Babyschale.', 'I\'ve seen it all here. A car with fairy lights, a man in a fur coat, a van with a baby seat.'),
 ('courier', 'Weißt du, wie man ohne Rückspiegel fährt? Ich auch nicht. Meiner ist gestern abgefallen.', 'Do you know how to drive without a mirror? Me neither. Mine fell off yesterday.'),
 ('student', 'Ich schreib meine Abschlussarbeit über Verkehrsfluss. Hier lerne ich mehr als in der Uni.', 'I\'m writing my thesis on traffic flow. I learn more here than at uni.'),
 ('salaryman', 'Wer hier um vier Uhr morgens noch steht, hat entweder keinen Schlaf oder keinen Grund zu schlafen.', 'Anyone still here at four in the morning either has no sleep or no reason to sleep.'),
 ('drifter', 'Ich hab meine Reifen nach meinen Exfreundinnen benannt. Sie halten alle nicht lange.', 'I named my tyres after my exes. None of them last long.'),
]

# Spieltipps (kind tip)
TIPS = [
 ('veteran', 'Wer vorne fährt, verliert keine SP. Klingt einfach, ist es aber nicht.', 'Whoever is in front loses no SP. Sounds easy. It isn\'t.'),
 ('veteran', 'Jede Berührung mit der Wand kostet dich SP. Die Wand gewinnt immer.', 'Every touch of the wall costs you SP. The wall always wins.'),
 ('mechanic', 'Bessere Teile gibt es erst, wenn du dir einen Namen gemacht hast. Ruf ist hier die Währung.', 'Better parts only come once you\'ve made a name. Reputation is the currency here.'),
 ('mechanic', 'Fahr nicht mit kaputtem Auto los. Eine Reparatur ist billiger als eine Niederlage.', 'Don\'t head out with a broken car. A repair is cheaper than a defeat.'),
 ('fan', 'Fährst du mehrere Siege am Stück, gibt es mehr Geld. Aber zurück in die Garage, und die Serie ist weg.', 'Win several in a row and the money goes up. Head back to the garage and the streak is gone.'),
 ('fan', 'Hab gehört, die Leader kommen erst, wenn du ihre ganze Crew geschlagen hast. Manche lassen dich eine Nacht warten.', 'Heard the leaders only show up once you\'ve beaten their whole crew. Some make you wait a night.'),
 ('taxi', 'Wenn dich einer von hinten anblinkt, will er ein Rennen. Warnblinker heißt ja, Blinker heißt nein.', 'If someone flashes you from behind, they want a race. Hazards mean yes, indicators mean no.'),
 ('rookie', 'Mir hat jemand gesagt: nicht vor dem Countdown losfahren. Ich hab es trotzdem gemacht. Er hatte recht.', 'Someone told me: don\'t go before the countdown. I did anyway. He was right.'),
 ('photo', 'Knapp an Autos vorbei bringt Combo-Punkte. Ein Crash nimmt dir alles wieder weg. Gute Bilder gibt es trotzdem.', 'Passing close to cars earns combo points. A crash takes it all away. Still makes good pictures.'),
 ('guard', 'Tagsüber sind die Läden offen, nachts die Straßen. Plan deinen Tag.', 'By day the shops are open, by night the roads. Plan your day.'),
 ('trucker', 'Tank lieber voll, bevor du losfährst. Ein leerer Tank um drei Uhr ist kein Spaß.', 'Fill up before you go. An empty tank at three am is no fun.'),
 ('courier', 'Beim Autohändler gibt es jeden Tag andere Angebote. Importe sieht man da fast nie. Wenn doch, schlag zu.', 'The dealer has different offers every day. You almost never see imports there. If you do, grab it.'),
 ('veteran', 'Die alten Importe sind die seltensten. Je älter und teurer, desto seltener taucht so einer beim Händler auf.', 'Old imports are the rarest. The older and pricier, the less often one turns up at the dealer.'),
 ('salaryman', 'Wer zu lange wach bleibt, fährt schlechter. Zu Hause kann man ab zehn Uhr schlafen.', 'Stay up too long and you drive worse. At home you can sleep from ten.'),
 ('drifter', 'Drift bringt Combo-Punkte. Bremst dich aber auch aus. Such dir aus, was dir wichtiger ist.', 'Drifting earns combo points. It also slows you down. Pick what matters more.'),
 ('mechanic', 'Ein Gegner, der dich schlägt, kommt wieder. Und beim zweiten Mal ist er stärker.', 'A rival who beats you comes back. And the second time he\'s stronger.'),
 ('fan', 'Manche Fahrer tauchen nur zu bestimmten Uhrzeiten auf. Achte auf die Uhr.', 'Some drivers only show up at certain times. Watch the clock.'),
 ('photo', 'Im Rivalen-Lexikon zu Hause kannst du Gegner markieren. Dann sagt dir das Radar, wenn sie in der Nähe sind.', 'In the rival lexicon at home you can mark rivals. The radar then tells you when they\'re near.'),
]

# Gerüchte über Crews (kind crew, about = Crew-ID): (crew, speaker, de, en)
CREW = [
 ('t_lantern', 'student', 'Die Mayonaka Lanterns sind Studenten aus Shibuya. Laut, aber harmlos. Mit denen fängt jeder an.', 'The Mayonaka Lanterns are students from Shibuya. Loud, but harmless. Everyone starts with them.'),
 ('t_zangyo', 'salaryman', 'Die vom Zangyō Express fahren nach der Überstunde. Wenn du einen mit Krawatte siehst, ist er einer von ihnen.', 'The Zangyō Express guys race after overtime. If you see one in a tie, he\'s one of them.'),
 ('t_showa', 'veteran', 'Der Shōwa Retro Club fährt alte Miramar und Italiener. Langsam, aber unterschätz die Oma im Autobello nicht.', 'The Shōwa Retro Club drives old Miramars and Italians. Slow, but don\'t underestimate the grandma in the Autobello.'),
 ('t_diana', 'fan', 'Die Diana Sisters halten zusammen. Schlägst du eine, wollen die anderen fünf Rache.', 'The Diana Sisters stick together. Beat one and the other five want revenge.'),
 ('t_bxboys', 'mechanic', 'Die Nihyaku Boys fahren nur 200BX und streiten über Klappscheinwerfer. Ihr Chef kommt aus Hokkaido.', 'The Nihyaku Boys only drive 200BX and argue about pop-ups. Their boss is from Hokkaido.'),
 ('t_yamagumi', 'trucker', 'Die Yama-Gumi kommen aus den Bergen. Hohe Kisten, aber die kennen keine Angst vor Kurven.', 'The Yama-Gumi come down from the mountains. Tall boxes, but they have no fear of corners.'),
 ('t_neon', 'photo', 'Der Ginza Neon Club glänzt mehr, als er fährt. Aber ihre Chefin, die mit dem leuchtenden Moonhawk, ist eine andere Liga.', 'The Ginza Neon Club shines more than it drives. But their queen, the one in the glowing Moonhawk, is another league.'),
 ('t_kombi', 'salaryman', 'Die Kombi Papas fahren, wenn die Familie schläft. Unterschätz nie einen Vater mit 40 Minuten Zeit.', 'The Kombi Papas race while the family sleeps. Never underestimate a dad with 40 minutes to spare.'),
 ('t_kitsune', 'taxi', 'Die Kōsoku Kitsune sehen aus wie Opas Limousine. Bis sie an dir vorbei sind.', 'The Kōsoku Kitsune look like grandpa\'s sedan. Until they\'re past you.'),
 ('t_pocket', 'rookie', 'Die Pocket Rockets aus Kōchi sind winzig. Und sie bremsen später als du.', 'The Pocket Rockets from Kōchi are tiny. And they brake later than you.'),
 ('t_hoshikuzu', 'trucker', 'Die Hoshikuzu Rally-dan springen über jede Fuge. Wenn du Allrad hörst, sind sie es.', 'The Hoshikuzu Rally-dan jump every joint. If you hear all-wheel drive, it\'s them.'),
 ('t_sleeper', 'courier', 'Die Sleeper Agents fahren amerikanische Familienlimousinen mit viel zu großen Motoren. Sehen aus wie Mietwagen.', 'The Sleeper Agents drive American family sedans with far too much engine. They look like rentals.'),
 ('t_kasumi', 'drifter', 'Die Kasumi Drift Union fährt lieber quer als schnell. Du siehst sie am Rauch.', 'The Kasumi Drift Union would rather go sideways than fast. You spot them by the smoke.'),
 ('t_etkklassik', 'mechanic', 'Bayern Kaze lieben alte deutsche Limousinen. Lederhandschuhe, Ersatzteile aus Übersee und sehr viele Meinungen.', 'Bayern Kaze love old German saloons. Leather gloves, spare parts from overseas and a lot of opinions.'),
 ('t_sbr', 'mechanic', 'Hirochi Blood sind Werksleute. Nur SBR. Manche fahren elektrisch und reden mit den anderen nicht mehr.', 'Hirochi Blood are factory people. SBR only. Some drive electric and don\'t talk to the others anymore.'),
 ('t_yokota', 'guard', 'Die Night Patrol 16 sind Soldaten vom Stützpunkt. Laut, freundlich, und sie teilen ihre Pizza, wenn sie gewinnen.', 'Night Patrol 16 are soldiers from the base. Loud, friendly, and they share their pizza when they win.'),
 ('t_kurogane', 'veteran', 'Die Kurogane-kai fahren nur schwarz. Sie reden nicht. Wenn du einen siehst, ist er schon hinter dir.', 'The Kurogane-kai only drive black. They don\'t talk. If you see one, he\'s already behind you.'),
 ('t_muscle73', 'fan', 'Shōwa 48 Muscle fahren amerikanische V8 wie aus alten Filmen. Auf der Geraden sind sie gefährlich.', 'Shōwa 48 Muscle drive American V8s straight out of old movies. On the straights they\'re dangerous.'),
 ('t_raijin', 'mechanic', 'Die Raijin Garage sitzt unter den Gleisen. Ihre Turbos hörst du, bevor du sie siehst.', 'Raijin Garage is under the railway tracks. You hear their turbos before you see them.'),
 ('t_hotrod', 'photo', 'Die Kōenji Greasers fahren Autos, die älter sind als ihre Großeltern. Mit Motoren, die viel zu stark sind.', 'The Kōenji Greasers drive cars older than their grandparents. With engines that are far too strong.'),
 ('t_bolide', 'photo', 'Rosso Ottantuno sammeln italienische Exoten aus den Achtzigern. Wenn einer davon hier parkt, mach ein Foto.', 'Rosso Ottantuno collect eighties Italian exotics. If one of them parks here, take a picture.'),
 ('t_vivace', 'courier', 'Périph Tokyo hupen mehr als jeder Taxifahrer. Ihr Chef backt die besten Croissants der Stadt.', 'Périph Tokyo honk more than any taxi driver. Their boss bakes the best croissants in town.'),
 ('t_akatsuki', 'veteran', 'Akatsuki Racing war mal ein Werksteam. Ihre Autos dürften eigentlich gar nicht auf die Straße.', 'Akatsuki Racing used to be a works team. Their cars shouldn\'t really be on the road.'),
 ('t_etkmodern', 'salaryman', 'Der Rennspecht Kai sind Unternehmer aus Roppongi. Sie reden über Allrad wie andere über Aktien.', 'The Rennspecht Kai are entrepreneurs from Roppongi. They talk about AWD like others talk about stocks.'),
 ('t_bastion', 'guard', 'Die Bastion Brotherhood fährt Muscle Cars mit Kompressor. Ihr Anführer war mal Kampfpilot.', 'The Bastion Brotherhood drive supercharged muscle cars. Their leader used to be a fighter pilot.'),
 ('t_scintilla', 'taxi', 'Der Scintilla Salon sind die Reichsten der Stadt. Die fahren gegen dich, weil ihnen langweilig ist.', 'The Scintilla Salon are the richest in town. They race you because they\'re bored.'),
]

# Gerüchte über Leader (kind leader): kommen, wenn die Crew fast geschlagen ist
LEADER = [
 ('t_lantern', 'student', 'Riku, der Gründer der Lanterns, will jeden Neuling persönlich sehen. Er vergibt sogar Noten.', 'Riku, founder of the Lanterns, wants to see every rookie in person. He even hands out grades.'),
 ('t_zangyo', 'salaryman', 'Der Abteilungsleiter vom Zangyō Express hat seit 1996 keinen Urlaub genommen. Er nimmt Rennen sehr ernst.', 'The section chief of Zangyō Express hasn\'t taken a holiday since 1996. He takes races very seriously.'),
 ('t_showa', 'veteran', 'Der Chrom-Kaiser fährt einen Autobello aus Neapel. Frag ihn nicht nach der Geschichte, sonst stehst du morgen noch da.', 'The Chrome Emperor drives an Autobello from Naples. Don\'t ask him about it or you\'ll still be here tomorrow.'),
 ('t_diana', 'fan', 'Aiko, die große Schwester der Diana Sisters, nimmt es persönlich, wenn jemand ihre Mädels schlägt.', 'Aiko, big sister of the Diana Sisters, takes it personally when someone beats her girls.'),
 ('t_bxboys', 'mechanic', 'Der Chef der Nihyaku Boys fährt mit Winterreifen. Er sagt, das sei Taktik. Bisher stimmt es.', 'The Nihyaku Boys\' boss drives on winter tyres. He says it\'s tactics. So far he\'s right.'),
 ('t_yamagumi', 'trucker', 'Der Bergkönig der Yama-Gumi fährt einen Bus. Er kam damit über drei Pässe, ohne einmal zu schalten.', 'The Mountain King of the Yama-Gumi drives a van. He came over three passes in it without changing gear.'),
 ('t_neon', 'photo', 'Reika, die Königin der Lichter, kennt jede Ampel in Ginza. Ihr Moonhawk leuchtet wie ein Flughafen.', 'Reika, the Queen of Lights, knows every light in Ginza. Her Moonhawk glows like an airport.'),
 ('t_kombi', 'salaryman', 'Super-Papa hat fünf Kinder und einen getunten Van. Er fährt mit Babyschale als Ballast.', 'Super Dad has five kids and a tuned van. He races with a baby seat as ballast.'),
 ('t_kitsune', 'taxi', 'Die Chefin der Kitsune heißt Neunschwanz. Niemand hat sie zweimal hintereinander geschlagen.', 'The Kitsune boss is called Nine Tails. Nobody has beaten her twice in a row.'),
 ('t_pocket', 'rookie', 'Der Raketenmann der Pocket Rockets hat sich ein deutsches Auto geholt und redet seitdem mit Akzent.', 'The Pocket Rockets\' Rocket Man got himself a German car and has spoken with an accent ever since.'),
 ('t_hoshikuzu', 'trucker', 'Der Chef der Rally-dan hat in Europa Rallyes gefahren. Sein Beifahrer ist angeblich noch dort.', 'The Rally-dan boss raced rallies in Europe. His co-driver is supposedly still there.'),
 ('t_sleeper', 'courier', 'Der Chef der Sleeper Agents fährt einen Mietwagen, den er nie zurückgegeben hat. Behauptet er.', 'The Sleeper Agents\' boss drives a rental he never returned. So he claims.'),
 ('t_kasumi', 'drifter', 'Weißer Nebel, der Chef der Kasumi, ist nur in seinem eigenen Rauch zu sehen. Halte Abstand.', 'White Mist, the Kasumi boss, can only be seen in his own smoke. Keep your distance.'),
 ('t_etkklassik', 'mechanic', 'Der Knallharte von Bayern Kaze ist für seine Frau aus Deutschland hergezogen. Fahren kann er trotzdem.', 'The Hard Case of Bayern Kaze moved here from Germany for his wife. He can still drive.'),
 ('t_sbr', 'mechanic', 'Der Chef von Hirochi Blood hat den eSBR 800 mitentwickelt. Du hörst ihn nicht kommen.', 'The Hirochi Blood boss co-developed the eSBR 800. You won\'t hear him coming.'),
 ('t_yokota', 'guard', 'Der Sergeant der Night Patrol hat seinen Roamer im Frachtflugzeug mitgebracht. Offiziell als Ersatzteil.', 'The Night Patrol sergeant brought his Roamer over in a cargo plane. Officially as a spare part.'),
 ('t_kurogane', 'veteran', 'Das Oberhaupt der Kurogane fährt einen schwarzen Bolide namens Notte. Ich hab ihn nie kommen sehen.', 'The Kurogane patriarch drives a black Bolide called Notte. I never saw him coming.'),
 ('t_muscle73', 'fan', 'Der Chef von Shōwa 48 Muscle redet nur in Filmzitaten. Sein Barstow riecht nach Popcorn.', 'The Shōwa 48 Muscle boss only talks in movie quotes. His Barstow smells of popcorn.'),
 ('t_raijin', 'mechanic', 'Der Donnergott der Raijin Garage hat jedes Auto dort selbst gebaut. Sein eigenes ist das lauteste.', 'The Thunder God of Raijin Garage built every car there himself. His own is the loudest.'),
 ('t_hotrod', 'photo', 'Der King der Greasers kämmt sich vor jedem Rennen die Tolle. Wer ihn schlägt, ist der neue King.', 'The Greasers\' King combs his quiff before every race. Whoever beats him is the new King.'),
 ('t_bolide', 'photo', 'Der Chef von Rosso Ottantuno hat den Rückspiegel abgebaut. Er schaut nie zurück.', 'The Rosso Ottantuno boss removed his mirror. He never looks back.'),
 ('t_vivace', 'courier', 'Le Patron von Périph Tokyo liefert nachts Croissants aus. Mit 500 PS, damit sie warm bleiben.', 'Le Patron of Périph Tokyo delivers croissants at night. With 500 hp so they stay warm.'),
 ('t_akatsuki', 'veteran', 'Der Teamchef von Akatsuki war Werksfahrer. Er trägt eine Stoppuhr um den Hals, auch beim Einkaufen.', 'The Akatsuki team boss was a works driver. He wears a stopwatch around his neck, even shopping.'),
 ('t_etkmodern', 'salaryman', 'Der Vorstand vom Rennspecht Kai leitet ein Start-up, das keiner versteht. Sein ETK versteht jeder.', 'The Rennspecht Kai chairman runs a start-up nobody understands. Everyone understands his ETK.'),
 ('t_bastion', 'guard', 'Redtail, der Chef der Bastion Brotherhood, fährt, als hätte er noch Nachbrenner.', 'Redtail, the Bastion Brotherhood boss, drives like he still has afterburners.'),
 ('t_scintilla', 'taxi', 'Die Gräfin vom Scintilla Salon hat den Salon gegründet, weil ihr der Golfclub zu laut war. Ihr Auto ist es nicht.', 'The Countess of the Scintilla Salon founded it because the golf club was too loud. Her car isn\'t quiet either.'),
]

# Gerüchte über Wanderer und Bosse (kind wanderer/boss): verraten die Bedingung indirekt
SPECIAL = [
 ('w_ojisan', 'veteran', 'Es gibt einen alten Herrn im Bluebuck. Er fährt nur gegen Leute, die einen Miramar lieben.', 'There\'s an old gentleman in a Bluebuck. He only races people who love a Miramar.'),
 ('w_rodeo', 'guard', 'Ein Texaner vom Stützpunkt treibt seinen Pick-up am frühen Abend quer durch die Kurven. Ruft dabei Yeehaw.', 'A Texan from the base herds his pickup sideways through corners in the early evening. Yells yeehaw.'),
 ('w_kemuri', 'drifter', 'Kemuri driftet den alten Bluebuck seines Großvaters. Er zeigt sich erst, wenn die Kasumi geschlagen sind.', 'Kemuri drifts his grandfather\'s old Bluebuck. He only shows himself once the Kasumi are beaten.'),
 ('w_rentner', 'trucker', 'Ein alter Kapitän fährt einen Wendover-Rennwagen. Der kommt erst, wenn du schon viele Nächte hier bist.', 'An old captain drives a Wendover race car. He only turns up once you\'ve spent many nights here.'),
 ('w_shinkiro', 'fan', 'Kurz vor der Dämmerung, nach vielen Nächten, leuchtet manchmal ein BX auf. Dann ist er weg.', 'Just before dawn, after many nights, a BX sometimes lights up. Then it\'s gone.'),
 ('w_rallye', 'courier', 'Eine Französin fährt mit ihrem Rennauto zum Bäcker. Sie sucht Gegner, die Périph Tokyo geschlagen haben.', 'A Frenchwoman drives her race car to the bakery. She looks for people who beat Périph Tokyo.'),
 ('w_dtm', 'mechanic', 'Ein alter Tourenwagenfahrer fährt nur gegen Leute im ETK. Sein Team sucht ihn seit den Achtzigern.', 'An old touring car driver only races people in an ETK. His team has been looking for him since the eighties.'),
 ('w_noir', 'taxi', 'Zwischen eins und drei Uhr kreuzt manchmal eine schwarze Katze deinen Weg. Eine mit vier Rädern.', 'Between one and three am a black cat sometimes crosses your path. One with four wheels.'),
 ('w_tetsujin', 'mechanic', 'Tetsujin hört am Pfeifen deines Laders, ob du würdig bist. Ohne Turbo brauchst du gar nicht erst zu kommen.', 'Tetsujin can tell from your turbo\'s whistle if you\'re worthy. Without a turbo, don\'t bother.'),
 ('w_slider', 'guard', 'Eine Amerikanerin schiebt einen Fullsize quer durch C1. Sie will Leute, die die Night Patrol geschlagen haben.', 'An American woman pushes a full-size sideways through C1. She wants people who beat Night Patrol.'),
 ('w_hotaru', 'photo', 'Hotaru war früher beim Neon Club. Seit sie geschlagen sind, leuchtet am frühen Abend ein Burnside auf.', 'Hotaru used to be in the Neon Club. Since they were beaten, a Burnside glows in the early evening.'),
 ('w_kazekiri', 'taxi', 'Kazekiri fährt nur gegen jemanden, der jede Radarfalle der Stadt kennt. Jede einzelne.', 'Kazekiri only races someone who knows every speed trap in the city. Every single one.'),
 ('w_pastor', 'trucker', 'Ein Prediger aus Alabama segnet am frühen Morgen Reifen. Danach fährt er gegen dich.', 'A preacher from Alabama blesses tyres in the early morning. Then he races you.'),
 ('w_oval', 'fan', 'Ein Stockcar-Fahrer aus Florida sucht nur Gegner, die schon richtig viele Siege haben.', 'A stock car driver from Florida only looks for rivals who already have a lot of wins.'),
 ('w_marshal', 'guard', 'Ein Ex-Polizist aus Nevada wartet auf den, der Shōwa 48 Muscle geschlagen hat.', 'An ex cop from Nevada is waiting for whoever beat Shōwa 48 Muscle.'),
 ('w_fink', 'salaryman', 'Ein Vertreter mit Reklame auf dem Auto taucht auf, wenn der Zangyō Express geschlagen ist. Er verkauft Waschmaschinen.', 'A salesman with ads on his car shows up once Zangyō Express is beaten. He sells washing machines.'),
 ('w_tsukiyomi', 'veteran', 'Tsukiyomi fährt nur zwischen Mitternacht und drei. Niemand kennt sein Gesicht.', 'Tsukiyomi only drives between midnight and three. Nobody knows his face.'),
 ('w_nurburg', 'mechanic', 'Eine deutsche Langstreckenfahrerin sucht dich, wenn du Bayern Kaze geschlagen hast.', 'A German endurance driver comes looking once you\'ve beaten Bayern Kaze.'),
 ('w_yurei', 'taxi', 'Um zwei Uhr nachts, nach vielen Nächten, fährt ein leuchtender Wagen von 1933. Ohne Fahrer.', 'At two in the morning, after many nights, a glowing car from 1933 drives by. No driver.'),
 ('w_erbstueck', 'photo', 'Ein reicher Erbe mit einer seltenen Heritage Edition wartet auf den, der den Rennspecht Kai schlägt.', 'A rich heir with a rare Heritage Edition waits for whoever beats the Rennspecht Kai.'),
 ('w_noodle', 'trucker', 'Ein Ramen-Koch mit einem Gasser riecht nach Nitro. Er will gegen den, der die Greasers geschlagen hat.', 'A ramen chef with a gasser smells of nitro. He wants whoever beat the Greasers.'),
 ('w_gruppe5', 'veteran', 'Ein Gruppe-5-Bolide verschwand 1984 in Fuji. Seit Rosso Ottantuno geschlagen ist, sieht man ihn wieder.', 'A Group 5 Bolide vanished at Fuji in 1984. Since Rosso Ottantuno were beaten, people see it again.'),
 ('w_hakone', 'trucker', 'Ein Opa aus Hakone sucht jemanden, der die Yama-Gumi und die Rally-dan geschlagen hat.', 'A grandpa from Hakone is looking for someone who beat the Yama-Gumi and the Rally-dan.'),
 ('w_tasti', 'student', 'Ein Junge im Cola-Hot-Rod fährt nur am frühen Abend. Er trinkt nur sein eigenes Produkt.', 'A kid in a cola-coloured hot rod only drives in the early evening. He only drinks his own product.'),
 ('w_mont', 'fan', 'Ein Schweizer Konditor fährt erst gegen jemanden mit sehr vielen Siegen. Er sagt, sonst lohnt es die Sahne nicht.', 'A Swiss pastry chef only races someone with a great many wins. Otherwise it\'s not worth the cream, he says.'),
 ('w_kemuri2', 'drifter', 'Wer Kemuri schlägt, bekommt Besuch von einem deutschen Drift-Profi. Mit noch mehr Rauch.', 'Whoever beats Kemuri gets a visit from a German pro drifter. With even more smoke.'),
 ('w_fukurou', 'photo', 'Zwischen eins und vier fährt ein Filmauto, das nie zurückgegeben wurde. Die Eule.', 'Between one and four a film car that was never returned drives the loop. The Owl.'),
 ('w_corsa', 'veteran', 'Eine italienische Werksfahrerin fährt jede Nacht mit ihrem Rennauto ins Hotel. Sie wartet auf den, der den Salon schlägt.', 'An Italian works driver takes her race car to the hotel every night. She waits for whoever beats the Salon.'),
 ('w_benikaze', 'trucker', 'Die Schwester des Bergkönigs hat einen Hopper für die Viertelmeile gebaut. Sie kommt, wenn die Yama-Gumi fallen.', 'The Mountain King\'s sister built a quarter-mile Hopper. She comes once the Yama-Gumi fall.'),
 ('w_tractor', 'guard', 'Ein Farmer aus Iowa mit einem Drag-Pick-up wartet auf den, der die Bastion Brotherhood schlägt.', 'An Iowa farmer with a drag pickup waits for whoever beats the Bastion Brotherhood.'),
 ('w_viper', 'courier', 'Ein Mann aus Detroit misst alles in Viertelmeilen. Er fährt nur zwischen zehn und Mitternacht.', 'A man from Detroit measures everything in quarter miles. He only drives between ten and midnight.'),
 ('w_wheelie', 'fan', 'Wheelie Wanda steht beim Start auf den Hinterrädern. Sie sucht Leute mit vielen Siegen, die Shōwa 48 Muscle geschlagen haben.', 'Wheelie Wanda launches on her rear wheels. She looks for people with lots of wins who beat Shōwa 48 Muscle.'),
 ('w_bigblock', 'mechanic', 'Big Block Barry fährt nur gegen Autos mit Kompressor. Sein Motor stammt angeblich aus einem Flugzeugschlepper.', 'Big Block Barry only races supercharged cars. His engine supposedly came out of an aircraft tug.'),
 ('w_familie', 'salaryman', 'Eine Familie mit 1100 PS fährt zum Einkaufen. Sie wollen den, der die Angestellten und die Papas geschlagen hat.', 'A family with 1100 hp goes grocery shopping. They want whoever beat the office workers and the dads.'),
 ('w_kofun', 'student', 'Ein Archäologe hat einen Covet mit über 1000 PS. Er fährt nur gegen andere Covet-Fahrer.', 'An archaeologist has a Covet with over 1000 hp. He only races other Covet drivers.'),
 ('w_doc', 'guard', 'Ein Zahnarzt vom Stützpunkt wartet auf den, der die Sleeper Agents geschlagen hat. Es wird kurz wehtun.', 'A dentist from the base waits for whoever beat the Sleeper Agents. It will hurt for a second.'),
 ('w_hellcat', 'trucker', 'Eine Oma aus Georgia fährt mit 1000 PS zum Bingo. Sie will den, der Ōji-san geschlagen hat.', 'A grandma from Georgia drives 1000 hp to bingo. She wants whoever beat Ōji-san.'),
 ('w_dragvan', 'courier', 'Zwischen fünf und sechs Uhr morgens fährt ein Lieferwagen von 1933 mit 1300 PS. Die Pakete tun mir leid.', 'Between five and six am a 1933 delivery van with 1300 hp drives by. I feel sorry for the parcels.'),
 ('w_bakuon', 'mechanic', 'Bakuon fährt einen BX mit 1300 PS. Er fährt nur gegen andere BX-Fahrer.', 'Bakuon drives a BX with 1300 hp. He only races other BX drivers.'),
 ('w_nitro', 'photo', 'Ein Mann ohne Augenbrauen fährt einen Burnside mit fast 1500 PS. Er will den, der die Greasers und Noodle geschlagen hat.', 'A man with no eyebrows drives a Burnside with almost 1500 hp. He wants whoever beat the Greasers and Noodle.'),
 ('w_afterburner', 'guard', 'Seit Redtail geschlagen ist, fährt ein Bastion ohne erkennbaren Fahrer. Manche sagen, es ist sein alter Flügelmann.', 'Since Redtail was beaten, a Bastion with no visible driver roams the loop. Some say it\'s his old wingman.'),
 ('w_kaminari', 'veteran', 'Zwischen drei und vier Uhr, nach der Eule und der Signora, kommt der Blitz. Mehr weiß niemand.', 'Between three and four am, after the Owl and the Signora, comes the Lightning. Nobody knows more.'),
 ('w_henry', 'salaryman', 'Ein Amerikaner in einem deutschen I-Series fährt erst, wenn der Ginza Neon Club gefallen ist. Spät, zwischen elf und vier.', 'An American in a German I-Series only shows up once the Ginza Neon Club has fallen. Late, between eleven and four.'),
 ('w_alex_zockt', 'drifter', 'Da fährt einer im BX, der glaubt, er wäre der Schnellste. Er kommt angeblich erst, wenn dich sieben Blitzer erwischt haben.', 'There\'s a guy in a BX who thinks he\'s the fastest. Supposedly he only comes once seven speed cameras have caught you.'),
 ('b_shirotora', 'veteran', 'Der Weiße Tiger bewacht den Inneren Ring. Er zeigt sich erst, wenn die Lanterns, der Neon Club, die Yama-Gumi und die Kitsune gefallen sind.', 'The White Tiger guards the inner loop. He only shows himself once the Lanterns, the Neon Club, the Yama-Gumi and the Kitsune have fallen.'),
 ('b_kokuryu', 'veteran', 'Den Schwarzen Drachen kennt jeder. Er fährt nur gegen den, der Kasumi, Akatsuki, Raijin und Kurogane geschlagen hat.', 'Everyone knows the Black Dragon. He only races whoever beat Kasumi, Akatsuki, Raijin and Kurogane.'),
 ('b_mugen', 'veteran', 'Mugen gab es schon, als der Ring eröffnet wurde. Wer Tiger und Drache schlägt, trifft ihn vielleicht zwischen zwei und vier.', 'Mugen was here when the loop opened. Whoever beats the Tiger and the Dragon might meet him between two and four.'),
]

# Vorlagen (kind waiting): {name} = ein Rivale, der gerade auf dich wartet (das System setzt ihn ein)
WAITING = [
 ('fan', 'Ich hab gehört, {name} sucht dich. Heute Nacht auf dem Ring.', 'I heard {name} is looking for you. Out on the loop tonight.'),
 ('taxi', '{name} ist vorhin an mir vorbei und hat nach dir gefragt.', '{name} passed me earlier and asked about you.'),
 ('guard', '{name} war vorhin hier und hat nach deinem Auto gefragt.', '{name} was here earlier asking about your car.'),
 ('photo', 'Ich hab heute {name} fotografiert. Sah aus, als würde jemand gesucht. Vielleicht du.', 'I took a picture of {name} tonight. Looked like they were waiting for someone. Maybe you.'),
 ('trucker', '{name} fährt heute Nacht auf dem Ring. Pass gut auf.', '{name} is out on the loop tonight. Watch yourself.'),
 ('veteran', 'Seit deinem Sieg gegen {name} redet hier jeder von einer Revanche.', 'Since you beat {name}, everyone here is talking about a rematch.'),
]

# Wie die Figuren an den PAs aussehen und was sie fahren (talk.lua).
# figur m/f, when = wann sie an den PAs stehen (Gewicht nachts/tagsüber, 0 = nie),
# cars = Automodelle neben denen sie stehen (leer = steht ohne Auto, z. B. der Parkwächter),
# match = Teil des Config-Namens, der passen muss (z. B. taxi), look = Teile fürs Porträt (Silhouetten-Tool),
# color = Lackfarbe der Figur (0..1).
SPEAKER_STYLE = {
 'fan':       dict(figur='m', night=3, day=1, cars=[('sunburst2', ''), ('covet', ''), ('pessima', '')], color=[0.9, 0.45, 0.1], look=[dict(jacke='hoodie', haare='capback'), dict(jacke='tshirt', haare='stachel', hals='kopfhoerer'), dict(jacke='sukajan', haare='kurz')]),
 'mechanic':  dict(figur='m', night=2, day=2, cars=[('pickup', ''), ('van', '')], color=[0.25, 0.35, 0.55], look=[dict(jacke='overall', haare='cap', hals='handtuch'), dict(jacke='overall', haare='bandana'), dict(jacke='overall', haare='kahl', brille='goggles')]),
 'trucker':   dict(figur='m', night=2, day=3, cars=[('van', ''), ('pickup', '')], color=[0.7, 0.6, 0.2], look=[dict(jacke='warnweste', haare='cap', hals='handtuch'), dict(jacke='warnweste', haare='muetze'), dict(jacke='jeans', haare='kurz', extra='zahnstocher')]),
 'taxi':      dict(figur='m', night=2, day=2, cars=[('fullsize', 'taxi'), ('midsize', 'taxi'), ('fullsize', '')], color=[0.85, 0.75, 0.2], look=[dict(jacke='weste', haare='scheitel', haarfarbe='silber'), dict(jacke='anzug', haare='kurz', brille='halb'), dict(jacke='weste', haare='kahl', extra='maske')]),
 'photo':     dict(figur='f', night=2, day=1, cars=[('covet', ''), ('etkc', '')], color=[0.75, 0.3, 0.6], look=[dict(jacke='jeans', haare='bobcut', hals='kette'), dict(jacke='bomber', haare='zopf', brille='rund'), dict(jacke='windbreaker', haare='capback')]),
 'veteran':   dict(figur='m', night=3, day=1, cars=[('moonhawk', ''), ('bluebuck', ''), ('miramar', ''), ('sbr', '')], color=[0.55, 0.55, 0.6], look=[dict(jacke='leder', haare='tolle', haarfarbe='silber'), dict(jacke='mantel', haare='kahl', brille='sonne'), dict(jacke='strick', haare='scheitel', haarfarbe='silber', brille='rund')]),
 'rookie':    dict(figur='m', night=3, day=1, cars=[('covet', ''), ('pessima', ''), ('bx', '')], color=[0.3, 0.75, 0.4], look=[dict(jacke='hoodie', haare='stachel'), dict(jacke='tshirt', haare='kurz'), dict(jacke='training', haare='capback')]),
 'guard':     dict(figur='m', night=1, day=2, cars=[], color=[0.2, 0.3, 0.25], look=[dict(jacke='warnweste', haare='muetze'), dict(jacke='warnweste', haare='cap', haarfarbe='silber'), dict(jacke='militaer', haare='muetze', extra='maske')]),
 'courier':   dict(figur='m', night=1, day=3, cars=[('van', ''), ('pickup', '')], color=[0.2, 0.5, 0.8], look=[dict(jacke='windbreaker', haare='capback', extra='headset'), dict(jacke='polo', haare='cap'), dict(jacke='windbreaker', haare='kurz', hals='kopfhoerer')]),
 'student':   dict(figur='f', night=2, day=1, cars=[('covet', ''), ('pessima', '')], color=[0.6, 0.7, 0.95], look=[dict(jacke='strick', haare='hime', hals='schal'), dict(jacke='bluse', haare='zoepfe', brille='rund'), dict(jacke='hoodie', haare='dutt')]),
 'salaryman': dict(figur='m', night=2, day=2, cars=[('midsize', ''), ('etki', ''), ('legran', '')], color=[0.35, 0.35, 0.4], look=[dict(jacke='anzug', haare='scheitel', brille='halb'), dict(jacke='anzug', haare='kurz'), dict(jacke='mantel', haare='scheitel', brille='rund')]),
 'drifter':   dict(figur='m', night=3, day=0, cars=[('sunburst2', 'drift'), ('bx', ''), ('sunburst2', '')], color=[0.85, 0.15, 0.2], look=[dict(jacke='sukajan', haare='stachel', extra='zahnstocher'), dict(jacke='tokko', haare='irokese'), dict(jacke='bomber', haare='bandana', brille='sonne')]),
}

# Wenn man denselben Fahrer in derselben Nacht (oder am selben Tag) nochmal anspricht (kind again)
AGAIN = [
 ('Hab dir doch schon alles erzählt. Fahr los, die Nacht wartet nicht.', 'I already told you everything. Get going, the night won\'t wait.'),
 ('Mehr weiß ich gerade auch nicht. Frag mal die anderen hier.', 'That\'s all I know right now. Ask the others around here.'),
 ('Du schon wieder? Wenn ich was Neues höre, sag ich Bescheid.', 'You again? If I hear anything new, I\'ll let you know.'),
 ('Komm morgen wieder. Bis dahin hat sich bestimmt was rumgesprochen.', 'Come back tomorrow. Word gets around by then.'),
 ('Ich trink nur noch meinen Kaffee aus. Dann bin ich auch weg.', 'Just finishing my coffee. Then I\'m off too.'),
 ('Wenn du so viel redest wie du fährst, wird das heute nichts mehr.', 'If you talk as much as you drive, nothing\'s happening tonight.'),
 ('Mehr gibt es nicht zu erzählen. Ehrlich.', 'There\'s nothing more to tell. Honestly.'),
 ('Schau dich lieber auf dem Ring um als hier auf dem Parkplatz.', 'Better look around on the loop than here in the car park.'),
]

# Einstellungen fürs Gesprächs-System (talk.lua). Werte im Handbuch erklärt.
PA = {
 '_hinweis': 'Fahrer an den PAs (napSpots der Kartendatei). nightCount/dayCount = wie viele Fahrer nachts/tagsüber (von, bis). '
             'spawnDistance = ab dieser Entfernung zur PA-Mitte erscheinen sie, despawnDistance = ab hier verschwinden sie wieder (m). '
             'spotRadius = in diesem Umkreis um die PA-Mitte werden Parkbuchten gesucht (m). talkDistance = so nah musst du zu Fuß ran (m), '
             'lookDistance = ab hier dreht sich der Fahrer zu dir. importantChance = Chance, dass ein Fahrer ein Gerücht oder einen Hinweis statt Smalltalk hat. '
             'secondLineChance = Chance auf einen zweiten Satz. rankSlack = so viele Ränge vor dem nötigen Rang hört man schon von Crews und Wanderern. '
             'heardWeight = Gewicht für Sätze, die man schon kennt (1 = normal, 0 = nie wieder). excludeConfigs = Configs mit diesen Wörtern parken nie an der PA. '
             'portraitVariants = Porträts je Sprecher (art/portraits/npc/<sprecher>_<n>.svg). '
             'loreChance = Chance auf Wissen (fact) statt Smalltalk, wenn kein Gerücht kommt. ownTopicWeight/otherTopicWeight = Gewicht für Wissen der eigenen Figur bzw. anderer Figuren. '
             'placeWeight = Faktor für Wissen über genau diese PA. moreChance = Chance, beim zweiten Ansprechen noch Wissen zu bekommen statt "Hab dir schon alles erzählt". '
             'rivalNight/rivalDay = wie viele Rivalen und Wanderer pro PA nachts/tagsüber neben ihrem Auto stehen (von, bis). rivalWaitDistance/rivalWaitSpeed = so weit weg (m) und so schnell (km/h) musst du sein, bis der verabredete Rivale vor dir auftaucht. '
             'rivalWeightNew/rivalWeightBeaten/rivalWeightHolder = wie oft neue, geschlagene und Rivalen mit deinem Auto (Pink Slip) an der PA stehen.',
 'nightCount': [3, 6], 'dayCount': [1, 2],
 'spawnDistance': 230, 'despawnDistance': 330, 'spotRadius': 70,
 'talkDistance': 2.8, 'lookDistance': 9,
 'importantChance': 0.4, 'secondLineChance': 0.35, 'rankSlack': 1, 'heardWeight': 0.15,
 'loreChance': 0.6, 'ownTopicWeight': 3, 'otherTopicWeight': 0.5, 'placeWeight': 3, 'moreChance': 0.5,
 'rivalNight': [0, 2], 'rivalDay': [0, 0], 'rivalWaitDistance': 250, 'rivalWaitSpeed': 30,
 'rivalWeightNew': 3, 'rivalWeightBeaten': 1, 'rivalWeightHolder': 6,
 'portraitVariants': 3,
 'excludeConfigs': ['police', 'pursuit', 'interceptor', 'undercover', 'race', 'rally', 'drag', 'track', 'gymkhana', 'safety', 'baja', 'stunt', 'derby', 'prerunner', 'crawler', 'ambulance', 'fire'],
}

# Überleitung, wenn man denselben Fahrer nochmal anspricht und er noch etwas Wissenswertes kennt (kind more)
MORE = [
 ('Ach, wo du schon mal da bist, eins noch.', 'Oh, since you\'re here, one more thing.'),
 ('Warte, mir ist noch was eingefallen.', 'Wait, something else just came to mind.'),
 ('Du bist ja neugierig. Na gut, hör zu.', 'Curious one, aren\'t you? Fine, listen.'),
 ('Hast du kurz Zeit? Das hier weiß kaum einer.', 'Got a second? Hardly anyone knows this.'),
 ('Eine Sache noch, dann lass ich dich in Ruhe.', 'One more thing, then I\'ll leave you alone.'),
 ('Schon wieder du? Dann erzähl ich dir was Neues.', 'You again? Then I\'ll tell you something new.'),
]

def build():
    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from lore import LORE, SMALL_MORE
    talk = []
    def add(kind, speaker, de, en, **extra):
        talk.append(dict(id=f'{kind}_{len([t for t in talk if t["kind"] == kind]) + 1}', kind=kind, speaker=speaker, text={'de': de, 'en': en}, **extra))
    for s, de, en in SMALL + SMALL_MORE: add('small', s, de, en)
    for s, de, en in TIPS: add('tip', s, de, en)
    for team, s, de, en in CREW: add('crew', s, de, en, about=team)
    for team, s, de, en in LEADER: add('leader', s, de, en, about=team)
    for rid, s, de, en in SPECIAL: add('boss' if rid.startswith('b_') else 'wanderer', s, de, en, about=rid)
    for s, de, en in WAITING: add('waiting', s, de, en)
    for de, en in AGAIN: add('again', '', de, en)
    for de, en in MORE: add('more', '', de, en)
    for s, topic, mp, place, lines in LORE:
        extra = dict(topic=topic)
        if mp: extra['map'] = mp
        if place: extra['place'] = place
        if len(lines) > 1: extra['lines'] = [{'de': de, 'en': en} for de, en in lines[1:]]
        add('fact', s, lines[0][0], lines[0][1], **extra)
    return {
     '_hinweis': 'PA-Gespräche (System: talk.lua, Einstellungen unter pa). speakers = allgemeine Figuren an den Parkplätzen (figur, night/day = wie oft nachts/tagsüber, cars = Autos, match = Config-Name enthält, look = Porträt-Teile, color = Lack der Figur). kind: small = belanglos, tip = Spieltipp, again = Antwort, wenn man denselben Fahrer nochmal anspricht (speaker leer = alle), '
                 'crew = Gerücht über eine Crew (about = Crew-ID, sinnvoll ab deren minRank - 1, solange nicht geschlagen), leader = Gerücht über den Leader '
                 '(wenn die Crew fast geschlagen ist), wanderer/boss = verrät die Bedingung eines Wanderers oder Bosses (about = Rivalen-ID, solange nicht geschlagen), '
                 'waiting = Vorlage, {name} = ein Rivale, der gerade auf dich wartet. '
                 'fact = Wissen über Japan, Tokio, den Shutoko und die Szene (topic = Thema fürs Label, map = nur auf dieser Karte, place = nur an PAs, deren Name das enthält, '
                 'text = erster Satz, lines = weitere Sätze der Geschichte). more = Überleitung, wenn man jemanden nochmal anspricht und er noch Wissen hat. '
                 'Neue Wissens-Texte am besten in tools/generator/lore.py eintragen.',
     'pa': PA,
     'speakers': [dict({'id': i, 'name': {'de': de, 'en': en}}, figur=SPEAKER_STYLE[i]['figur'], night=SPEAKER_STYLE[i]['night'], day=SPEAKER_STYLE[i]['day'],
                       cars=[{'model': m, 'match': mt} if mt else {'model': m} for m, mt in SPEAKER_STYLE[i]['cars']],
                       color=SPEAKER_STYLE[i]['color'], look=SPEAKER_STYLE[i]['look']) for i, de, en in SPEAKERS],
     'talk': talk,
    }

if __name__ == '__main__':
    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from protect import DATA, write_protected
    d = build()
    rv = json.load(open(os.path.join(DATA, 'rivals.json'), encoding='utf-8'))
    ids = {r['id'] for r in rv['rivals']} | {t['id'] for t in rv['teams']}
    sp = {s['id'] for s in d['speakers']}
    for t in d['talk']:
        assert t['speaker'] in sp or t['kind'] in ('again', 'more'), t
        assert t['kind'] != 'fact' or t['topic'] in ('shutoko', 'c1', 'place', 'racing', 'cars', 'tokyo', 'japan', 'beamng'), t
        assert 'about' not in t or t['about'] in ids, t
    assert {t['about'] for t in d['talk'] if t['kind'] in ('wanderer', 'boss')} == {r['id'] for r in rv['rivals'] if r.get('wanderer') or r.get('boss')}
    assert {t['about'] for t in d['talk'] if t['kind'] == 'crew'} == {t['id'] for t in rv['teams']}
    write_protected('chat.json', d)  # Handänderungen in chat.json bleiben erhalten
    from collections import Counter
    print(len(d['talk']), Counter(t['kind'] for t in d['talk']))
