# Vertical slice implementation plan

The `roadmap-implementation` branch starts from playable revision `f812046` on `feature/dynamic-water`. It includes M1–M6 and the sand, footprints, and splash polish. The sections below record the verification and progression checkpoints for M7–M12.

## Definition of done

A first-time player can start a session from the menu, learn to collect recurring floating trash with a starter rod, and take it to a nearby fishing shack in a shared Sack. Trash sales fund rod and Sack upgrades and permanent cleanup. Cleaner water brings back catchable fish that the player can carry and sell for more gold coins. The map supports short trips between the shoreline and shack, and the menu, HUD, and shop use a consistent visual theme. The player can start a fresh session in-game. The main scene and standalone graphics preview run without parser or resource errors.

## Next milestone

Continue with [Milestone 10](#milestone-10--catchable-fish-and-fish-sales). Connect catchable fish to true pollution and let fish share the Sack and sales flow.

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

**Planned.** The player starts seeing scarce catchable fish around 50% pollution remaining, sees them more often as the water clears, and can earn more coins from larger or rarer catches.

- Add catchable fish distinct from the [decorative ambient fish](../scripts/gameplay/ambient_fish.gd). Give catchable fish readable target cues. Drive their spawn chances from true total pollution, with the highest chance at 0%, while ambient silhouettes keep following the eased water visuals. Decide what happens to already-spawned catchable fish if pollution rises above the threshold.
- Start with four or five species and variable sizes. Tune species, size ranges, rarity, spawn chances, and sale prices. Carry landed fish in the Sack with trash and sell them at the shack. Resolve competing targets through the existing cast and return lifecycle and honor available Sack space.

**Verification**

Use seeded trials above, near, and below the threshold and at 0% to check eligibility and increasing spawn chances. Raise pollution through the threshold again while the graphics are still easing. Check catchable fish behavior against the agreed rule and confirm ambient silhouettes cannot be hooked. Land fish and trash into the same Sack, verify a full load rejects extra catches, then sell controlled samples to check that larger fish of the same species and rarer fish of comparable size pay more.

## Milestone 11 — Start menu, onboarding, and interface

**Planned.** A first-time player can start from a menu, learn the cleanup and exchange loop from short prompts, and use a coherent HUD and shop at both default and reduced window sizes.

- Consult the user at the start of this milestone before choosing the visual direction. The theme is open. Apply the agreed theme across the start menu, in-game HUD, and shop. Show pollution, Sack capacity, coins, current gear tiers, upgrade effects and prices, and cleanup purchase status where players need them.
- Bring forward concise shoreline, cast, retrieve, and miss cues from the earlier onboarding plan. Add turn-in and upgrade guidance and retain access to detailed controls.
- Provide a labeled way to start a fresh session independent of temporary pollution levels. Let the game entry point own session creation and reset. Handle menu and shop clicks before fishing input and guard against repeated start or restart activation.

**Verification**

Ask a first-time player to start, make a catch, exchange a load, and buy an upgrade using the on-screen cues. Resize the window and check labels, focus, and aim accuracy. Click and close shop and menu controls without casting or retrieving, then resume fishing. Start two fresh sessions and verify the spawn, gear, Sack, coins, projects, arrivals, pollution, and visuals reset each time.

## Milestone 12 — Playtest and stabilize the slice

**Planned.** A player can go from the starter rod to a first fish sale and lasting recovery, then start a fresh session and repeat the loop.

- Play through two fresh sessions from the start menu to a fish sale, including trash-funded upgrades and cleanup, a pollution rebound, and the agreed clean-water check. Observe whether a new player can find the shack and learn what to do next. Check travel time, early affordability, Sack slowdown, full inventory, rapid inputs, range edges, and small-window legibility.
- Run Godot editor import, main-scene startup, the updated smoke tests, the standalone water preview, and the real-render water check. Record the Godot version, renderer, skipped checks, and known limitations. Check that the README controls and architecture notes match the integrated scenes and systems. Keep generated captures and editor data out of Git.

**Verification**

Both sessions reach a fish sale through normal play. The replay flow resets session state, water and ambient fish respond correctly to live changes, and the independent preview still shows animated dirty, intermediate, and clean states. Check the debugger for parser, resource, and orphan-node errors.

## Scope guardrails

Keep one compact, dependency-free Godot 4 shoreline. Defer multiple levels, dialogue, quests, save files, and procedural worlds. Permanent purchases last for the playthrough. Preserve the existing water study, ambient fish, sand, footprints, and landing effects for the computer graphics class. This roadmap covers gameplay and its interface. Additional rendering, effects, and art direction will be scoped separately.
