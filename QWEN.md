# QWEN.md — blobber-godot

## Project Overview

**blobber-godot** is a Godot 4.6 first-person grid crawler (blobber) game engine / template. It was built through a disciplined 15-day development plan to create a jam-safe, reusable foundation for grid-based dungeon crawlers. The project focuses on:

- **First-person, cardinal-only movement** on a square grid (full-cell steps, 90° turns only)
- **Configurable snap/smooth movement** with deterministic state reconciliation
- **Unified input pipeline** supporting keyboard, gamepad, and UI buttons
- **Passability/collision system** driven by GridMap occupancy
- **Input queue with anti-overlap protection** for deterministic command execution
- **Scene transition isolation** — overlay scenes (inventory, combat, town) pause exploration commands

The project is intentionally **game-agnostic** — it provides engine-like reusable systems only, not a specific jam game. It is designed to be branched at game jam start and extended with game-specific content.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Engine | Godot 4.6 (GL Compatibility renderer) |
| Physics | Jolt Physics (3D) |
| Language | GDScript 2.0 |
| Testing | GUT (Godot Unit Testing framework) |
| IDE | VS Code (with GUT extension) |
| Resolution | 1280×720 viewport stretch |

---

## Directory Structure

```
blobber-godot/
├── addons/gut/            # GUT testing framework plugin
├── assets/                # Art, audio, and other media
├── components/            # Reusable node components
│   ├── grid_entity.gd     # Base class for grid-based entities
│   └── movement_controller.gd  # Movement execution + smoothing
├── docs/                  # Development plans and documentation
│   ├── 15days_plan.md     # The original 15-day development plan
│   ├── day12_presets.md   # Config presets documentation
│   ├── day13_runbook.md   # Build readiness runbook
│   └── day14_compliance_checklist.md  # Jam-rule compliance checklist
├── models/                # Data models and domain types
│   ├── grid/              # GridState, GridDefinitions, GridMapper, GridCommand
│   └── input/             # Input mapping models
│   ├── character_stats.gd
│   ├── inventory.gd
│   ├── item_data.gd
│   ├── hostile_actor_definition.gd
│   ├── movement_outcome.gd
│   ├── rps_system.gd      # Rock-paper-scissors combat system
│   └── analysis/          # Analysis/scanning system models
├── resources/             # Resource files (.tres, .gd)
│   ├── movement_config.gd # Movement tuning Resource class
│   └── presets/           # Snap/smooth config presets
├── scenes/                # Godot scenes (.tscn)
│   ├── title/             # Title screen
│   ├── world/             # Exploration/world scenes
│   ├── player/            # Player character scene
│   ├── overlays/          # Inventory, combat, town overlays
│   └── hostiles/          # Enemy-related scenes
├── systems/               # Autoload / singleton systems
│   ├── game_boot.gd       # Game boot / initialization
│   └── scene_transition.gd # Scene transition with fade + loading overlay
├── tests/                 # GUT automated tests (48 test files)
├── ui/                    # HUD and UI components
├── project.godot          # Godot project configuration
└── hud_theme.tres         # HUD theme resource
```

---

## Key Architecture Concepts

### Grid State Machine

- **`GridState`** — Resource holding `cell: Vector2i`, `previous_cell: Vector2i`, `facing: Facing` (NORTH/EAST/SOUTH/WEST)
- **`GridEntity`** — Node3D base class that owns a `GridState` and a `MovementController`; processes commands via `execute_command()`
- **`MovementController`** — Executes commands (step/turn), handles smooth tweening, emits `action_started`, `action_completed`, `movement_outcome` signals

### Command Pattern

Commands are defined in `GridCommand.Type` enum and include:

- `STEP_FORWARD`, `STEP_BACK`, `MOVE_LEFT`, `MOVE_RIGHT` (translation)
- `TURN_LEFT`, `TURN_RIGHT` (rotation)

### Input Pipeline

All input sources (keyboard, gamepad, UI buttons) feed into a single command pipeline. Inputs are mapped in `project.godot` under `[input]`:

- WASD / Q-E for movement and turning
- Gamepad D-pad and face buttons
- Number keys 1-3 for item slots
- Space for pickup, E for interact, F for analyze
- R/T for cycle target prev/next

### Passability System

- GridMap-based occupancy extraction
- Physics layer 1 named "walls" for collision detection
- `passability_fn` Callable injected into `MovementController` for dynamic passability checks

### Scene Management

- **`SceneTransition`** autoload provides fade-to-black transitions with loading overlay
- **`GameBoot`** autoload handles game initialization

---

## Building and Running

### Prerequisites

- Godot 4.6+ installed
- GUT plugin enabled (already configured in `project.godot`)
- VS Code with GUT extension (optional, for running tests from IDE)

### Running the Game

1. Open the project in Godot 4
2. Press **Run Project** (`F5`)
3. The title screen appears — select **Start Game** to enter the exploration world

### Running Tests (GUT)

**From VS Code:**

1. Open Command Palette
2. Run: `GUT: Run All Tests`

**From Godot Editor:**

- Open the GUT panel from the bottom panel and click **Run All**

**From CLI (headless):**

```bash
godot --headless --path /Users/kc00l/blobber-godot -s res://addons/gut/gut_cmdln.gd
```

Configuration is in `.gutconfig.json` — tests live under `res://tests/`.

---

## Development Conventions

### Coding Style

- GDScript 2.0 with `class_name` for globally accessible types
- Resources (`.tres`) for config data; `Resource`-extending classes for models
- Signals for event-driven communication (e.g., `action_completed`, `command_completed`, `movement_outcome`)
- Snake_case for functions and variables (GDScript convention)
- Typed variables and return types preferred

### Testing Practices

- One test file per feature/module, named `test_<module>.gd`
- GUT framework for assertions and test lifecycle
- Compliance rehearsal tests exist (e.g., `test_day14_compliance_rehearsal.gd`)
- Tests cover: roundtrip accuracy, passability, input normalization, camera sync, collision feedback, scene isolation

### Design Principles

- **Deterministic**: same input script always produces identical state history
- **No drift**: end-of-action hard snap to canonical grid state
- **Anti-overlap**: one-command queue, tween protection, single completion signal per action
- **Isolation**: overlay scenes guarantee zero movement commands during their active phase

---

## Relevant Autoloads

| Autoload | Path | Purpose |
|---|---|---|
| `GameBoot` | `systems/game_boot.gd` | Game initialization, engine start time tracking |
| `SceneTransition` | `systems/scene_transition.gd` | Scene transitions with fade + loading overlay |

---

## Key Resources

- **`15days_plan.md`** — Full development plan with deliverables and exit criteria for each day
- **`day13_runbook.md`** — Startup expectations, manual run instructions, troubleshooting
- **`day14_compliance_checklist.md`** — Jam-rule compliance sign-off (first-person, full-step, cardinal turns)
- **`movement_config.tres`** — Default movement tuning (cell_size=1.0, smooth_mode=true, step_duration=0.08s, turn_duration=0.06s)
