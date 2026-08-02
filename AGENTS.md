# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.7.1 space-RTS prototype. `project.godot` points to `scenes/main.tscn`, while gameplay and UI logic live in `src/`. Keep reusable configuration types in `src/config/` and fixed-step simulation helpers in `src/simulation/`. Tunable Godot resources belong in `data/balance/`; change these instead of embedding balance values in gameplay scripts. Standalone headless checks live in `tests/`, and design decisions are documented in `docs/`. The local Godot binary under `.tools/godot/` is ignored by Git and launched through `scripts/godot`.

## Build, Test, and Development Commands

- `./scripts/godot --editor --path .` opens the project in the pinned editor.
- `./scripts/godot --headless --path . --editor --quit` imports assets and validates that the project loads.
- `./scripts/godot --headless --path . --script tests/test_simulation_lifecycle.gd` runs one focused test.
- `for f in tests/test_*.gd; do ./scripts/godot --headless --path . --script "$f" || exit 1; done` runs the complete suite.

There is no separate build system or linter configured; use Godot's parser and headless runs as the baseline validation.

## Coding Style & Naming Conventions

Follow existing typed GDScript: tabs for indentation, explicit parameter/return types, and typed collections where practical. Use `snake_case` for files, functions, and variables; `PascalCase` for named classes/resources; and `UPPER_SNAKE_CASE` for constants. Keep simulation changes deterministic at the configured 20 Hz physics rate. Prefer small domain scripts over further expanding `src/main.gd`.

## Testing Guidelines

Tests extend `SceneTree`, collect descriptive failures, call `quit(1)` on failure, and `quit(0)` on success. Name new files `tests/test_<behavior>.gd`. Add focused regression coverage for gameplay, lifecycle, navigation, weapon, or camera changes. Run the project load check and the full suite before submitting.

## Commit & Pull Request Guidelines

Recent history uses short, imperative, sentence-case subjects, for example `Fix simulation lifecycle and missile outcomes`. Keep each commit scoped to one coherent change. Pull requests should explain player-visible behavior, list validation commands, link the relevant issue or design document, and include screenshots or a short capture for visual/UI changes. Call out intentional changes to `data/balance/` explicitly.

## Agent-Specific Instructions

Automated contributors must read `/home/user/.codex/RTK.md` and prefix shell commands with `rtk`. Preserve unrelated working-tree changes and do not treat provisional values in `docs/equilibrage.md` as final design decisions.
