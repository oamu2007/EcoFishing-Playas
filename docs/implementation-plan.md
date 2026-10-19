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

- Build the fishing rod as an owned scene/component with explicit ready, cast, and retrieve states.
- Add cast targeting/range rules and simple line/hook presentation.
- Prevent movement or repeated casts only where the chosen feel requires it.
- Detect catchable targets using dedicated collision layers and emit a typed catch result.

**Exit check:** The player can repeatedly cast and retrieve; valid targets are detected once and invalid casts recover safely.

## Milestone 4: Trash collection and pollution

- Create a reusable trash scene with an exported pollution-removal value.
- Place several readable trash targets in the test water.
- Implement the pollution system as the single owner of the pollution total.
- Route fishing results to pollution changes through signals/coordinator logic.
- Display the current pollution or cleanliness value in the HUD.

**Exit check:** Retrieving trash removes it once, updates the HUD by the correct amount, and clamps pollution at its valid bounds.

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
