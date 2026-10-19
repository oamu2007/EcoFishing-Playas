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
- Use authored spawn markers for the vertical slice before considering procedural spawning.
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
