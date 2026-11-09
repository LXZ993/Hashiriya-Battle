# Hashiriya Battle Changelog

## Alpha 0.9.2 (as of 2026-11-06)

### Dev menu: notes are no longer lost (8 Nov)
- Fixed: name and note of a place were only kept when you clicked "Save". They are now saved automatically: when leaving the field, on Enter, on "Close", when opening another place and when closing the dev menu.

### Clearer crew chain (9 Nov)
- In a crew battle (leader with escorts) the opponent you have to close in on now drives with hazard lights. A box "Crew battle 1/2" at the top shows his name, whether he is ahead or behind, the distance, from how many metres it starts and the time left. Once you are close enough, the speed matching starts by itself.
- The messages now say exactly what to do. Starts from 70 m instead of 45 m, 90 s instead of 60 s, and an escort ahead of you slows down more so you can catch him.

### After your test (9 Nov)
- Fixed: no parked cars at Shibaura PA and Tatsumi 1st PA any more. When BeamNG briefly did not deliver the map's parking data, the mod set its own data with only our bays, which replaced the map's parking spots for good. Now the mod waits for the map's parking spots and swaps out wrong data from before.
- Fixed: the crew chain (e.g. against Riku Tanabe) always ended in "False start". A false start now only counts if you accelerate yourself. If the escort passes you while catching up, he simply leads.
- Fixed: the speedometer was still visible on foot. It now checks for an engine like the tachometer.
- Lexicon: the driving style icon now sits before the car name, a bit larger and brighter.
- Lexicon > Story: chapters are orange headings, scenes are indented below, and an opened scene shows the dialogue line by line with speaker names.

### Police: roadblock and wanted list (8 Nov)
- New: if you do not stop for 2 minutes at 3 stars, 2 police cars block the road about 300 m ahead. Hitting it or stopping in front of it means arrest. At most 2 roadblocks per pursuit.
- New: wanted list. If you escape at 3 stars, you are wanted until the next game day ("Wanted until tomorrow" in the status). Every pursuit then starts at 3 stars right away, laser checks chase you as soon as they see you, and the police wait at your garage or home with the arrest fine (150,000 ¥).

### After your third test (8 Nov)
- Kameibashi is no longer a PA but the emergency bay it really is: no travel destination, no map point, no nap. At night 2 to 4 rivals park there (talk and challenge them like at the PAs) and 1 to 2 people just hang out, like a small illegal meet. Empty by day. Bays: your dev places PA 1, PA 2 and the new PA 38 to 41.
- Fixed: the colour preview and bought paints in the shop did not show on the car. The paint is now set directly on this exact car and checked afterwards. If it does not show, the car respawns with the new paint.
- Shop: instead of a separate "Not fitted" entry, the fitted part now has a red X behind it. Clicking it removes the part (goes into the cart as before).
- Fixed: police cars drove without lights at night. From 18:00, at night and until 07:00 they now use low beams.
- Fixed: maintenance (oil, coolant, tyres) did not run at all, the log kept showing "maintenance.onUpdate ... field init". BeamNG treated our function "init" as its own loader function and deleted it afterwards. It has a different name now.

### After your second test (8 Nov)
- Fixed: the music pause (Ctrl + End) did not really pause the music. It now pauses like BeamNG's own menu music and is also muted while paused.
- Fixed: the music slider only worked after moving it several times. The mod now also reads the live value of the music channel and applies every change right away. Each change is logged as "Musik-Regler: Kanal ..., Einstellung ...".

### After your test (8 Nov)
- Water temperature and oil temperature are now two separate UI apps ("Hashiriya Battle: Water temperature" and "... Oil temperature"), movable and removable on their own. The old combined app stays for older layouts.
- New: pause music. Ctrl + End or "Pause music" under Tools in the left menu. Press again to continue at the same spot. Skipping also ends the pause.
- Fixed: the BeamNG "Music" slider (Options > Audio) now also affects the mod music.
- Fixed: the speedometer was visible on foot. It now hides like the tachometer.
- Fixed: the paint list (buying a car, shop) showed internal paints of our rival configs such as "hashiriya_tadashi_s2 Paint 1". Hidden and hashiriya_ paints are no longer offered.

### Speedometer with separate gauges
- RPM and speed are now two separate analog round gauges side by side. Right: the tachometer with the gear shown large in the centre. Left: the new speedometer with needle and a small number in the centre. Its scale starts at 200 km/h (120 mph) and grows when you drive faster.
- New: pedal bars at the bottom of the gauges. Red for the brake pedal on the tachometer, green for the throttle on the speedometer. They show how far you are pressing the pedal right now.
- Fuel now sits inside the speedometer below the number: small E to F bar with litres and tank size, orange below 25 %, flashing red below 10 %. The old water temperature bar in the tachometer is gone, the oil/water gauges replace it.
- Boost is now a small round gauge like oil and water too (vacuum grey-blue, red from 80 % of the scale), above the tachometer. Oil/water sits above the speedometer, the powertrain bar to the left of it.
- The orange decorative arcs at the edge of the round gauges are gone.

### Fix: broken cars at PAs
- PA drivers without a fixed config got a random config of their model, including configs from other mods and from the user folder. That put e.g. an Ibishu conversion with floating wheels, struts and driveshaft at a PA. Now these drivers take a car from the predefined parked-car pool (Agent Traffic JP, same as parking lots). Only without the Agent mod an official BeamNG config is used. Fixed configs from `chat.json` stay as they are.

### Stage rivals with their own configs
- Hinata Oda, Tadashi Hirota and Taiga Shimizu now drive Alex's own builds with skins in stage 2 and 3 instead of the stock config: Hinata in the Covet, Tadashi in the Sunburst, Taiga in the 200BX.
- Named paint presets in a saved config (e.g. "Solar Yellow" as second color) are now applied correctly.

### Trucks in traffic
- New: the Cherrier Percheron drives in traffic as a European import (box, flatbed, tanker, mixer, cola truck), roughly every 20th car. Twice as many in hardcore mode.
- Adjustable in `data/cars.json` under `trafficTrucks`.
- New: 12 own truck liveries, all invented: 3 Japanese freight companies and 3 dekotora each for box and tanker (cab + body). Traffic trucks now only use these, via 43 own configs.

### Hardcore mode
- New: **Hardcore mode**. When creating a new save, pick Normal or Hardcore in the last step. Fixed for that save, shown with a red tag in the save list.
- Engine starts cold (warm it up first), maintenance due twice as fast with stronger effects, starter car with 12 % fuel, fuel use one and a half times.
- Everything costs one and a half times as much (repair, towing, parts, maintenance, fuel, dealer, fines), prize money only three quarters.
- Pink slip rivals only race for cars. Game over deletes the save.
- More mobile police checks by day (2 more), 30 % more traffic.
- Save only at home or in the garage, quitting without saving = towed with double fine, quitting mid-battle = loss.
- Rivals not on minimap and radar, no fast travel to parking areas or the garage.
- Unstuck only 3 times per game day, each time with a service fee.
- Trophies from hardcore saves get a red hardcore frame.
- Every rule can be set separately in `data/hardcore.json`.

### Oil and water temperature gauges
- New: two small round gauges left of the tachometer, in the same style (segment arc, big italic number, slanted badge): coolant and oil.
- Colors: blue = still cold, white = operating temperature, orange = getting hot, red = the engine takes damage from here (water from 120 °C, oil from 150 °C). In the red zone the number turns red and the badge flashes.
- Shows °C or °F depending on the game setting. Hidden on electric cars.

### New main parking areas and travel
- New: two main parking areas placed by JDMArsch (LXZ aka. LXZockt): **Heiwajima PA** and **Oi PA (Westbound)**, each with 16 parking bays. Cars park there, drivers wait to talk, rivals hang out, and you can nap in your car.
- New: **Kameibashi PA** on the C1 City Loop near Shintomichō, below Tsukijigawa Kameibashi Park, with 2 parking bays.
- All main parking areas (Shibaura and Tatsumi too) are now on the big map (M), with name, description and preview picture. The pictures are still placeholders in `art/pa/`.
- Dev version: the main parking areas have a Quick Travel button on the big map, and "Go" in the dev menu takes you to the arrival point.
- New: travel. Leave the C1 slowly at an exit, then pick a destination in the left menu: the garage or a main parking area you have visited. Travelling skips time and costs fuel.
- Start PA: in the garage (Service tab) use "Head out from ..." to start at a visited main parking area, at the same cost.
- Heiwajima PA has a shop for all parts (drive in and stop to open the parts terminal) and a gas station.
- All 66 on- and off-ramps by JDMArsch are in. The on-ramps are prepared for the map change after 1.0.

### Colorable Japan liveries
- New: 4 modern Factory Tech styles after new references by JDMArsch (LXZ aka. LXZockt): wedge with slash cuts, layered bars, chevron band and checker. Available on Pessima Mk2, Covet, Sunburst and SBR4.
- New: 5 styles using the real BeamNG lore logos as sponsors: Sponsor Race Car (JGTC style), Pro Drift, Tuning Shop Demo Car, Group A Rally and Company Car (Pigeon/Hopper). Only on cars where they fit era and drivetrain; 16 styles and 67 paint designs in total. Every car gets its own layout and main sponsor for these styles, no copies.
- New: 6 more detailed styles with new inspirations: Wa Pattern (seigaiha, asanoha, kikko, hanko seal), Manga Speed (halftone, speed lines, sound words), Splinter Camo, Group C Retro, GT Waves and Kanjo Loop. Every car has its own layout, 95 paint designs in total.
- New: liveries can now also contain fixed, non-paintable colors (gold, seals, hazard stripes, sponsors in original colors).
- Changed: the older Sponsor, Rally, Drift, Shop Demo, Race Team and Company styles now use fixed colors too: white number boards and rally plates, small sponsors as stickers in brand colors, company logos in a fixed company color.
- Changed: each car now only gets the styles that fit its era and drivetrain. No drift on front-wheel drive cars, no Bosozoku, Kaido or two-tone on modern cars, drift added on the Sunburst.
- New: 63 paint designs for all 9 Japanese cars (Pessima Mk1 and Mk2, 200BX, Covet, Hopper, Miramar, Pigeon, Sunburst, SBR4) in 7 styles: Street Drift Flames, Street Drift Team, Factory Sports, Bosozoku, Kaido Racer, Factory Two-Tone and Factory Race Team.
- All designs are drawn in VectorCraft after references by JDMArsch (LXZ aka. LXZockt) and run cleanly over pillars, roof and hood.
- Colorable like the vanilla "Custom" skin: paint 1 is the base coat, paints 2 and 3 color the livery. Found in the configurator under Paint Design as "Hashiriya: ... (Colorable)". All sponsors are made up or BeamNG lore.
- Every style has 3 shape variants spread across the cars. Each car carries its own brand (Ibishu or Hirochi), its own texts, teams and numbers, and the BeamNG lore logos from the game as sponsors (DriftGear, Okudai, Wangan, GripAll and more).
- Every livery comes with a .vectorcraft file and a layered PSD for fine-tuning.

### Speed cameras and police
- New: speed limits apply during the day. Speed cameras are the 45 fixed speed traps on C1, and now and then the police run laser checks. Nothing is measured at night.
- Speed camera: drive past a speed trap too fast and you get flashed and fined, the faster the pricier. Counted per game day: 1st and 2nd time only money, from the 3rd time the police come as well.
- Laser check: on each day a patrol car waits at a few police spots for a few hours. Too fast there and it chases you right away. At first there are 1 to 2 checks a day, more as your rank rises because word of the night races gets around.
- The minimap and radar only show a check once you have seen it that day. Patrol cars in a chase flash red there, checks are white-grey. All police lights are red like in Japan, including the flashers on the Sunburst patrol car and "POLICE" in the status.
- Chase with 1 to 3 stars in the status at the top right. 1 star: the police follow you and want you to stop (ticket). 2 stars (kept fleeing, crashes, flashed again or already ticketed today): they overtake you and brake you down. 3 stars: they ram you. Stopping at 3 stars = arrest, a big fine and a tow to the garage.
- Escape: stay out of sight long enough and the police give up. That earns a little REP (less than beating a rival, only 3 times a day).
- During a chase, saving, napping, towing, parking menus and challenges are blocked.
- Police spots are placed in the dev menu (type "Police / checkpoint": laser or own camera, speed limit, direction, "always manned" for testing; today's roster is under Tools). All values in data\police.json, test buttons in the dev menu under Tools.

### Stickers
- New in the garage: "Stickers" tab. Put the logos from your trophy wall on your car, like the stickers in TXR: crew logos and symbols (also in leader gold), wanderer seals, boss emblems and the 走.
- Pick a view, set size, rotation and position, then apply. Each sticker costs 3,000 yen, removing is free.
- Stickers stay on the car and can be edited again later.

### Aura
- New, like in TXR: at night rivals have an aura in their colour, a soft glow under the car. Crews in their crew colour, leaders with a golden rim, wanderers and bosses in the colour of their seal.
- In battle the aura gets brighter, pulses and gets a glowing rim around the body. The fewer SP the driver has left, the weaker it glows.
- You only get an aura from the rival it belongs to, after beating them. Equip it on the trophy wall in the new "Auras" tab and choose when (always at night, battle only, off) and how strong.
- Effects like thunderclouds, lightning or rain around the car come after 1.0.

### Bulletin board (HashiNet forum)
- New: the garage PC has a "Bulletin board" tab, the scene's forum. The number on the tab shows new posts.
- Rumours about wanderers and bosses you can meet soon. Each day a rumour reveals something different (time, car brand, wanted part, which crew has to fall first), never the full condition. Read along and piece the rest together. Bought tips stay more precise.
- Crew news: how many drivers of a crew you have beaten, when the leader goes out personally, who was just beaten and which crew is new in the scene (with crew logo).
- Night report: who you beat last night. Plus scene posts, trivia about Japan and the C1, classifieds and ads for today's side jobs.
- Filters: All, Rumours, Crews, Scene, Jobs, plus the search at the top of the terminal.
- Also readable at the PAs: place notice boards with the new dev menu place type "Schwarzes Brett (Aushang)". There you see "[T] Read bulletin board" (on foot or in a stopped car), the board opens in the left menu. Walking away closes it.
- All texts and settings in data\board.json.

### New side jobs: taxi shift and delivery round
- New at the job board: the taxi shift. A company taxi (Pessima in Shinonome or Gekko livery) waits next to you, your own car stays parked. Pick up and drop off three passengers, then bring the taxi back to the depot.
- Pay is the meter (flag fall + distance) plus tips. Tips are lost by speeding (limit 80 km/h, the status display warns you), jerky braking and acceleration, damage and being late. Each fare gets 1 to 5 stars and the passenger tells you what they think.
- Too much damage during a fare: the passenger gets out and pays nothing. The company deducts the taxi's repairs from your pay at the end of the shift. Cancelling pays out what you have earned so far.
- The taxi does not count as your car: your fuel, damage and wear stay untouched, and there are no battles in the taxi.
- New: the delivery round. Drive 3 to 4 stops in a row with your own car under one overall time. If time runs out, only delivered stops are paid.
- Now five offers per day on the board (complete at most four). New dev menu place types: "Taxi: Fahrgast-Punkt" (passenger point) and "Taxi-Depot".
### Crew battles, declining and bets
- New, like in TXR 2025: leaders and bosses drive with two escorts in a convoy. Challenge anyone in the group and you race them all in a row: first the escorts from back to front, then the leader or boss. The display shows "CHAIN 1/3". After each win the next one waits for you.
- A loss (or a false start) breaks the chain: the group regroups and next time it starts over. Leaders bring members of their crew, bosses bring the leaders of the crews you had to beat before.
- Crew tactics: while you race someone from the group, the other escorts block for him. They pull in just ahead of you, brake with you and close the line. Against a leader his crew members on the road block too. The display then shows "BLOCKING".
- Rivals now decline visibly: if one doesn't want to (just raced you, night limit reached or simply not in the mood), he sets his turn signal and a stop sign with a cross and the reason appears in the middle of the screen. If you decline yourself, the sign shows in orange.
- Bets: while matching speed the rival sometimes offers a bet in yen. Hazards = accept, flash = raise the stake (up to triple), do nothing = no bet. Win = stake on top, loss = stake gone. Never more than half your money, not in pink slip races.
- Everything is adjustable in the new file data/crewbattle.json.
### Nicknames, trophies and phone messages
- 20 ranks instead of 15: five new in-between ranks (Lane Changer, Midnight Blade, Loop Breaker, Storm Runner, Loop Phantom). Everything else unlocks at the same reputation as before, you just rank up more often. Old saves fit automatically.
- 89 nicknames instead of 7, in the groups Battle, Driving style, Road and Life & garage: e.g. Sideways (50 drifts), Slipstreamer, Hairline, Witching Hour (wins between 2 and 4 am), Kamikaze, Mile Eater, Radar Terror, Wrench Head, Chatterbox. Many come in several tiers.
- New: titles per car model like in TXR 2025, e.g. "Covet Driver" after 10 wins with the Covet, then Expert (25), Master (50) and Legend (100).
- Every nickname you earn stays yours and can be picked: Trophy wall > "Nicknames" tab (or tap your nickname on the menu card). "Automatic" always wears the newest. Open ones show their progress, e.g. 13 / 25.
- New on the trophy wall: "Trophies" tab. Every crew leader you beat gives a plaque, every boss a cup, the final boss the big cup. Tap one for the day, car and battle time of the win.
- Phone messages are now easy to spot: green "Phone message" tab with a phone icon on the speech bubble and a ringing phone on the portrait.

### More wanderer conditions
- 23 new condition types for rivals and wanderers (like in TXR): win streak, money, number of cars, at most X losses, naturally aspirated only or forced induction only, manual gearbox only, drivetrain (FWD, RWD, AWD), a part that must not be fitted, paint colour, characters in the plate, power and weight, odometer of the car, top speed already reached, in-game weekday, active nickname, chosen logo, days without a loss, car almost undamaged, PAs visited and any value from the statistics (e.g. pink slips won or side jobs done).
- The rival builder in the dev menu keeps the new conditions when editing.

### Buy rival cars
- New: beat a crew leader, boss or wanderer and their car shows up at the car dealer under "Rival cars", in their paint, with picture and previous owner. A message after the win tells you.
- Each car is sold only once and it's expensive: leader 5x, wanderer 7x, boss 10x the BeamNG price. Adjustable in dealer.json ("rivalCars"), per rival also an own factor or not for sale at all.

### Maintenance: oil, coolant, tires
- New: every car has engine oil, coolant and tires from 100 % to 0 %. They drop with every kilometre.
- In the garage (Service tab) you see all three with a bar and price and service them one by one or all at once.
- Below 50 % you feel it: old oil costs power, low coolant overheats the engine faster, worn tires have less grip. Below 20 % you get a warning on the road.
- Used cars start at 35 to 90 %, rival cars fresh. New tires from the shop count as fresh. Everything adjustable in maintenance.json.

### Trophy wall (logo collection)
- New, like in TXR: beat a crew leader and you get the crew logo. Beat a wanderer or boss and you get their seal or emblem. A message after the win tells you which logo is new.
- New "Trophy wall" tile in the left menu (on the road and at home) with your current logo and how many you have (e.g. 16 / 73). Inside are all logos by crews, wanderers and bosses. Locked crew logos are grey, seals and emblems stay "?" until you beat them. Tap one to see what it takes.
- Tap an unlocked logo to make it yours: it then shows at the top left of the SP display during battles instead of the Hashiriya mark 走. "Default" switches back.
- Every save slot has its own collection and choice. Old saves get the logos of every opponent already beaten right away.

### Clear key overview
- The key check when starting a new save now shows every key of the mod, sorted into Battle, Hashiriya Battle, On the road and Developer. New: skip music, get out/get in and (dev version only) title camera and dev menu.
- Red means needed and missing. Grey means just handy and may stay free.
- New in the pause menu: Esc > Mods > Hashiriya Battle now has the tabs "Keys" and "Music". "Keys" shows all bindings any time, "Bind" opens the BeamNG controls straight for that key.

### Three save slots
- New: up to three saves side by side. "New game" now asks for a slot (1 to 3) first. An occupied slot is only overwritten after you confirm, and only once you finish the setup.
- New "Load game" entry on the title screen: all slots with driver name, rank, car, day, money and last save time. "Continue" loads the slot you played last.
- Saves can be deleted on the title screen (with confirmation). Switching slots mid-game saves the running game first.
- Your existing save automatically becomes slot 1.

### Unstuck
- New: "Unstuck" with Shift + U or as a tile in the left menu. If you get caught in a guardrail or object with the car or on foot (some of them on C1 are not fully solid and hold you like a magnet), you are moved back 0.5 m along your own path, facing the way you were and without momentum.
- Still stuck? Pressing again shortly after moves you back further (1.5 m, 3 m, 6 m).
- Damage and fuel stay, it is free. Blocked during battles, conversations, in shops, above 15 km/h and when the car is on its roof (get towed then). Short cooldown between uses. Everything adjustable in world.json ("unstuck").

### Wanderer Builder to send around
- New Wanderer Builder: a single HTML file that helpers and testers open in their browser with a double click (offline, English and German). They build their own Wanderer with it and send back one file.
- Inside: name, Japanese name, nickname, backstory, sign for the Wanderer seal, the new Bob avatar with all parts including beards and an own colour, the car config (just drag in the .pc), Japanese license plate with preview, driving style, strength, conditions and three lines.
- Submitted Wanderers come into the game with avatar, seal, plate, config and credits entry, exactly as the builder shows them.
- The Wanderer Builder now knows all 30 condition types (weekday, NA/turbo, manual gearbox, drivetrain FWD/RWD/AWD, paint colour, power, weight, mileage, win streak, money, nickname, emblem, statistics, visited parking areas and more), sorted into five groups. The build date is shown at the bottom.
- Handbook: all links to the old Wanderer form now point to the Wanderer Builder. The old Google form is marked as outdated and folded away for reference only.
- Wanderer Builder reworked after Alex's feedback: the neck is visible again with the hoodie, fur coat and parka; headphone band and towel sit behind the neck; glasses temples run to the edge of the head instead of into the eyes; the comb lines of "slicked back" stay inside the hair; the ponytail falls closer to the neck.
- New avatar parts: kimono with obi, happi (festival coat), hairstyles giant regent (bōsōzoku), pompadour (Elvis) and punch perm, visor eyes crossed (X X), hearts, stars and squeezed, plus the mouth shape (straight, grin, smirk, crooked, grim, teeth), also together with a cigarette or toothpick. "Blazer suit" is now "Women's suit (blazer)".
- Every fabric colour works with every top. Locked parts show the reason right below them (e.g. the field cap needs the field jacket, the hat needs elegant clothes).
- License plate: "Type" only offers types that really exist in the chosen region; Okinawa is its own region with US Air Force only.
- Driving style as uniform buttons with explanations (aggression 1 to 8, cruising speed, strength with "from rank X"). The nickname condition lists all nicknames with how to earn them. New field "Anything else?" for wishes and later changes.

### New left menu
- The left menu (Home key) is tidied up: a card at the top with money, time, rank and reputation bar, plus small fields for record and "Nearby". The main entries (save, lexicon, dealer, stats, nap, tow) are tiles instead of a long list.
- Rarely used entries (skip music, parking marker, bug report, dev menu, quit mode) sit under a collapsible "Tools".
- Home works the same way: "Sleep" as a wide tile with its note, then save, lexicon, job board and tutorial.
- New rival lexicon: all crews as a compact list with logo and progress bar, one crew opens at a time. Rivals take one line each (name, nickname, car, driving style); description and quote only show when you click.
- The lexicon has a search (name, car or crew) and filters: All, Open, Beaten, Watch list. Use the star in front of a name to add someone to your watch list. A dot on the right shows open (ring) or beaten (orange).

### Portraits: beards
- The Bob portraits can now wear beards (Henry's idea): stubble, moustache, chin beard, goatee, sideburns, full beard, long goatee, contour beard, chin strap, anchor beard and short boxed beard, in many colours (all hair colours plus grey, white, ginger and salt-and-pepper).
- 49 rivals and 20 PA drivers now have a beard, including some wanderers. Boss Mugen wears a silver goatee, Boss Shirotora a platinum chin beard. All other figures look the same as before.
- The silhouette tool has new "Beard" and "Beard colour" fields under "Extras".

### Save where you park
- Loading no longer always takes you home. You start where you properly saved: at home (save or sleep) and in the garage like before, out on the road exactly at that spot, same heading, time, fuel and damage.
- On the road you can only save when the car is standing still with the engine off: pull over to the shoulder or into a PA, stop, ignition off, then "Park & save here" in the menu. Park in the middle of the expressway and that is where you start. A nap in the car counts as parked.
- Saving with the engine running shows an "ENGINE OFF!" notice with a 2026 eco joke. Keep trying and you get an extra one.
- Quit without parking properly (or the game crashed)? Progress is never lost, your position is tracked every 30 seconds. By default the expressway police towed your car to the garage (towing fee plus a fine). The fine doubles every time: 20,000 ¥, then 40,000, 80,000 and so on, so towing is no shortcut and you start at home. world.json (saving.unsavedExit) can switch this to "continue from the last checkpoint".
- The menu shows below "Save" where your current save spot is, in red while you are not parked.

### Team logos (drafts)
- Every crew now has its own logo in the style of a die-cut vinyl sticker (just the motif and lettering), leaders get the same logo with a gold border. Every wanderer has a personal seal with their own sign, and the three bosses have their own emblems. All original designs.
- Logos are built into the SP display in a battle (your 走 mark on the left, the crew symbol on the right), as a sticker on the portrait in the speech bubble for challenge, win and loss, in PA talks with rivals and at every crew in the rival lexicon. Wanderer and boss seals only appear in the lexicon after you beat them.

### Traffic and PA drivers
- Traffic now really uses all 152 Japanese vehicles of the Agent traffic mod. Before, only the first few cars of Agent's list ever showed up. Now the list is mixed by frequency, cars already picked become rarer, and extra hidden cars take turns with the driving ones. Parked cars are much more varied too.
- Mechanic, trucker, courier, taxi driver, student and office worker now drive fitting cars from Agent Traffic JP at the PAs (kei trucks, Dutro, JPN Taxi, Crown etc.) with Agent's liveries. Without the Agent mod the old cars are used.
- 10 new people at the PAs: postman, refuse collector, road worker, electrician, security guard, cleaner, family man, retired camper, otaku and map car driver, each with their own car, portrait, small talk and mostly a knowledge story.
- The taxi configs (Shinonome, Gekko) and police configs (Pessima Mk2, Sunburst) are now part of the mod. The taxis park next to the taxi drivers at the PAs.

### PA rivals
- Rivals at the PAs now visibly leave: after you accept, the rival gets into their car, starts the engine, turns the lights on at night and rolls slowly out of the PA onto the C1. There they are a normal rival on the radar. They cruise slowly at first so you can catch up. They follow an exit route that is recorded once per PA in the dev menu (Places > record PA exit) and always park backed in, nose towards the lane. Without a route, or if they get stuck, they wait ahead of you like before.

### Liveries
- New Japanese liveries (own, made-up companies) as paint designs in the configurator: two taxis on the Pessima Mk1 (Shinonome Kotsu, Gekko), police on the Pessima Mk2 and Sunburst, plus mechanic, freight, courier and ambulance on the Gavril D-Series and H-Series. Configs for the PA drivers follow.

### Starter cars
- The starter car pool is now final: 34 stock configs of the Ibishu Covet, Ibishu Miramar, Hirochi Sunburst, Ibishu 200BX/Diana, Pessima Mk1 and Pessima Mk2 (manual and automatic). No other cars are offered at the start any more (e.g. the Covet DX and Miramar Export are gone).
- Sunburst, Pessima Mk1 and Pessima Mk2 now use the same condition range as the 200BX and Diana: 180,000 to 290,000 km and more engine wear.
- The offered starter cars are now sorted by their actual price, cheapest first.

### HUD
- Rivals on the minimap (bottom left) now use the same colors as in the radar (top right): orange rival, yellow leader, purple wanderer, red boss, grey beaten, blue lost. The rival in the current battle pulses slightly.
- Your own arrow on the minimap is now white (like your dot in the middle of the radar), so it stands out from orange rivals.

### Rival garage (developer tool)
- New in the dev version: entry "Gegner-Garage (Dev)" in the BeamNG main menu under More, right next to Hashiriya Battle. It starts the regular BeamNG garage with all its features (parts, tune, paint, decals, vehicles, photo, lights, camera) and puts the "Rival garage" panel on top. Search rivals or filter by crews, leaders, wanderers, bosses, own configs and missing configs, click one, and his car loads in the garage with his config (as in game with plate and fixed paint, or the plain config).
- New: stages like the rematch versions in TXR 2025. A rival can come back stronger in a later chapter, with a new nickname, new lines, their own config and often only then with an aura. Genzō announces the comeback by phone, on the road it says "(stage 2)".
- Coming back with an aura: Kemuri and Kazekiri (from chapter 4), Benikaze and Noir (from chapter 5), Gruppe Fünf and Fukurō (epilogue). Shinkirō, Tsukiyomi, Yūrei, Hotaru, Kaminari and Afterburner have their aura from the start.
- Three crew members rise to wanderer in two stages: Hinata Oda ("Heir of the Lantern"), Tadashi Hirota ("The Dropout") and Taiga Shimizu ("Blizzard"), stage 3 with an aura.
- Reika Hoshino, leader of the Neon crew, now has an aura too, like every rival with PowerGlow paint. So there is an aura to unlock early on.
- Rival garage: filter "Stufen" (stages). Saving on a stage creates its own config and writes it to the stage. The aura editor works per stage.
- Wanderer Builder: new choice "Comeback (wish)" with the chapter.
- Aura editor in the "Aura" tab: per rival aura on/off, colour (hex field and sliders) and strength, with live preview on the car, saved to rivals.json. Plus sliders for shell, haze and light and the rule for who gets an aura automatically, saved to aura.json. Both with backup.
- Like in TXR 2025, only a few rivals carry an aura now: the three bosses and 12 special wanderers (including all with Powerglow paint: Shinkirō, Tsukiyomi, Yūrei, Hotaru). More can be switched on in the editor. Crew, leader, wanderer and boss auras in the trophy wall now only come from rivals who carry one themselves.
- The glowing haze gets thinner in battle as SP drops and disappears when SP is almost empty.
- Wanderer Builder: new choice "Aura (wish)". The wish goes into the file with the avatar colour, the import script shows it.
- The aura now really glows around the car: a soft flame shell in the aura colour, rising glowing haze and the ground light. In a battle it gets taller, brighter and pulses. Applies to rivals, your own aura and the preview in the rival garage. Adjustable in aura.json (shell, haze).
- Loading a rival now also sets his licence plate number (before, the old car's number stayed and only the plate design changed).
- Next to it: description, crew with all members and their cars, conditions in plain words, driving style, reward and lines. That keeps a car in character while tuning it, e.g. the company cars of Zangyō Express.
- "Save to rival" writes the tuned config back: own mod configs are overwritten (with a backup), BeamNG configs stay untouched and the rival gets his own hashiriya_r_<id>.pc, rivals.json is only changed at that one spot.
- "Aura" tab: see a rival's aura right on the car in the garage (ground, battle, level, SP), with a brighter preview and "reload aura.json".
- The original BeamNG garage (More > Garage) stays completely unchanged; the panel only appears through the own entry. Not in the release.

### Handbook
- Every file and folder name in the handbook is now a link: click opens the file, the folder icon next to it opens its folder. New in "Folders and files": quick access to the most important files and folders.
- Chapter "Testing" links the tick-off test list, now with 114 new tests for all features from 1 to 4 Nov 2026.
- Links open in the browser, in Explorer or directly in the editor (set up Explorer/editor once with tools\Handbuch-Links-einrichten.bat).

### Bug fixes
- Cars of the drivers at the PAs (rivals and info drivers) sometimes overlapped with a parked traffic car. Their bay is now reserved against parked traffic, and a car that still ends up in it is moved elsewhere right away.
- PA drivers' cars had the default plate instead of a Japanese one. They now get a Japanese plate design (taxis and vans green), rivals their own.

## Alpha 0.9.1 (as of 2026-11-02)

### Side jobs
- Courier, express and fragile jobs: pick up the goods first, then deliver them. The timer starts at pickup.
- Pickup point, destination and photo spot get a ground marker like the parking lots (orange, green for photo jobs), plus a navigation route on the minimap.
- Photo job: with custom photo spots you park the car right there. The photo plays a shutter sound and a short flash.
- Tips: only for wanderers and bosses you can already meet. They are much pricier (from 250,000 yen, bosses from 750,000 yen, 10 % more per rank). Genzō then sends you the hint as a phone message.

### Garage and dealer
- The car dealer is now right in the garage menu (Service tab).
- A car's sell price now depends on its value, bought parts, condition and kilometres driven.
- "Not installed" is now called "Removed".

### Story and PAs
- The chapter card now waits until the battle and the rival's line are over.
- Genzō now has a portrait.
- Dev menu, places: new types "PA driver stand spot" and "photo spot". PA drivers use saved stand spots instead of random places (no more standing inside cars).
- Fixed standing spots for the drivers at Tatsumi PA 1 and Shibaura PA (60 spots, placed by JDMArsch).
- PA drivers can get a fixed custom config (chat.json, cars[].config).
- Title menu and new save: a note that the mod is balanced with community help, asking for feedback in the forum thread.
- PA Bobs now use the outfit color from their portrait (before, e.g. a yellow taxi driver had a wine-red vest in the portrait).
- Dev menu: hide single pillars or whole types, and show the map's parking bays as markers.

## Alpha 0.9 (as of 2026-11-02)

### New: Rival driving character
- Every rival now has a driving style: clean racer, blocker or rammer.
- Clean racers leave you room. Blockers close the line in front of you more often. Rammers look for contact beside you and brake-check.
- Rivals without a fixed style get one that matches their aggression. Bosses are never rammers on their own.
- The style is shown in the rival lexicon once you know the rival (since Alpha 0.9.2 as a colourless symbol, the text only in the dev version).

### New: Music controls
- New music: four AI placeholder songs (Full Throttle Soul, Kaze ni Nare, Midnight King, Moeagare) play in all situations for now. They are marked as AI in the credits, can be switched off per situation and will be replaced by real tracks. The old Kevin MacLeod tracks are gone.
- Your own music: put your songs into the hashiriya_musik folder in the BeamNG user folder, sorted by situation (title, day, night, parking area, garage, shop, battle, boss, wanderer, pink slip).
- The title menu and the new save screen show a tip that your own music gives the best experience.
- In the pause menu under Esc > Mods > Hashiriya Battle you pick for every situation which songs play, mod songs and your own.
- Music selection in the pause menu: every song, including the AI songs and your own, can be switched on and off per situation. Also per situation the source (both, mod, own, off), next song, open folder, rescan and reset to default.
- Song order per situation: shuffle or a fixed order you sort yourself.
- Music no longer jumps around so much: a song keeps playing if it is also part of the new situation, and in free roam (PA, garage, home, shop) it plays to the end. Battle changes crossfade more slowly.
- New music situations: parking area (PA), garage and home, battles against leaders and bosses, against wanderers and pink slip.
- New camera shutter sound for the photo job (camera_digital_shutter).
- Music can now also play as WAV in full quality: if a WAV with the same name sits next to the OGG, the WAV is played. The title song Daikoku now runs this way in its new version V3.
- Skip music: End key or in the Hashiriya menu under Tools. It also shows which track is playing.
- Each track can be limited to certain situations: time of day, rival type (normal, leader, wanderer, boss), pink slip, rank, parking area or map (data/music.json, see handbook).
- Traffic is now quiet on the title screen so the title music can be heard.

### Bug fixes
- Status display top right: during a photo job (e.g. after "too early") the text was cut off on the left, including the chapter line. Long lines now wrap and the time window is shorter (07-09 h).
- The music was silent. It now plays through BeamNG's own music channel.
- BeamNG's main menu music stops as soon as you start Hashiriya Battle and comes back in the regular main menu.
- After the title screen, engine, tyre and other vehicle sounds stayed muted. They now return to the volume from your audio options.

## Alpha 0.8 (as of 2026-11-02)

### New: Remove and sell parts
- At the garage PC you can now remove almost every part ("Removed"), including stock parts. Only mandatory parts the car can't exist without stay in.
- In the parts storage every part that isn't installed has a "Sell" button with its price. Click twice and it's gone. A part brings 40 % of its price.
- Sold stock parts can be bought again at the shop.

### New: Sell cars
- In the garage every car except the active one has a "Sell" button with its price. A car brings half its value. Stored parts of that car go with it.

### New: Game over
- If you lose your last car in a pink slip, you stand on foot at the garage. If you can afford the cheapest dealer offer, buy a new car there and it's waiting in the garage.
- If you can't, your career is over: game over with rank, days and record, then a new career.

## Alpha 0.7 (as of 2026-11-02)

### New: Daytime side jobs
- The garage and your home now have a job board with four jobs every day, daytime only.
- Courier: bring cargo to a destination within a time limit. Damage to your car is taken off the pay.
- Express: tighter time limit, more money.
- Fragile: more money, but damage counts three times. Too much damage and the job fails.
- Photo job: be on foot at a parking area while the photographer's time window is open.
- During a job the status display shows destination, direction, distance and time left.
- Pay grows with your rank. At most four jobs per day.

### New: Buy tips
- At the job board you can buy hints about wanderers and bosses. They go into the rival lexicon, just like hints from parking area talks.

## Alpha 0.6 (as of 2026-11-02)

### New: Story and chapters
- The career now has a story: prologue, five chapters and an epilogue. You arrive in Tokyo and want to find out who Mugen is.
- Each chapter starts with a chapter card (title in English and Japanese, short text).
- Scenes play in the speech bubble: in the garage, when waking up at home, at the parking areas and after important battles. Continue with T.
- Short phone messages also arrive while driving and advance on their own.
- The current chapter goal is shown below your money and in the menu.
- The rival lexicon has a "Story" page at the top with all chapters and scenes you've seen.
- Old saves jump straight into the matching chapter.
- The story texts are still a draft and are being agreed with JDMArsch.

## Alpha 0.5.1 (as of 2026-11-02)

### New: Music
- Own music depending on the situation: title screen, day driving, night driving, shops and battles each have their own playlist, with smooth crossfades.
- Title music: "Daikoku" by z3rdax, made for the mod, which then keeps running as a loop.
- Volume follows the BeamNG master and music sliders.
- The credits now have a Music section listing every track with its license notice.

### Bug fixes
- Crash damage was not saved: after reloading, the car was fixed again, dents gone, lost parts back on, engine like new. Damage is now kept in the save (dents, broken parts, engine and radiator damage), and the repair price is correct after loading. Only a repair fixes the car.

## Alpha 0.5 (as of 2026-11-01)

### New: rivals at the parking areas
- At night, rivals and wanderers now also stand next to their own cars at Shibaura PA and Tatsumi PA, with portrait, nickname and their line. Bosses don't.
- Walk up and talk to them with T. Then T = battle, walk away = no.
- The rival heads out first and waits on the C1. Once you drive out, they show up ahead of you. Flash your lights and the battle runs as usual.
- A rival standing at a PA won't appear on the road at the same time.

### New: pink slips
- About every third rival also races for pink slips. You need rank 3 and at least two cars in your garage. Accept with G.
- Win and their car is yours: their config, paint and plate, straight into your garage.
- Lose and they take your car with all its upgrades and drive it from then on, on the road and at the PA. You carry on at home with your next car.
- Every win against them brings your car back. They also show up at the PAs more often then.
- The SP HUD shows "PINK SLIP" during the race.
- New key "Talk: pink slip" (default G), also in the key check.

## Alpha 0.4.1 (as of 2026-11-01)

### New: more to talk about at the PAs
- Drivers in the parking areas now have far more to say: 77 knowledge texts about the Shutoko, the C1, Tokyo, Japan, cars and the history of street racing. Many are short stories spread over two or three speech bubbles.
- Examples: when the first piece of the Shutoko opened and what the toll cost, why the C1 runs over rivers and old castle moats, why Nihonbashi is Japan's kilometre zero and will soon see the sky again, the Rainbow Bridge, the late-80s scene, kei cars and yellow plates.
- Every PA has its own fun facts: at Shibaura PA you learn about the Rainbow Bridge and its loop, at Tatsumi PA about the district and the weekend closures.
- Each driver type has favourite topics. The veteran tells history, the trucker talks traffic, the student talks about Tokyo.
- Knowledge texts have a blue edge and show their topic at the bottom, for example "Knowledge · Shutoko".
- Talk to someone again and they often remember something you haven't heard yet.
- 47 new lines of small talk, 4 for each driver type.
- The drivers are Bobs and they know it: 27 knowledge texts about BeamNG, such as where the world comes from, how nodes and beams make every dent, why a Bob weighs 89 kilos and which manufacturers are Japanese ("Knowledge · BeamNG").
- 104 knowledge texts in total.

## Alpha 0.4 (as of 2026-11-01)

### New: talking at the parking areas (PA)
- Drivers now stand next to their parked cars at Shibaura PA and Tatsumi PA: 3 to 6 at night, 1 to 2 during the day. There are 12 types, for example trucker, photographer, old hand, car park attendant and drift fan. Each has their own cars and three portraits.
- Get out and walk over. "[T] Talk" appears. Press T to talk; press again for the next line or to end the conversation.
- What drivers tell you depends on your progress: rumours about crews once your rank fits, rumours about leaders when a crew is almost beaten, and who is waiting for you tonight.
- Tips about wanderers and bosses unlock the hint in the rival lexicon, so you learn how to meet them.
- The same night always shows the same people at a PA; the next night different ones are there. Talk to someone twice and they'll tell you so.
- Drivers turn towards you as you approach.
- New key "Talk" (default T), also listed in the key check.

## Alpha 0.3.5 (as of 2026-11-01)

### Bug fixes
- Trying on parts in the shop fully repaired the car. A damaged car now has to be repaired before you try on or swap parts or apply the setup. The terminal shows a repair button with the price. Painting still works.
- Swapping parts in the shop reset the wear and mileage of the parts. They are kept now.

## Alpha 0.3.4 (as of 2026-11-01)

### Bug fixes
- In the release build the Hashiriya menu on the left could not be clicked. Cause: an old HUD layout from development still contains the builder as an invisible full-screen app, and BeamNG did not let clicks through it. The placeholder is now marked as non-interactive and lets every click through.

## Alpha 0.3.3 (as of 2026-11-01)

### Bug fixes
- Alpha 0.3.2: nothing in the game could be clicked anymore (menus, side menu, apps). Fixed.

### New
- Title screen: new "Changelog" entry where you can expand and read every version.

## Alpha 0.3.2 (as of 2026-11-01)

All changes since Alpha 0.3 (includes the test build Alpha 0.3.1).

### HUD
- Own HUD apps in the Hashiriya style: messages, tasks and scoreboard top left, a landscape minimap, speedometer, boost and drivetrain. Slimmer than before, no chunky boxes.
- The gear display no longer shows an error value, and the minimap loads reliably.

### Tuning
- Parts are now spread over 6 tiers (LV1 to LV6) instead of 3, based on class and price. It takes longer to unlock the best parts.
- When a new tuning tier unlocks, a notice shows the new parts. This also works while you are on foot.

### Sleeping
- After sleeping or a nap you cannot sleep again for 6 in-game hours.

### Release build
- No more quick travel via the big map: the quick travel points are gone, and no location has a "Quick Travel" button.
- An old HUD layout from development no longer covers the whole screen.
- The new-parts test from the developer menu is locked in the release.

### Other
- The button in the BeamNG main menu ("More ..." page) now shows the Hashiriya Battle logo.
- Credits: new "Testing" section with Slim Henry.

## Alpha 0.3 (as of 30 Oct 2026)

All changes since Alpha 0.2 (29 Oct 2026, internally still called "Alpha 1").

### Rivals and crews
- Big roster: 26 crews with leaders plus 42 wanderers, almost 300 rivals in total. Every rival has their own Japanese licence plate, some have a fixed paint job.
- No more brand names for rivals. All of them have fitting Japanese or foreign names and a short backstory.
- Every rival has their own lines for the challenge, a win and a loss. They show up in a new speech bubble with a silhouette portrait and in the rival lexicon.
- New rank system with 15 ranks. Tuning tiers now depend on your rank.
- Hints about wanderers stay hidden until you have heard about them.
- Rank and nickname are shown in the status HUD.

### Battles
- Own rival AI: in front, the rival weaves through traffic like a real hashiriya but still brakes in time. Behind you, the rival hangs on with a rubber band and stays close.
- When challenging, the rival's line stays on screen for 6 seconds, then the countdown runs from 5. The result stays for 9 seconds.
- After a false start you can challenge the same rival again after 30 seconds.
- Rivals spawn more reliably: correct direction on one-way roads, no spawns at road edges or in gaps, with a retry if something goes wrong.

### New game, starter car and dealer
- New title screen with its own camera view, time of day and traffic already running in the background. Credits on the title screen.
- Japanese licence plates (region, type and special plates) can be chosen for a new game, at the dealer and in the garage.
- Starter car selection with tiles for power, torque and weight plus bars for condition and fuel. Weaker starter cars are in better condition.
- Starter cars never cost more than your starting money.
- Changing the colour in the showroom shows the car in the new colour right away.
- The car dealer only offers cars that fit your progress (power cap based on the rivals you can reach). Dealer cars are used, imports are very rare.

### Daytime and free time
- Day jobs: BeamNG "Garage to Garage" missions pay out yen. Time trials are hidden.
- Sleeping and napping fade to black, the clock fast-forwards to the wake-up time.

### Troubleshooting
- Mod log in settings/hashiriya_battle/logs in the BeamNG user folder (size-limited).
- Menu > Create bug report writes everything important into one file you can send to the developer.

### Release build
- Restrictions like the official BeamNG career, only the node grabber stays: no vehicle selector or vehicle config, no repair, recover, flip or reset, no switching to other cars, no console, no editor, no slow motion.
- Pause menu without the vehicle and environment tabs, the freeroam tab is called "Hashiriya Battle" and no longer has freeroam buttons.
- No quick travel via the big map. Time trials no longer show up in the points of interest either.
- All dev and cheat tools in the Hashiriya menu are off.

## Alpha 0.2 (as of 29 Oct 2026, internally "Alpha 1")

All changes since Henry's test build (28 Oct 2026, morning).

### Battles and rivals
- Several rivals drive in traffic at the same time (up to 4). Beaten rivals keep driving and come back later for a rematch.
- Rivals drive with their lights on at night. Some rivals may later drive without lights as their trademark.
- Rivals spawn further away, no longer on on-ramps, and start rolling at cruising speed right away. Stuck rivals get pushed again or removed.
- Rival radar in the HUD with colours: orange rival, yellow leader, purple wanderer, red boss, grey beaten, blue lost.
- Challenging is blocked when the speed difference is over 30 km/h ("Too fast" / "Too slow").
- You can only challenge from up to 30 m behind the opponent.
- Before the countdown, cruise control matches the speed and closes the gap. The countdown only starts once you are close enough.
- During the countdown cruise control locks the throttle. Pulling ahead or getting too fast counts as a false start.
- Leaders: a hint appears after the last team member. Some leaders show up the same night, others the next night. A leader who is ready is spawned first.
- No more battle limit per night.
- Rivals now challenge you too: if one drives behind you for a while, they flash their headlights. Hazard lights = accept, left or right indicator = decline.

### Reputation, streak and combo
- Win streak: more prize money and reputation for consecutive wins. It ends with a loss, in the garage, at home or at daybreak.
- Driving style combo only during a battle at night: near miss, razor-thin, close overtake, slipstream, drift, full throttle in traffic. A crash clears the combo.
- Statistics page in the menu.
- Speed traps only count when you get flashed. Triggering all of them attracts a wanderer.

### Rival lexicon
- The lexicon can be opened from anywhere in the menu.
- Watch list with up to 5 rivals, shown in the HUD. A rival is crossed off after you beat them.
- Leaders show their status (waiting for members, from next night, on the road).

### New game and starter cars
- Key check before starting: shows whether headlight flash, hazard lights, left/right indicators and the Hashiriya menu are bound. "Bind" opens the BeamNG controls directly for the missing key.
- Choose between rookie and experienced. Rookies get the 7-page tutorial (pictures to follow).
- Seed system: driver name and licence plate decide which 3 of 13 used cars are offered. Mileage, condition and fuel level are rolled.
- Starter cars are used: mileage, wear and older paint. A used engine misfires slightly and warms up faster, but stays drivable.
- The tank is never below 25 % when you buy the car.
- The starter car's price is taken from your starting money.
- The showroom is now the C1 map's workshop. After buying, the car stands in the garage bay.

### Day, night and home
- A game day now lasts 36 instead of 24 minutes, so the night (8 pm to 6 am) lasts 15 minutes.
- The HUD always shows time, weekday and date.
- The game clock always keeps running and no longer stops.
- Traffic follows the time of day: full during the day, less at night. It is also switched on at start if it was off in the BeamNG main menu.
- Sleeping at home: during the day until 8 pm, blocked between 8 pm and 10 pm, from 10 pm until 6 am.
- Nap in the car at parking areas (Shibaura PA, Tatsumi PA and the lay-bys): 0.5 to 2 hours.

### Shop and garage
- Shop on foot: menu at the entrance, camera from the entrance onto the car. The car is held in place while shopping, a "Leave shop" button ends the visit.
- Opening hours 8 am to 8 pm. Outside those hours a note shows the times.
- Shopping cart with total (remove single items, buy all, clear). Vehicle stats show changes in green or red.
- Part categories reworked: engine, body, bumpers and extras now show the right parts, also on the 200BX.
- The transparent part view disappears when leaving.
- The tank can no longer be adjusted in the garage setup. The fuel level is kept on respawn, repair and reset.

### Refuelling
- Refuelling while holding the key works continuously. The fuel sound stops cleanly.

### HUD and menu
- HUD layout by JDMArsch (damage at the bottom, navigation).
- Status app bigger and below the hints, nothing is cut off at the top anymore.
- "Save position" also works at the garage at the map origin.

### Release preparation (still off in the alpha)
- Release switch in data/build.json: blocks reset, console, editor, slow motion, quick travel via the map and time changes via Time & Weather.
- Node grabber stays allowed, with a fixed strength.
