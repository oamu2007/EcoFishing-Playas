# EcoFishing Playas

EcoFishing Playas is a 2D top-down environmental fishing game set in Playas de Tijuana. Instead of catching fish, the player removes ocean trash; as pollution falls, the water clears and marine life returns.

The project includes a playable beach, fisherman movement, and a mouse-aimed cast/wait/retrieve loop. Trash collection and pollution tracking are planned next.

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

The command-line equivalent is:

```sh
godot --path .
```

## Project layout

- `assets/` — original sprites, tilesets, fonts, and audio
- `effects/` — reusable particle, animation, and visual-effect resources
- `scenes/` — modular gameplay, level, component, and UI scenes
- `scripts/` — typed GDScript organized by responsibility
- `shaders/` — Godot shaders and related resources
- `ui/` — shared interface themes and styles
- `docs/` — architecture and implementation planning

See [docs/architecture.md](docs/architecture.md) for the proposed system design and [docs/implementation-plan.md](docs/implementation-plan.md) for vertical-slice milestones. Contributor conventions are in [AGENTS.md](AGENTS.md).
