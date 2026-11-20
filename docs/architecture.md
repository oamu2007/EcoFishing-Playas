# Architecture

## Goals

The first vertical slice should support a compact Playas de Tijuana shoreline where the player moves, casts a fishing rod, retrieves trash, and sees ocean pollution decrease. Fish become more visible or more common as water quality improves. The architecture favors small scene-owned behaviors and event-driven coordination without adding global infrastructure prematurely.

## Current scene tree

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
│   ├── FishingShack (Node2D)
│   ├── ShackShop (Node)
│   │   └── Sack (Node)
│   ├── TrashManager (Node2D)
│   └── PollutionSystem (Node)
├── HUD (CanvasLayer)
└── ShackPanel (CanvasLayer)
```

The tree omits decorative nodes. `Main` instantiates the level and HUD, and the level owns local gameplay and environmental presentation.

The level also creates footprint and splash nodes at runtime, plus a shader-backed sand overlay and static sand-detail node under `Environment`.

## Scene responsibilities

### Implemented fishing composition

`Player` owns a `FishingRod` and checks `is_active()` to lock movement outside `IDLE`. The rod owns an aiming pivot, a tip marker, separate `FishingLine` and `FishingHook` scenes, and a status label. The pivot rotates toward the world-space mouse position; line endpoints are converted into local coordinates.

The level derives an axis-aligned water rectangle from its rectangular ocean polygon and injects it into the rod. Translation/scaling is supported; rotated or nonrectangular water needs a polygon-based validator. Validation checks distance to water (140 px), a water target, and range (60–240 px for the starter rod), measured from the rod origin.

States are `IDLE -> CASTING -> WAITING -> RETRIEVING -> IDLE`. The target is fixed on cast. Hook ground position interpolates toward it while only the visual child receives `-4 * height * t * (1 - t)` on screen Y. Height is zero at both endpoints. Collision stays on the water plane; retrieval interpolates back to the tip. Clicks during casting/retrieval are ignored.

Typed rod signals: `state_changed`, `hook_landed`, `retrieval_advanced(previous_position, current_position, hook_radius)`, `retrieval_completed`, and `target_detected`. The hook queries monitorable `Area2D` targets on layer 3 (`FishingTarget`); only waiting overlaps emit detection. `TrashManager` subscribes to these events and owns selection, attachment, and successful collection. No autoloads are needed.

### Implemented cleanup composition

`World` owns a `TrashManager` (which contains unhooked trash), a `PollutionSystem`, and the existing player/environment. `Main` binds the HUD to these local instances. The rod supplies the total trash allowance for a cast and remains independent of the pollution model.

- `OceanTrash` is a reusable `Area2D` scene with bottle, can, and bag visuals. Each instance has a catch circle, type, and configurable pollution value. Vertical current moves the Area2D itself during physics updates; bobbing remains visual-only. All three types contribute five floating points by default.
- `TrashManager` starts with six nearshore items by default (seed 2026). The level computes a reachable shoreline segment from actual boundary shapes, player collider extents, and rod offset. Starter and offshore stop bands use the shoreline segment and the rod's base range. Every ten seconds the manager schedules an arrival if either band's slots allow it. Eight of twelve slots are reserved for the starter band. Candidates are spaced from floating items and reserved stop positions. Arrivals begin beyond the camera's ocean edge, ease toward their stops, and register for pollution as their centers enter the water.
- Each item receives seeded current speed (4–8 world pixels/second maximum) and phase. `configure_drift()` fits a cosine orbit with amplitude at most 80 px into the same reachable vertical limits used for spawning, preserving the initial position. X stays fixed, and the valid shoreline segment spans the full permitted Y range, so every starter-band drift position remains castable. Cosine velocity reaches zero at either end before reversing. Current moves detection geometry predictably; bobbing does not. There is no fluid simulation or object-to-object collision, so drifting items can cross each other after spawning.
- On `hook_landed`, the manager selects the nearest available item whose own catch radius contains the landing position. This synchronous geometric check avoids stale physics overlap caches and prevents catches along the airborne path. `target_detected` remains an additional waiting-only hint; its handling is deferred to avoid reparenting during physics callbacks. Landing/waiting attachment remains limited to one item.
- During RETRIEVING the rod emits each actual hook movement segment, including the final segment **before** switching to IDLE. The manager projects each current trash position onto the bounded segment and tests distance against `item.catch_radius + hook_radius` (defaults 24 + 10 px). This is a swept hook disk against the item's catch disk; neither the fishing line nor an infinite ray collects items. An empty landing can still sweep a piece on the way back without tunneling at high hook speeds. One shared trash limit covers landing, waiting, and retrieval.
- Hooking reparents each item to the hook's visual anchor, stops drift/bobbing, and disables monitorability. A compact five-column offset pattern keeps attached sprites distinct. Per-item flags and a typed held-item array prevent duplicates. Pollution and counts remain unchanged until `retrieval_completed` in IDLE. The manager clears its held array first, then finalizes/removes every returned item and emits one `trash_collected(item_id: int, type_name: String)` per successful item. The model consumes each ID once, including for batch returns.
- `PollutionSystem` registers live IDs as they arrive and consumes each ID once on successful return. The total is the sum of floating points, capped at 30, and permanent points, bounded at 0–70. Permanent points start at 70. When both components are zero, the meter reaches 0% until another piece arrives. The pollution signal emits only when the capped total changes.
- `TrashManager.trash_hooked(type_name)` and `trash_returned(count, type_name)` feed cast-scoped HUD notifications, including misses. The level routes arrivals and successful collection to the model.

### Compact interface

The normal HUD is a 264 × 85 px translucent corner card with live pollution, Sack usage, gold, and gear tiers. Catch notifications use small unboxed text and aggregate successful returns. Detailed instructions are hidden until the `toggle_help` action (H); key repeat does not toggle repeatedly. A six-second startup hint reduces to “H Help”. All HUD controls ignore mouse input, preserving cast clicks. The help panel is explicitly toggled and does not pause gameplay.

Swept detection samples each item's current physics position rather than solving continuous relative motion for moving trash. At the configured gentle current speed this keeps the implementation small; unusually fast currents would need relative-motion sweeps. The shoreline/water validator still assumes this axis-aligned rectangular level.

### Sack and fishing shack

The level injects its Sack into `Player` and `TrashManager`. The Sack holds sale values across casts, applies a linear movement multiplier as it fills, and has three slots and a 12% full-load slowdown by default. The trash manager checks Sack space and the rod's trash limit before attachment. It stores a successful return before registering pollution removal. Full Sack casts leave excess trash in the water.

`FishingShack` marks a short route inland from starter-range water. The player presses E in range with the rod idle. `Main` opens the modal `ShackPanel` and gates both movement and rod input until the panel closes. `ShackShop` owns the session wallet and purchase state. It credits the sum of the Sack's sale values once, then empties it. Typed `RodUpgrade` and `SackUpgrade` resources configure ordered upgrade tiers, their prices, and their effects. A purchase addresses a specific tier and debits only on success. The trash manager retains cast ownership until fish need the same geometry arbitration in M10. This keeps M8's change limited to one catch producer and avoids global session state.

### Pollution-responsive water

The level injects `PollutionSystem` into `Environment/Water` (`WaterVisuals`). It reads `normalized_pollution` immediately, then subscribes to `pollution_changed(normalized_pollution: float)`. Values range from 0 (clean) to 1 (initial pollution). The controller smoothly displays changes over 1.6 seconds using a finite Hermite interpolation; the HUD independently receives the true model value immediately. A private material is created once per water instance and only its `pollution_level` uniform changes during transitions.

`water.tscn` owns a procedural static Seabed (effective Z -10) and a ColorRect Surface with `shaders/ocean.gdshader` (Z -9). Beach, player, and floating trash stay at Z 0, fishing feedback at player-relative +5, and the HUD in its CanvasLayer. The old Ocean polygon stays hidden as the authority for bounds; old deep/shallow polygons and static foam are hidden. The new shader handles foam inside the same water rectangle, leaving collision and game coordinates unchanged.

The CanvasItem shader uses Hermite-interpolated value noise, weighted frequency layers, two nonparallel travelling sine waves, continuous dirty-to-clean palettes, and alpha compositing over real seabed geometry. It is isolated to the Surface and uses the existing GL Compatibility renderer. `displayed_pollution_changed(value)` lets ambient fish follow the same smoothed value. The model also exposes `permanent_points`, `floating_points`, `current_pollution`, `trash_collected`, and `remaining_trash`.

Fixtures can initialize explicit permanent and floating loads, including an entirely clean ocean. Scene reloads/rebinding synchronize immediately. Initial state is read when connecting after level readiness, avoiding missed initialization events. A separate `water_preview.tscn` demonstrates 1.0/0.5/0.0 with isolated materials and no game-state model. See [water-rendering.md](water-rendering.md) for equations, layering, tuning, capture commands, and performance limits.

### Ambient fish

The level owns `ambient_fish.tscn` alongside `Water` under `Environment`. After configuring water and binding it to the initialized pollution model, the level supplies the same authored rectangle and local `WaterVisuals` to the fish scene. The scene connects to `displayed_pollution_changed(value)` and reads `displayed_pollution` immediately, including at startup in an empty world. Fish tint and opacity follow the displayed value directly during a retarget.

The scene creates six copies of one `Polygon2D` silhouette and keeps them for its lifetime. Fixed ellipse centers, periods, and phases spread routes along the shore. Routes use the first 280 px of the water by default and reserve room for the rotated silhouettes. The layer draws at effective Z -8 above the surface and below the beach, floating trash, and fishing feedback. Fish are decorative CanvasItems with no physics or cleanup state.

Tune `early_reveal_pollution`, `late_reveal_pollution`, and `fade_width` on the `AmbientFish` instance. The defaults start the two groups at 0.79 and 0.43, stagger each group by 0.035 per fish, and apply a smoothstep fade over up to 0.24 pollution units. At displayed pollution 1.0, 0.5, and 0.0, the default layer shows zero, three, and six fish respectively across the shoreline. `nearshore_width`, `murky_tint`, and `clear_tint` set route width and tint/opacity endpoints.

### Beach detail and landing effects

Commit `2589291` adds three local presentation scripts and `shaders/sand.gdshader`. The level creates their nodes in `_ready()`. These nodes are owned by the running level's scene tree and are released with it.

- `footprints.gd` receives the player reference and measures actual movement in `_process()`. Every 26 pixels it places an alternating footprint with a six-pixel lateral offset. Prints fade over eight seconds and are capped at 80. The node draws after Environment and before Player at Z 0.
- `water_splash.gd` receives `hook_landed` through the level, with the landing position and true normalized pollution. It creates one 18-droplet `CPUParticles2D` burst with a 0.6-second lifetime and two expanding rings with a 0.18-second stagger and 0.9-second lifetime. Droplet nodes free themselves on `finished`. Rings are removed when their lifetime ends. The effect draws at Z 3 below the rod and hook at player-relative +5.
- The sand overlay is a mouse-ignoring ColorRect under Environment fitted to the Beach polygon's rectangle. Its private material combines smooth value-noise dunes, sine wind marks, and two-pixel grain with 0.32 alpha. Shader uniforms control colors, dune/grain strength, opacity, and area size.
- `sand_details.gd` generates ten pebble clusters, twelve shells, and eighteen wind arcs once with seed 2026, then uses cached draw commands. It uses bounded placement attempts and spacing for pebble-cluster and shell centers.

The sand overlay and detail positions derive from the authored Beach polygon. The detail inset keeps pebbles and shells away from wet sand. Footprint and splash nodes continue processing/redrawing while empty. Most effect settings are script constants rather than exported Inspector controls. Extracting a reusable presentation scene and exposing tuning are follow-up maintenance work.

### Planned replay

Milestone 11 adds a fresh-session action owned by `Main`. See the [implementation plan](implementation-plan.md) for exit checks.

## Systems and data flow

```text
Input -> Player / FishingRod
FishingRod lifecycle -> TrashManager
TrashManager.trash_arrived -> PollutionSystem.register_trash(item_id, points)
TrashManager.trash_collected -> Level -> PollutionSystem.collect(item_id)
TrashManager hook and collection events -> HUD notifications
PollutionSystem.pollution_changed -> HUD and WaterVisuals
WaterVisuals.displayed_pollution_changed -> AmbientFish
FishingRod.hook_landed -> Level -> WaterSplash (true pollution tint)
Player position -> Footprints
```

The rod reports lifecycle and hook positions. The trash manager identifies and finalizes items, then the level passes the returned IDs to the pollution model. The HUD reads the true pollution value immediately, while fish follow the visual transition.

## State ownership

- Session pollution belongs to `PollutionSystem`, with a clear initial and minimum value.
- Fishing state belongs to `FishingRod` (IDLE, CASTING, WAITING, RETRIEVING).
- Movement state belongs to `Player`. `Sack` provides the load multiplier and owns carried items. `ShackShop` owns coins and purchased tiers.
- Water clarity follows normalized pollution, and fish visibility follows the displayed water value.
- Collectible configuration should move into typed custom `Resource` data only when multiple variants make that worthwhile.

## Initial technical choices

- Use `CharacterBody2D` and `move_and_slide()` for top-down movement.
- Use Godot input actions rather than checking physical keys in gameplay scripts.
- Use `Area2D`/collision layers for fishing targets and interaction detection.
- Use a shader parameter, modulate value, or layered sprites to transition water clarity; isolate the choice behind the water presentation scene.
- Use seeded nearshore and offshore trash arrivals with separate capacity limits.
- Avoid autoloads initially. Add a session/game-state autoload only when changing levels creates a demonstrated need for persistent state.
