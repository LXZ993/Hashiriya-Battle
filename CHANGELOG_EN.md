# Hashiriya Battle Changelog

## Alpha 0.9.2 (as of 2026-11-03)

### Liveries
- New Japanese liveries (own, made-up companies) as paint designs in the configurator: two taxis on the Pessima Mk1 (Shinonome Kotsu, Gekko), police on the Pessima Mk2 and Sunburst, plus mechanic, freight, courier and ambulance on the Gavril D-Series and H-Series. Configs for the PA drivers follow.

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
- The style is shown in the rival lexicon once you know the rival.

### New: Music controls
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
