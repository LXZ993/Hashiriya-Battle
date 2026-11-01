# Hashiriya Battle Changelog

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
