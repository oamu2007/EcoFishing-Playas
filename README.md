# EcoFishing Playas

EcoFishing Playas is a 2D top-down environmental fishing game set in Playas de Tijuana. Instead of catching fish, the player removes ocean trash; as pollution falls, the water clears and marine life returns.

The project includes a playable beach, fisherman movement, mouse-aimed fishing, and a complete trash cleanup loop. Retrieve bottles, cans, and bags to reduce pollution and finish the finite cleanup session. Water clarity and fish presentation are planned next.

## Requirements

- Godot Engine 4.7 or another compatible Godot 4 release
- No external packages or plugins

## Open the project

1. Launch the Godot Project Manager.
2. Select **Import**.
3. Choose the `project.godot` file in this repository.
4. Open the imported project in the editor.

From a terminal with Godot available on `PATH`, you can also open the editor from the repository root:

```sh
godot --editor --path .
```

On systems where the executable is versioned, use `godot4` instead of `godot`.

## Run the project

Press **F5** to run. Move with **WASD or arrow keys**. Approach the shoreline, aim into the ocean with the mouse, and **left click** when the target is green. After landing, **left click again** to retrieve. Movement locks until retrieval completes. A red marker/status message explains invalid casts.

Aim at or near a trash item's center to hook one item on landing. During retrieval, the hook also collects trash crossed along its return path, with small offsets for held items. Cast beyond several aligned objects to collect a batch. All held items count only after returning to the fisherman. A completely empty cast/return does not change pollution. Walk along the shoreline to reach the whole batch.

The default session spawns 24 initially separated, reachable items using seed 2026. Trash drifts gently up/down with seeded variation and smooth turnarounds inside reachable water. Mint bottles remove 10 pollution units, orange cans 15, and cream bags 20. The compact HUD shows collected/total and pollution percentage; **H** toggles detailed controls. Catch notifications and completion use small text. Collect all items to finish; items do not respawn. Stop with **F8** and run with **F5** to reset.

The level's `TrashManager` node exposes batch count/cap, seed, spacing, shoreline clearance, and catch-radius settings in the Inspector. Pollution totals use the actual spawned batch, including an empty batch. The [architecture notes](docs/architecture.md) document `PollutionSystem.normalized_pollution` and `pollution_changed` for future water-shader/fish presentation.

The command-line equivalent is:

```sh
godot --path .
```

## Headless verification

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/fishing_smoke_test.gd
godot --headless --path . --script res://tests/cleanup_smoke_test.gd
godot --headless --path . --script res://tests/refinement_smoke_test.gd
godot --headless --path . --quit-after 120
```

Visual clarity, mouse aiming after resizing, and the feel of the full cleanup loop still require an interactive run. Detailed acceptance steps are in [the implementation plan](docs/implementation-plan.md).

## Project layout

- `assets/` — original sprites, tilesets, fonts, and audio
- `effects/` — reusable particle, animation, and visual-effect resources
- `scenes/` — modular gameplay, level, component, and UI scenes
- `scripts/` — typed GDScript organized by responsibility
- `shaders/` — Godot shaders and related resources
- `ui/` — shared interface themes and styles
- `docs/` — architecture and implementation planning

See [docs/architecture.md](docs/architecture.md) for the proposed system design and [docs/implementation-plan.md](docs/implementation-plan.md) for vertical-slice milestones. Contributor conventions are in [AGENTS.md](AGENTS.md).
