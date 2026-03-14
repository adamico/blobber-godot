# Plan: DCJam 2026 — Missing Features Build

Five milestones. M1 is a strict prerequisite for everything else. M4 model work can start in parallel with M2.

---

## M1 — Entity & Stats Foundation
*Everything downstream depends on this.*

### Class design sketch

**`CharacterStats` — `res://models/character_stats.gd`** (`extends Resource`)
- `@export var max_health: int`, `var health: int`, `@export var attack: int`, `@export var defence: int`
- `signal damaged(amount: int, old_health: int, new_health: int)`
- `signal healed(amount: int, old_health: int, new_health: int)`
- `func take_damage(amount: int)` — applies defence, enforces minimum 1 damage, clamps to 0, emits `damaged`
- `func heal(amount: int)` — clamps heal input to non-negative, clamps to `max_health`, emits `healed`
- `func fill() -> void` — restores to full (`max_health`), emits `healed` when health changes
- `func is_dead() -> bool`

**`GridEntity` — `res://components/grid_entity.gd`** (`extends Node3D`)
*Shared by Player and Enemy via inheritance. No visuals here.*
- **Owns:** `var grid_state: GridState`, `var movement_controller: MovementController`, `var stats: CharacterStats`, `@export var movement_config: MovementConfig`
- **Shared setup:** `_ready()` creates `GridState`, `MovementController`, connects `action_completed` → `_on_action_completed()`
- **Shared API:**
  - `func execute_command(cmd: GridCommand.Type) -> bool` — passthrough to `movement_controller`, guarded by `command_processing_enabled`
  - `func pause_commands() / resume_commands()` — sets `command_processing_enabled`; `resume_commands()` drains the queue
  - `func _apply_canonical_transform()` — syncs `global_position` + `rotation_degrees.y` from `grid_state`
  - `func _on_action_completed(cmd, new_state)` — updates `grid_state`, calls `_apply_canonical_transform()` — **virtual**, subclasses call `super()`
- **One-command queue:** `_queued_command` + `_enqueue_command()` + `_drain_queued_command()` live here (identical logic currently in `Player`)

**`Player` — `res://scenes/player/player.gd`** (`extends GridEntity`)
*Keeps everything that is camera- or input-specific.*
- **Adds:** `@export var eye_height`, `@onready var _camera: Camera3D`, `@export var input_actions_enabled`
- **Adds:** `signal blocked_feedback_cue(cmd)`
- **Adds:** `_active_tween`, `_blocked_tween` — smooth position/yaw animation on `action_started`
- **Overrides:** `_on_action_completed()` — kills tween, calls `super()`, drains queue, logs debug
- **Adds:** `_unhandled_input()`, `execute_action()`, `_find_pressed_action()`, `_command_for_action()` — input pipeline, Player-only
- **Adds:** `_play_blocked_feedback()`, `_cancel_blocked_feedback()` — bump animation, Player-only
- **Adds:** `_sync_camera_height()`, `_resolve_target_yaw()` — camera helpers

**`Enemy` — `res://scenes/enemies/enemy.gd`** (`extends GridEntity`) *(implemented in M2)*
*Keeps everything that is AI- or visual-specific.*
- **Adds:** reference to `EnemyAI` node (or inline `_choose_intent()`)
- **Adds:** `MeshInstance3D` for in-world visibility (in `.tscn`, not in script)
- **Overrides:** `_on_action_completed()` — calls `super()`, notifies `EnemyAI` that the move finished
- No input, no camera, no tween (snap movement only for now; smooth upgrade possible later)

### Build steps

1. Create `CharacterStats` resource as designed above
2. Create `GridEntity` base class — extract `grid_state`, `movement_controller`, `movement_config`, queue logic, `execute_command()`, `pause/resume_commands()`, `_apply_canonical_transform()`, `_on_action_completed()` from current `Player`
3. Refactor `Player` to `extends GridEntity` — delete extracted code, keep camera/input/tween/feedback logic, override `_on_action_completed()` with `super()` call
4. Add `stats: CharacterStats` to `GridEntity._ready()` (default-constructed if null)
5. Add `COMBAT` state to `GameStateMachine` + `to_combat()` / `is_combat()` methods
6. Add HP bar HUD to `main.tscn`, wired to `player.stats.damaged` and `player.stats.healed`
7. GUT tests: `CharacterStats` (damage, heal, clamp, death flag), `GridEntity` base (command execution, queue, pause/resume, canonical transform)

---

## M2 — Enemy Presence in the World
*Depends on M1. `ItemData` resource (M4 prereq) can start in parallel.*

1. Create `Enemy` scene — `Node3D` + `MeshInstance3D` visible in 3D world, with `enemy.gd` extending `GridEntity`. Must move on the player's grid (jam rule).
2. Create `EnemyAI` node — drives `Enemy.execute_command()` through the inherited `GridEntity` API. Strategy is injectable (step-echo vs real-time left open).
3. Add entity registry to `main.gd` so enemies block movement (dynamic cells in `GridOccupancyMap` or a separate layer)
4. Encounter detection in `main.gd` — on every `action_completed`, check for player/enemy cell overlap or adjacency → call `_trigger_combat(enemies)`
5. `_trigger_combat()`: call `pause_exploration_commands()`, transition to `COMBAT` state, hand off to `CombatRoundManager`

**Decision point:** Step-echo vs async enemy movement — recommend step-echo for MVP, can be upgraded later.

---

## M3 — Combat System
*Depends on M1 + M2.*

Add `ATTACK`, `DEFEND`, `USE_ITEM` to `GridCommand.Type` regardless of variant.  
**Resolve the combat mode decision before implementing the rest of M3** (see Open Decisions).

---

### Variant A — Turn-based (round resolution)

*Classic blobber feel. All entities lock-step; player always gets a reaction window.*

1. Create `CombatRoundManager` — accepts combatant list, opens an intent phase, waits until all entities have submitted one command, then resolves all simultaneously → emits `round_resolved`
2. In `COMBAT` mode, `Player` blocks `_unhandled_input` dispatching movement commands; instead maps `ATTACK`/`DEFEND`/`USE_ITEM` keys to `submit_intent(cmd)` on `CombatRoundManager`
3. `EnemyAI` calls `submit_intent(cmd)` immediately when `CombatRoundManager` opens its intent phase
4. Resolution: all moves execute first (via `GridEntity.execute_command()`), then damage pairs resolve (`attacker.attack - defender.defence`, min 1) applied to `CharacterStats`
5. End-of-round: dead entities removed; player HP 0 → `to_gameover_failure()`; all enemies dead → `to_gameplay()` + resume exploration
6. UI minimum: action menu showing intent options + HP bars. `combat_placeholder.tscn` replaced by real combat HUD.

**What is turn-based-specific:** `CombatRoundManager`, intent submission gate, `round_resolved` signal.  
**What is shared with Variant B:** `ATTACK` command, `CharacterStats.take_damage()`, death checks, state transitions.

---

### Variant B — Real-time (cooldown-driven)

*More action-oriented. Each entity acts on its own timer; combat and navigation feel continuous.*

1. No `CombatRoundManager`. Instead, each `GridEntity` gains a `CombatCooldown` — a per-entity `Timer` node set from `CharacterStats.attack_speed` (new field)
2. `COMBAT` mode does **not** change `Player` input routing — movement keys still work, `ATTACK` key fires `execute_command(ATTACK)` immediately if `CombatCooldown` is ready
3. `execute_command(ATTACK)` on `GridEntity`: checks for an adjacent enemy, calls `target.stats.take_damage(stats.attack)`, starts `CombatCooldown`
4. `EnemyAI` fires `execute_command(ATTACK)` when its `CombatCooldown` expires and player is adjacent; otherwise moves toward player
5. End conditions same: HP 0 → `to_gameover_failure()`; all enemies dead → `to_gameplay()`
6. UI minimum: in-world HP bars above enemies + player HUD. No action menu needed; `combat_placeholder.tscn` retired.

**What is real-time-specific:** `CombatCooldown` timer, `attack_speed` stat, immediate command execution.  
**What is shared with Variant A:** `ATTACK` command, `CharacterStats.take_damage()`, death checks, state transitions.

---

## M4 — Items, Inventory & Town
*`ItemData` + `Inventory` model work can start in parallel with M2. Full UI needs M1.*

1. `ItemData` resource — `item_name`, `description`, `stat_effect: Dictionary`, `item_type` enum
2. `WorldPickup` node — sits on a grid cell, detected via `action_completed` in `main.gd`, auto-collects into player inventory
3. `Inventory` model on `Player` — `add_item()`, `remove_item()`, `use_item()` applying `stat_effect` to `CharacterStats`
4. Replace `inventory_placeholder.tscn` — real item list UI, use-item calls stat effect
5. Replace `town_placeholder.tscn` — "Rest" restores HP to max (satisfies jam rule 8); optional shop
6. Wire `open_inventory` and `open_town` input actions to real scenes

---

## M5 — Theme, Dungeon & Win Condition
*Depends on M1–M4. Theme content unblockable until DCJam theme is announced.*

1. **Theme content** — implement to announced theme
2. Build ≥1 complete dungeon floor: walls, enemy placements, pickups, an exit cell
3. Replace `success_goal_cell` hack with a real win trigger (boss kill, key + exit, etc.)
4. Death/retry flow — minimum full restart; roguelite variant adds a `RunProgress` autoload with carry-over stat bonuses
5. ≥2 floors or rooms (minimum for "feels like a game")
6. Title screen polish, pause, audio hooks
7. Final compliance pass using `docs/day14_compliance_checklist.md`

---

## Dependency Graph

```
M1 → M2 → M3 ─────┐
M1 → M4 (models)    ├──→ M5
     M4 (full UI) ──┘
```

---

## Open Decisions
*(must resolve before M3/M5 implementation starts)*

- **Combat mode (M3 gate):** Turn-based (Variant A: `CombatRoundManager`, intent phase, round tick) vs Real-time (Variant B: per-entity `CombatCooldown` timer, immediate execution). `CharacterStats`, `ATTACK` command, and death/state transitions are shared either way.
- **Enemy movement cadence:** Step-echo (acts after player's `action_completed`) vs real-time async timers
- **Death mechanic:** Full restart vs roguelite (`RunProgress` autoload with carry-over bonuses)

---

## Verification Checkpoints

| Milestone | Done when… |
|-----------|------------|
| M1 | GUT tests for `CharacterStats` + `GridEntity` base behavior pass; `Player` extends `GridEntity`; HP bar visible in running scene |
| M2 | Enemy visible in world, moves, triggers `COMBAT` state on encounter |
| M3 | Player can fight, win, and die; HP reflected in HUD; exploration resumes after combat |
| M4 | Player picks up item, opens inventory, uses item, HP changes |
| M5 | Full playthrough: title → dungeon → win/death → retry |
