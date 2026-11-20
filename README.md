# EcoFishing Playas

EcoFishing Playas is a 2D top-down environmental fishing game set in Playas de Tijuana. Start by fishing trash out of the ocean. Fund cleanup at the fishing shack to clear the water and bring back catchable fish.

The project includes a playable beach, fisherman movement, mouse-aimed fishing, and a complete trash cleanup loop. Retrieve bottles, cans, and bags to reveal the seabed and bring marine life back to the shoreline.

The beach also has procedural sand grain, wind marks, pebbles, and shells. Walking leaves alternating footprints that fade over eight seconds. Hook landings produce a brief droplet burst and two expanding ripples, tinted by the current pollution.

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

Press **F5**, then choose **Start session**. Move with **WASD or arrow keys**. Approach the shoreline, aim into the ocean with the mouse, and **left click** when the target is green. After landing, **left click again** to retrieve. Movement locks until retrieval completes. A red marker and a HUD message explain rejected casts.

Aim at or near a trash item's center to hook one item on landing. During retrieval, the hook also collects trash crossed along its return path, with small offsets for held items. Upgraded rods can collect several aligned objects in one return, subject to the space in the Sack. All held items count only after returning to the fisherman. An empty return leaves the Sack and cleanup progress unchanged. New trash can still raise the meter independently. Walk along the shoreline to find more targets.

The session starts with six reachable pieces. New trash drifts in from offshore, and the starter rod returns one piece per cast. Each piece contributes five floating points while in the water. Floating pollution caps at 30 points and the session starts with 70 permanent points.

With the rod idle, press **E** near the fishing shack. On the Sell screen, drag items into the sale tray or select them with the mouse or keyboard, then choose **Sell selected**. Open Buy for rods, Sacks, and permanent cleanup. **E**, **Esc**, and **Return to shore** close the trader. After funding a cleanup project, return to shore and follow the cue to see the crew at work. Your gold balance stays at the top left.

New catchable fish visit at 50% pollution or below. Aim at their white split rings. When a fish latches, click or press **Space** as the marker crosses the green arc, then click to reel it into the Sack. A fish already in the water can finish its visit after a rebound. Larger and rarer fish sell for more gold. After funding every project, clearing the floating trash can bring the water to 0% between arrivals.

Press **H** or click **Help** for controls. Open **Menu** or press **Esc** when the shop is closed. Use **Resume session** or **Esc** to continue, or **Start fresh** to reset the session.

The level's `TrashManager` exposes starter and offshore stop bands, arrival cadence, population limits, seed, spacing, and catch radius in the Inspector. The HUD updates immediately while water clarity and ambient fish visibility ease toward the new state over 1.6 seconds. The `AmbientFish` node exposes reveal thresholds, fade width, tint, and nearshore route width. [Architecture notes](docs/architecture.md) describe the bindings and tuning.

For the graphics-course demonstration, open `scenes/levels/water_preview.tscn` and press **F6** to compare animated 100%, 50%, and 0% states without changing gameplay. [Water rendering](docs/water-rendering.md) explains the shader mathematics and artist controls and gives exact screenshot instructions.

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
godot --headless --path . --script res://tests/water_smoke_test.gd
godot --headless --path . --script res://tests/fish_smoke_test.gd
godot --headless --path . --script res://tests/shop_smoke_test.gd
godot --headless --path . --script res://tests/cleanup_projects_smoke_test.gd
godot --headless --path . --script res://tests/catchable_fish_smoke_test.gd
godot --headless --path . --script res://tests/session_flow_smoke_test.gd
godot --headless --path . --script res://tests/trader_smoke_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/playthrough_smoke_test.gd
godot --headless --path . --quit-after 120
```

To compile and render the shader on the GPU and write comparison images, also run `godot --path . --script res://tests/water_render_check.gd` without `--headless`. Captures go to the ignored `.godot/water_captures/` directory. The [implementation plan](docs/implementation-plan.md) records the playthroughs, GPU checks, and known limitations.

## Project layout

- `assets/` — original sprites, tilesets, fonts, and audio
- `effects/` — reusable particle, animation, and visual-effect resources
- `scenes/` — modular gameplay, level, component, and UI scenes
- `scripts/` — typed GDScript organized by responsibility
- `shaders/` — Godot shaders and related resources
- `ui/` — shared interface themes and styles
- `docs/` — architecture and implementation planning

Milestone status and checkpoint results are in the [implementation plan](docs/implementation-plan.md). Contributor conventions are in [AGENTS.md](AGENTS.md).
