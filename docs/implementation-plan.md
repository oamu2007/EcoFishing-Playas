# Vertical slice implementation plan

The `roadmap-implementation` branch starts from playable revision `f812046` on `feature/dynamic-water`. Revision `0ee166b` completes M7–M12, `97b5709` completes M13–M18, and `d91844c` completes the verified M19–M25 follow-up. M26–M30 build on the M25 checkpoint.

## Definition of done

A first-time player can start a session from the menu, learn to collect recurring floating trash with a starter rod, and take it to a nearby fishing shack in a shared Sack. Trash sales fund rod and Sack upgrades and permanent cleanup. Cleaner water brings back catchable fish that the player can carry and sell for more gold coins. The map supports short trips between the shoreline and shack, and the menu, HUD, and shop use a consistent visual theme. The player can start a fresh session in-game. The main scene and standalone graphics preview run without parser or resource errors.

After the follow-up, trash arrives at a gentler pace, upgrades take several trips to earn, rod tiers and fish species are recognizable by sight, and a short timing challenge must be won to land a fish. A screen-based trader handles item selection and visual purchases. The balance stays visible at the top left with a coin icon, cleanup crews visibly carry out purchased projects, and the animated start menu includes future save and load controls.

In the next pass, incoming trash keeps moving inward until it reaches the equipped rod's horizontal range. Fish take more precise timing to land, optional add-ons are bought for individual rods, and more cleanup purchases deliver smaller improvements. The title and pause screens have separate layouts, contextual help stays hidden until requested, the trader supports a one-action sale, and music and sound effects cover the full session.

The next playtest pass makes catchable fish more active and gives common, rare, and trophy encounters distinct stakes. The trader has roomier add-on cards and a shortcut back from Buy or Sell. Purchased add-ons are visible on the rod. A full Sack gives brief feedback at cast time, and footsteps sit lower in the mix.

## Current checkpoint

[Milestones 26–28](#milestone-26--fish-motion-and-timing-feel) are verified. Player review called for a clearer common-to-rare difficulty gap, which informed the rare and trophy windows. Continue with Sack feedback and footsteps in M29. The first-time-player run, human listening pass, and cross-device checks from [M25](#milestone-25--integrated-playtest-and-stabilization) carry forward to M30.

## Completed baseline

Milestones 1–6 and the subsequent visual polish describe the existing finite-batch prototype and its recorded checks. In that build, the player clears 24 drifting trash pieces to reach 0%, sees ambient fish return, and restarts from the editor. Milestones 7–12 replace the finite-batch finish with ongoing progression.

## Milestone 1: Project bootstrap

**Status: Implemented (October 18, 2026).** See subsequent milestones for editor and runtime verification of the integrated build.

- [x] Confirm the project configuration targets Godot 4.7.
- [x] Define a 960 × 540 viewport, responsive canvas scaling, and movement input actions.
- [x] Create the main scene and one test shoreline level.
- [x] Add a simple controls HUD and establish collision layers/masks in project settings.
- [x] Set the main scene for F5 project runs.
- [x] Add a fishing input action (implemented in Milestone 3).

**Exit check:** Running the project opens the test shoreline at the expected aspect ratio with no errors.

## Milestone 2: Player movement

**Status: Implemented (October 18, 2026).** See subsequent milestones for scripted movement verification. Manual playthrough remains pending.

- [x] Build a modular `CharacterBody2D` player scene.
- [x] Implement typed top-down movement with normalized diagonal input and exported speed.
- [x] Add beach and ocean collision boundaries plus a smoothing follow camera.
- [x] Add a clear placeholder fisherman assembled from procedural shapes.
- [x] Support both WASD and arrow-key movement.

**Exit check:** WASD and arrow keys move the player smoothly, collisions hold, and diagonal movement is not faster.

## Milestone 3: Fishing interaction

**Status: Implemented; verification results recorded below.**

- [x] Modular rod, line, and hook scenes with IDLE, CASTING, WAITING, RETRIEVING states.
- [x] Mouse aim; left click casts and retrieves after landing.
- [x] Shoreline proximity, water bounds, range validation, and green/red aim feedback.
- [x] Interpolated cast with separate parabolic visual height and exact water landing.
- [x] Connected line, rotating rod, movement locking, and repeated-click protection.
- [x] Typed lifecycle and waiting-only FishingTarget overlap signals.
- [x] Actual catch selection and collection with trash implemented in Milestone 4.

Manual acceptance procedure:

1. Press F5. Test WASD/arrows, diagonal speed, beach collision, and camera follow.
2. From spawn, aim at water and click. Expect a red marker and “Move closer to the shoreline”; movement remains available.
3. Walk right to the ocean barrier. Aim on sand, then water beyond 420 px from the rod. Both reject without locking movement.
4. Aim into visible water (world X=1000 near the player's Y). Green means valid. Click: hook arcs up then lands exactly on target, with line connected.
5. Rapidly click and hold movement during flight: no extra cast, early retrieval, or player movement.
6. Wait several seconds after landing: hook stays on target, line stays visible, status says “Waiting”. Moving the mouse does not move the hook.
7. Click to retrieve. Rapid clicks cannot restart it. Hook returns to tip, line/hook hide, and movement unlocks. Repeat at different targets.
8. Resize the window and repeat aiming to check camera/canvas conversion. Check the Debugger for errors.

Automated verification on Godot 4.7.2: headless editor import passed; the main scene ran for 120 frames without script/resource errors; `tests/fishing_smoke_test.gd` passed with zero failures. It checks input configuration, rejected/valid targets, movement lock, arc height, line endpoints, exact landing, stable waiting, click gating, and retrieval cleanup. Interactive appearance and mouse aiming after window resizing still need the manual procedure above.

Run from the project root (use the full executable path if Godot is not on PATH):

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/fishing_smoke_test.gd
godot --headless --path . --quit-after 120
```

**Exit check:** The player can repeatedly cast and retrieve; valid targets are detected once and invalid casts recover safely.

## Milestone 4: Trash collection and pollution

**Status: Implemented; Godot 4.7.2 automated checks passed. Interactive visual acceptance remains manual.**

- [x] Reusable typed trash scene with bottle, can, and bag shapes, configurable catch radius/value, and visual-only bobbing.
- [x] Finite seeded initial batch with active-item cap, nonoverlap/shoreline spacing, and casting reachability checked against actual shoreline collision geometry.
- [x] Nearest single-item attachment on landing; misses remain valid fishing cycles.
- [x] Attached trash follows the hook and scores only after successful return; duplicate catches/removals/scoring are guarded.
- [x] Independent pollution model with initial/current pollution, normalized pollution, collected/remaining counts, change/completion signals, and safe empty-batch handling.
- [x] HUD counts/percentage, hook/collection notifications, persistent completion message, and existing control instructions.
- [x] Existing fishing smoke test retained; cleanup smoke test covers deterministic spawning, bounds/spacing/reachability, type coverage, nearest selection, attachment, duplicates, misses, completion, capped/empty batches, and HUD completion.

Automated verification: headless editor import, `tests/fishing_smoke_test.gd`, `tests/cleanup_smoke_test.gd`, a headless main-scene run, and `git diff --check`. See the architecture document for future shader signal bindings.

Manual acceptance:

1. Press F5. Confirm 0/24 collected and 100% pollution (batch expanded in Milestone 4.5). Walk right to the beach boundary; move up/down the shoreline to see the full batch.
2. Identify a mint bottle, orange can, or cream bag. Aim at its center and left-click with a green marker. Confirm the normal arc/line, one attached item after landing, and unchanged counts/pollution while waiting.
3. Click again. Confirm held items follow the hook, then disappear only on return; counts/pollution update once per returned item and a collection notification appears. Milestone 4.5 also collects crossed trash along the return path.
4. Cast into a clear gap. Wait, then retrieve. No item or pollution/count change should occur.
5. Repeat with rapid clicks and movement keys during casting/retrieval. No extra catch/score or movement should occur. Check invalid sand/far/inland targets still reject.
6. Walk along the shoreline and collect all 24. Confirm 24/24 collected, 0% pollution, and the completion message. Wait to confirm no replacements spawn.
7. Resize the window and check aiming/UI legibility. Stop/re-run with F8/F5 to reset the seeded batch. No in-game restart button is implemented yet.

Run the added test with `godot --headless --path . --script res://tests/cleanup_smoke_test.gd` after the editor import command above.

**Exit check:** Retrieving trash removes it once, updates the HUD by the correct amount, and clamps pollution at its valid bounds.

## Milestone 4.5: Gameplay refinement

**Status: Implemented; Godot 4.7.2 smoke tests passed. Interactive feel still requires manual acceptance.**

- [x] Increase the default finite batch/cap from 12 to 24; preserve seeded generation and reachable-water constraints.
- [x] Give each item seeded vertical speed, phase, and direction; smoothly reverse inside reachable limits with no teleporting. Actual catch geometry follows current movement; bobbing remains visual-only.
- [x] Preserve one nearest landing catch and permit multiple retrieval catches using actual previous/current hook segments and the combined hook/item disk radii.
- [x] Attach each item once with readable offsets, stop its drift, and score all held items only on successful return.
- [x] Replace the large overlay with a compact translucent counter/bar, small batch notifications, anchored completion, and H-toggle help.
- [x] Extend cleanup regression assertions for the larger batch and multiple returned values; retain the fishing regression test.
- [x] Add `tests/refinement_smoke_test.gd`: five minutes of seeded drift/bounds/reachability, smooth reversal, swept tunneling prevention, near misses, duplicate sweeps, delayed batch scoring, empty return, completion, H-toggle/repeat, and compact HUD sizing.

Verification: editor/import check, all three smoke tests, runtime startup, and `git diff --check`. Rendered UI screenshots at 960 × 540 and 720 × 480 were inspected for layout and legibility; gameplay timing/feel remains manual.

Manual acceptance:

1. Press F5. Check the small 0/24 and 100% card. After six seconds, the hint reduces to H Help. Press H twice to open/close details; confirm the ocean stays unobstructed by the default HUD.
2. Approach the shoreline and watch trash for 20–30 seconds. Items move gently up/down with visual bobbing; follow one toward its turnaround. It should slow and reverse, remain in water, and remain castable from the beach.
3. Aim at one item and cast. Only one may attach on landing; pollution/counts remain unchanged while waiting.
4. Cast beyond two or more roughly aligned items, then retrieve. The hook should pick up items actually crossed, including on an initially empty cast. Held sprites have distinct offsets; adjacent items outside the hook/item radii remain floating. For a deterministic high-speed arrangement, run the refinement smoke test below.
5. Confirm no score occurs during retrieval. On return, each held item scores once, and the notification shows the returned batch size. Rapid clicks and movement keys must not interrupt the states or create duplicates.
6. Cast/retrieve through a completely clear path; the counts/pollution remain unchanged. Clean the full finite batch and confirm 24/24, 0%, completion, and no respawn.
7. Resize the window, toggle H, and confirm counters, completion, notifications, and aim coordinates remain usable. F8/F5 resets the seed/session.

```sh
godot --headless --path . --script res://tests/refinement_smoke_test.gd
```

Limitations at this milestone include drifting objects passing through one another after initial spawn and sweeps sampling the current item position per segment, suitable for these slow currents. The level uses axis-aligned rectangular water. Ambient fish and landing particles were added in later milestones.

## Milestone 5: Environmental response

**Status: Implemented.** The four baseline smoke tests and the OpenGL render check passed again on Godot 4.7.2 / GL Compatibility before M6 edits. A scripted GPU playthrough on an isolated copy of the M5 revision reached 24/24, exercised three mid-transition retargets, checked resizing and help, and verified a fresh start and the standalone preview. Dirty, intermediate, and clean gameplay captures were reviewed. No blocking baseline regression was found. The Windows desktop-control approval timed out, so the manual F5/F8/F6 editor playthrough remains pending.

- [x] Add a CanvasItem shader with pollution_level, clean/dirty artist palettes, depth gradient, layered smooth value noise, sediment, two slow travelling waves, restrained highlights, and animated shoreline foam.
- [x] Add real procedural seabed geometry beneath a continuously varying transparent surface.
- [x] Bind a dedicated typed water controller to the existing pollution model; smooth visuals over 1.6 seconds while numerical HUD updates remain immediate.
- [x] Keep one private material per instance, initialize/rebind/reset correctly, and stop idle CPU updates while GPU animation continues.
- [x] Preserve beach geometry, collisions, fishing/spawn bounds, player/trash physics, pollution calculations, and compact HUD. Retain the hidden Ocean polygon as the bounds source.
- [x] Add a separate live three-state preview and reproducible full-scene screenshots without changing game state.
- [x] Document all shader equations, explicit draw order, tuning, renderer compatibility, and performance limits in `docs/water-rendering.md`.
- [x] Add headless water-state tests and a real OpenGL render check; retain the previous three smoke tests.

Automated checks: editor/import, fishing/cleanup/refinement/water smoke tests, headless main startup, and `git diff --check`. Real-render checks compile the shader on Intel Iris Xe / OpenGL Compatibility, compare dirty/midway/clean images and actual seabed visibility, confirm animation at both endpoints, and write captures under `.godot/water_captures/`. Screenshots were visually reviewed; cross-device performance still requires profiling.

Manual acceptance:

1. Press F5. At 100% the water should be muted/murky with almost invisible sand/rocks, but moving waves/foam and all trash remain visible.
2. Approach the same shoreline and cast/retrieve. The HUD percentage changes on return immediately; water smoothly approaches the new state over approximately 1.6 seconds, without a jump or change to beach collision.
3. Retrieve another batch during a transition. Confirm the new target is approached continuously, and the line/hook/trash/aim marker remain readable.
4. At roughly halfway, expect subdued turquoise and partially visible seabed. At completion, expect cyan/blue, clearly visible submerged details, and continuing wave motion. Empty casts must not change water pollution.
5. Stop/re-run (F8/F5). Water starts dirty again with fresh counts. Confirm the compact HUD and H-help still behave normally after resizing.
6. Open `scenes/levels/water_preview.tscn`, press F6, and compare all three continuously animated states. Use the separate non-headless render harness for fixed-phase screenshots; see the graphics study document.

```sh
godot --headless --path . --script res://tests/water_smoke_test.gd
godot --path . --script res://tests/water_render_check.gd
```

**Exit check:** Cleanup continuously changes water color/opacity, reveals the real seabed, and preserves ongoing surface animation at 100%, 50%, and 0%, with no gameplay regression.

## Milestone 6: Ambient fish return

**Status: Implemented.** The level-owned `AmbientFish` scene follows the local `WaterVisuals` value after initial synchronization. See [architecture](architecture.md#ambient-fish) for the route and reveal settings.

- [x] Add six bounded, deterministic nearshore swim routes using one silhouette style.
- [x] Fade fish with displayed pollution, with zero at 100%, three at 50%, and six at 0% by default.
- [x] Draw decorative fish at effective Z -8, below beach and fishing feedback. Keep the water-only preview and gameplay accounting intact.
- [x] Verify dirty, intermediate, and clean states, mid-transition retargeting, swim bounds, fresh instances, and initially clean/empty worlds.

Godot 4.7.2 verification passed with no errors or warnings in the final editor import, all five smoke tests, or 120-frame headless main-scene startup. The existing non-headless render check passed with zero failures on Intel Iris Xe / OpenGL 3.3 Compatibility. The full-scene captures show distinct water and fish states while the hook, line, and trash retain contrast. The three-panel capture remains a water and seabed comparison.

An additional local GPU playthrough drove movement and mouse clicks through the game’s input API. It reached 24/24 from the default seed, observed three mid-transition retargets, and confirmed that an empty cast left pollution unchanged and a fresh scene reset to 100%. It verified zero, three, and six active fish silhouettes across the shore at 100%, 54%, and 0% respectively. Captures at 1280 × 720 and 800 × 450 showed readable aim markers, hooks, lines, and trash. Help toggled after the resize. This run used scripted input, so the manual editor playthrough is still pending.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/fish_smoke_test.gd
godot --path . --script res://tests/water_render_check.gd
```

The [README](../README.md#headless-verification) lists the full set of smoke and startup commands.

**Exit check:** During a normal cleanup, fish are hidden at the dirty start, clearly present partway through, and most abundant at completion. Cast targets and floating trash remain readable at default and reduced window sizes.

## Visual polish following M6

**Status: Implemented on feature/dynamic-water in `2589291`, reviewed November 18, 2026.** This adds beach and landing feedback to the playable prototype.

- [x] Add a sand shader with grain, dune variation, and wind marks.
- [x] Add seeded pebble clusters, shells, and wind arcs.
- [x] Add alternating movement-driven footprints with an eight-second fade and an 80-print cap.
- [x] Add pollution-tinted hook-landing droplets and staggered expanding ripples, with lifetime cleanup.

Review on Godot 4.7.2 / Intel Iris Xe / OpenGL Compatibility passed all five existing smoke tests, main-scene startup, and the non-headless water render check. A temporary local harness exercised player movement and rod landing, confirmed footprint creation/expiration, confirmed two rings and one particle emitter on landing, verified their removal after the effect, and checked that landing left pollution unchanged. Gameplay captures were visually reviewed for sand, footprints, and splash/line readability. The editor import completed with a local safe-save permission error, without script or import errors. This verification used scripted gameplay rather than a manual full-session playthrough.

The review found no blocking gameplay regression. The new effects still use hard-coded tuning and map dimensions, and the transient effect nodes redraw while idle. Those limitations are documented in the architecture notes.

## Milestone 7 — Continuous trash and two-source pollution

**Verified November 19, 2026.** The starter rod returns one piece per cast and the meter responds to both returns and live arrivals.

- Replace the finite spawn in [TrashManager](../scripts/systems/trash_manager.gd) with recurring, testable arrivals. Each piece starts offscreen, moves inward into view, then switches at a randomized stop point to the existing gentle drift. Use bands based on castable distances from the actual shoreline collider. Keep recurring starter opportunities and reserve farther stops for later rod tiers. Bound the active population so a buildup offshore cannot shut off starter supply.
- Tune the [starter rod](../scripts/gameplay/fishing_rod.gd) for short range and slower casting and retrieval than upgraded tiers. Apply one shared per-cast trash limit across landing, waiting, and retrieval sweep so the current multi-item behavior can become an upgrade. Keep valid misses, aim feedback, movement lock, and exactly-once removal after a successful return.
- Replace batch-relative scoring in [PollutionSystem](../scripts/systems/pollution_system.gd) with a floating contribution bounded at 0–30 percentage points and a permanent-cleanup contribution bounded at 0–70. Start the permanent contribution at 70 and keep it there in ordinary play until the shop sells cleanup. Use deterministic fixtures to exercise reductions in both contributions. Landed trash leaves the floating calculation on successful return. Exchange at the shack will handle coins in Milestone 8.
- Update the temporary HUD and H-help for live pollution, starter limits, and catch or miss feedback. Remove the finite collected/total indicator and the empty-batch completion rule. Drive per-cast feedback from the catch lifecycle so an arrival mid-cast leaves it intact. Keep numerical pollution immediate and water and ambient fish synchronized through the existing visual easing. Changes in active count that leave pollution unchanged should leave the current transition running.

**Verification**

With a fixed test seed, watch pieces enter from outside the visible shoreline view and switch smoothly to bounded drift at different stops. Catch a near piece and reject a farther cast. Sweep through multiple pieces with the starter rod and confirm exactly one returns. Leave the shore alone long enough to exercise replenishment and the active cap, then confirm starter-range arrivals are still available. Check empty returns, duplicate catch events, component limits, immediate HUD updates, and smooth water retargeting in both directions. After a burst of arrivals, confirm water and ambient fish settle at the latest target. With 70 points of permanent pollution outstanding, clearing floating trash never signals completion.

**Regression checks**

Adapt the cleanup, refinement, water, and ambient-fish smoke tests that assume a 24-piece batch. Keep the fishing lifecycle checks and use explicit 100%, 50%, and 0% fixtures for the ambient-fish reveal and water states. In the [GPU water check](../tests/water_render_check.gd), pause arrivals and fixture trash motion, keep ambient fish visually fixed or hidden during water-only comparisons, and settle or suppress the landing splash. Preserve the palette, seabed visibility, and endpoint animation checks. Keep a separate landed-hook capture for gameplay contrast. Compare true pollution and active and collected trash before and after visual overrides, run live arrivals in a separate check, and open the standalone preview with F6.

**Checkpoint results**

- Six starter pieces begin in water. A piece contributes five points from the instant its center crosses into the authored water rectangle through successful retrieval. The floating total caps at 30 points. The initial permanent contribution is 70. A running session can reach 0% when all permanent projects are complete and there is no trash contributing floating points. M9 verifies that the next arrival lifts the meter from zero.
- The ten-second cadence and four-second ingress are configurable. Eight of twelve slots are reserved for starter trash. Stop bands are 110–205 and 310–545 world pixels from the collider-derived rod origin. The base rod reaches 240 pixels, casts in 1.05 seconds, and retrieves in 0.85 seconds.
- Godot 4.7.2 editor import, 120-frame main startup, all five smoke tests, and `git diff --check` passed. Seeded checks covered repeatable starter catches, fast sweeps, re-entry after clearing a starter slot at cap, one-time collection, immediate HUD updates, both easing directions, and ambient fish following the final target.
- OpenGL 3.3 Compatibility on Intel Iris Xe passed the water comparison, endpoint animation, seabed visibility, and separate landed-hook capture. The standalone preview ran directly for 120 rendered frames. A rendered shoreline harness at 1280 × 720 and 800 × 450 confirmed all six sampled pieces started offscreen and all five with stops in view crossed into view before settling. This verification used scripted gameplay and direct scene launch. The manual editor-key playthrough remains pending.
- Next action is to connect catches to the Sack and tune trash-funded gear at a nearby shack.

## Milestone 8 — Sack, shack, and gear upgrades

**Verified November 19, 2026.** A full starter Sack finances a first rod or Sack upgrade at the fishing shack.

- Add the shared Sack with a low starting capacity and a slight, tunable movement slowdown as it fills. Landed trash uses Sack space. Leave excess items in the water when the Sack or per-cast limit is reached. Give clear feedback on a full Sack, and restore normal speed after unloading. Use the same inventory for fish in Milestone 10.
- Expand the [shoreline map](../scenes/levels/playas_vertical_slice.tscn) slightly for the shack and any cleanup sites that need room. Keep the shack close to starter-range fishing spots. Recheck camera limits, collision shapes, casting and drift bounds, and beach-detail coverage after map edits.
- Add the exchange and upgrade transactions in a basic shop UI. Sell rod upgrades for reach, cast and retrieval speed, and trash per cast, plus Sack capacity upgrades. Keep coins, gear, and inventory in the current session. Display Sack use, coins, and purchased tiers in the temporary interface. Tune initial payouts and prices with trash income alone.

**Verification**

Test with base gear and zero coins. Fill the Sack, observe the slowdown and full feedback, and confirm another cast cannot overflow inventory or remove excess trash. Walk to the shack and exchange the load once for the displayed amount. Earn and buy each upgrade using trash, then verify a previously unreachable target becomes valid, cast and retrieval get faster, a return can carry multiple pieces within free Sack space, and the Sack can hold more. Try unaffordable purchases and repeated shop clicks and check for duplicate credits, duplicate upgrades, or stray casts.

**Checkpoint results**

- The beach extends 100 world pixels west. The shack is on the route from spawn to the shoreline, with a 64 px approach radius. E opens the shop with the rod idle and movement and casting are gated until close. The blocking shack wall leaves the direct beach route open. The sand overlay and detail placement fit the expanded beach.
- The starter Sack holds three items and slows movement by up to 12%. Trash pays four gold each. The first rod and Sack upgrades cost 12 gold each, and the final tiers cost 28 and 24. Rod tiers reach 390 and 600 px, speed up cast and return, and hold two and three trash respectively. Sack tiers hold five and eight items. These values are configurable.
- Followed the architecture review recommendation to inject the Sack into the existing trash manager while there is one catch producer. M10 will centralize selection and the temporary held list so both fish and trash share the same Sack limit and landing priority.
- Godot 4.7.2 editor import, main startup, six smoke tests, and the OpenGL water render check passed. The shop test funds all four gear upgrades through trash, exercises a physical walk to the shack, checks the full-load multiplier, and checks empty sales, unaffordable and repeated purchases, suppressed gameplay input, multiple trash returns, and limited free space. The map harness checked the collider boundaries, camera limits, frontage, prompt, sand coverage, and unchanged water and casting geometry. A rendered frontage check identified prompt overlap from the idle rod text, which is now hidden near the shack.
- Final theme and a first-time player check remain in M11. Next action is to add the permanent cleanup catalog and verify 0% followed by a live rebound.

## Milestone 9 — Permanent cleanup purchases

**Verified November 19, 2026.** Trash income funds the cleanup catalog, and permanent reductions hold through further arrivals.

- Choose a small catalog of projects, their costs, point reductions, and any map space they require. Possible projects include clearing stranded debris, removing submerged debris or abandoned nets, and restoring a tide pool. The catalog should let the player remove all 70 permanent points within the playthrough. Use simple visible state changes or completed-project feedback.
- Set prices and reductions so reasonable starter-gear trips and early upgrade choices can bring total pollution to around 50% with trash income alone. Tune for a realistic floating load, including rebounds. Check that purchases are affordable in a practical order and that recurring starter income remains available.

**Verification**

Use only trash sales to buy the first meaningful upgrades and cleanup and reach the fish threshold. Confirm each project charges coins once, removes its stated permanent points, and stays complete across further arrivals and shop visits. Exercise all projects, verify only the floating component rebounds, and test the agreed 0% behavior in a running session. Confirm a new session restores the permanent contribution and the catalog.

**Checkpoint results**

- Clearing stranded debris costs 12 gold and removes 30 permanent points. Net removal costs 20 gold and removes 20 points. Tide pool restoration costs 24 gold and removes the final 20. Each purchase displays confirmation and remains marked Complete at the shack. This version uses shop feedback for project results.
- A starter-size trip funded the Shore rod, and two affordable cleanup purchases reached 50% even after returning to the full 30-point floating load. The full catalog reduces the permanent contribution to zero. After the last contributing trash is landed, the meter reaches 0%, then rebounds to 5% when the next piece enters the water. This was verified with the live arrival path and actual casts at seeded trash positions.
- Godot 4.7.2 editor import, main startup and seven smoke tests passed. The cleanup projects test covers trash-funded gear and projects, price and point accounting, duplicate and unaffordable purchases, catalog persistence through shop visits and arrivals, zero and rebound, and new-session reset. Rendered shop layout and E/Esc input passed at 1280 × 720 and 800 × 450.
- Next action is to add catchable fish at 50% and below. M11 will apply the chosen visual theme to the shop.

## Milestone 10 — Catchable fish and fish sales

**Verified November 19, 2026.** Catchable visitors appear at 50% true pollution and become more common as the water clears. Fish share the Sack and sale with trash.

- Add catchable fish distinct from the [decorative ambient fish](../scripts/gameplay/ambient_fish.gd). Give catchable fish readable target cues. Drive their spawn chances from true total pollution, with the highest chance at 0%, while ambient silhouettes keep following the eased water visuals. Decide what happens to already-spawned catchable fish if pollution rises above the threshold.
- Start with four or five species and variable sizes. Tune species, size ranges, rarity, spawn chances, and sale prices. Carry landed fish in the Sack with trash and sell them at the shack. Resolve competing targets through the existing cast and return lifecycle and honor available Sack space.

**Verification**

Use seeded trials above, near, and below the threshold and at 0% to check eligibility and increasing spawn chances. Raise pollution through the threshold again while the graphics are still easing. Check catchable fish behavior against the agreed rule and confirm ambient silhouettes cannot be hooked. Land fish and trash into the same Sack, verify a full load rejects extra catches, then sell controlled samples to check that larger fish of the same species and rarer fish of comparable size pay more.

**Checkpoint results**

- `CatchableFishManager` tries every four seconds, with a 24% chance at 50% pollution and 85% at 0%. The capped population swims in reachable nearshore routes with a white split-ring cue. Above 50%, new visits stop. Existing fish can complete their 26-second visit, and a hooked fish can finish retrieval.
- Four configurable species are Topsmelt, Pacific sardine, Barred surfperch, and Kelp bass. The value is one gold plus length in centimeters plus a rarity bonus. The Sack retains species, length, and price in its sale details.
- A single catch resolver chooses the nearest eligible fish or trash on landing and while waiting. Retrieval sweeps still collect trash in path order. The trash allowance is specific to trash, and one reserved Sack limit covers all held catches. The existing ambient silhouettes have no catch area.
- Godot 4.7.2 editor import, main startup, eight smoke tests, and a 120-trial seeded sample at each level passed. At 51%, 50%, 25%, and 0%, the sample produced 0, 27, 65, and 101 visitors. Tests exercise true versus displayed threshold crossings, natural departure and hooked fish staying attached, nearest-target competition, swept trash, mixed and full loads, duplicate handling, and size/rarity sale prices.
- Rendered fish cues remained distinct from ambient silhouettes and trash at 960 × 540 and 800 × 450 on Intel Iris Xe / OpenGL Compatibility.
- Next action is the M11 theme decision and new-session flow. M12 covers full playthroughs from the menu through a fish sale and replay.

## Milestone 11 — Start menu, onboarding, and interface

**Verified November 19, 2026.** The menu starts and replaces sessions. The HUD and shack shop share the Coastal field guide theme chosen by the user.

- Consult the user at the start of this milestone before choosing the visual direction. The theme is open. Apply the agreed theme across the start menu, in-game HUD, and shop. Show pollution, Sack capacity, coins, current gear tiers, upgrade effects and prices, and cleanup purchase status where players need them.
- Bring forward concise shoreline, cast, retrieve, and miss cues from the earlier onboarding plan. Add turn-in and upgrade guidance and retain access to detailed controls.
- Provide a labeled way to start a fresh session independent of temporary pollution levels. Let the game entry point own session creation and reset. Handle menu and shop clicks before fishing input and guard against repeated start or restart activation.

**Verification**

Ask a first-time player to start, make a catch, exchange a load, and buy an upgrade using the on-screen cues. Resize the window and check labels, focus, and aim accuracy. Click and close shop and menu controls without casting or retrieving, then resume fishing. Start two fresh sessions and verify the spawn, gear, Sack, coins, projects, arrivals, pollution, and visuals reset each time.

**Checkpoint results**

- The user chose Coastal field guide with sand and shed browns. The shared theme uses sand paper, brown borders and focus outlines, ocean ink, and teal actions. The menu illustration uses the same palette and the shack as its landmark.
- The HUD cues movement, aiming, retrieval, first turn-in, affordability, and fish recovery. Full or partial loads give a clear next action. Detailed controls open with H or the Help button. Esc closes an open shop before it can open the session menu. Start fresh rebuilds the world, inventory, wallet, gear, projects, seed, and visuals.
- Godot 4.7.2 passed editor import, 120-frame startup, nine smoke tests, and the OpenGL water render check. Actual viewport clicks drove start, an empty return, catches, sales, first gear and cleanup purchases, pause and resume with a waiting hook, and two resets. Resized aim reached the selected world point. Layout and focus checks passed at 1280 × 720 and 800 × 450.
- An independent first look used the desktop UI to start and review the cues. Desktop input offered key taps without sustained movement, so the end-to-end onboarding route was verified with scripted Godot inputs. That review led to a clickable Help control and a prompt that explains the first upgrade's remaining gold cost.
- Next action is the two end-to-end playthroughs, cleanup rebound verification, preview, and documentation review.

## Milestone 12 — Playtest and stabilize the slice

**Verified November 19, 2026.** Two fresh sessions made a fish sale, permanently funded all projects, reached 0% displayed pollution, and took the next live rebound.

- Play through two fresh sessions from the start menu to a fish sale, including trash-funded upgrades and cleanup, a pollution rebound, and the agreed clean-water check. Observe whether a new player can find the shack and learn what to do next. Check travel time, early affordability, Sack slowdown, full inventory, rapid inputs, range edges, and small-window legibility.
- Run Godot editor import, main-scene startup, the updated smoke tests, the standalone water preview, and the real-render water check. Record the Godot version, renderer, skipped checks, and known limitations. Check that the README controls and architecture notes match the integrated scenes and systems. Keep generated captures and editor data out of Git.

**Verification**

Both sessions reach a fish sale through normal play. The replay flow resets session state, water and ambient fish respond correctly to live changes, and the independent preview still shows animated dirty, intermediate, and clean states. Check the debugger for parser, resource, and orphan-node errors.

**Checkpoint results**

- The test started at the shipped menu, walked actual routes, cast by viewport input, and used the shop's sale and purchase buttons. Two sessions ran at 1280 × 720 and 800 × 450. Replay used Start fresh and restored the original state. The first full-load trip to the shack took 1.65 seconds of game time. The first gear purchase was at 15.7 seconds. Both sessions funded the Shore rod, Canvas Sack, and first two cleanup projects by selling trash, then made the first fish sale for 29 gold at 143.3 seconds.
- After the Offshore rod and last project, both sessions reached a fully displayed 0% at 164.6 seconds. All six ambient fish were visible, and the next trash arrival took the meter to 5%. The permanent contribution stayed at zero and the graphics settled to the new target. The test also checked Sack slowdown, full inventory, repeat sale and casting clicks, range edges, mouse aim, and orphan counts after replay.
- Menu and Help now sit beside the HUD readouts on the beach side to leave the far water clear for casting. The README documents the menu, shop, controls, fish visits, and verification commands. The standalone preview footer documents returning through the game menu.
- Godot 4.7.2.stable.official.ed1daf0bf passed editor import, main startup, ten smoke tests, and both complete runs with and without GPU rendering. OpenGL 3.3 Compatibility on Intel Iris Xe passed the water render check, including seabed visibility and animation. The standalone preview ran for 120 GPU frames. All three preview panes also showed measurable animation across two captures with true shader time. The release checks reported no parser, resource, or orphan-node errors. Generated captures and logs are ignored.
- The desktop first-look review covered the menu and visual cues. Full playthroughs used scripted game inputs. An independent human onboarding playthrough and cross-device graphics checks remain pending. Runtime progress is session-only. The shoreline is rectangular, and drifting items use bounded paths without object-to-object collision.

## Milestone 13 — Trash drift and progression pacing

**Verified November 20, 2026.** Floating trash moves inward more gradually, and three full starter Sack trips fund the first upgrade.

- Increase the ingress duration and separately tune arrival cadence, starting load, and active population if needed. Compare with M7's four-second ingress and ten-second cadence. Retain randomized stopping points, the gentle settled drift, and recurring starter-range catches even at the active cap.
- Rebalance trash payouts, fish payouts, gear prices, and cleanup prices together. The M12 scripted run bought its first upgrade at 15.7 seconds, sold its first fish at 143.3 seconds, and reached a displayed 0% at 164.6 seconds. Use those as the comparison baseline. Aim for several starter Sack trips before the first upgrade and meaningful choices between gear and cleanup. Preserve steady opportunities to fish while earning those purchases.
- Preserve the 30/70 pollution split, a trash-funded route to the fish threshold, and the 0% state followed by a live rebound. Keep tuning values configurable.

**Verification**

Compare seeded runs on the same route and record ingress duration, time between starter-range catch opportunities, trips and time to first upgrade, time to 50%, time to first fish sale, and time to full cleanup. Verify slower ingress on screen, a viable trash-only income path, and that fish sales leave room for continued progression. Recheck the live 0% rebound and starter access at cap.

**Checkpoint results**

| Same seeded input route | M12 (`0ee166b`) | M13 |
| --- | ---: | ---: |
| Offshore ingress / arrival cadence | 4 / 10 s | 9 / 8 s |
| New starter-range opportunities, mean / longest gap | 14.5 / 20.1 s | 10.6 / 24.8 s |
| First upgrade | 1 trip, 15.7 s | 3 trips, 46.1 s |
| First true 50% threshold crossing | 60.5 s | 273.5 s |
| First fish sale | 143.3 s, 29 gold | 282.7 s, 10 gold |
| Full permanent cleanup and displayed 0% | 164.6 s | 449.3 s |

- Both window sizes reproduced the same checkpoints. The first full-load walk remained 1.65 seconds. Six initial pieces and eight reserved nearshore slots preserve both the 100% start and starter access at the 12-item cap.
- Trash sells for 3 gold. The first rod, Sack, and cleanup choices cost 24, 21, and 24 gold. Later rods, Sacks, and projects leave room for progression after a fish sale. Fish prices add 0.75 gold per centimeter, rounded, and a species rarity bonus to the base value. The trash-only fixture funded all projects and the offshore rod. Both live runs restored all six ambient fish at 0%, then rebounded to 5%.
- Godot 4.7.2 passed editor import, main startup, and ten smoke tests. Intel Iris Xe / OpenGL Compatibility verified seeded trash crossing into the camera while still drifting inward at 1280 × 720 and 800 × 450. Independent pacing feedback remains pending. M14 adds the distinct catch visuals and timing challenge.

## Milestone 14 — Distinct fish, visible rod upgrades, and catch timing

**Verified November 20, 2026.** Four original fish sprites, three equipped rod designs, and a circular timing challenge are in the game.

- Give the existing four catchable species distinctive body shapes, fins, or markings. Make them readable at gameplay scale and reuse the same visuals for inventory cards. Use original, generated, or freely licensed assets with any required attribution. Keep size variation, rarity, and catch-target cues.
- Give every rod tier a recognizable in-hand appearance. Start with a visibly basic rod and progressively improve its build and finish. Switch the artwork when the upgrade is applied and preserve alignment of the grip, rod tip, line, and cast origin.
- Trigger a circular timing challenge after a catchable fish latches. Show a moving marker and a green success zone against red miss zones, with a shape or position cue for readability. A timed press in the success zone allows retrieval. A miss or timeout releases the fish and returns the player to a usable fishing state. Keep the timing window configurable, give the player a short first-use cue, and keep trash catches on their existing flow.

**Verification**

Identify the four fish in motion at gameplay scale and compare every rod tier equipped and casting. Exercise early, successful, late, repeated, and absent timing input. A successful catch lands once if there is Sack space. A miss or timeout adds no item or coins and leaves the next cast usable. Check trash-only casts, mixed targets, a full Sack, and opening or closing the pause menu during the challenge.

**Checkpoint results**

- The topsmelt is slim and striped, the sardine is silver-blue with a forked tail, the surfperch is deep-bodied and barred, and the bass is spiny and mottled. The Sack retains each fish's sprite for the M15 trader. The cane, reinforced shore, and offshore rod textures share the same grip and tip alignment. Upgrades switch the art as the new cast settings apply.
- A latched fish starts a 1.8-second dial with a configurable 22% success arc. Click or press Space in the marked arc, then click to reel in. Early, late, or absent input releases the fish and clears the line. Pausing freezes the dial and resuming restores it. Trash and full-Sack casts retain their prior input flow.
- Godot 4.7.2 passed editor import, focused catch, fishing, refinement, shop, and session tests, and two full input playthroughs. The timing-aware route sold its first fish at 283.9 seconds and reached displayed 0% at 449.5 seconds at both sizes, with a live rebound to 5%. Intel Iris Xe / OpenGL rendered all four fish in motion and the three rod tiers, and captures at 1280 × 720 and 800 × 450 showed the white catch rings and the dial's marked success boundaries.
- Next action is the dedicated trader and persistent in-session coin display.

## Milestone 15 — Screen-based shack trader and coin display

**Verified November 20, 2026.** The shack opens a full-screen trader with separate Sell and Buy pages and a shared coin balance.

- Show the shack trader on a dedicated screen with Sell, Buy, and an exit back to the shoreline. The trader interaction is screen-based. Route focus, pointer, and cancel input through the trader while it is open.
- On the Sell screen, show everything currently carried in the Sack, with item visuals and values. Let players drag items from the inventory side to a sale tray on the other side and drag them back to undo the selection. Show the pending total and confirm the sale explicitly. Confirmed sales remove only selected items and award their value once. Provide an accessible click or keyboard equivalent for selecting and removing items.
- Open a separate Buy screen with visual cards for rod tiers, Sack upgrades, and cleanup projects. Show the item or project art, effect, price, and availability. Use the rod tier artwork from M14 and the tuned prices from M13.
- Add a gold coin icon and a consistent top-left balance that remains visible across gameplay and all in-session menu and trader screens. Update it immediately after confirmed sales and purchases, including at small window sizes.

**Verification**

Enter the trader from shore, switch screens, and leave without triggering a cast. Select a mixed sale, undo an item, confirm, and verify that the unsold items remain and the top-left total is correct. Check cancel, invalid drops, repeated confirmation, unaffordable and already purchased items, and mouse and keyboard navigation at default and reduced window sizes.

**Checkpoint results**

- Sell shows individual fish and trash with their art and gold values. Drag either way or select a card with the mouse or keyboard. Confirming credits only the selected entries. Canceling discards the selection, and duplicate, stale, or repeated confirmations leave the Sack and balance alone.
- Buy shows visual rod, Sack, and project cards with effects, prices, and purchase availability. The single top-left coin display stays visible at the shore, in each trader page, and in the pause menu.
- Godot 4.7.2 passed import, focused regressions, and two live input playthroughs. The new trader smoke test passed headless and on Intel Iris Xe / OpenGL at 1280 × 720 and 800 × 450. It dragged between both columns, used keyboard selection, canceled a pending sale, sold a fish and one of two identical cans, and verified the remaining can, balance, locked and owned rod controls, and input isolation. The full route recorded its first fish sale at 284.1 seconds and displayed 0% at 447.7 seconds.
- Next action is M16's visible project staging and session-long completed sites.

## Milestone 16 — Visible permanent cleanup work

**Verified November 20, 2026.** All three cleanup purchases stage visible work and leave lasting changes to their sites.

- Give each permanent project a simple staged action suited to its site. For example, a shore crew can gather debris, a skiff and crew can lift a net, or workers can clear a tide pool and leave a visible improvement. Keep staging brief and show the player where to look when returning from the trader.
- Keep the project transaction and its 70-point contribution in the existing cleanup model. Stage the presentation from a successful purchase, then show a completed state that lasts for the session. Keep the sequence safe across menu transitions, repeated input, and a new session.

**Verification**

Buy each project through the trader, observe the crew or equipment arrive and do the work, and confirm the visible result and pollution reduction. Reopen the trader, check that the project is complete, and verify that revisiting the site or reopening the menu does not replay the work or charge again. Confirm replay restores the initial sites, project states, and pollution.

**Checkpoint results**

- A beach crew gathers stranded debris north of the shack, an offshore skiff lifts the abandoned net and leaves a small buoy, and the south crew clears silt and litter from the tide pool. Each work sequence lasts 3.4–3.6 seconds by default, with a shoreline cue telling the player where to look.
- A successful purchase immediately reduces permanent pollution and queues its presentation. The crew starts when the player returns to shore. Multiple projects play in purchase order. Reopening the trader or pausing freezes an active crew, and starting fresh restores all sites. The 70-point contribution and completed flags stay in the existing models.
- Godot 4.7.2 passed editor import, main startup, cleanup, session, trader, and water tests. The tests checked every purchase, queue ordering, one-time charges, pause and trader transitions, persistence within the session, and replay. The full route passed at both window sizes. Intel Iris Xe / OpenGL captures from the shack showed each crew in action and the before and after sites at 1280 × 720 and 800 × 450.
- Next action is M17's animated menu and inactive Save and Load buttons.

## Milestone 17 — Animated start menu

**Verified November 20, 2026.** The title and pause menus share an animated Coastal field guide shore illustration and responsive controls.

- Build on the chosen Coastal field guide direction with a lively shoreline or shack illustration, subtle looping motion, and satisfying hover, focus, and click feedback. Keep motion and sound subordinate to legible options.
- Present a clear, working New Game action and preserve the appropriate resume or restart controls during a session. Include clearly inactive Save and Load placeholders for future work. Defer save slots, persistence, and all Save and Load behavior.

**Verification**

Open the menu at startup and during play. Check that animated elements loop cleanly, feedback responds to mouse and keyboard activation, repeated New Game clicks create one session, and Save and Load placeholders leave the session and files untouched. Verify focus, labels, and legibility at both window sizes.

**Checkpoint results**

- Surf, water glints, a fish, and the shack pennant move on a subtle 12-second loop. The scene stops updating when dismissed. The active button has distinct hover, focus, and pressed states. The title opens with New Game focused, and pause retains Resume session and Start fresh.
- Save and Load are disabled, labeled Coming later, and skipped by keyboard focus. Their clicks have no effect on startup or session state. The existing launch guard still accepts repeated New Game or Start fresh activation only once.
- Godot 4.7.2 passed editor import, startup, and the session, trader, and cleanup smoke tests. Render checks at 1280 × 720 and 800 × 450 on Intel Iris Xe / OpenGL verified animation, a seamless loop, hover and hold feedback, and keyboard resume. The title, pause, and both placeholders fit at both sizes.
- Next action is the integrated M18 playtest and graphics verification.

## Milestone 18 — Follow-up playtest and stabilization

**Verified November 20, 2026.** The integrated build passed the scripted route from New Game through a timed fish sale, visible rod upgrades, permanent cleanup, and replay.

- Play from New Game through the first upgrade, first fish sale, and full permanent cleanup. Record the M13 pacing checkpoints against the M12 baseline, exercise the new trader and timing challenge, confirm the live pollution rebound, and check a fresh-session reset.
- Run the relevant Godot import, startup, smoke, and GPU rendering checks. Verify the standalone graphics preview and the new visuals at default and reduced sizes. Seek an independent human onboarding playthrough and record the result or any pending manual or cross-device checks. Update the README and architecture notes where behavior or scene ownership changed.

**Checkpoint results**

The seeded route starts the clock when the session opens. The M18 headless and rendered runs each used 1280 × 720 and 800 × 450 and reproduced the same checkpoints.

| Checkpoint | M12 (`0ee166b`) | M13 | M18 |
| --- | ---: | ---: | ---: |
| Offshore ingress / arrival cadence | 4 / 10 s | 9 / 8 s | 9 / 8 s |
| New starter-range opportunities, mean / longest gap | 14.5 / 20.1 s | 10.6 / 24.8 s | 11.2 / 24.8 s |
| First full-Sack walk to the shack | 1.65 s | 1.65 s | 1.65 s |
| First gear upgrade | 1 trip, 15.7 s | 3 trips, 46.1 s | 3 trips, 46.0 s |
| First true 50% threshold crossing | 60.5 s | 273.5 s | 273.3 s |
| First fish sale | 143.3 s, 29 gold | 282.7 s, 10 gold | 284.1 s, 10 gold |
| All projects funded and displayed pollution at 0% | 164.6 s | 449.3 s | 447.7 s |

- Each session drove movement and viewport input from New Game or Start fresh through the first equipped rod upgrade, trash-funded threshold, timed fish, confirmed trader sales, and all three cleanup projects. The runs verified the updated coin balance, saw six ambient fish at displayed 0%, and observed the next floating arrival rebound to 5%. Completed work stayed visible and Start fresh restored the original gear, Sack, balance, sites, and pollution.
- The player could pause during fish timing and resume the same challenge. Focused tests also exercised a partial mixed sale with separate identical catches, invalid drops, a full Sack, repeated input, cap access, and cleanup queueing. A separate keyboard check scrolled to the eighth Cargo Sack entry and selected it at 800 × 450.
- Godot 4.7.2.stable.official.ed1daf0bf passed editor import, 120-frame main startup, and all 11 smoke tests. The full route also passed with Intel Iris Xe / OpenGL 3.3 Compatibility. The checks reported no parser, resource, or orphan-node errors. The standalone water preview ran for 120 rendered frames, and its 100%, 50%, and 0% panes changed across true shader-time captures. The water render check passed, including progressive seabed visibility. The title, trader, fish dial, rod tiers, and cleanup stages were visually reviewed at both window sizes during their milestone checks.
- An independent first-time human playthrough remains pending, including discovery of menu, fishing, trader, and timing cues and whether the three starter trips feel productive. Cross-device graphics and performance checks also remain pending. Save and Load are visibly inactive, and session progress is in memory.

## Milestone 19 — Slower trash drift and rod range

**Verified November 20, 2026.** New trash takes longer to drift inward than in M18 and keeps moving until it reaches the horizontal casting boundary of the currently equipped rod.

- Slow visible inward motion compared with M18's nine-second ingress. Tune travel speed and arrival cadence separately so the crossing looks slower while starter gear still has a steady supply to catch.
- Use the actual shoreline casting position and the equipped rod's maximum range to place or adjust the inward stopping band. Keep an approaching piece moving until it reaches the horizontal reach boundary, then let it settle at a randomized, valid stop at or inside that boundary. If the player buys a rod while trash is in transit, apply the new range to ongoing arrivals without jumping positions or reversing into deeper water. Keep settled pieces on their current gentle drift.
- Keep spawning offscreen, honor water bounds and shoreline clearance, and keep arrivals and settled trash within the population cap. Preserve the 30-point floating contribution and its live rebound.

**Verification**

Compare seeded captures with M18 at default and reduced window sizes. Check offscreen entry, visible speed, and the first reachable position for each rod tier. Upgrade mid-arrival and verify the path remains smooth. Exercise the cap with in-transit and settled pieces and record the new gap between starter-range catch opportunities.

- Intel Iris Xe / OpenGL Compatibility captures at 1280 × 720 and 800 × 450 matched offscreen entry and landing in the nearshore band. The same visible world segment (X 1360–1100) took 2.42 seconds in M18 and 5.92 seconds in M19. The seeded starter arrival took 15.62 seconds from spawn to settle versus 9.00 seconds in M18. Inward speed is 44 px/s and the independent spawn cadence remains eight seconds.
- First reachable X was 1048.85, 1198.43, and 1408.88 for Starter, Shore, and Offshore, respectively, within one physics step of each rod's measured shoreline boundary. Two purchases during ingress changed the stopping band without moving the piece on the purchase frame or reversing its path. Settled trash retained vertical drift. The twelve-slot cap held across mixed and settled populations, and floating pollution remained capped at 30 points.
- The two-size seeded headless route took three trips and 47.4 seconds for the first rod. Its fixed starter-range sample measured average and longest gaps of 8.0 seconds across four arrivals before the rod upgrade shifted new stops outward (M18 measured 11.2 and 24.8 seconds across 31 arrivals). The route reached the fish threshold at 166.8 seconds, sold the first fish at 253.6 seconds for 12 gold, and reached displayed 0% at 482.1 seconds before rebounding to 5%.
- Editor import, 120-frame startup, refinement, shop, cleanup project, session flow, and the complete seeded route passed on Godot 4.7.2. Human pacing and cross-device visibility remain for M25. Next is M20 timing and optional rod add-ons.

## Milestone 20 — Harder fish timing and optional rod add-ons

**Verified November 20, 2026.** Landing fish takes more precise timing, and players can buy optional upgrades for the rod they use.

- Tighten the existing 1.8-second dial with a faster sweep and a smaller readable success window. Start with one faster success check for common fish and two successive checks for rarer fish. Tune the difficulty against normal mouse and Space input. Keep pause and retry behavior clear.
- Add a small add-on selection to the trader with purchases scoped to a specific rod. Start with a safeguard that forgives one missed timing input per hooked fish and a modest cast or retrieval speed boost. Display each effect, price, and ownership by rod. Buying a new rod leaves its add-on slots empty so the player can purchase the add-ons separately for that rod.
- Keep the full fish and cleanup progression reachable with stock rods. Treat add-ons as optional benefits and preserve Sack limits, fish escape, and trash catch flow.

**Verification**

Compare the timing challenge with M18. Check success, a second-stage miss, timeout, pause and resume, and recovery on the next cast. Buy the same add-on for two rods independently and check its effect only when the purchased rod is equipped. Verify duplicate purchases are rejected and complete the fish catch path with no add-ons.

- The sweep takes 1.30 seconds with a 221 ms success window. M18 allowed a 1.80-second sweep and a 396 ms window. Topsmelt and sardines use one check. Surfperch and kelp bass use two. The dial identifies the current check and cues retrieval after success.
- Slip guard costs 12 gold and retries one missed input per fish. A timeout still releases the catch. Quick spool costs 15 gold and shortens cast and reel durations by 15%. Both effects and prices are configurable. Ownership is per rod, and the next rod starts with empty slots.
- The fish smoke test passed stock two-stage success, a second-stage mouse miss, early and late misses, timeout, recovery, keyboard repeat rejection, duplicate purchase rejection, and both effects on two rods. The headless stock route passed pause/resume, fish sale at 253.4 seconds, cleanup, and reset at 1280 × 720 and 800 × 450. The rendered trader smoke test passed actual purchase input, pricing, and ownership at both sizes on Intel Iris Xe / OpenGL Compatibility. Editor import registered the new resource and reported a local settings safe-save error.
- Human timing feel and discovery carry forward to M25. Next is the expanded cleanup catalog in M21.

## Milestone 21 — More permanent cleanup projects

**Verified November 20, 2026.** The player restores the coast through more purchases, each with a smaller effect and its own visible result.

- Add two or three additional purchasable instances of each existing project type, covering stranded debris, abandoned nets, and tide pool restoration. Give each instance a distinct site or work area, purchase state, and visible before-and-after result. Reuse the existing crew and equipment staging where it fits.
- Add a small number of new cleanup types. Possible projects include clearing a blocked shore drain or skimming trapped surface debris. Choose projects that fit the compact shoreline and have a short, readable work sequence.
- Rebalance individual reductions and prices so the catalog still removes exactly 70 permanent points in total. Keep a practical path to 50% with trash income and a complete path to 0%. Make repeat projects individual purchases with their own status and one-time charge.

**Verification**

Buy two instances of the same project type and confirm that they charge and complete separately and stage work at the correct sites. Fund the fish threshold using only trash sales, then buy the full catalog and verify the exact permanent total, visible completed sites, live floating-trash rebound, and reset on New Game.

- The 90-gold catalog contains three debris removals, three net removals, three tide pool restorations, a blocked drain, and a surface skim. Each project has a location, a unique site ID, and separate funding and work state. The first seven cost 54 gold and bring permanent pollution down to 20 points, which keeps fish eligible at the full 30-point floating load. All eleven bring permanent pollution to zero.
- Cleanup fixtures funded the threshold and full catalog from trash, bought two debris projects in one visit, and verified distinct crews and completions, duplicate rejection, trader suspension, exact debits and reductions, rebound, and reset. The seeded two-size route recorded a first fish sale at 252.6 seconds and displayed 0% at 449.7 seconds before the next arrival restored 5%.
- Godot 4.7.2 imported the icons and passed cleanup, trader, session flow, and the complete seeded route. OpenGL captures at both sizes showed the drain and skimming projects before, during, and after work. The editor again reported a local settings write error. First-time discovery and cross-device review remain for M25. Next is M22 pause, Sell All, and help visibility.

## Milestone 22 — Pause controls, Sell All, and help visibility

**Verified November 20, 2026.** Esc opens a compact in-game pause menu, selling a full Sack takes one action, and contextual hint text appears when Help is active.

- Bind Esc to pause and resume during play. Route Esc to the active trader page or overlay first so one keypress performs one action. Retain the on-screen Menu button. Use a compact pause layout over the current session with Resume, the existing restart option, an inactive Save entry, and a clearly labeled way to quit to title. Confirm actions that discard the current session. Keep the pause screen visually distinct from the title screen.
- Add a clearly labeled **Sell All (F)** control on the Sell screen. The button and a single fresh F press sell the full Sack in one transaction, including any staged items. Keep partial drag-and-drop sales available. Disable the action for an empty Sack and ignore key repeat and F outside the Sell screen.
- Hide bottom-left instructional and status text and the text above the player by default. Show those text layers only while H or the Help button has enabled help. Preserve essential state through the regular HUD, shop controls, and the fish timing dial.

**Verification**

Check Esc from shore, an active fishing challenge, and each trader page. Verify pause freezes play and resumes the same state. Test Sell All by button and F with staged, unstaged, and identical items. Confirm the correct credit once and no sale outside the Sell page. Toggle H on and off and verify both text layers follow it while the permanent HUD remains legible.

- Esc cancels an active drag first, backs out of Sell or Buy, closes the trader home, and opens pause from play. Pause has Resume, Start fresh, inactive Save, and Quit to title. Restart and quit require confirmation, and Esc dismisses confirmation without closing pause. Both Help text layers default to hidden. The fish dial retains timing and outcome cues with Help off.
- Godot 4.7.2 passed the OpenGL trader and session flow checks, focused shop and fish regression checks, and the two-size headless playthrough. Checks covered staged and unstaged duplicates in one sale, button and F charges, empty sales, repeat and out-of-page input, keyboard focus, pause during fishing and cleanup, confirmation, and clean New Game after quitting. The editor import reported only the local settings write error.
- Human onboarding and typography review carry forward. Next is M23 title art and type.

## Milestone 23 — Title screen and UI typography

**Verified November 20, 2026.** The title has a large game name over full-screen animated art of the Playas setting, with clear game menu actions.

- Keep and expand the existing coastal artwork and animation into a full-bleed background. Use the broad title-over-setting composition suggested by Poly Bridge as inspiration for an original EcoFishing layout. Give the game name visual prominence and arrange the controls where the art leaves room for legible text. Keep New Game working and keep the existing future Save and Load controls inactive.
- Review fonts across the title, pause menu, HUD, shop, inventory, and help. Pick a distinctive display face where it fits and readable text and numeric faces for functional UI. Use assets with suitable permissions, include required attribution, and ask the user if access or a download is needed. Continue typography and layout work that can proceed with existing assets while waiting.

**Verification**

Check the title and pause menu side by side at default and reduced window sizes. Verify the title reads clearly over moving artwork, focus remains visible, button labels and prices fit, and instructions and inventory values are legible at gameplay scale. Recheck New Game and the inactive Save and Load controls.

- The title expands the original coastline into a full-screen composition with dark water behind the game name and animated foam, schools of fish, and a flag by the shack. Pause keeps the compact panel over the running shoreline. Bricolage Grotesque sets display headings. Atkinson Hyperlegible Next handles controls, prices, counts, and help. Both font licenses and sources are in [asset credits](asset-credits.md).
- OpenGL captures at 1280 × 720 and 800 × 450 showed the title at two animation phases and the pause, Help, Sell, and Buy screens. The title focus ring and inactive controls remained visible. The reduced capture fit the inventory names, prices, and Sell All value. The Godot session flow, trader, and HUD refinement checks passed, including New Game and inactive Save and Load.
- Cross-device typography and first-time discovery remain for M25. Next is continuous music and action sound in M24.

## Milestone 24 — Continuous music and action sound effects

**Verified November 20, 2026.** One background track loops throughout the game and actions have distinct sound feedback.

- Use the user-provided `geoffharvey-tropical-coconut-island-367671.mp3` from Downloads. Keep one playback owner across title, gameplay, pause, trader, and fresh-session transitions so the music loops without restarting or doubling as screens change. Leave room for additional tracks later.
- Add short, distinct effects for gameplay and UI actions. Cover footsteps, cast, splash, reel, catch, miss, timing success and failure, menu navigation, confirm and cancel, inventory pickup and drop, sales, purchases, and cleanup work. Trigger effects on the corresponding action or transaction outcome. Balance effects against the music and manage repeated sounds such as footsteps.
- Record asset sources and attribution as applicable. Use existing or freely licensed sound where suitable. Ask the user if an asset requires access or a download.

**Verification**

Listen through a full loop and switch between title, gameplay, pause, trader, and New Game. Check that exactly one music stream continues and that the restart point sounds clean. Play the fishing, shop, and cleanup paths and verify that sounds match their outcomes and stay distinguishable during rapid input. Record any listening checks that need a human ear.

- The root audio scene owns one playlist-backed music player and a separate eight-voice effects player. The imported MP3 matches the supplied file. The 117.39-second track completed a natural wrap on WASAPI at original speed. The mixer recorded a quiet ending and music resumed after the wrap without a playback restart from scene logic.
- The audio smoke test passed with Dummy and WASAPI drivers. It tracked the same music playback through title, gameplay, pause, trader, restart, quit to title, and New Game. It verified distinct cues for fishing outcomes, successful sales and purchases, the cleanup crew, and menu and inventory actions. The rendered route measured a 0.576 linear master peak, below clipping. Footfalls alternate pitch, and rapid focus and miss sounds are rate-limited.
- Godot imported the assets without errors using a portable editor. Music and effects sources are in [asset credits](asset-credits.md). A human listening pass remains for the track seam and the balance and clarity of overlapping cues. Next is the M25 integrated comparison.

## Milestone 25 — Integrated playtest and stabilization

**Verified November 20, 2026.** A new session demonstrates slower arrivals, the expanded economy, the harder fish challenge, the revised screens, and continuous audio.

- Run a seeded playthrough from New Game through the first rod purchase, a timed fish catch without add-ons, a Sell All transaction, and full cleanup. Test an optional add-on on two different rods. Compare arrival speed and progression timings with M18, verify 0% and the live rebound, and confirm session reset.
- Run Godot import, main-scene startup, relevant smoke tests, and the graphics preview and GPU checks. Verify the UI at default and reduced window sizes. Record automated results, listening and visual checks, and any pending first-time-player or cross-device checks. Update the README and architecture notes for changed controls and scene ownership.

**Comparison with M18**

Each game clock starts when New Game or Start fresh opens the session. The main route reproduced the same checkpoints at 1280 × 720 and 800 × 450, headless and with Intel Iris Xe / OpenGL 3.3 Compatibility.

| Checkpoint | M18 (`97b5709`) | M25 |
| --- | ---: | ---: |
| Seeded trash crossing of world X 1360–1100 | 2.42 s | 5.92 s |
| Seeded Starter arrival from spawn to settle | 9.00 s | 15.62 s |
| Arrival cadence while a slot is available | 8.0 s | 8.0 s |
| New opportunities in the Starter's original range, mean / longest gap | 11.2 / 24.8 s (31 arrivals) | 8.0 / 8.0 s (4 arrivals) |
| First full-Sack walk to the shack | 1.65 s | 1.65 s |
| First rod purchase | 46.0 s, 3 trips | 47.2 s, 3 trips |
| First true 50% threshold crossing | 273.3 s | 166.6 s |
| First fish sale with stock gear | 284.1 s, 10 gold | 252.5 s, 13 gold |
| Full catalog funded and displayed pollution at 0% | 447.7 s | 482.1 s on a stock route, 546.0 s with two optional purchases |

The range sample uses the Starter rod's original boundary throughout. In M25, equipping the Shore rod moves incoming stops outward, so the four measured opportunities came before the first upgrade. Seven trash-funded projects secured the stable fish threshold at 249.0 seconds even with a full floating load. The main test alternated selling by F and button, secured a timed fish before fitting any add-on, and bought Quick spool separately for the Shore and Offshore rods. Those optional purchases added 30 gold to the route. The stock comparison followed the same final route with those purchases skipped.

Both routes left all eleven sites complete and showed six ambient fish at 0% before the next floating arrival restored 5%. Restart and New Game after Quit to title restored the starting catch, gear, balance, add-on ownership, cleanup, and pollution state.

**Verification**

- Godot 4.7.2 passed a fresh editor import, 120-frame main startup, and all twelve smoke tests. The integrated route passed again with rendering enabled. A native window close now stops audio before quitting. The startup check follows that path. Godot's forced `--quit-after` can still report audio references at process exit. [Godot issue #76745](https://github.com/godotengine/godot/issues/76745)
- The standalone water preview ran for 120 rendered frames. All three panes changed across captures using live shader time, and the water render check confirmed progressive seabed visibility. Captures at 1280 × 720 and 800 × 450 covered the moving title, pause, Help, Sell and Buy, and second-stage and secured fish cues.
- The supplied track wrapped naturally after 117.39 seconds on WASAPI. Transition checks tracked one uninterrupted playback instance. Fixture actions produced the expected effects and the recorded master peak stayed below clipping.

**Outstanding manual checks**

- Run an independent first-time playthrough to assess discovery of Help, the trader, and two-stage fishing, and how the first three trips feel.
- Listen through the full music transition and overlapping gameplay and interface sounds to judge the seam, clarity, and balance by ear.
- Check graphics, frame pacing, UI legibility, and audio on another device.

## Milestone 26 — Fish motion and timing feel

**Playable checkpoint verified November 21, 2026.** Catchable fish swim faster. Common fish have one check, and rare fish have two, with a counter that changes color as the player advances.

- Increase the travel speed or route variation of catchable fish so they visibly swim farther over the same time. Keep their target cue and catch area aligned to the moving fish. Preserve reachable routes, water bounds, and the current pollution threshold.
- Shorten the dial sweep slightly from the M25 baseline of 1.30 seconds. Vary the green success zone across a noticeably wider spread of positions between fish and between checks. Keep the zone steady during each check, preserve enough reaction time for the earliest position, and keep the whole window inside the sweep.
- Replace the multi-check label with a compact, colored stage counter such as `1/2` and `2/2`. Keep the count readable over the dial and use the digits to communicate progress independently of color. Keep one deliberate check for common fish and use the existing multi-check distinction for rare fish, with a more demanding window only if playtesting calls for it.

**Playable review checkpoint**

Share a build or quick test scene with repeatable common and rare encounters. Let the player try several of each without waiting for natural spawns. Record sweep time, effective success-window duration, and the spread of zone positions relative to M25. Ask whether common fish take attention and rare fish feel clearly harder. Continue the independent trader and feedback work during the review, and use the feedback to settle trophy timing in M27.

In Godot, open [`tests/fish_timing_review.tscn`](../tests/fish_timing_review.tscn) and press **F6**. Press **1** for a common encounter or **2** for a rare one. Each key casts into a live swim route with stock gear. Click or press Space in the green arc, then click to reel in. After a catch or miss, press 1 or 2 to try again. The fixture makes space when the practice Sack fills.

**Verification**

Watch several fish swim farther while staying in valid, reachable water. Exercise early and late zone positions, both multi-check labels, second-stage misses, Slip guard, pause and resume, and successful landing with stock gear. Confirm that the displayed green zone and the accepted input interval agree.

| Timing and motion | M25 | M26 |
| --- | ---: | ---: |
| One-way sweep | 1.30 s | 1.20 s |
| Effective success window per check | 221 ms | 204 ms |
| Zone center positions | Fixed at 64% and 70% by stage | Sampled within 50–83% |
| Full center spread | 6 percentage points / 78 ms | 33 percentage points / 396 ms |
| Earliest green arc opens | 722 ms | 498 ms |
| Swim speed along the same ellipse | 0.65–0.95 rad/s | 1.15–1.60 rad/s |

The first-check sample across 128 fish spanned 50.3–82.6%. Each second check moved at least 10 percentage points from the first. Slip guard restarted the same check with the same arc on a missed input. Timeout still released the fish. Seeded spawn counts at 51%, 50%, 25%, and 0% were unchanged at 0, 27, 65, and 101 out of 120 trials per level. Route samples checked the moving cue and collider against the catch point and the full swim loop against stock casting reach and water bounds.

Godot 4.7.2 passed fishing, catchable fish, main startup, and the seeded cleanup playthrough. The stock practice fixture landed common and rare fish at 1280 × 720 and 800 × 450 and checked stage-two pause, resume, and a click over the dial. Both colored counters were legible in rendered captures. The editor import completed with a local settings safe-save error. Player review requested a bigger difficulty gap for rare fish. M27 addresses that feedback.

## Milestone 27 — Trophy fish

**Verified November 21, 2026.** California sheephead joins the roster as a rare, high-value trophy with distinctive dark and coral art.

- Add one visually distinctive trophy species to the existing roster. Give it an exceptionally low encounter weight when fish are eligible, a larger average size, and a substantially higher sale value than ordinary fish. Keep rarity, size range, and payout configurable.
- Use the timing framework from M26 to make a trophy encounter rewarding to land. Keep it catchable with stock gear and optional for earning upgrades, funding cleanup, or reaching 0% pollution.

**Verification**

Use a large seeded sample to compare encounter frequency, average size, and sale value with the existing fish. Use a forced encounter to check the full swim, hook, timing, landing, inventory art, and sale path. Confirm the ordinary progression route works without encountering a trophy fish.

The common check keeps its 204 ms window. Barred surfperch and kelp bass now have two 168 ms checks following the M26 player review. The trophy uses three 150 ms checks, with the same 1.20-second sweep. The added check makes the trophy harder while leaving time to react in each window with stock gear. Press **3** in the practice scene for a controlled trophy encounter. Human review of these revised windows remains open.

| Species | Encounters in 100,000 weighted draws | Mean length | Mean payout |
| --- | ---: | ---: | ---: |
| Topsmelt | 49,861 | 16.0 cm | 13.1 gold |
| Pacific sardine | 29,887 | 18.5 cm | 17.0 gold |
| Barred surfperch | 15,064 | 23.5 cm | 22.8 gold |
| Kelp bass | 4,948 | 29.4 cm | 30.2 gold |
| California sheephead | 240 | 70.9 cm | 96.9 gold |

The trophy is configured for approximately one in 401 spawned fish, 55–85 cm, and 81–111 gold. The forced encounter passed swim, hook, three stock checks, landing, Sack and trader art, and exact sale credit. Both seeded ordinary playthroughs reached 0% and its live rebound without a trophy visit. The editor imported the new art and reported the existing local settings safe-save error. Continue M28 and M29.

## Milestone 28 — Roomier rod add-on cards and trader shortcut

**Verified November 21, 2026.** The Buy page opens with two spacious add-on cards above the gear and cleanup listings. Fitted add-ons appear on the held rod. B returns to the trader home from Buy or Sell.

- Give add-on cards more spacing and clearer visual hierarchy. Show each add-on's icon, effect, price, and ownership for the equipped rod without crowding the surrounding catalog. Keep controls readable and reachable at reduced window sizes.
- Give Slip guard and Quick spool distinct fitted details on the in-hand rod. Show the corresponding detail immediately after purchase and derive it from the equipped rod's add-on ownership. Check the art with either or both add-ons and keep the grip, rod tip, and line aligned.
- Add a visible `Back (B)` shortcut in Buy and Sell. A fresh B press returns to trader home. On Sell, cancel any active drag or pending selection without selling or changing the Sack. Ignore B on trader home and outside the trader, and preserve the existing Esc and Sell All behavior.

**Verification**

Review Buy at 1280 × 720 and 800 × 450. Fit each add-on, inspect the held rod with both, and buy another rod to verify that its art reflects its separate ownership. Use B from Buy and Sell, including a staged sale or drag, and check focus, balance, and inventory. Recheck Esc, F, and keyboard repeat.

The trader smoke test passed headless and on Intel Iris Xe / OpenGL at both sizes. Rendered Buy captures showed both icons, effects, and prices above the catalog, with Back visible. The test bought both add-ons, fit Quick spool independently on the next rod, and confirmed that prices and ownership followed the equipped rod. Held-rod captures showed Slip guard alone, both pieces with a line attached at the tip, and Quick spool alone. B from a scrolled Buy page or Sell with a staged drag returned focus to Sell and preserved gold and Sack contents. The Esc drag-only press, F, keyboard repeat, and out-of-page B all passed. Continue M29.

## Milestone 29 — Full Sack feedback and quieter walking

**Planned.** Casting with a full Sack gives immediate, brief feedback, and walking sounds quieter.

- Show a small, short-lived `Sack full` pop-up as soon as a cast is attempted with no space. Keep it available with Help off as action feedback. Reuse or refresh the same pop-up on repeated attempts, and keep it clear of the aim point and timing dial. Preserve the existing cast and inventory rules.
- Lower the volume of footsteps relative to M25 while keeping them audible. Adjust the footstep cue independently of the music and other action effects.

**Verification**

Cast with a full Sack and with one free slot, with Help both on and off. Verify that the pop-up appears immediately only for the full Sack, clears on its own, and never stacks. Listen while walking into the next cast and compare footsteps, music, and fishing effects against M25.

## Milestone 30 — Focused playtest and regression checks

**Planned.** A stock-gear session demonstrates the revised fishing feel, trader navigation, and action feedback, with a separate controlled trophy encounter.

- Play common and rare catches back to back, exercise a controlled trophy encounter and sale, fit add-ons, and return to the trader home with B from both pages. Check a full-Sack cast and listen for the quieter steps. Record which game-feel feedback was reviewed and what remains open.
- Run Godot import, main-scene startup, and relevant fishing, trader, session, audio, and graphics checks at the supported test sizes. Check that cleanup progression and continuous music still work. Update the README and architecture notes where controls, behavior, or ownership changed. Record pending human or cross-device checks separately from automated results.

## Scope guardrails

Keep one compact, dependency-free Godot 4 shoreline. Defer multiple levels, dialogue trees, quests, save files, and procedural worlds. Permanent purchases last for the playthrough. Preserve the existing water study, ambient fish, sand, footprints, and landing effects for the computer graphics class. This roadmap covers gameplay, its interface, and the visual changes listed above. Further graphics work will be scoped separately.
