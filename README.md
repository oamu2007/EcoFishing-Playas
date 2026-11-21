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

Press **F5**, then choose **New Game**. Move with **WASD or arrow keys**. Approach the shoreline, aim into the ocean with the mouse, and **left click** when the target is green. After landing, **left click again** to retrieve. Movement locks until retrieval completes. The aiming marker turns red outside the cast range. **H** or **Help** shows the reason and other prompts.

Aim at or near a trash item's center to hook one item on landing. During retrieval, the hook also collects trash crossed along its return path, with small offsets for held items. Upgraded rods can collect several aligned objects in one return, subject to the space in the Sack. All held items count only after returning to the fisherman. A cast attempt at capacity briefly shows **Sack full**, even with Help hidden. An empty return leaves the Sack and cleanup progress unchanged. New trash can still raise the meter independently. Walk along the shoreline to find more targets.

The session starts with six reachable pieces. New trash drifts in from offshore at 44 world pixels per second and settles within the equipped rod's horizontal reach. An arrival can start every eight seconds when a population slot is available. Three full starter Sack trips fund the first rod upgrade. Each piece contributes five floating points once in the water, up to a 30-point floating cap. The session starts with 70 permanent points.

With the rod idle, press **E** near the fishing shack. On the Sell screen, choose **Sell All** or press **F** to sell the whole Sack, including items staged in the tray. Drag or select individual items and choose **Sell selected** for a partial sale. **Back (B)** returns to trader home from Buy or Sell and clears any sale in progress. **Esc** first cancels an active drag, then steps back one page at a time. **E** and **Return to shore** close the trader. Buy offers rods, Sacks, add-ons, and eleven cleanup projects. Each rod has independent add-on ownership and shows its fitted pieces in hand. Fund a cleanup project and return to shore to see the crew at work. Your gold balance stays at the top left.

New catchable fish visit at 50% pollution or below. Aim at their moving white rings. When a fish latches, click or press **Space** as the marker crosses the green arc. The arc changes position between checks and the dial counts your progress. Common fish need one check, surfperch and kelp bass need two shorter checks, and the California sheephead trophy needs three. After the dial confirms the catch, click to reel it in. Slip guard retries one missed input per hooked fish, and Quick spool shortens casts and reels. Larger and rarer fish sell for more gold. After funding every project, clearing the floating trash can bring the water to 0% between arrivals.

To practice with stock gear, open [`tests/fish_timing_review.tscn`](tests/fish_timing_review.tscn) in Godot and press **F6**. Press **1** for a common fish, **2** for a rare fish, or **3** for a trophy. Each key starts a cast into a live swim route.

Press **H** or click **Help** to reveal controls and contextual text. Open **Menu** or press **Esc** from play to pause. Use **Resume** or **Esc** to continue. **Start fresh** and **Quit to title** ask for confirmation before discarding progress. **Save** and **Load** are inactive. The background track continues across screens and sessions. [Asset credits](docs/asset-credits.md) lists the music, effects, and fonts.

The level's `TrashManager` exposes the starting band, arrival speed and cadence, stopping inset, population cap, seed, spacing, and catch radius in the Inspector. The HUD updates immediately while water clarity and ambient fish visibility ease toward the new state over 1.6 seconds. The `AmbientFish` node exposes reveal thresholds, fade width, tint, and nearshore route width. [Architecture notes](docs/architecture.md) describe the bindings and tuning.

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
godot --headless --path . --max-fps 60 --script res://tests/audio_smoke_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/playthrough_smoke_test.gd
godot --headless --path . --max-fps 60 --script res://tests/startup_check.gd
```

The playthrough test drives two seeded sessions at 1280 × 720 and 800 × 450 and reports the pacing checkpoints. Omit `--headless` to run the same route with rendering enabled or to run the audio smoke test with the system audio driver. To compile the water shader and capture comparison images, run `godot --path . --script res://tests/water_render_check.gd`. Captures go to the ignored `.godot/water_captures/` directory. The [implementation plan](docs/implementation-plan.md) records the playthroughs, GPU checks, and remaining manual checks.

## Project layout

- `assets/` — original sprites, tilesets, fonts, and audio
- `effects/` — reusable particle, animation, and visual-effect resources
- `scenes/` — modular gameplay, level, component, and UI scenes
- `scripts/` — typed GDScript organized by responsibility
- `shaders/` — Godot shaders and related resources
- `ui/` — shared interface themes and styles
- `docs/` — architecture and implementation planning

Milestone status and checkpoint results are in the [implementation plan](docs/implementation-plan.md). Contributor conventions are in [AGENTS.md](AGENTS.md).
