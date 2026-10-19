# Pollution-responsive ocean: graphics study

## Run and demonstrate

Open `scenes/levels/water_preview.tscn` and press F6 for a live, side-by-side 100% / 50% / 0% comparison. All panels use the same shader, geometry, seabed seed, and GPU animation clock. There is no pollution model or trash manager in this scene. F5 still launches the normal game.

In gameplay, the HUD reports actual pollution immediately; the water eases toward it over 1.6 seconds. Clearing the level reveals sand patches and submerged rocks through the cyan surface. Slow waves and shoreline foam continue at both endpoints.

## Coordinates and color

The surface is a ColorRect inside `water.tscn`. Its normalized UV coordinates become local water-plane coordinates:

```text
p = UV * water_size
depth = smoothstep(0, 0.9, UV.x)
D = smoothstep(0, 1, clamp(pollution_level, 0, 1))
C_clean = mix(clean_shallow, clean_deep, depth)
C_dirty = mix(dirty_shallow, dirty_deep, depth)
C = mix(C_clean, C_dirty, D)
```

This creates a continuous, near-to-deep color gradient. At pollution 0.5, the two palettes contribute equally, producing subdued turquoise. At 1, the green-gray/brown teal palette dominates; at 0, the blue/cyan palette dominates. There are no discrete pollution thresholds or texture swaps. Source-color uniforms let the Compatibility renderer handle color inputs consistently.

Local water coordinates keep the pattern fixed to the level rather than to the camera. No vertices, collisions, fishing targets, or spawn coordinates are distorted.

## Value noise and suspended sediment

`hash21()` produces a reproducible pseudo-random scalar at integer lattice coordinates using `fract`, multiplication, and a dot product. `value_noise()` samples four lattice corners and interpolates them with cubic Hermite weights:

```text
cell = floor(q); f = fract(q)
u = f*f*(3 - 2*f)
N(q) = mix(mix(h00,h10,u.x), mix(h01,h11,u.x), u.y)
```

Hermite weights have zero slope at cell boundaries, avoiding hard grid transitions and pixelated noise. The moving domain is:

```text
t = TIME * wave_speed
q = p/135 + (0.025, -0.017)*t
cloud = 0.57*N(q) + 0.29*N(2.03*q + offset1)
      + 0.14*N(4.07*q + offset2)
```

The three weighted frequency bands add organic variation without a texture asset or CPU noise image. Noninteger frequency ratios/offsets reduce obvious repetition. A fourth value-noise sample advects more slowly to suggest suspended sediment. Its warm sediment color contribution is weighted by `D * murkiness`, so cleanup removes the muddy appearance continuously.

Noise contrast stays small (roughly 0.035–0.085 before weighting) to avoid hiding trash. There are no scrolling hard noise cells, quantized bands, screen-space distortion, or temporal random numbers; animation samples a spatially smooth field continuously.

## Travelling waves and shoreline foam

Two nonparallel waves use different spatial frequencies, directions, and time coefficients:

```text
wa = sin(dot(p,(0.85,0.53))*0.038 - 0.9*t + 0.7*cloud)
wb = sin(dot(p,(-0.35,0.94))*0.061 + 0.67*t + 0.5*cloud)
ripple = 0.5 + 0.5*(0.6*wa + 0.4*wb)
highlight = smoothstep(0.62,0.98,ripple) * wave_strength
```

For a plane wave `sin(k·p - omega*time)`, phase travels perpendicular to its crests with speed `omega / |k|`. At default wave_speed 0.35, the components travel at approximately 8.3 and 3.8 world pixels/second before the subtle noise warp. This is a calm surface, not a physical wave solver. Highlights remain low contrast and exist at every pollution level.

Two narrow smoothstep ribbons follow a slowly changing shore-side position:

```text
edge(y,t) = 10 + 3*sin(0.022*y + 0.55*t)
              + 2*sin(0.051*y - 0.37*t)
foam = 1 - smoothstep(inner_width, outer_width, abs(p.x-edge))
```

The second ribbon lies 18 px farther out. Foam remains entirely inside the water rectangle. Its tint becomes slightly muted in dirty water. The beach boundary never moves; only the optical edge does.

## Visibility through alpha compositing

The seabed is actual cached CanvasItem geometry: a colored base, 13 gently irregular sand patches, and 18 small rock silhouettes. It is not a generated image or a baked screen color.

```text
alpha_clean = mix(0.56, 0.83, depth)
alpha = mix(alpha_clean, 0.985, D*murkiness)
C_final = alpha*C_surface + (1-alpha)*C_seabed
```

With default murkiness, clean water transmits 44% of the nearshore bed and 17% of the deep bed, while fully dirty water transmits only 1.5%. Both color and visibility are continuous across the complete pollution range. Small rocks and restrained sand colors remain beneath the gameplay layer, so this detail cannot hide trash or the hook.

## Time-domain transition

`WaterVisuals` reads `PollutionSystem.normalized_pollution` on binding, then subscribes to `pollution_changed`. It never changes the model or HUD. Each new target records the currently displayed value and restarts a finite Hermite transition:

```text
r = clamp(elapsed / 1.6, 0, 1)
w = r*r*(3 - 2*r)
displayed = mix(start_displayed, target_pollution, w)
```

This reaches the target exactly without overshoot. Retargeting during collection starts from the displayed value, avoiding a discontinuity in color/opacity (velocity can change when a transition restarts). Initial scene load, empty scenes, dependency rebinding, and scene reloads synchronize immediately. GPU TIME keeps animating after the controller stops its idle CPU processing.

The controller owns one private ShaderMaterial duplicated once on readiness. Only the scalar uniform changes during interpolation. `displayed_pollution_changed(value)` is available for future synchronized visual effects; the true model signal remains the interface for immediate gameplay rules.

## Draw order and scope

| Layer | Effective Z / canvas | Responsibility |
| --- | --- | --- |
| Seabed | -10 | Static submerged geometry |
| Surface and shader foam | -9 | Color, waves, murkiness, transparency |
| Beach / player / floating trash | 0 | Existing gameplay presentation |
| Rod / line / hook / aim marker | +5 relative to player | Fishing feedback |
| HUD | CanvasLayer | Existing compact counters/help |

The original `Environment/Ocean` polygon is retained hidden as the authoritative authored bounds. Legacy deep/shallow polygons and static foam lines are hidden; the new scene replaces only their drawing. Collision nodes, player, fishing, trash physics, and pollution math are unchanged. The shader is attached only to `Water/Surface`, never to a parent shared with gameplay nodes.

## Artist controls

Select a Water instance's Surface material to tune `clean_shallow`, `clean_deep`, `dirty_shallow`, `dirty_deep`, `sediment_color`, `wave_speed`, `wave_strength`, `murkiness`, and `foam_strength`. Controller `transition_duration` sets the cleanup response time. `water_size` is configured from the level bounds. Defaults target this scene's 960×540 base viewport.

`use_time_override` / `time_override` are reserved for the separate render harness to compare the same wave phase. Gameplay and the live preview leave override disabled and use TIME normally.

## Screenshots for a class presentation

Run this command **without** `--headless` so a real OpenGL shader is compiled and rendered:

```sh
godot --path . --script res://tests/water_render_check.gd
```

The brief window closes automatically and writes ignored, reproducible captures under `.godot/water_captures/`:

- `comparison.png`: the labeled three-panel study.
- `dirty.png`, `midway.png`, `clean.png`: identical gameplay framing, a visible landed hook/line and trash, fixed wave time, and a label identifying the visual-only preview. Actual pollution/trash counts are unchanged by capture.

For slides, use comparison.png first, then the three full-scene images in pollution order. Copy these generated files somewhere permanent before clearing the Godot cache. For a live animated demonstration, open the preview scene and press F6. Capture a short video there, then switch to F5 to demonstrate actual retrieval, immediate HUD accounting, and the 1.6-second water transition.

## Verification and performance

`water_smoke_test.gd` checks initial state, model changes, immediate numerical HUD updates, finite interpolation/clamping, material isolation/reuse, rebinding, reset, and empty-level behavior. Previous fishing, cleanup, and refinement tests remain intact.

`water_render_check.gd` checks image differences among palettes, stronger visibility of actual seabed as pollution falls (by temporarily hiding the bed), animation at both endpoints, and unchanged gameplay state. The sampled image difference is an RGB regression check, not a physical turbidity measurement. On the tested Intel Iris Xe OpenGL device, the dirty/mid/clean seabed differences were approximately 0.0017 / 0.0200 / 0.0384, with zero render-check failures. Screenshots were visually inspected.

The shader uses one transparent surface pass, four value-noise evaluations (16 inexpensive corner hashes), two ripple sine components, and two shoreline sine components per fragment. It needs no external textures, screen reads, render targets, compute shaders, particles, or renderer changes. Seabed commands are cached; there is no CPU-side per-pixel work during gameplay. Screenshot pixel sampling occurs only in the developer render check.

Cost scales with visible water pixels/window resolution and transparent overdraw; 4K windows or very low-end devices still need profiling. A warmed-up 90-frame observation at 960×540 on the tested Iris Xe averaged approximately 8.3 ms wall time per frame, including display pacing; this is not isolated GPU timing or a portable benchmark. The render check verifies the existing GL Compatibility path on one device, not all GPUs or a guaranteed frame rate. Gameplay assumes the existing axis-aligned rectangular shoreline; there is no physical refraction or water simulation. Fish and particles are intentionally deferred.
