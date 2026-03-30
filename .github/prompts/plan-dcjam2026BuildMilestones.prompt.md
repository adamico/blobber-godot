# Plan: DCJam 2026 — Missing Features Build

Five milestones. M1 is a strict prerequisite for everything else. M4 model work can start in parallel with M2.

> **Status as of 14 March 2026:** M1–M4 complete. M5 is the only remaining work.

---

## ~~M1 — Entity & Stats Foundation~~ ✅ DONE

**Delivered:**
- `CharacterStats` (`res://models/character_stats.gd`) — `take_damage`, `heal`, `fill`, `is_dead`, `damaged`/`healed` signals, defence-reduced clamped damage
- `GridEntity` (`res://components/grid_entity.gd`) — base class with `grid_state`, `movement_controller`, `stats`, one-command queue, `execute_command`, `pause/resume_commands`, `apply_canonical_transform`, virtual `_on_action_completed`
- `Player` (`res://scenes/player/player.gd`) — `extends GridEntity`; camera, input pipeline, smooth tween, blocked-feedback animation
- `GameStateMachine` — `COMBAT` state, `to_combat()`, `is_combat()`
- HP bar HUD wired in `main.gd` via `_add_hp_bar()` → `WorldUIModule.setup_hp_bar()`

---

## ~~M2 — Enemy Presence in the World~~ ✅ DONE

**Delivered:**
- `Enemy` (`res://scenes/enemies/enemy.gd`) — `extends GridEntity`, `add_to_group("grid_enemies")`, `tick_ai`, `choose_combat_intent`
- `EnemyAI` (`res://scenes/enemies/enemy_ai.gd`) — step-echo strategy; `choose_command` (navigate toward player), `choose_combat_intent` (returns `ATTACK`)
- `WorldEncounterModule` wired into `main.gd` — entity registry, encounter detection on `action_completed`, calls `start_combat()`
- `start_combat()` / `end_combat()` in `main.gd` — pauses exploration, transitions state, hands off to `WorldTurnOrchestrator`

**Resolved:** Step-echo enemy movement (acts after player's `action_completed`).

---

## ~~M3 — Combat System~~ ✅ DONE

**Resolved:** Turn-based Variant A.

**Delivered:**
- `CombatRoundManager` (`res://models/combat/combat_round_manager.gd`) — `start_round`, `submit_intent`, `_resolve_round`, `round_resolved` signal; intent-phase gate
- `WorldTurnOrchestrator` drives round lifecycle; `handle_combat_input` routes player intent in `COMBAT` mode
- `EnemyAI.choose_combat_intent` submits `ATTACK` immediately on intent-phase open
- `combat_placeholder.tscn` **replaced** by `scenes/combat/combat_overlay.gd` — real Attack / Defend / Use Item buttons, Player HP label, Enemy HP + count display

~~Variant B (real-time cooldown)~~ — not implemented; not needed.

---

## ~~M4 — Items, Inventory & Town~~ ✅ DONE

**Delivered:**
- `ItemData` (`res://models/item_data.gd`) — `item_name`, `description`, `stat_effect: Dictionary`, `item_type` enum (`CONSUMABLE`, `EQUIPMENT`, `QUEST`)
- `WorldPickup` (`res://components/world_pickup.gd`) — grid-cell positioned, `collect_if_player_on_cell`, auto `queue_free` on collect
- `Inventory` (`res://models/inventory.gd`) — `add_item`, `remove_item`, `use_item` (applies `stat_effect` to `CharacterStats`), `item_added/removed/used` signals
- `Player` — `add_item`, `remove_item`, `use_item` delegates to `Inventory`
- `inventory_overlay.tscn` / `inventory_overlay.gd` — real item list UI with Use button, HP display, `open_inventory` action wired
- `town_overlay.tscn` / `town_overlay.gd` — Rest button calls `rest_player()` (fills HP to max), `open_town` action wired

---

## M5 — Theme, Dungeon & Win Condition
*Depends on M1–M4. Theme content blocked until DCJam theme is announced; all structural steps can start now.*

1. **Theme content** — implement to announced theme (names, aesthetics, story hook)
2. Build ≥1 complete dungeon floor in `main.tscn`: walls, ≥1 enemy placement, ≥1 `WorldPickup`, a designated exit cell
3. Replace `success_goal_cell` export hack (`main.gd` line 10) with a real win trigger — recommended: `ExitCell` marker node activates only after all enemies on the floor are dead; fires existing `to_gameover_success()` path
4. Death/retry flow — confirm `WorldRunOutcomeModule` properly fires `defeat_overlay.tscn` on player HP → 0; wire Retry button to full scene reload (`get_tree().reload_current_scene()`)
5. Build ≥2 floors or rooms (scene transition reuses existing `title_scene_path` loading infrastructure)
6. Title screen polish — functional Start button on `title_screen.tscn` wired to gameplay scene
7. Pause menu (low-effort: toggle overlay + resume/quit)
8. Audio hooks — placeholder `AudioStreamPlayer` nodes for footsteps, combat hit, pickup, death
9. Final compliance pass using `docs/day14_compliance_checklist.md`

---

## Dependency Graph

```
M1 ✅ → M2 ✅ → M3 ✅ ─────┐
M1 ✅ → M4 ✅ (models) ─────┤
         M4 ✅ (full UI) ───┘──→ M5 ← YOU ARE HERE
```

---

## Resolved Decisions

| Decision | Choice |
|---|---|
| Combat mode | Turn-based Variant A (`CombatRoundManager`, intent phase, `round_resolved`) |
| Enemy movement cadence | Step-echo (acts after player's `action_completed`) |
| Death mechanic | Full restart (`reload_current_scene`) — roguelite deferred |

---

## Verification Checkpoints

| Milestone | Status | Done when… |
|-----------|--------|------------|
| M1 | ✅ | GUT tests pass; `Player extends GridEntity`; HP bar visible |
| M2 | ✅ | Enemy visible, moves, triggers `COMBAT` state on encounter |
| M3 | ✅ | Player can fight, win, die; HP in HUD; exploration resumes after combat |
| M4 | ✅ | Player picks up item, opens inventory, uses item, HP changes |
| M5 | ⬜ | Full playthrough: title → dungeon → win/death → retry |
