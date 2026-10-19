# EcoFishing Playas

EcoFishing Playas is a 2D top-down environmental fishing game set in Playas de Tijuana. Instead of catching fish, the player removes ocean trash; as pollution falls, the water clears and marine life returns.

The repository currently contains the Godot 4 project foundation, directory conventions, and a plan for the first playable vertical slice. Gameplay has not been implemented yet.

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

There is no main scene yet because gameplay implementation has intentionally not started. After the first implementation milestone creates and assigns a main scene, run it with **F6** for the current scene or **F5** for the project.

The command-line equivalent, once a main scene exists, is:

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
