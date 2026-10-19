# EcoFishing Playas contributor guide

## Project scope

EcoFishing Playas is a 2D top-down environmental fishing game built with Godot 4 and GDScript. Keep the project runnable in Godot 4, dependency-free, and focused on a small playable vertical slice before expanding its scope.

## Directory conventions

- `scenes/`: Composed Godot scenes. Group reusable parts in `components/`, moment-to-moment play in `gameplay/`, maps in `levels/`, and interface scenes in `ui/`.
- `scripts/`: GDScript source. Mirror scene ownership where useful; put reusable behavior in `components/`, coordinating logic in `systems/`, and interface controllers in `ui/`.
- `assets/`: Source art, audio, fonts, sprites, and tilesets that Godot imports.
- `shaders/`: Godot shader source and shader resources.
- `effects/`: Reusable particle, animation, material, and visual-effect resources.
- `ui/`: Shared themes, style boxes, and other interface resources. UI scene files remain in `scenes/ui/`.
- `docs/`: Architecture, planning, and design notes.

## Godot and GDScript conventions

- Use Godot 4 APIs and syntax only. Do not introduce compatibility code for Godot 3.
- Use typed GDScript for properties, parameters, return values, collections, signals, and local variables when the type is knowable.
- Use `class_name` only for genuinely reusable project-wide types. Avoid filling the global class namespace with scene-specific controllers.
- Use `snake_case` for files, variables, functions, and signals; `PascalCase` for named classes and node types; and `SCREAMING_SNAKE_CASE` for constants.
- Keep scripts focused on one responsibility. Prefer composition with child nodes/resources over deep inheritance trees.
- Export tunable gameplay values with `@export` and give them explicit types. Keep balancing values out of hard-coded control flow.
- Cache required nodes with typed `@onready` properties. Use unique node names or exported node references when that makes scene refactors safer.
- Treat warnings as useful design feedback. Avoid suppressing warnings without a short reason.

## Scene design

- Build features as modular scenes with clear public interfaces. A scene should own its internal node layout and expose behavior through methods, exported configuration, and signals.
- Keep the main level responsible for composition, not detailed feature logic.
- Prefer reusable components for movement, interaction targets, collectibility, pollution contribution, and health/state where appropriate.
- Avoid brittle absolute node paths across scene boundaries. Communicate through the nearest owning coordinator or a deliberately injected reference.
- Keep runtime state separate from presentation when practical so visuals can change without rewriting game rules.

## Signals and communication

- Use signals for events that other components may observe, such as trash collected, pollution changed, cast completed, or fish availability changed.
- Name signals as events in the past tense or as state changes, and type their arguments.
- Connect signals in the scene editor for stable local relationships and in code for dynamically instantiated nodes.
- Prefer direct typed method calls for commands to a known dependency. Prefer signals for notifications and sibling/parent decoupling.
- Do not use a global event bus by default. Add autoloads only for truly cross-scene state or services, and document each one in `docs/architecture.md`.

## Maintainability and verification

- Keep gameplay deterministic enough to test individual systems without requiring the full level.
- Add comments for intent and constraints, not line-by-line narration.
- Update architecture and implementation notes when introducing a new top-level system, autoload, or scene boundary.
- Do not commit `.godot/`, generated imports, local editor state, or exported builds. Commit original assets and project resources needed to reproduce imports.
- Before handing off a change, open the project in Godot when available, check for parser/import errors, and run the main scene when one exists.
