/**
 * Hashiriya Battle – Community-Wanderer (Google-Formular, englisch)
 *
 * EINRICHTEN (einmalig, ca. 2 Minuten):
 *  1. https://script.google.com öffnen → "Neues Projekt".
 *  2. Den ganzen Inhalt dieser Datei hineinkopieren (vorhandenen Code ersetzen) und speichern.
 *  3. Oben in der Funktionsauswahl "formularAnlegen" wählen → "Ausführen".
 *     Google fragt nach Berechtigungen (Formulare, Tabellen, Drive). Bestätigen.
 *  4. Unten im "Ausführungsprotokoll" stehen die Links:
 *     - Link zum Teilen (den schickst du der Community)
 *     - Link zum Bearbeiten (nur für dich)
 *     - Link zur Prüf-Tabelle (nur für dich)
 *  Neue Version des Skripts? Einfach erneut "formularAnlegen" ausführen: das legt ein NEUES Formular an.
 *  Das alte Formular kannst du in Google Drive löschen.
 *
 * EINSENDUNGEN PRÜFEN UND EXPORTIEREN:
 *  1. "rivalsExportieren" ausführen. Neue Einsendungen landen in der Tabelle "Hashiriya Battle – Wanderer prüfen"
 *     mit Status "Neu".
 *  2. In der Tabelle in der Spalte "Status" "Angenommen" oder "Abgelehnt" eintragen (Auswahlliste).
 *  3. "rivalsExportieren" nochmal ausführen. Alle angenommenen Wanderer landen im Drive-Ordner
 *     "Hashiriya Battle – Community Import":
 *       community_wanderer.json            Einträge für rivals.json (mit Avatar, Kennzeichen, Sprüchen, Credits)
 *       credits.json                       Namen für die Credits im Spiel
 *       vehicles/<model>/<config>.pc       die eingefügten Configs
 *  4. Den Ordner herunterladen (Rechtsklick → Herunterladen, gibt eine ZIP) und mir geben.
 *     Ich übernehme ihn mit tools/community/import_wanderer.py in die Mod.
 *
 * Teilnehmer brauchen KEIN Google-Konto.
 * Listen (Crews, Leader, Wanderer, Bosse, Avatar-Teile) erzeugt tools/community/build_form_lists.py.
 */

var TITEL = 'Hashiriya Battle – Become a Wanderer';
var ORDNER = 'Hashiriya Battle – Community Import';
var TABELLE = 'Hashiriya Battle – Wanderer prüfen';

// --- ERZEUGT von tools/community/build_form_lists.py aus rivals.json, nicht von Hand ändern ---
var TEAMS = [["t_lantern", "Mayonaka Lanterns"], ["t_zangyo", "Zangyō Express"], ["t_showa", "Shōwa Retro Club"], ["t_diana", "Diana Sisters"], ["t_yamagumi", "Takane Yama-Gumi"], ["t_bxboys", "Nihyaku Boys"], ["t_neon", "Ginza Neon Club"], ["t_kombi", "Kombi Papas"], ["t_kitsune", "Kōsoku Kitsune"], ["t_pocket", "Pocket Rockets"], ["t_hoshikuzu", "Hoshikuzu Rally-dan"], ["t_sleeper", "Sleeper Agents"], ["t_kasumi", "Kasumi Drift Union"], ["t_etkklassik", "Bayern Kaze"], ["t_sbr", "Hirochi Blood"], ["t_yokota", "Night Patrol 16"], ["t_kurogane", "Kurogane-kai"], ["t_muscle73", "Shōwa 48 Muscle"], ["t_raijin", "Raijin Garage"], ["t_hotrod", "Kōenji Greasers"], ["t_bolide", "Rosso Ottantuno"], ["t_vivace", "Périph Tokyo"], ["t_akatsuki", "Akatsuki Racing"], ["t_etkmodern", "Rennspecht Kai"], ["t_bastion", "Bastion Brotherhood"], ["t_scintilla", "Scintilla Salon"]];
var LEADERS = [["t_lantern_leader", "Riku Tanabe – Mayonaka Lanterns"], ["t_zangyo_leader", "Shūhei Kachō – Zangyō Express"], ["t_showa_leader", "Toshirō Kaneda – Shōwa Retro Club"], ["t_diana_leader", "Aiko Hanazawa – Diana Sisters"], ["t_yamagumi_leader", "Jiro Takane – Takane Yama-Gumi"], ["t_bxboys_leader", "Daisuke Hokuto – Nihyaku Boys"], ["t_neon_leader", "Reika Hoshino – Ginza Neon Club"], ["t_kombi_leader", "Kōji Ōkubo – Kombi Papas"], ["t_kitsune_leader", "Shiori Kitsuneda – Kōsoku Kitsune"], ["t_pocket_leader", "Mikio Saitō – Pocket Rockets"], ["t_hoshikuzu_leader", "Takeo Kitahara – Hoshikuzu Rally-dan"], ["t_sleeper_leader", "Frank Whitaker – Sleeper Agents"], ["t_kasumi_leader", "Kaito Shirasagi – Kasumi Drift Union"], ["t_etkklassik_leader", "Wolfgang Brandl – Bayern Kaze"], ["t_sbr_leader", "Seiji Hirochika – Hirochi Blood"], ["t_yokota_leader", "Sgt. Marcus Delgado – Night Patrol 16"], ["t_kurogane_leader", "Masamune Kurogane – Kurogane-kai"], ["t_muscle73_leader", "Kōtarō Nishikawa – Shōwa 48 Muscle"], ["t_raijin_leader", "Genji Raijima – Raijin Garage"], ["t_hotrod_leader", "Eiji Yamamoto – Kōenji Greasers"], ["t_bolide_leader", "Marco Galli – Rosso Ottantuno"], ["t_vivace_leader", "Antoine Moreau – Périph Tokyo"], ["t_akatsuki_leader", "Ryo Akatsuki – Akatsuki Racing"], ["t_etkmodern_leader", "Haruki Kurosaki – Rennspecht Kai"], ["t_bastion_leader", "Col. Jack \"Redtail\" Harmon – Bastion Brotherhood"], ["t_scintilla_leader", "Valentina Saionji – Scintilla Salon"]];
// Alle Crew-Mitglieder (id, Name, Crew) für die Namenssuche beim Export
var MEMBERS = [["t_lantern_1", "Kenta Mori", "Mayonaka Lanterns"], ["t_lantern_2", "Yui Sakamoto", "Mayonaka Lanterns"], ["t_lantern_3", "Daichi Ono", "Mayonaka Lanterns"], ["t_lantern_4", "Haruto Ishii", "Mayonaka Lanterns"], ["t_lantern_5", "Sora Takeda", "Mayonaka Lanterns"], ["t_lantern_6", "Mei Arakawa", "Mayonaka Lanterns"], ["t_lantern_7", "Yuma Kogure", "Mayonaka Lanterns"], ["t_lantern_8", "Hinata Oda", "Mayonaka Lanterns"], ["t_lantern_leader", "Riku Tanabe", "Mayonaka Lanterns"], ["t_zangyo_1", "Tadashi Hirota", "Zangyō Express"], ["t_zangyo_2", "Michiko Aoyama", "Zangyō Express"], ["t_zangyo_3", "Hideo Kubo", "Zangyō Express"], ["t_zangyo_4", "Kazue Sugawara", "Zangyō Express"], ["t_zangyo_5", "Masato Ikeda", "Zangyō Express"], ["t_zangyo_6", "Junko Ebina", "Zangyō Express"], ["t_zangyo_7", "Toru Matsui", "Zangyō Express"], ["t_zangyo_8", "Reiko Hamada", "Zangyō Express"], ["t_zangyo_9", "Yoshio Kanno", "Zangyō Express"], ["t_zangyo_10", "Satoshi Ueno", "Zangyō Express"], ["t_zangyo_11", "Atsuko Kimura", "Zangyō Express"], ["t_zangyo_leader", "Shūhei Kachō", "Zangyō Express"], ["t_showa_1", "Fumio Nagai", "Shōwa Retro Club"], ["t_showa_2", "Setsuko Nagai", "Shōwa Retro Club"], ["t_showa_3", "Isao Hirose", "Shōwa Retro Club"], ["t_showa_4", "Kimiko Sasaki", "Shōwa Retro Club"], ["t_showa_5", "Masao Kudō", "Shōwa Retro Club"], ["t_showa_6", "Haruko Ōishi", "Shōwa Retro Club"], ["t_showa_7", "Gonzō Tabata", "Shōwa Retro Club"], ["t_showa_8", "Giulia Rossi", "Shōwa Retro Club"], ["t_showa_9", "Luca Rossi", "Shōwa Retro Club"], ["t_showa_leader", "Toshirō Kaneda", "Shōwa Retro Club"], ["t_diana_1", "Momo Hanazawa", "Diana Sisters"], ["t_diana_2", "Kana Uchida", "Diana Sisters"], ["t_diana_3", "Natsumi Ono", "Diana Sisters"], ["t_diana_4", "Sakura Imai", "Diana Sisters"], ["t_diana_5", "Rei Kurosawa", "Diana Sisters"], ["t_diana_6", "Yuka Ōta", "Diana Sisters"], ["t_diana_leader", "Aiko Hanazawa", "Diana Sisters"], ["t_yamagumi_1", "Goro Yamane", "Takane Yama-Gumi"], ["t_yamagumi_2", "Tomoe Hirata", "Takane Yama-Gumi"], ["t_yamagumi_3", "Isamu Kuroki", "Takane Yama-Gumi"], ["t_yamagumi_4", "Hana Oyama", "Takane Yama-Gumi"], ["t_yamagumi_5", "Taro Kumagai", "Takane Yama-Gumi"], ["t_yamagumi_6", "Fumiko Kumagai", "Takane Yama-Gumi"], ["t_yamagumi_7", "Shige Nakayama", "Takane Yama-Gumi"], ["t_yamagumi_8", "Kiyoshi Tanizaki", "Takane Yama-Gumi"], ["t_yamagumi_9", "Nobu Iwasaki", "Takane Yama-Gumi"], ["t_yamagumi_10", "Yoko Fujimori", "Takane Yama-Gumi"], ["t_yamagumi_11", "Hachiro Mori", "Takane Yama-Gumi"], ["t_yamagumi_12", "Chiyo Hosokawa", "Takane Yama-Gumi"], ["t_yamagumi_leader", "Jiro Takane", "Takane Yama-Gumi"], ["t_bxboys_1", "Kenji Ōno", "Nihyaku Boys"], ["t_bxboys_2", "Taiga Shimizu", "Nihyaku Boys"], ["t_bxboys_3", "Shō Murakami", "Nihyaku Boys"], ["t_bxboys_4", "Yūki Fujii", "Nihyaku Boys"], ["t_bxboys_5", "Ryōta Hokuto", "Nihyaku Boys"], ["t_bxboys_6", "Hikaru Abe", "Nihyaku Boys"], ["t_bxboys_leader", "Daisuke Hokuto", "Nihyaku Boys"], ["t_neon_1", "Mika Fujita", "Ginza Neon Club"], ["t_neon_2", "Shun Arai", "Ginza Neon Club"], ["t_neon_3", "Nana Kudo", "Ginza Neon Club"], ["t_neon_4", "Takeshi Mura", "Ginza Neon Club"], ["t_neon_5", "Ayumi Kanzaki", "Ginza Neon Club"], ["t_neon_6", "Goro Shibata", "Ginza Neon Club"], ["t_neon_7", "Sachiko Mine", "Ginza Neon Club"], ["t_neon_8", "Kaoru Nishio", "Ginza Neon Club"], ["t_neon_9", "Erika Mochizuki", "Ginza Neon Club"], ["t_neon_10", "Jun Tachibana", "Ginza Neon Club"], ["t_neon_11", "Carlos Mendoza", "Ginza Neon Club"], ["t_neon_leader", "Reika Hoshino", "Ginza Neon Club"], ["t_kombi_1", "Hiroki Saitō", "Kombi Papas"], ["t_kombi_2", "Kenta Ōkubo", "Kombi Papas"], ["t_kombi_3", "Makoto Yasuda", "Kombi Papas"], ["t_kombi_4", "Takashi Mori", "Kombi Papas"], ["t_kombi_5", "Norihiko Endō", "Kombi Papas"], ["t_kombi_6", "Daichi Hara", "Kombi Papas"], ["t_kombi_7", "Yusaku Tomita", "Kombi Papas"], ["t_kombi_8", "Kazuya Ōmura", "Kombi Papas"], ["t_kombi_9", "Shinobu Kato", "Kombi Papas"], ["t_kombi_10", "Hayato Ichikawa", "Kombi Papas"], ["t_kombi_11", "Takumi Ōkubo", "Kombi Papas"], ["t_kombi_12", "Mamoru Fuse", "Kombi Papas"], ["t_kombi_leader", "Kōji Ōkubo", "Kombi Papas"], ["t_kitsune_1", "Akane Sugiyama", "Kōsoku Kitsune"], ["t_kitsune_2", "Hiro Matsuda", "Kōsoku Kitsune"], ["t_kitsune_3", "Kiko Iwata", "Kōsoku Kitsune"], ["t_kitsune_4", "Masaru Endo", "Kōsoku Kitsune"], ["t_kitsune_5", "Tamaki Fushimi", "Kōsoku Kitsune"], ["t_kitsune_6", "Ginji Kuzunoha", "Kōsoku Kitsune"], ["t_kitsune_7", "Ume Kuzunoha", "Kōsoku Kitsune"], ["t_kitsune_8", "Inari Tsuda", "Kōsoku Kitsune"], ["t_kitsune_leader", "Shiori Kitsuneda", "Kōsoku Kitsune"], ["t_pocket_1", "Kotarō Mizuno", "Pocket Rockets"], ["t_pocket_2", "Ayame Kitano", "Pocket Rockets"], ["t_pocket_3", "Ryūsei Arima", "Pocket Rockets"], ["t_pocket_4", "Kaede Nomoto", "Pocket Rockets"], ["t_pocket_5", "Tsubasa Ide", "Pocket Rockets"], ["t_pocket_6", "Gen Yanagi", "Pocket Rockets"], ["t_pocket_7", "Mirai Toda", "Pocket Rockets"], ["t_pocket_leader", "Mikio Saitō", "Pocket Rockets"], ["t_hoshikuzu_1", "Shōta Kiyohara", "Hoshikuzu Rally-dan"], ["t_hoshikuzu_2", "Erina Kaji", "Hoshikuzu Rally-dan"], ["t_hoshikuzu_3", "Hideki Mitsuya", "Hoshikuzu Rally-dan"], ["t_hoshikuzu_4", "Nanami Kiyohara", "Hoshikuzu Rally-dan"], ["t_hoshikuzu_5", "Kōsuke Hirai", "Hoshikuzu Rally-dan"], ["t_hoshikuzu_6", "Ai Sekiguchi", "Hoshikuzu Rally-dan"], ["t_hoshikuzu_7", "Hayao Kitahara", "Hoshikuzu Rally-dan"], ["t_hoshikuzu_leader", "Takeo Kitahara", "Hoshikuzu Rally-dan"], ["t_sleeper_1", "Kenichi Ōshima", "Sleeper Agents"], ["t_sleeper_2", "Brenda Kowalski", "Sleeper Agents"], ["t_sleeper_3", "Yasuo Tamura", "Sleeper Agents"], ["t_sleeper_4", "Dale Hutchins", "Sleeper Agents"], ["t_sleeper_5", "Yoshiki Mae", "Sleeper Agents"], ["t_sleeper_6", "Harold Beckett", "Sleeper Agents"], ["t_sleeper_7", "Mayumi Beckett", "Sleeper Agents"], ["t_sleeper_8", "Tomohiro Saeki", "Sleeper Agents"], ["t_sleeper_9", "Gary Lindqvist", "Sleeper Agents"], ["t_sleeper_10", "Noriko Wada", "Sleeper Agents"], ["t_sleeper_11", "Bob Danner", "Sleeper Agents"], ["t_sleeper_12", "Shinya Kuroe", "Sleeper Agents"], ["t_sleeper_leader", "Frank Whitaker", "Sleeper Agents"], ["t_kasumi_1", "Sota Nishida", "Kasumi Drift Union"], ["t_kasumi_2", "Aoi Kamiya", "Kasumi Drift Union"], ["t_kasumi_3", "Ren Hayashi", "Kasumi Drift Union"], ["t_kasumi_4", "Yuto Kanda", "Kasumi Drift Union"], ["t_kasumi_5", "Rin Asakura", "Kasumi Drift Union"], ["t_kasumi_6", "Kohei Mizushima", "Kasumi Drift Union"], ["t_kasumi_7", "Lukas Brenner", "Kasumi Drift Union"], ["t_kasumi_leader", "Kaito Shirasagi", "Kasumi Drift Union"], ["t_etkklassik_1", "Shigeru Bando", "Bayern Kaze"], ["t_etkklassik_2", "Hanae Kröger", "Bayern Kaze"], ["t_etkklassik_3", "Takeshi Murase", "Bayern Kaze"], ["t_etkklassik_4", "Kōichi Oyamada", "Bayern Kaze"], ["t_etkklassik_5", "Rie Hamaguchi", "Bayern Kaze"], ["t_etkklassik_6", "Jun Uehara", "Bayern Kaze"], ["t_etkklassik_7", "Ingrid Vogel", "Bayern Kaze"], ["t_etkklassik_8", "Masahiro Amano", "Bayern Kaze"], ["t_etkklassik_9", "Daiki Fukuda", "Bayern Kaze"], ["t_etkklassik_10", "Midori Kawase", "Bayern Kaze"], ["t_etkklassik_11", "Ryōhei Ishikawa", "Bayern Kaze"], ["t_etkklassik_leader", "Wolfgang Brandl", "Bayern Kaze"], ["t_sbr_1", "Kōhei Nakamoto", "Hirochi Blood"], ["t_sbr_2", "Mariko Tsuji", "Hirochi Blood"], ["t_sbr_3", "Hiroshi Kanda", "Hirochi Blood"], ["t_sbr_4", "Kenzō Ōtsuka", "Hirochi Blood"], ["t_sbr_5", "Yumi Hirochika", "Hirochi Blood"], ["t_sbr_6", "Tomoya Kuwabara", "Hirochi Blood"], ["t_sbr_7", "Shizuka Mori", "Hirochi Blood"], ["t_sbr_8", "Denki Yamato", "Hirochi Blood"], ["t_sbr_leader", "Seiji Hirochika", "Hirochi Blood"], ["t_yokota_1", "Cpl. Jenny Morales", "Night Patrol 16"], ["t_yokota_2", "Pvt. Tyler Brooks", "Night Patrol 16"], ["t_yokota_3", "Sgt. Ray Washington", "Night Patrol 16"], ["t_yokota_4", "Lt. Amanda Price", "Night Patrol 16"], ["t_yokota_5", "Spc. Danny Okafor", "Night Patrol 16"], ["t_yokota_6", "MSgt. Earl Jennings", "Night Patrol 16"], ["t_yokota_7", "Cpl. Kevin Reed", "Night Patrol 16"], ["t_yokota_8", "Sgt. Lisa Kim", "Night Patrol 16"], ["t_yokota_leader", "Sgt. Marcus Delgado", "Night Patrol 16"], ["t_kurogane_1", "Shinji Kuroda", "Kurogane-kai"], ["t_kurogane_2", "Asuka Mizuno", "Kurogane-kai"], ["t_kurogane_3", "Tetsuya Hara", "Kurogane-kai"], ["t_kurogane_4", "Kyoko Sato", "Kurogane-kai"], ["t_kurogane_5", "Ryuji Kagami", "Kurogane-kai"], ["t_kurogane_6", "Ginzo Yami", "Kurogane-kai"], ["t_kurogane_leader", "Masamune Kurogane", "Kurogane-kai"], ["t_muscle73_1", "Hiroyuki Gondō", "Shōwa 48 Muscle"], ["t_muscle73_2", "Mamiko Takei", "Shōwa 48 Muscle"], ["t_muscle73_3", "Jōji Fukui", "Shōwa 48 Muscle"], ["t_muscle73_4", "Rumi Kawabe", "Shōwa 48 Muscle"], ["t_muscle73_5", "Tsuyoshi Doi", "Shōwa 48 Muscle"], ["t_muscle73_6", "Yoshie Kobayakawa", "Shōwa 48 Muscle"], ["t_muscle73_7", "Ken Hollister", "Shōwa 48 Muscle"], ["t_muscle73_8", "Daijirō Sano", "Shōwa 48 Muscle"], ["t_muscle73_9", "Asami Kurokawa", "Shōwa 48 Muscle"], ["t_muscle73_leader", "Kōtarō Nishikawa", "Shōwa 48 Muscle"], ["t_raijin_1", "Takumi Inoue", "Raijin Garage"], ["t_raijin_2", "Mai Kobayashi", "Raijin Garage"], ["t_raijin_3", "Yusuke Ota", "Raijin Garage"], ["t_raijin_4", "Sayaka Nomura", "Raijin Garage"], ["t_raijin_5", "Daigo Kirishima", "Raijin Garage"], ["t_raijin_6", "Kenji Hoshi", "Raijin Garage"], ["t_raijin_7", "Haru Tsukamoto", "Raijin Garage"], ["t_raijin_8", "Ichiro Sakai", "Raijin Garage"], ["t_raijin_9", "Noa Fujisaki", "Raijin Garage"], ["t_raijin_10", "Tetsu Ogura", "Raijin Garage"], ["t_raijin_11", "Kanna Shibuya", "Raijin Garage"], ["t_raijin_leader", "Genji Raijima", "Raijin Garage"], ["t_hotrod_1", "Tomio Kagawa", "Kōenji Greasers"], ["t_hotrod_2", "Shingo Watanuki", "Kōenji Greasers"], ["t_hotrod_3", "Sumire Nakano", "Kōenji Greasers"], ["t_hotrod_4", "Junpei Ōsugi", "Kōenji Greasers"], ["t_hotrod_5", "Bunzō Hamano", "Kōenji Greasers"], ["t_hotrod_6", "Rikiya Takamine", "Kōenji Greasers"], ["t_hotrod_7", "Ryōko Ishizuka", "Kōenji Greasers"], ["t_hotrod_8", "Rokurō Ueda", "Kōenji Greasers"], ["t_hotrod_9", "Minoru Kōno", "Kōenji Greasers"], ["t_hotrod_leader", "Eiji Yamamoto", "Kōenji Greasers"], ["t_bolide_1", "Kazunari Ōmi", "Rosso Ottantuno"], ["t_bolide_2", "Sayuri Okazaki", "Rosso Ottantuno"], ["t_bolide_3", "Eizō Takasugi", "Rosso Ottantuno"], ["t_bolide_4", "Ryūnosuke Hamasaki", "Rosso Ottantuno"], ["t_bolide_5", "Chiaki Morandi", "Rosso Ottantuno"], ["t_bolide_6", "Shūsaku Shiraishi", "Rosso Ottantuno"], ["t_bolide_7", "Mayu Shinoda", "Rosso Ottantuno"], ["t_bolide_8", "Ginya Fujikawa", "Rosso Ottantuno"], ["t_bolide_9", "Shiho Haneda", "Rosso Ottantuno"], ["t_bolide_leader", "Marco Galli", "Rosso Ottantuno"], ["t_vivace_1", "Camille Laurent", "Périph Tokyo"], ["t_vivace_2", "Junichi Ōtani", "Périph Tokyo"], ["t_vivace_3", "Élodie Marchand", "Périph Tokyo"], ["t_vivace_4", "Hiroto Tsuruta", "Périph Tokyo"], ["t_vivace_5", "Sachi Kanemoto", "Périph Tokyo"], ["t_vivace_6", "Pierre-Yves Garnier", "Périph Tokyo"], ["t_vivace_leader", "Antoine Moreau", "Périph Tokyo"], ["t_akatsuki_1", "Kazuki Okada", "Akatsuki Racing"], ["t_akatsuki_2", "Emi Tsuchiya", "Akatsuki Racing"], ["t_akatsuki_3", "Naoki Ueda", "Akatsuki Racing"], ["t_akatsuki_4", "Rina Kawaguchi", "Akatsuki Racing"], ["t_akatsuki_5", "Shogo Hasegawa", "Akatsuki Racing"], ["t_akatsuki_6", "Mio Takagi", "Akatsuki Racing"], ["t_akatsuki_7", "Tatsuya Moriyama", "Akatsuki Racing"], ["t_akatsuki_leader", "Ryo Akatsuki", "Akatsuki Racing"], ["t_etkmodern_1", "Ren Ishida", "Rennspecht Kai"], ["t_etkmodern_2", "Saya Kurihara", "Rennspecht Kai"], ["t_etkmodern_3", "Tomoaki Ishiguro", "Rennspecht Kai"], ["t_etkmodern_4", "Yuri Hasebe", "Rennspecht Kai"], ["t_etkmodern_5", "Gōtarō Mori", "Rennspecht Kai"], ["t_etkmodern_6", "Nao Kōzuki", "Rennspecht Kai"], ["t_etkmodern_7", "Fumiya Hanamura", "Rennspecht Kai"], ["t_etkmodern_8", "Maki Ōta", "Rennspecht Kai"], ["t_etkmodern_9", "Shinpei Akiyama", "Rennspecht Kai"], ["t_etkmodern_10", "Ayano Tōdō", "Rennspecht Kai"], ["t_etkmodern_leader", "Haruki Kurosaki", "Rennspecht Kai"], ["t_bastion_1", "Mike Brown", "Bastion Brotherhood"], ["t_bastion_2", "Shōji Yamaguchi", "Bastion Brotherhood"], ["t_bastion_3", "Linda Carver", "Bastion Brotherhood"], ["t_bastion_4", "Ryōsuke Ōhara", "Bastion Brotherhood"], ["t_bastion_5", "Darnell Hayes", "Bastion Brotherhood"], ["t_bastion_6", "Kumiko Steele", "Bastion Brotherhood"], ["t_bastion_7", "Maj. Tony Russo", "Bastion Brotherhood"], ["t_bastion_leader", "Col. Jack \"Redtail\" Harmon", "Bastion Brotherhood"], ["t_scintilla_1", "Kenzaburō Ōtori", "Scintilla Salon"], ["t_scintilla_2", "Iori Takamura", "Scintilla Salon"], ["t_scintilla_3", "Tadamasa Kujō", "Scintilla Salon"], ["t_scintilla_4", "Chiharu Matsukata", "Scintilla Salon"], ["t_scintilla_5", "Hideaki Sumiyoshi", "Scintilla Salon"], ["t_scintilla_6", "Ruriko Asakura", "Scintilla Salon"], ["t_scintilla_7", "Riccardo Bianchi", "Scintilla Salon"], ["t_scintilla_8", "Akari Daimon", "Scintilla Salon"], ["t_scintilla_9", "Masaki Ōkura", "Scintilla Salon"], ["t_scintilla_leader", "Valentina Saionji", "Scintilla Salon"]];
var WANDERERS = [["w_ojisan", "Ōji-san"], ["w_rodeo", "Rodeo Rick"], ["w_kemuri", "Kemuri"], ["w_rentner", "Kapitän Isoda"], ["w_shinkiro", "Shinkirō"], ["w_rallye", "Mathilde"], ["w_dtm", "Shūzō Okabe"], ["w_noir", "Noir"], ["w_tetsujin", "Tetsujin"], ["w_slider", "Big Mama Slide"], ["w_hotaru", "Hotaru"], ["w_kazekiri", "Kazekiri"], ["w_pastor", "Reverend Joe"], ["w_oval", "Junior Bascomb"], ["w_marshal", "Marshal Kirby"], ["w_fink", "Mr. Fink"], ["w_tsukiyomi", "Tsukiyomi"], ["w_nurburg", "Greta Krüger"], ["w_yurei", "Yūrei"], ["w_erbstueck", "Kiyotaka Ōmiya"], ["w_noodle", "Noodle"], ["w_gruppe5", "Gruppe Fünf"], ["w_hakone", "Hakone-Ojii"], ["w_tasti", "Tasti-Kid"], ["w_mont", "Urs Brunner"], ["w_kemuri2", "Nebelwerfer"], ["w_fukurou", "Fukurō"], ["w_corsa", "Signora Corsa"], ["w_benikaze", "Benikaze"], ["w_tractor", "Farmer Hank"], ["w_viper", "Rattler Vic"], ["w_wheelie", "Wheelie Wanda"], ["w_bigblock", "Big Block Barry"], ["w_familie", "Familie Kondō"], ["w_kofun", "Kofun"], ["w_doc", "Doc Holloway"], ["w_hellcat", "Hurricane Hattie"], ["w_dragvan", "Der Lieferant"], ["w_bakuon", "Bakuon"], ["w_nitro", "Takuma Nakamura"], ["w_afterburner", "Afterburner"], ["w_kaminari", "Kaminari"]];
var BOSSES = [["b_shirotora", "Shirotora"], ["b_kokuryu", "Kokuryū"], ["b_mugen", "Mugen"]];
// Avatar-Teile (Slot im Silhouetten-Tool, Titel, [Teil-ID, Text, nur w/m])
var AVATAR = [{"key": "kopf", "title": "Avatar: Head shape", "opts": [["rund", "Bob (standard)"], ["oval", "Egg"], ["kantig", "Angular"], ["breit", "Wide"], ["schmal", "Narrow"], ["kinn", "Pointed chin"]]}, {"key": "gesicht", "title": "Avatar: Face (eyes on the visor display)", "opts": [["normal", "Normal"], ["grimmig", "Grim"], ["muede", "Bored"], ["fokus", "Focused"], ["grinsen", "Grin ^^"], ["traurig", "Sad"], ["zwinkern", "Wink"], ["zyklop", "One eye"], ["aus", "Display off"]]}, {"key": "haare", "title": "Avatar: Hair or hat", "opts": [["bobcut", "Bob cut (women)", "w"], ["hime", "Long with bangs (women)", "w"], ["wellen", "Long waves (women)", "w"], ["zoepfe", "Two pigtails (women)", "w"], ["kahl", "Bald (men)", "m"], ["kurz", "Short"], ["scheitel", "Side parting"], ["stachel", "Spiky"], ["tolle", "Pompadour"], ["lang", "Long"], ["zopf", "Ponytail"], ["dutt", "Bun"], ["irokese", "Mohawk"], ["cap", "Cap"], ["capback", "Cap backwards"], ["muetze", "Beanie"], ["stirnband", "Headband"], ["bandana", "Bandana"]]}, {"key": "haarfarbe", "title": "Avatar: Hair colour", "opts": [["schwarz", "Black"], ["braun", "Dark brown"], ["rotbraun", "Auburn"], ["blond", "Bleached blond"], ["silber", "Silver grey"]]}, {"key": "brille", "title": "Avatar: Glasses", "opts": [["keine", "None"], ["sonne", "Sunglasses"], ["wrap", "Sports glasses"], ["rund", "Round glasses"], ["halb", "Half-rim glasses"], ["goggles", "Goggles on the forehead"], ["klappe", "Eye patch"]]}, {"key": "jacke", "title": "Avatar: Top / jacket", "opts": [["sukajan", "Sukajan (souvenir jacket)"], ["hawaii", "Hawaiian shirt"], ["jeans", "Denim jacket"], ["weste", "Shirt with vest"], ["warnweste", "Work jacket with hi-vis vest"], ["militaer", "Military jacket"], ["windbreaker", "Windbreaker"], ["strick", "Cardigan"], ["polo", "Polo shirt"], ["bluse", "Blouse with bow (women)", "w"], ["kostuem", "Blazer (women)", "w"], ["pelz", "Coat with fur collar"], ["rollkragen", "Turtleneck"], ["hoodie", "Hoodie"], ["bomber", "Bomber jacket"], ["leder", "Leather jacket"], ["anzug", "Suit and tie (men)", "m"], ["training", "Track jacket"], ["tshirt", "T-shirt"], ["overall", "Mechanic overalls"], ["mantel", "Coat with high collar"], ["tokko", "Tokkō coat (long embroidered coat)"], ["racing", "Racing jacket"]]}, {"key": "ton", "title": "Avatar: Clothing colour", "opts": [["graphit", "Graphite"], ["nachtblau", "Navy"], ["braun", "Brown"], ["oliv", "Olive"], ["hell", "Light grey"], ["weinrot", "Burgundy"]]}, {"key": "extra", "title": "Avatar: Extra on the head", "opts": [["keins", "None"], ["spange", "Hair clip (women)", "w"], ["zigarette", "Cigarette"], ["zahnstocher", "Toothpick"], ["maske", "Face mask"], ["headset", "Headset"], ["ohrring", "Earrings"], ["kratzer", "Scratches"], ["pflaster", "Plaster"]]}, {"key": "hals", "title": "Avatar: Extra around the neck", "opts": [["keins", "None"], ["kopfhoerer", "Headphones"], ["kette", "Necklace"], ["schal", "Scarf"], ["handtuch", "Towel"], ["hundemarke", "Dog tag"], ["halstuch", "Neckerchief"]]}, {"key": "patch", "title": "Avatar: Patch on the jacket", "opts": [["keiner", "None"], ["nummer", "Race number"], ["sponsor", "Sponsor patch"], ["kanji", "Kanji stripe"]]}];
// --- ENDE ERZEUGT ---

var UEBERRASCHUNG = 'Surprise me';

// Stärke-Stufen: ab Rang, SP, Preisgeld in $, Ruf
var STUFEN = [
  ['1 – Easy',   { minRank: 1, maxSp: 1100, rewardUsd: 7000,  rep: 70 }],
  ['2 – Medium', { minRank: 2, maxSp: 1250, rewardUsd: 9000,  rep: 90 }],
  ['3 – Tough',  { minRank: 3, maxSp: 1350, rewardUsd: 10000, rep: 100 }],
  ['4 – Strong', { minRank: 5, maxSp: 1450, rewardUsd: 12000, rep: 120 }],
  ['5 – Brutal', { minRank: 6, maxSp: 1600, rewardUsd: 14000, rep: 130 }]
];

// Kennzeichen: Agent's Japanese Plates Pack (Pflicht-Mod)
var REGIONEN = ['Shinagawa (Tokyo)', 'Sapporo (Hokkaido)', 'Toyota (Aichi)', 'Shizuoka', 'Himeji (Hyogo)',
  'Kōchi', 'Kumamoto', 'Kagoshima'];
var KZ_TYPEN = ['Private', 'Kei (light vehicle)', 'Commercial', 'Commercial kei'];
// Teilname im Slot licenseplate_design_2_1: am5jp_<region>_<typ> (aus license-plate-japan.jbeam der Mod)
var REGION_IDS = ['shinagawa', 'sapporo', 'toyota', 'shizuoka', 'himeji', 'kochi', 'kumamoto', 'kagoshima'];
var TYP_IDS = ['standard', 'kei', 'commercial', 'keicommercial'];

// Battle-Zeit im Spiel: 20:00 bis 06:00 (world.json nightFrom/nightTo)
var NACHT = [20, 21, 22, 23, 0, 1, 2, 3, 4, 5, 6];

var BEDINGUNGEN = [
  'Only at certain hours of the night',
  'Only against a certain player car',
  'Only if the player has a certain tuning part installed',
  'Only after the player has beaten a whole team',
  'Only after the player has beaten a certain team leader or member',
  'Only after the player has beaten a certain Wanderer',
  'Only after the player has beaten a certain boss',
  'Only from a certain night (in-game day) onwards'
];

var FIGUREN = [['m', 'Man'], ['f', 'Woman']];

// Feld-Schlüssel → Titel im Formular (der Export findet die Antworten über diese Titel)
var F = {
  credit:      'Your name for the credits',
  contact:     'How can I reach you? (Discord or BeamNG forum name)',
  role:        'How did you contribute?',
  name:        'Your Wanderer name',
  jp:          'Your Wanderer name in Japanese (optional)',
  nick:        'Your nickname / title',
  desc:        'Your backstory',
  figur:       'Avatar: figure',
  source:      'Your car',
  model:       'Model ID',
  config:      'Config file name',
  pcText:      'Your config (content of the .pc file)',
  modName:     'Mod name (mod cars only)',
  modLink:     'Mod link (mod cars only)',
  livery:      'Custom skin (optional)',
  region:      'Plate: region',
  plateType:   'Plate: type',
  plateTop:    'Plate: top number',
  plateBottom: 'Plate: main number',
  aggr:        'How aggressive do you drive?',
  cruise:      'Your cruising speed before a battle (km/h)',
  tier:        'How strong are you?',
  conds:       'When do you show up?',
  hFrom:       'Hours: from',
  hTo:         'Hours: until',
  playerModel: 'Player car (model ID)',
  playerPart:  'Tuning part (word in the part name)',
  team:        'Beaten team',
  leader:      'Beaten team leader',
  member:      'Beaten team member (name)',
  wanderer:    'Beaten Wanderer',
  boss:        'Beaten boss',
  minDay:      'From night',
  idea:        'Your own idea for a condition',
  lChallenge:  'Your line when you challenge the player',
  lWin:        'Your line when you win',
  lLose:       'Your line when you lose',
  consent:     'Consent'
};

function formularAnlegen() {
  var form = FormApp.create(TITEL);
  form.setDescription(
    'Congratulations! As a thank-you for helping with Hashiriya Battle, whether by testing or with your mods, ' +
    'you get to be part of the game as a Wanderer: a lone driver on the expressway who only shows up under certain conditions.\n\n' +
    'Please fill in this form as completely as you can. The more you tell me, the more your Wanderer will feel like you. ' +
    'Anything you leave open I will fill in myself.\n\n' +
    'IMPORTANT – YOUR CAR\n' +
    'Your car has to fit the lore of the classic Genki highway battle games: a Japanese car, or an import that is ' +
    'sought-after in Japan. No everyday off-the-shelf car from Europe or America, please; go for something exotic or rare.\n\n' +
    'MOD CARS\n' +
    'You can pick a mod car, but there is no guarantee I can use it. If the mod is not already included in Hashiriya Battle ' +
    'as a DLC, I first have to check whether it works with the mod and the AI, and whether the mod author agrees. ' +
    'If it doesn\'t work out, I will contact you about an alternative.\n\n' +
    'Required: "Agent\'s Japanese Plates Pack" for your license plate.');
  form.setCollectEmail(false);
  form.setAllowResponseEdits(true);
  form.setConfirmationMessage('Thanks! I\'ll get in touch if anything is missing. See you on the expressway.');

  // 1 – About you
  form.addSectionHeaderItem().setTitle('1 · About you');
  text(form, F.credit, true, 'Shown in the credits of the mod.');
  text(form, F.contact, true, 'So I can ask you questions if something is missing.');
  form.addMultipleChoiceItem().setTitle(F.role).setRequired(true)
    .setChoiceValues(['Testing', 'Mod author', 'Other']);

  // 2 – Wanderer
  form.addPageBreakItem().setTitle('2 · Your Wanderer')
    .setHelpText('Please use original names only, no names from other games. Japanese names fit the setting well.');
  text(form, F.name, true, 'Your driver name in Latin letters, as shown in the game. Max 24 characters. Example: Kagerō',
    /^.{1,24}$/, 'Max 24 characters');
  text(form, F.jp, false,
    'The same name written in Japanese (kanji, katakana or hiragana). It is shown small next to your name in the rival list, ' +
    'like the existing rivals have it. Example: Kagerō → 陽炎. Leave empty if you are not sure, I can add it.');
  text(form, F.nick, false, 'The title other drivers know you by, shown under your name. Example: The Heat Veil');
  form.addParagraphTextItem().setTitle(F.desc).setRequired(false)
    .setHelpText('One or two sentences for the rival list. Who are you, and why do you drive the expressway at night?');

  // 3 – Avatar
  form.addPageBreakItem().setTitle('3 · Your avatar')
    .setHelpText('In the game every driver appears as a figure in the style of Bob, BeamNG\'s robot-like NPC: a smooth ' +
      'helmet-shaped head with a dark visor, the eyes are pixels on the visor display. Your avatar shows up next to the ' +
      'speech bubble when you challenge the player, win or lose. Pick your look below. Everything you leave on ' +
      '"' + UEBERRASCHUNG + '" I choose to match your backstory. Items marked (women) or (men) only fit that figure.');
  form.addMultipleChoiceItem().setTitle(F.figur).setRequired(true)
    .setChoiceValues(FIGUREN.map(function (f) { return f[1]; }));
  AVATAR.forEach(function (s) {
    form.addListItem().setTitle(s.title).setRequired(false)
      .setChoiceValues([UEBERRASCHUNG].concat(s.opts.map(function (o) { return o[1]; })));
  });

  // 4 – Car, config and plate
  form.addPageBreakItem().setTitle('4 · Your car and plate')
    .setHelpText('Japanese car or an import that is sought-after in Japan. Something exotic or rare, no everyday European or American car.');
  form.addMultipleChoiceItem().setTitle(F.source).setRequired(true)
    .setChoiceValues(['Stock BeamNG car', 'Mod car']);
  text(form, F.model, true, 'The car\'s folder name in BeamNG, e.g. sunburst2, sbr, bx.', /^[A-Za-z0-9_]+$/,
    'Only letters, digits and _');
  text(form, F.config, true,
    'Save your setup (parts, tuning and paint) in BeamNG as a config named hashiriya_wanderer_XXX, where XXX is your Wanderer ' +
    'name (e.g. hashiriya_wanderer_kagero). Enter the name here.',
    /^hashiriya_wanderer_[A-Za-z0-9_]+(\.pc)?$/, 'Format: hashiriya_wanderer_XXX (XXX = your Wanderer name, letters/digits/_)');
  form.addParagraphTextItem().setTitle(F.pcText).setRequired(true)
    .setHelpText('Open the saved file in a text editor and paste its whole content here. You find it in your BeamNG user folder ' +
      'under vehicles\\<model ID>\\hashiriya_wanderer_XXX.pc (e.g. Documents\\BeamNG.drive\\current\\vehicles\\sunburst2\\). ' +
      'It starts with { and ends with }.')
    .setValidation(FormApp.createParagraphTextValidation()
      .setHelpText('Paste the whole file: it starts with { and ends with }')
      .requireTextMatchesPattern('^\\s*\\{[\\s\\S]*\\}\\s*$')
      .build());
  text(form, F.modName, false,
    'Only for mod cars. If the mod is not yet a DLC of Hashiriya Battle, I have to check compatibility and ask the mod author first.');
  text(form, F.modLink, false, 'Only for mod cars. Link to the BeamNG repository page, e.g. https://www.beamng.com/resources/…');
  text(form, F.livery, false,
    'Only if you made your own skin for your Wanderer. Name it and send me the files via Discord or the forum. ' +
    'Your paint colours are already saved in the config, so you don\'t need to list them.');
  form.addSectionHeaderItem().setTitle('License plate')
    .setHelpText('Uses "Agent\'s Japanese Plates Pack". The hiragana character is set automatically in the game.\n' +
      'Example: top number 330, main number 12-34. Low numbers with dots: .. .1 or .. 12 (space instead of -).');
  form.addListItem().setTitle(F.region).setRequired(true).setChoiceValues(REGIONEN);
  form.addListItem().setTitle(F.plateType).setRequired(true).setChoiceValues(KZ_TYPEN);
  text(form, F.plateTop, true, '2 or 3 digits, e.g. 330', /^[0-9]{2,3}$/, '2 or 3 digits');
  text(form, F.plateBottom, true, 'Format 12-34, or with dots: .. .1',
    /^([0-9]{2}-[0-9]{2}|[0-9.]{2} [0-9.]{2})$/, 'Format 12-34 (or with dots, e.g. .. .1)');

  // 5 – Driving style
  form.addPageBreakItem().setTitle('5 · Your driving style');
  form.addScaleItem().setTitle(F.aggr).setRequired(true).setBounds(1, 8)
    .setLabels('careful', 'pushy, take every risk')
    .setHelpText('Most Wanderers sit at 6.');
  form.addListItem().setTitle(F.cruise).setRequired(true)
    .setChoiceValues(['80', '90', '100', '110', '115', '120', '130', '140'])
    .setHelpText('How fast you roll in traffic before the player flashes you.');
  form.addMultipleChoiceItem().setTitle(F.tier).setRequired(true)
    .setChoiceValues(STUFEN.map(function (s) { return s[0]; }))
    .setHelpText('Decides from which rank on the player meets you. I balance the exact numbers at the end.');

  // 6 – Conditions
  form.addPageBreakItem().setTitle('6 · When do you show up?')
    .setHelpText('Wanderers only appear under certain conditions. Tick one or more and fill in the matching fields below. ' +
      'Battles in Hashiriya Battle happen at night, between 20:00 and 06:00 in-game time.');
  form.addCheckboxItem().setTitle(F.conds).setRequired(false).setChoiceValues(BEDINGUNGEN);
  var hours = NACHT.map(function (h) { return ('0' + h).slice(-2) + ':00'; });
  form.addListItem().setTitle(F.hFrom).setChoiceValues(hours).setHelpText('In-game time. Nights run from 20:00 to 06:00.');
  form.addListItem().setTitle(F.hTo).setChoiceValues(hours);
  text(form, F.playerModel, false, 'Model ID of the car the player has to drive, e.g. miramar');
  text(form, F.playerPart, false, 'A word from the part name, e.g. turbo, supercharger, slick');
  form.addListItem().setTitle(F.team).setChoiceValues(TEAMS.map(function (t) { return t[1]; }))
    .setHelpText('You only show up after the player has beaten this whole team, leader included.');
  form.addListItem().setTitle(F.leader).setChoiceValues(LEADERS.map(function (l) { return l[1]; }));
  text(form, F.member, false, 'Or a normal team member: type the name as shown in the game, e.g. Kenta Mori');
  form.addListItem().setTitle(F.wanderer).setChoiceValues(WANDERERS.map(function (w) { return w[1]; }));
  form.addListItem().setTitle(F.boss).setChoiceValues(BOSSES.map(function (b) { return b[1]; }));
  text(form, F.minDay, false, 'Number, e.g. 5', /^[0-9]{1,2}$/, 'Number from 1 to 99');
  form.addParagraphTextItem().setTitle(F.idea).setHelpText('e.g. only in rain, only after the player lost to you 3 times …');

  // 7 – Lines
  form.addPageBreakItem().setTitle('7 · Your lines (optional)')
    .setHelpText('Short lines shown in the speech bubble next to your avatar, max 90 characters each. Make them sound like you.');
  text(form, F.lChallenge, false, '', /^.{0,90}$/, 'Max 90 characters');
  text(form, F.lWin, false, '', /^.{0,90}$/, 'Max 90 characters');
  text(form, F.lLose, false, '', /^.{0,90}$/, 'Max 90 characters');

  // 8 – Consent
  form.addPageBreakItem().setTitle('8 · Submit');
  form.addCheckboxItem().setTitle(F.consent).setRequired(true).setChoiceValues([
    'I agree that my credit name, my Wanderer and my config appear in Hashiriya Battle and are released publicly with the mod.'
  ]);

  var props = PropertiesService.getScriptProperties();
  props.setProperty('FORM_ID', form.getId());
  var sheet = pruefTabelle(true);
  Logger.log('Link zum Teilen: ' + form.getPublishedUrl());
  Logger.log('Link zum Bearbeiten (nur für dich): ' + form.getEditUrl());
  Logger.log('Prüf-Tabelle (nur für dich): ' + sheet.getParent().getUrl());
}

function text(form, title, required, help, pattern, patternHelp) {
  var item = form.addTextItem().setTitle(title).setRequired(!!required);
  if (help) item.setHelpText(help);
  if (pattern) {
    item.setValidation(FormApp.createTextValidation()
      .setHelpText(patternHelp || 'Invalid input')
      .requireTextMatchesPattern(pattern.source)
      .build());
  }
  return item;
}

// ---------------------------------------------------------------------------------------------
// Prüf-Tabelle: eine Zeile pro Einsendung, Alex setzt den Status

var SPALTEN = ['Eingang', 'Wanderer', 'Credit-Name', 'Kontakt', 'Rolle', 'Auto', 'Config', 'Status', 'Notiz', 'Antwort-ID'];
var STATUS = ['Neu', 'Angenommen', 'Abgelehnt'];

function pruefTabelle(neu) {
  var props = PropertiesService.getScriptProperties();
  var id = props.getProperty('SHEET_ID');
  var ss = null;
  if (id && !neu) { try { ss = SpreadsheetApp.openById(id); } catch (e) { ss = null; } }
  if (!ss) {
    ss = SpreadsheetApp.create(TABELLE);
    props.setProperty('SHEET_ID', ss.getId());
    var sh = ss.getSheets()[0];
    sh.setName('Einsendungen');
    sh.getRange(1, 1, 1, SPALTEN.length).setValues([SPALTEN]).setFontWeight('bold');
    sh.setFrozenRows(1);
    sh.hideColumns(SPALTEN.length);
  }
  return ss.getSheets()[0];
}

// ---------------------------------------------------------------------------------------------
// Export: neue Antworten in die Prüf-Tabelle, angenommene als Dateien in den Drive-Ordner

function rivalsExportieren() {
  var id = PropertiesService.getScriptProperties().getProperty('FORM_ID');
  if (!id) throw new Error('Kein Formular gefunden. Zuerst "formularAnlegen" ausführen.');
  var form = FormApp.openById(id);
  var sheet = pruefTabelle(false);
  var statusCol = SPALTEN.indexOf('Status') + 1, noteCol = SPALTEN.indexOf('Notiz') + 1, idCol = SPALTEN.length;

  // vorhandene Zeilen: Antwort-ID → Zeile
  var rows = {}, last = sheet.getLastRow();
  if (last > 1) {
    sheet.getRange(2, idCol, last - 1, 1).getValues().forEach(function (v, i) { if (v[0]) rows[v[0]] = i + 2; });
  }

  var accepted = [], credits = [], configs = [], seen = {}, neu = 0;
  form.getResponses().forEach(function (resp) {
    var a = {};
    resp.getItemResponses().forEach(function (ir) { a[ir.getItem().getTitle()] = ir.getResponse(); });
    var res = toRival(a, resp.getTimestamp());
    var r = res.rival;
    var row = rows[resp.getId()];
    var info = [Utilities.formatDate(resp.getTimestamp(), 'Europe/Berlin', 'yyyy-MM-dd HH:mm'), r.name, r.credit.name,
      a[F.contact] || '', r.credit.role, r.model, res.pc ? 'ok' : 'FEHLT/kaputt'];
    if (!row) {
      sheet.appendRow(info.concat(['Neu', res.notes.join('; '), resp.getId()]));
      row = sheet.getLastRow();
      neu++;
    } else {
      sheet.getRange(row, 1, 1, info.length).setValues([info]); // Bearbeitete Antwort: Daten auffrischen, Status bleibt
    }
    var status = String(sheet.getRange(row, statusCol).getValue() || 'Neu');
    if (status !== 'Angenommen') return;
    if (seen[r.id]) r.id += '_' + (++seen[r.id]); else seen[r.id] = 1;
    accepted.push(r);
    credits.push({ name: r.credit.name, role: r.credit.role, wanderer: r.name, id: r.id });
    if (res.pc) configs.push({ model: r.model, file: res.pcFile, text: res.pc });
  });
  sheet.getRange(2, statusCol, Math.max(1, sheet.getLastRow() - 1), 1).setDataValidation(
    SpreadsheetApp.newDataValidation().requireValueInList(STATUS, true).build());

  var folder = ordner(DriveApp.getRootFolder(), ORDNER);
  datei(folder, 'community_wanderer.json', JSON.stringify(accepted, null, 1));
  datei(folder, 'credits.json', JSON.stringify({ community: credits }, null, 1));
  var veh = ordner(folder, 'vehicles');
  configs.forEach(function (c) { datei(ordner(veh, c.model), c.file, c.text); });

  Logger.log(neu + ' neue Einsendung(en) in der Prüf-Tabelle: ' + sheet.getParent().getUrl());
  Logger.log(accepted.length + ' angenommene Wanderer, ' + configs.length + ' Configs exportiert: ' + folder.getUrl());
}

function ordner(parent, name) {
  var it = parent.getFoldersByName(name);
  return it.hasNext() ? it.next() : parent.createFolder(name);
}

function datei(folder, name, content) {
  var it = folder.getFilesByName(name);
  if (it.hasNext()) it.next().setContent(content); else folder.createFile(name, content, 'application/json');
}

function slug(s) {
  return String(s).normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '') || 'x';
}

// Englischer Text; Deutsch übersetzt Alex/Claude später (bis dahin gleicher Text)
function both(v) { v = (v || '').trim(); return v ? { de: v, en: v } : undefined; }

function findId(list, label) {
  var hit = list.filter(function (x) { return x[1] === label; })[0];
  return hit ? hit[0] : null;
}

// Crew-Mitglied über den Namen finden (ohne Akzente, Groß/klein egal)
function findMember(name) {
  var n = slug(name);
  var hit = MEMBERS.filter(function (m) { return slug(m[1]) === n; })[0];
  return hit ? hit[0] : null;
}

function toRival(a, when) {
  var g = function (k) { var v = a[F[k]]; return typeof v === 'string' ? v.trim() : v; };
  var notes = [];
  var tierIdx = Math.max(0, STUFEN.map(function (s) { return s[0]; }).indexOf(g('tier')));
  var tier = STUFEN[tierIdx][1];
  var model = (g('model') || '').toLowerCase();
  var cfgName = (g('config') || '').replace(/\.pc$/i, '').toLowerCase();
  var conds = g('conds') || [];
  var has = function (i) { return conds.indexOf(BEDINGUNGEN[i]) >= 0; };
  var c = { minRank: tier.minRank };
  if (has(0) && g('hFrom') && g('hTo')) c.hours = [parseInt(g('hFrom'), 10), parseInt(g('hTo'), 10)];
  if (has(1) && g('playerModel')) c.playerModel = g('playerModel').toLowerCase();
  if (has(2) && g('playerPart')) c.playerPart = g('playerPart').toLowerCase();
  if (has(3) && g('team')) { var t = findId(TEAMS, g('team')); if (t) c.beatenTeam = t; }
  var beaten = [];
  if (has(4) && g('leader')) beaten.push(findId(LEADERS, g('leader')));
  if (has(4) && g('member')) {
    var m = findMember(g('member'));
    if (m) beaten.push(m); else notes.push('Mitglied "' + g('member') + '" nicht gefunden');
  }
  if (has(5) && g('wanderer')) beaten.push(findId(WANDERERS, g('wanderer')));
  if (has(6) && g('boss')) beaten.push(findId(BOSSES, g('boss')));
  beaten = beaten.filter(Boolean);
  if (beaten.length) c.beatenRivals = beaten;
  if (has(7) && g('minDay')) c.minDay = parseInt(g('minDay'), 10);

  var top = g('plateTop') || '', bottom = g('plateBottom') || '';
  var r = { id: 'w_' + slug(g('name')), name: g('name') };
  if (g('jp')) r.jp = g('jp');
  r.nick = both(g('nick')) || both(g('name'));
  r.wanderer = true;
  r.community = true;
  r.model = model;
  r.config = 'vehicles/' + model + '/' + cfgName + '.pc';
  r.aggression = Math.round((0.3 + ((parseInt(g('aggr'), 10) || 6) - 1) * 0.1) * 100) / 100; // 1..8 → 0.3..1.0
  r.cruiseKmh = parseInt(g('cruise'), 10) || 115;
  r.maxSp = tier.maxSp; r.rewardUsd = tier.rewardUsd; r.rep = tier.rep;
  r.conditions = c;
  r.desc = both(g('desc')) || { de: '', en: '' };
  // Text: 4 Zeichen obere Zeile (inkl. /) + 5 Zeichen untere Zeile, so teilt BeamNG (limit 4 / limit2 5)
  var ri = REGIONEN.indexOf(g('region')), ti = KZ_TYPEN.indexOf(g('plateType'));
  r.plate = { text: (top.length === 2 ? top + '//' : top + '/') + bottom,
    design: 'am5jp_' + REGION_IDS[ri < 0 ? 0 : ri] + '_' + TYP_IDS[ti < 0 ? 0 : ti] };

  // Avatar fürs Silhouetten-Tool: figur + gewählte Teile (der Rest kommt automatisch)
  r.figur = findId(FIGUREN, g('figur')) || 'm';
  var sil = {};
  AVATAR.forEach(function (s) {
    var v = a[s.title];
    if (!v || v === UEBERRASCHUNG) return;
    var o = s.opts.filter(function (x) { return x[1] === v; })[0];
    if (!o) return;
    if (o[2] && o[2] !== (r.figur === 'f' ? 'w' : 'm')) { notes.push(s.key + ' "' + o[0] + '" passt nicht zur Figur'); return; }
    sil[s.key] = o[0];
  });
  if (Object.keys(sil).length) r.silhouette = sil;

  r.credit = { name: g('credit'), role: g('role') };
  var lines = {};
  if (both(g('lChallenge'))) lines.challenge = both(g('lChallenge'));
  if (both(g('lWin'))) lines.win = both(g('lWin'));
  if (both(g('lLose'))) lines.lose = both(g('lLose'));
  if (Object.keys(lines).length) r.lines = lines;
  if (g('livery')) r.skin = g('livery');
  if (g('source') === 'Mod car') r.requires = { mods: [{ name: g('modName') || '?', link: g('modLink') || '' }] };
  if (g('idea')) r._idee = g('idea');
  if (g('contact')) r._kontakt = g('contact');
  r._eingang = Utilities.formatDate(when, 'Europe/Berlin', 'yyyy-MM-dd');

  // Config prüfen: muss gültiges JSON mit "parts" sein
  var pc = null, raw = g('pcText') || '';
  try {
    var j = JSON.parse(raw);
    if (j && typeof j === 'object' && j.parts) pc = JSON.stringify(j, null, 2);
    else notes.push('Config ohne "parts"');
  } catch (e) { notes.push('Config ist kein gültiges JSON'); }
  return { rival: r, pc: pc, pcFile: cfgName + '.pc', notes: notes };
}
