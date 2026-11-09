# Architecture

## Goals

The first vertical slice should support a compact Playas de Tijuana shoreline where the player moves, casts a fishing rod, retrieves trash, and sees ocean pollution decrease. Fish become more visible or more common as water quality improves. The architecture favors small scene-owned behaviors and event-driven coordination without adding global infrastructure prematurely.

## Current scene tree

The tree shows the M6 implementation on `feature/dynamic-water`. On `main`, the level still draws the original ocean polygons and foam, while the player, fishing rod, trash manager, pollution model, and HUD use the same ownership described below.

```text
Main (Node)
├── World (Node2D)
│   ├── Environment (Node2D)
│   │   ├── Ocean (hidden Polygon2D, authoritative water bounds)
│   │   ├── Water (Node2D)
│   │   │   ├── Seabed (Node2D)
│   │   │   └── Surface (ColorRect)
│   │   └── AmbientFish (Node2D)
│   ├── WorldBounds (StaticBody2D)
│   ├── Player (CharacterBody2D)
│   │   └── FishingRod (Node2D)
│   ├── TrashManager (Node2D)
│   └── PollutionSystem (Node)
└── HUD (CanvasLayer)
```

The tree omits decorative nodes. `Main` instantiates the level and HUD, and the level owns local gameplay and environmental presentation.

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

Swept detection samples each item's current physics position rather than solving continuous relative motion for moving trash. At the configured gentle current speed this keeps the implementation small; unusually fast currents would need relative-motion sweeps. The shoreline/water validator still assumes this axis-aligned rectangular level.

### Pollution-responsive water (M5, feature branch)

The level injects `PollutionSystem` into `Environment/Water` (`WaterVisuals`). It reads `normalized_pollution` immediately, then subscribes to `pollution_changed(normalized_pollution: float, collected_count: int, remaining_count: int)`. Values range from 0 (clean) to 1 (initial pollution). The controller smoothly displays changes over 1.6 seconds using a finite Hermite interpolation; the HUD independently receives the true model value immediately. A private material is created once per water instance and only its `pollution_level` uniform changes during transitions.

`water.tscn` owns a procedural static Seabed (effective Z -10) and a ColorRect Surface with `shaders/ocean.gdshader` (Z -9). Beach, player, and floating trash stay at Z 0, fishing feedback at player-relative +5, and the HUD in its CanvasLayer. The old Ocean polygon stays hidden as the authority for bounds; old deep/shallow polygons and static foam are hidden. The new shader handles foam inside the same water rectangle, leaving collision and game coordinates unchanged.

The CanvasItem shader uses Hermite-interpolated value noise, weighted frequency layers, two nonparallel travelling sine waves, continuous dirty-to-clean palettes, and alpha compositing over real seabed geometry. It is isolated to the Surface and uses the existing GL Compatibility renderer. `displayed_pollution_changed(value)` lets ambient fish follow the same smoothed value. The model also exposes `initial_total_pollution`, `current_pollution`, `trash_collected`, `remaining_trash`, and `cleanup_completed()`.

An empty batch has zero pollution/normalized value 0 and starts with clean water. Scene reloads/rebinding synchronize immediately. Initial state is read when connecting after level readiness, avoiding missed initialization events. A separate `water_preview.tscn` demonstrates 1.0/0.5/0.0 with isolated materials and no game-state model. See [water-rendering.md](water-rendering.md) for equations, layering, tuning, capture commands, and performance limits.

### Ambient fish (M6, feature branch)

The level owns `ambient_fish.tscn` alongside `Water` under `Environment`. After configuring water and binding it to the initialized pollution model, the level supplies the same authored rectangle and local `WaterVisuals` to the fish scene. The scene connects to `displayed_pollution_changed(value)` and reads `displayed_pollution` immediately, including at startup in an empty world. Fish tint and opacity follow the displayed value directly during a retarget.

The scene creates six copies of one `Polygon2D` silhouette and keeps them for its lifetime. Fixed ellipse centers, periods, and phases spread routes along the shore. Routes use the first 280 px of the water by default and reserve room for the rotated silhouettes. The layer draws at effective Z -8 above the surface and below the beach, floating trash, and fishing feedback. Fish are decorative CanvasItems with no physics or cleanup state.

Tune `early_reveal_pollution`, `late_reveal_pollution`, and `fade_width` on the `AmbientFish` instance. The defaults start the two groups at 0.79 and 0.43, stagger each group by 0.035 per fish, and apply a smoothstep fade over up to 0.24 pollution units. At displayed pollution 1.0, 0.5, and 0.0, the default layer shows zero, three, and six fish respectively across the shoreline. `nearshore_width`, `murky_tint`, and `clear_tint` set route width and tint/opacity endpoints.

### Planned replay

In Milestone 7, the HUD will show the replay control when the model reports zero remaining trash, including on initial bind for an empty batch. `Main` will handle the HUD's replay request and reload the session. Normal scene initialization will rebuild the seeded trash batch and synchronize the new model, HUD, water, and fish. See the [implementation plan](implementation-plan.md) for exit checks.

## Systems and data flow

```text
Input -> Player / FishingRod
FishingRod lifecycle -> TrashManager
TrashManager.trash_collected -> Level -> PollutionSystem.collect(item_id)
TrashManager hook and collection events -> HUD notifications
PollutionSystem.pollution_changed -> HUD and WaterVisuals
WaterVisuals.displayed_pollution_changed -> AmbientFish
```

The rod reports lifecycle and hook positions. The trash manager identifies and finalizes items, then the level passes the returned IDs to the pollution model. The HUD reads the true pollution value immediately, while fish follow the visual transition.

## State ownership

- Session pollution belongs to `PollutionSystem`, with a clear initial and minimum value.
- Fishing state belongs to `FishingRod` (IDLE, CASTING, WAITING, RETRIEVING).
- Movement state belongs to `Player`.
- Water clarity follows normalized pollution, and fish visibility follows the displayed water value.
- Collectible configuration should move into typed custom `Resource` data only when multiple variants make that worthwhile.

## Initial technical choices

- Use `CharacterBody2D` and `move_and_slide()` for top-down movement.
- Use Godot input actions rather than checking physical keys in gameplay scripts.
- Use `Area2D`/collision layers for fishing targets and interaction detection.
- Use a shader parameter, modulate value, or layered sprites to transition water clarity; isolate the choice behind the water presentation scene.
- Use a finite seeded spawn batch constrained to reachable water for this slice; do not add continuous respawning.
- Avoid autoloads initially. Add a session/game-state autoload only when changing levels creates a demonstrated need for persistent state.
