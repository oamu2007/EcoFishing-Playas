# Architecture

## Goals

The first vertical slice should support a compact Playas de Tijuana shoreline where the player moves, casts a fishing rod, retrieves trash, and sees ocean pollution decrease. Fish become more visible or more common as water quality improves. The architecture favors small scene-owned behaviors and event-driven coordination without adding global infrastructure prematurely.

## Current scene tree

```text
Main (Node)
├── SessionMenu (CanvasLayer)
└── Session (Node, created when a session starts)
    ├── World (Node2D)
    │   ├── Environment (Node2D)
    │   │   ├── Ocean (hidden Polygon2D, authoritative water bounds)
    │   │   ├── Water (Node2D)
    │   │   │   ├── Seabed (Node2D)
    │   │   │   └── Surface (ColorRect)
    │   │   └── AmbientFish (Node2D)
    │   ├── CleanupWork (Node2D)
    │   ├── WorldBounds (StaticBody2D)
    │   ├── Player (CharacterBody2D)
    │   │   └── FishingRod (Node2D)
    │   ├── FishingShack (Node2D)
    │   ├── ShackShop (Node)
    │   │   └── Sack (Node)
    │   ├── TrashManager (Node2D)
    │   ├── CatchableFishManager (Node2D)
    │   ├── CatchResolver (Node)
    │   └── PollutionSystem (Node)
    ├── HUD (CanvasLayer)
    ├── ShackPanel (CanvasLayer)
    └── CoinBalance (CanvasLayer)
```

The tree omits decorative nodes. The entry point owns the menu and running session. The session composes the world, HUD, trader, and coin balance. The level owns local gameplay and environmental presentation.

The level also creates footprint and splash nodes at runtime, plus a shader-backed sand overlay and static sand-detail node under `Environment`.

## Scene responsibilities

### Implemented fishing composition

`Player` owns a `FishingRod` and checks `is_active()` to lock movement outside `IDLE`. The rod owns an aiming pivot, a tip marker, separate `FishingLine` and `FishingHook` scenes, and a status label. The pivot rotates toward the world-space mouse position; line endpoints are converted into local coordinates.

The level derives an axis-aligned water rectangle from its rectangular ocean polygon and injects it into the rod. Translation/scaling is supported; rotated or nonrectangular water needs a polygon-based validator. Validation checks distance to water (140 px), a water target, and range (60–240 px for the starter rod), measured from the rod origin.

The normal cast follows `IDLE -> CASTING -> WAITING -> RETRIEVING -> IDLE`. A fish latch enters `TIMING` from `WAITING`. Success returns to `WAITING` with the fish secured, and a miss or timeout returns to `IDLE`. The target is fixed on cast. Hook ground position interpolates toward it while only the visual child receives `-4 * height * t * (1 - t)` on screen Y. Height is zero at both endpoints. Collision stays on the water plane. Retrieval interpolates back to the tip. Clicks during casting and retrieval are ignored.

The rod emits `state_changed`, `hook_landed`, `fish_timing_finished`, `retrieval_advanced(previous_position, current_position, hook_radius)`, `retrieval_completed`, and `target_detected`. The hook queries monitorable `Area2D` targets on layer 3 (`FishingTarget`) and emits detection for waiting overlaps. `CatchResolver` observes the lifecycle to select, attach, and finalize targets.

### Implemented cleanup composition

`World` owns a `TrashManager` (which contains unhooked trash), a `PollutionSystem`, and the existing player/environment. `Session` binds the HUD to these local instances. The rod supplies the total trash allowance for a cast and remains independent of the pollution model.

- `OceanTrash` is a reusable `Area2D` scene with bottle, can, and bag visuals. Each instance has a catch circle, type, and configurable pollution value. Vertical current moves the Area2D itself during physics updates; bobbing remains visual-only. All three types contribute five floating points by default.
- `TrashManager` starts with six nearshore items by default (seed 2026). The level computes a reachable shoreline segment from actual boundary shapes, player collider extents, and rod offset. Starter and offshore stop bands use the shoreline segment and the rod's base range. Every eight seconds the manager schedules an arrival if either band's slots allow it. Eight of twelve slots are reserved for the starter band. Candidates are spaced from floating items and reserved stop positions. Arrivals begin beyond the camera's ocean edge, ease toward their stops over nine seconds, and register for pollution as their centers enter the water.
- Each item receives seeded current speed (4–8 world pixels/second maximum) and phase. `configure_drift()` fits a cosine orbit with amplitude at most 80 px into the same reachable vertical limits used for spawning, preserving the initial position. X stays fixed, and the valid shoreline segment spans the full permitted Y range, so every starter-band drift position remains castable. Cosine velocity reaches zero at either end before reversing. Current moves detection geometry predictably; bobbing does not. There is no fluid simulation or object-to-object collision, so drifting items can cross each other after spawning.
- On `hook_landed`, the resolver selects the nearest available fish or trash whose own catch radius contains the landing position. This synchronous geometric check avoids stale physics overlap caches and prevents catches along the airborne path. `target_detected` remains an additional waiting-only hint; its handling is deferred to avoid reparenting during physics callbacks. Landing/waiting attachment remains limited to one item.
- During RETRIEVING the rod emits each actual hook movement segment, including the final segment **before** switching to IDLE. The resolver projects each current trash position onto the bounded segment and tests distance against `item.catch_radius + hook_radius` (defaults 24 + 10 px). This is a swept hook disk against the item's catch disk; neither the fishing line nor an infinite ray collects items. An empty landing can still sweep a piece on the way back without tunneling at high hook speeds. One shared trash limit covers landing, waiting, and retrieval.
- Hooking reparents each item to the hook's visual anchor, stops drift/bobbing, and disables monitorability. A compact five-column offset pattern keeps attached sprites distinct. Per-item flags and a typed held-item array prevent duplicates. Pollution and counts remain unchanged until `retrieval_completed` in IDLE. The resolver clears its held array first, stores each landed item in the Sack, and tells the target to finish collection. The trash manager sends the landed trash ID to the pollution model. The model consumes each ID once.
- `PollutionSystem` registers live IDs as they arrive and consumes each ID once on successful return. The total is the sum of floating points, capped at 30, and permanent points, bounded at 0–70. Permanent points start at 70. When both components are zero, the meter reaches 0% until another piece arrives. The pollution signal emits only when the capped total changes.
- The resolver’s `catch_hooked(type_name)` and `catches_returned(count, type_name)` feed cast-scoped HUD notifications, including misses. The level routes arrivals and successful collection to the model.

### Compact interface

The compact HUD shows live pollution, Sack usage, and gear tiers. The coin display sits above it. Short prompts follow movement, cast state, the Sack, and affordability. Rejected casts and results appear in a separate note. H or the clickable Help control toggles detailed controls without pausing. Informational controls ignore mouse input and the Menu button consumes its own clicks.

Swept detection samples each item's current physics position rather than solving continuous relative motion for moving trash. At the configured gentle current speed this keeps the implementation small; unusually fast currents would need relative-motion sweeps. The shoreline/water validator still assumes this axis-aligned rectangular level.

### Sack and fishing shack

The level injects its Sack into `Player` and `CatchResolver`. The Sack holds names and sale values across casts, applies a linear movement multiplier as it fills, and has three slots and a 12% full-load slowdown by default. The resolver checks Sack space and the rod's trash limit before attachment. It stores a successful return before finishing collection. Full Sack casts leave excess trash in the water.

`FishingShack` marks a short route inland from starter-range water. The player presses E in range with the rod idle. The session opens the full-screen `ShackPanel` and gates movement and rod input until the trader closes. The trader owns page navigation, keyboard focus, drag and drop, and its temporary sale selection. It selects individual `Sack.Entry` references, so identical catches remain distinct. `ShackShop` validates ownership and uniqueness, credits the selected entries once, and removes only those entries. The session-owned `CoinBalance` follows those transactions through gameplay, trading, and pause.

Typed `RodUpgrade` and `SackUpgrade` resources configure ordered upgrade tiers, their prices, and their effects. A purchase addresses a specific tier and debits only on success. The same shop sells configurable `CleanupProject` resources. It owns the completion flags for the session and applies each project’s stated reduction to `PollutionSystem` exactly once. Projects remove the entire 70-point permanent contribution when all are funded. Arrivals affect only floating points.

The level's `CleanupWork` scene listens for successful project purchases. It maps each project's work kind to an authored site and runs one visual sequence at a time after the trader closes. Each site draws its initial, working, and completed state. The session presents the site's watch cue through the HUD. The trader and the pause menu freeze work; replacing the session resets all sites and discards queued work.

### Pollution-responsive water

The level injects `PollutionSystem` into `Environment/Water` (`WaterVisuals`). It reads `normalized_pollution` immediately, then subscribes to `pollution_changed(normalized_pollution: float)`. Values range from 0 (clean) to 1 (initial pollution). The controller smoothly displays changes over 1.6 seconds using a finite Hermite interpolation; the HUD independently receives the true model value immediately. A private material is created once per water instance and only its `pollution_level` uniform changes during transitions.

`water.tscn` owns a procedural static Seabed (effective Z -10) and a ColorRect Surface with `shaders/ocean.gdshader` (Z -9). Beach, player, and floating trash stay at Z 0, fishing feedback at player-relative +5, and the HUD in its CanvasLayer. The old Ocean polygon stays hidden as the authority for bounds; old deep/shallow polygons and static foam are hidden. The new shader handles foam inside the same water rectangle, leaving collision and game coordinates unchanged.

The CanvasItem shader uses Hermite-interpolated value noise, weighted frequency layers, two nonparallel travelling sine waves, continuous dirty-to-clean palettes, and alpha compositing over real seabed geometry. It is isolated to the Surface and uses the existing GL Compatibility renderer. `displayed_pollution_changed(value)` lets ambient fish follow the same smoothed value. The model also exposes `permanent_points`, `floating_points`, `current_pollution`, `trash_collected`, and `remaining_trash`.

Fixtures can initialize explicit permanent and floating loads, including an entirely clean ocean. Scene reloads/rebinding synchronize immediately. Initial state is read when connecting after level readiness, avoiding missed initialization events. A separate `water_preview.tscn` demonstrates 1.0/0.5/0.0 with isolated materials and no game-state model. See [water-rendering.md](water-rendering.md) for equations, layering, tuning, capture commands, and performance limits.

### Ambient fish

The level owns `ambient_fish.tscn` alongside `Water` under `Environment`. After configuring water and binding it to the initialized pollution model, the level supplies the same authored rectangle and local `WaterVisuals` to the fish scene. The scene connects to `displayed_pollution_changed(value)` and reads `displayed_pollution` immediately, including at startup in an empty world. Fish tint and opacity follow the displayed value directly during a retarget.

The scene creates six copies of one `Polygon2D` silhouette and keeps them for its lifetime. Fixed ellipse centers, periods, and phases spread routes along the shore. Routes use the first 280 px of the water by default and reserve room for the rotated silhouettes. The layer draws at effective Z -8 above the surface and below the beach, floating trash, and fishing feedback. Fish are decorative CanvasItems with no physics or cleanup state.

Tune `early_reveal_pollution`, `late_reveal_pollution`, and `fade_width` on the `AmbientFish` instance. The defaults start the two groups at 0.79 and 0.43, stagger each group by 0.035 per fish, and apply a smoothstep fade over up to 0.24 pollution units. At displayed pollution 1.0, 0.5, and 0.0, the default layer shows zero, three, and six fish respectively across the shoreline. `nearshore_width`, `murky_tint`, and `clear_tint` set route width and tint/opacity endpoints.

### Catchable fish

`CatchableFishManager` reads true normalized pollution on each seeded spawn trial. The interval is four seconds, and the chance rises from 24% at 50% pollution to 85% at 0%. Above 50%, the manager skips arrivals and existing fish remain until their visit ends. There are at most three active visitors by default. The nearshore bounds fit each swim route within the starter rod's reach. The level connects the manager's spawn and departure signals to the catch resolver. Species, length ranges, rarity weights, sale bonuses, and colors are authored `FishSpecies` resources.

A catchable fish is a bright `FishingTarget` with a species sprite, split-ring cue, and collision on layer 3. A cast can attach one fish by landing or waiting and can collect trash on the return path. The Sack's space is shared by all pending catches. Fish have a timed visit that pauses when hooked. A hooked fish starts the rod's configurable timing state, which the HUD presents as a dial. A successful press allows retrieval and a miss or timeout makes the resolver release the fish. The session pause freezes the timer. Fish leave the manager when they escape or land, and the Sack keeps each landed fish's species, size, art, and sale price.

Starter, Shore and Offshore rod art shares a grip and tip coordinate. The shop applies the texture from each `RodUpgrade` alongside its cast settings.

### Beach detail and landing effects

Commit `2589291` adds three local presentation scripts and `shaders/sand.gdshader`. The level creates their nodes in `_ready()`. These nodes are owned by the running level's scene tree and are released with it.

- `footprints.gd` receives the player reference and measures actual movement in `_process()`. Every 26 pixels it places an alternating footprint with a six-pixel lateral offset. Prints fade over eight seconds and are capped at 80. The node draws after Environment and before Player at Z 0.
- `water_splash.gd` receives `hook_landed` through the level, with the landing position and true normalized pollution. It creates one 18-droplet `CPUParticles2D` burst with a 0.6-second lifetime and two expanding rings with a 0.18-second stagger and 0.9-second lifetime. Droplet nodes free themselves on `finished`. Rings are removed when their lifetime ends. The effect draws at Z 3 below the rod and hook at player-relative +5.
- The sand overlay is a mouse-ignoring ColorRect under Environment fitted to the Beach polygon's rectangle. Its private material combines smooth value-noise dunes, sine wind marks, and two-pixel grain with 0.32 alpha. Shader uniforms control colors, dune/grain strength, opacity, and area size.
- `sand_details.gd` generates ten pebble clusters, twelve shells, and eighteen wind arcs once with seed 2026, then uses cached draw commands. It uses bounded placement attempts and spacing for pebble-cluster and shell centers.

The sand overlay and detail positions derive from the authored Beach polygon. The detail inset keeps pebbles and shells away from wet sand. Footprint and splash nodes continue processing/redrawing while empty. Most effect settings are script constants rather than exported Inspector controls. Extracting a reusable presentation scene and exposing tuning are follow-up maintenance work.

### Menu and replay

`Main` starts at `SessionMenu` and owns a single instanced `session.tscn`. The menu activates its looping shoreline illustration while visible and owns focus and button feedback. New Game creates the first session. The HUD Menu button and Esc open the pause menu, with Esc closing an open trader first. Pause suspends the session and hides the HUD. The GPU water clock continues. Resume or Esc restores the session and HUD. Start fresh detaches and disposes of the old tree before adding a fresh instance. The entry point guards queued activation, and Save and Load are disabled buttons with no handlers. Gameplay fixtures can instantiate the session scene directly.

The menu, HUD, and trader share `ui/themes/coastal_field_guide.tres`. It defines sand-colored panels, brown borders and focus, ink text, and teal actions. The trader uses the menu's shoreline illustration with motion disabled. Trader and session menu controls capture pointer input before the rod's unhandled-input phase. The rod transforms mouse button event coordinates through the active viewport's canvas transform for aim accuracy after resizing.

## Systems and data flow

```text
Input -> Player / FishingRod
FishingRod lifecycle -> CatchResolver
TrashManager and CatchableFishManager spawn -> CatchResolver
CatchResolver completed return -> Sack
TrashManager.trash_arrived -> PollutionSystem.register_trash(item_id, points)
TrashManager.trash_collected -> PollutionSystem.collect(item_id)
CatchResolver hook and return events -> HUD notifications
FishingRod fish timing state -> HUD dial and outcome notification
ShackShop.purchases_changed -> CoinBalance and trader catalog
ShackShop.cleanup_funded -> CleanupWork -> HUD watch cue
PollutionSystem.pollution_changed -> HUD and WaterVisuals
WaterVisuals.displayed_pollution_changed -> AmbientFish
FishingRod.hook_landed -> Level -> WaterSplash (true pollution tint)
Player position -> Footprints
```

The rod reports lifecycle and hook positions. The resolver chooses and finalizes items. The trash manager reports each landed trash ID to the pollution model. The HUD and catchable fish manager read true pollution. Ambient fish follow the water's displayed value.

## State ownership

- Session pollution belongs to `PollutionSystem`, with a clear initial and minimum value.
- Fishing state belongs to `FishingRod` (IDLE, CASTING, WAITING, TIMING, RETRIEVING).
- Movement state belongs to `Player`. `Sack` provides the load multiplier and owns carried items. `ShackShop` owns coins and purchased tiers.
- Water clarity and ambient silhouettes follow an eased value. Catchable fish arrival probability uses true normalized pollution.
- Collectible configuration should move into typed custom `Resource` data only when multiple variants make that worthwhile.

## Initial technical choices

- Use `CharacterBody2D` and `move_and_slide()` for top-down movement.
- Use Godot input actions rather than checking physical keys in gameplay scripts.
- Use `Area2D`/collision layers for fishing targets and interaction detection.
- Use a shader parameter, modulate value, or layered sprites to transition water clarity; isolate the choice behind the water presentation scene.
- Use seeded nearshore and offshore trash arrivals with separate capacity limits.
- Avoid autoloads initially. Add a session/game-state autoload only when changing levels creates a demonstrated need for persistent state.
