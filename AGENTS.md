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

## Git Collaboration Rules

- Never commit or push automatically unless explicitly requested.
- Never modify unrelated files.
- Do not rewrite Git history.
- Work on feature branches for gameplay changes.
- Keep scenes modular to minimize merge conflicts.
- Explain every significant change.
- Run available checks before marking a task complete.
- Do not commit generated Godot cache files.
- Keep main stable and playable.

## Codex roadmap execution

- Use `docs/implementation-plan.md` as the gameplay roadmap. When the user authorizes a roadmap run, proceed through all authorized milestones in dependency order on a feature branch that includes the required baseline. Continue after each milestone without asking for approval. A milestone-specific request authorizes that milestone.
- The lead owns shared interfaces, scene wiring, and integrated verification. Choose configurable, reversible defaults for ordinary tuning. At each milestone, run the relevant Godot checks, record the outcome, decisions, pending checks, and next step in the roadmap, and continue. Diagnose failures and pursue independent work while resolving them. Reserve completion for milestones whose acceptance checks are satisfied.
- Delegate when there is an independently checkable task, such as tracing a regression, reviewing an integration, or implementing an isolated component. Use GPT-6.2 Sol at medium effort when available. Keep delegation narrow and run one subagent at a time by default. Give it the relevant milestone excerpt, file scope, and acceptance criteria. Ask for a concise report with file references and check results. For write tasks, give the worker explicit file ownership and keep concurrent edits disjoint. The lead verifies every delegated result.
- For a consequential technical decision with competing approaches, consult one read-only GPT-6.2 Astra subagent at medium effort when available. Give it the evidence, options, and constraints, and ask for a recommendation and tradeoffs. The lead decides within the authorized vision. If the model is unavailable, assess the tradeoffs with the available model.
- Ask the user when the roadmap reserves a decision for them, including the M11 UI theme, or when a choice materially changes the agreed player experience or scope. State the options, your recommendation, and the work that depends on the answer. Continue independent work while waiting. Pause only when the remaining work depends on that answer or a genuine blocker. Apply the Git collaboration rules above throughout the run.
