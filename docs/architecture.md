# Architecture

## Goals

The first vertical slice should support a compact Playas de Tijuana shoreline where the player moves, casts a fishing rod, retrieves trash, and sees ocean pollution decrease. Fish become more visible or more common as water quality improves. The architecture favors small scene-owned behaviors and event-driven coordination without adding global infrastructure prematurely.

## Proposed scene tree

```text
Main (Node)
├── World (Node2D)
│   ├── Shoreline (TileMapLayer or composed level scene)
│   ├── Water (Node2D)
│   │   ├── TrashContainer (Node2D)
│   │   └── FishContainer (Node2D)
│   ├── Player (CharacterBody2D)
│   │   ├── MovementComponent
│   │   ├── FishingRod
│   │   └── InteractionArea
│   └── PollutionSystem (Node)
├── Effects (Node2D)
└── HUD (CanvasLayer)
    ├── PollutionDisplay
    └── InteractionPrompt
```

This is a target composition, not a requirement to put every behavior in the main scene. `Player`, `FishingRod`, `Trash`, individual fish, HUD widgets, and effects should be independently instantiable scenes.

## Scene responsibilities

### Implemented fishing composition

`Player` owns a `FishingRod` and checks `is_active()` to lock movement outside `IDLE`. The rod owns an aiming pivot, a tip marker, separate `FishingLine` and `FishingHook` scenes, and a status label. The pivot rotates toward the world-space mouse position; line endpoints are converted into local coordinates.

The level derives an axis-aligned water rectangle from its rectangular ocean polygon and injects it into the rod. Translation/scaling is supported; rotated or nonrectangular water needs a polygon-based validator. Validation checks distance to water (140 px), a water target, and range (60–420 px), measured from the rod origin.

States are `IDLE -> CASTING -> WAITING -> RETRIEVING -> IDLE`. The target is fixed on cast. Hook ground position interpolates toward it while only the visual child receives `-4 * height * t * (1 - t)` on screen Y. Height is zero at both endpoints. Collision stays on the water plane; retrieval interpolates back to the tip. Clicks during casting/retrieval are ignored.

Typed rod signals: `state_changed`, `hook_landed`, `retrieval_advanced(previous_position, current_position, hook_radius)`, `retrieval_completed`, and `target_detected`. The hook queries monitorable `Area2D` targets on layer 3 (`FishingTarget`); only waiting overlaps emit detection. `TrashManager` subscribes to these events and owns selection, attachment, and successful collection. No autoloads are needed.

### Implemented cleanup composition

`World` owns a `TrashManager` (which contains unhooked trash), a `PollutionSystem`, and the existing player/environment. `Main` binds the HUD to these local instances. The rod remains unaware of pollution and trash types.

- `OceanTrash` is a reusable `Area2D` scene with bottle, can, and bag visuals. Each instance has a catch circle, type, and configurable pollution value. Vertical current moves the Area2D itself during physics updates; bobbing remains visual-only. The default batch cycles types with pollution values 10, 15, and 20.
- `TrashManager` spawns one finite batch (24 by default, seed 2026), with a configurable cap, initial spacing, shoreline clearance, and catch radius. There is no replenishment timer. The level computes a reachable shoreline segment from actual world-boundary shapes, player collider extents, and rod offset. The manager samples an inset ocean rectangle within rod range, validates each candidate with `FishingRod.invalid_target_reason_from()`, and rejects crowded candidates. A bounded attempt budget avoids infinite loops; impossible configurations warn and register only the actual batch.
- Each item receives seeded current speed (4–8 world pixels/second maximum) and phase. `configure_drift()` fits a cosine orbit with amplitude at most 80 px into the same reachable vertical limits used for spawning, preserving the initial position. X stays fixed, and the valid shoreline segment spans the full permitted Y range, so every drift position remains castable. Cosine velocity reaches zero at either end before reversing. Current moves detection geometry predictably; bobbing does not. There is no fluid simulation or object-to-object collision, so drifting items can cross each other after spawning.
- On `hook_landed`, the manager selects the nearest available item whose own catch radius contains the landing position. This synchronous geometric check avoids stale physics overlap caches and prevents catches along the airborne path. `target_detected` remains an additional waiting-only hint; its handling is deferred to avoid reparenting during physics callbacks. Landing/waiting attachment remains limited to one item.
- During RETRIEVING the rod emits each actual hook movement segment, including the final segment **before** switching to IDLE. The manager projects each current trash position onto the bounded segment and tests distance against `item.catch_radius + hook_radius` (defaults 24 + 10 px). This is a swept hook disk against the item's catch disk; neither the fishing line nor an infinite ray collects items. Multiple intersected items can attach in one frame, including after an empty landing, without tunneling at high hook speeds.
- Hooking reparents each item to the hook's visual anchor, stops drift/bobbing, and disables monitorability. A compact five-column offset pattern keeps attached sprites distinct. Per-item flags and a typed held-item array prevent duplicates. Pollution and counts remain unchanged until `retrieval_completed` in IDLE. The manager clears its held array first, then finalizes/removes every returned item and emits one `trash_collected(item_id: int, type_name: String)` per successful item. The model consumes each ID once, including for batch returns.
- `PollutionSystem.initialize(item_values: Dictionary[int, int])` snapshots actual spawned instance IDs and their pollution values. `collect(item_id)` consumes an ID once, subtracts its registered value, and updates counts. Unknown/duplicate IDs return false without emitting changes. This model can be tested without rendering or physics.
- `TrashManager.trash_hooked(type_name)` and `trash_collected(item_id, type_name)` feed temporary HUD notifications. The level routes successful collection to `PollutionSystem.collect()`. The HUD only observes model state and displays collected/remaining counts, pollution percentage, and completion.

### Compact interface

The normal HUD is a 264 × 48 px translucent corner card with collected/total and pollution percentage plus a slim pollution bar. Catch notifications use small unboxed text and aggregate completed batches. Completion stays at the lower-left viewport edge. Detailed instructions are hidden until the `toggle_help` action (H); key repeat does not toggle repeatedly. A six-second startup hint reduces to “H Help”. All HUD controls ignore mouse input, preserving cast clicks. The help panel is explicitly toggled and does not pause gameplay.

Swept detection samples each item's current physics position rather than solving continuous relative motion for moving trash. At the configured gentle current speed this keeps the implementation small; unusually fast currents would need relative-motion sweeps. The shoreline/water validator still assumes this axis-aligned rectangular level. Pollution signals and future shader bindings below are unchanged.

### Pollution-responsive water and future fish presentation

The level injects `PollutionSystem` into `Environment/Water` (`WaterVisuals`). It reads `normalized_pollution` immediately, then subscribes to `pollution_changed(normalized_pollution: float, collected_count: int, remaining_count: int)`. Values range from 0 (clean) to 1 (initial pollution). The controller smoothly displays changes over 1.6 seconds using a finite Hermite interpolation; the HUD independently receives the true model value immediately. A private material is created once per water instance and only its `pollution_level` uniform changes during transitions.

`water.tscn` owns a procedural static Seabed (effective Z -10) and a ColorRect Surface with `shaders/ocean.gdshader` (Z -9). Beach, player, and floating trash stay at Z 0, fishing feedback at player-relative +5, and the HUD in its CanvasLayer. The old Ocean polygon stays hidden as the authority for bounds; old deep/shallow polygons and static foam are hidden. The new shader handles foam inside the same water rectangle, leaving collision and game coordinates unchanged.

The CanvasItem shader uses Hermite-interpolated value noise, weighted frequency layers, two nonparallel travelling sine waves, continuous dirty-to-clean palettes, and alpha compositing over real seabed geometry. It is isolated to the Surface and uses the existing GL Compatibility renderer. `displayed_pollution_changed(value)` lets future visual effects follow the same smoothed value. Future fish gameplay may read the true model instead. The model also exposes `initial_total_pollution`, `current_pollution`, `trash_collected`, `remaining_trash`, and `cleanup_completed()`.

An empty batch has zero pollution/normalized value 0 and starts with clean water. Scene reloads/rebinding synchronize immediately. Initial state is read when connecting after level readiness, avoiding missed initialization events. Fish and particles are deferred. A separate `water_preview.tscn` demonstrates 1.0/0.5/0.0 with isolated materials and no game-state model. See [water-rendering.md](water-rendering.md) for equations, layering, tuning, capture commands, and performance limits.

- **Main:** Composes the level and HUD, starts a session, and connects high-level signals. It contains little or no gameplay logic.
- **Level:** Owns terrain, collision, spawn markers, camera boundaries, and authored placement for a single shoreline area.
- **Player:** Owns input-facing movement and the player's current ability to fish. It delegates casting and retrieval to the rod component/scene.
- **Fishing rod:** Runs the cast/retrieve state machine, presents the line and hook, detects a valid catch, and emits a result. It should not update pollution directly.
- **Trash:** Describes a collectible category, its pollution value, and its presentation. It reports collection once and then leaves the scene safely.
- **Pollution system:** Holds the current pollution amount, applies bounded changes, derives a normalized cleanliness value, and signals changes.
- **Fish population/presentation:** Reacts to cleanliness thresholds by spawning, revealing, or increasing fish activity. Fish are environmental feedback in the first slice and need not be catchable.
- **HUD:** Displays pollution and contextual prompts. It observes state and does not own game rules.
- **Effects:** Plays water, collection, and cleanup feedback in response to gameplay events.

## Systems and data flow

```text
Input -> Player -> FishingRod -> Trash collected
                                  |
                                  v
                         PollutionSystem
                           |           |
                           v           v
                          HUD     Water/Fish visuals
```

The player sends commands to its owned fishing rod. When the rod successfully retrieves a collectible, it emits a typed event containing the collected object or its pollution value. A level/session coordinator routes that result to the pollution system. The pollution system clamps the total, calculates cleanliness, and emits a typed `pollution_changed` signal. The HUD and environmental presentation subscribe independently.

This keeps collectibles unaware of UI and keeps the player unaware of water rendering or fish population rules.

## State ownership

- Session pollution belongs to `PollutionSystem`, with a clear initial and minimum value.
- Fishing state belongs to `FishingRod` (for example: ready, casting, waiting, retrieving, cooldown).
- Movement state belongs to `Player` or a reusable movement component.
- Visual clarity and fish activity are derived from normalized cleanliness rather than stored as competing sources of truth.
- Collectible configuration should move into typed custom `Resource` data only when multiple variants make that worthwhile.

## Initial technical choices

- Use `CharacterBody2D` and `move_and_slide()` for top-down movement.
- Use Godot input actions rather than checking physical keys in gameplay scripts.
- Use `Area2D`/collision layers for fishing targets and interaction detection.
- Use a shader parameter, modulate value, or layered sprites to transition water clarity; isolate the choice behind the water presentation scene.
- Use a finite seeded spawn batch constrained to reachable water for this slice; do not add continuous respawning.
- Avoid autoloads initially. Add a session/game-state autoload only when changing levels creates a demonstrated need for persistent state.

## Suggested scene and script files

```text
scenes/gameplay/main.tscn
scenes/levels/playas_vertical_slice.tscn
scenes/gameplay/player.tscn
scenes/gameplay/fishing_rod.tscn
scenes/gameplay/trash.tscn
scenes/gameplay/fish.tscn
scenes/ui/hud.tscn
scripts/gameplay/player.gd
scripts/components/top_down_movement.gd
scripts/systems/pollution_system.gd
scripts/gameplay/fishing_rod.gd
scripts/gameplay/trash.gd
scripts/systems/fish_population.gd
scripts/ui/hud.gd
```

Create these files incrementally during implementation rather than as empty placeholders.
