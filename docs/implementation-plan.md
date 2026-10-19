# Vertical slice implementation plan

## Definition of done

A player can launch the project into one small Playas de Tijuana shoreline, move in four directions, cast and retrieve a fishing line, collect visible trash from the water, and see pollution decrease. Water clarity and fish presence respond clearly to cleanup progress. The slice can be restarted and has no parser errors or broken resource references.

## Milestone 1: Project bootstrap

**Status: Implemented (October 18, 2026); editor/runtime verification pending.**

- [x] Confirm the project configuration targets Godot 4.7.
- [x] Define a 960 × 540 viewport, responsive canvas scaling, and movement input actions.
- [x] Create the main scene and one test shoreline level.
- [x] Add a simple controls HUD and establish collision layers/masks in project settings.
- [x] Set the main scene for F5 project runs.
- [ ] Add fishing and restart input actions when their systems are implemented.

**Exit check:** Running the project opens the test shoreline at the expected aspect ratio with no errors.

## Milestone 2: Player movement

**Status: Implemented (October 18, 2026); editor/runtime verification pending.**

- [x] Build a modular `CharacterBody2D` player scene.
- [x] Implement typed top-down movement with normalized diagonal input and exported speed.
- [x] Add beach and ocean collision boundaries plus a smoothing follow camera.
- [x] Add a clear placeholder fisherman assembled from procedural shapes.
- [x] Support both WASD and arrow-key movement.

**Exit check:** Keyboard/controller input moves the player smoothly, collisions hold, and diagonal movement is not faster.

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

Limitations: initial spawn spacing is enforced, but drifting objects may pass through one another. Sweeps use the current item position per segment, suitable for these slow currents. This level still uses axis-aligned rectangular water; shader, fish, and particles remain future work.

## Milestone 5: Environmental response

- Create a water presentation that interpolates between polluted and clear states.
- Define a few cleanliness thresholds for fish visibility/activity.
- Add lightweight fish movement/presentation and collection feedback effects.
- Make changes gradual and legible without coupling visuals to the HUD.

**Exit check:** Cleaning the level visibly clears the water and causes fish to appear, including correct behavior at boundary values.

## Milestone 6: Vertical-slice polish and verification

- Add a concise tutorial prompt and feedback for cast, miss, catch, and cleanup progress.
- Add a completion state when the target cleanliness is reached and a reliable restart path.
- Test input, collision edge cases, rapid casting, final-item collection, and scene reloads.
- Review node ownership, signal cleanup, typed-script warnings, and resource paths.
- Document controls and update architecture notes to match the implemented structure.

**Exit check:** A new player can complete the loop without explanation, and repeated runs produce no errors or orphan-node/resource warnings.

## Scope guardrails

Defer inventory, upgrades, multiple levels, dialogue, quests, save files, catchable fish, procedural worlds, and production art/audio until the vertical slice is stable. Placeholder assets are acceptable when they make the interaction and environmental change readable.
