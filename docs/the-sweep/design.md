# The Sweep — Design Summary

## Concept

*"Thank you for choosing Veridian Sanitation Solutions — a proud subsidiary of Syndicate Floor Services LLC. Your assignment has been logged. Your safety waiver has been auto-signed. Good luck down there."*

The hero's done. The cameras are off. The dungeon is a disaster.

You are **Unit 7**, a contracted operative for **Veridian Sanitation Solutions** — the galaxy's most cost-efficient post-crawl cleanup service. The dungeon was a live broadcast event; the hero made it to Floor 5, grabbed the relic, and got extracted. Nobody cleaned up after them. The leftover animatronic assets are still running their patrol loops, traps are still hot, and biohazardous boss-spill is coating the hallways. 

First-person grid-based dungeon crawler (blobber). Turn-based movement. 5 hand-crafted floors. Your KPI is simple: **100% Clean per floor.**

> *Veridian Sanitation Solutions is not responsible for operative injury, dissolution, or spontaneous undeath incurred during scheduled cleanup operations.*

---

## Core Fantasy
Defeating something is only half the job. Real work starts when the broadcast ends. You aren't here to loot; you are here to sanitize. You aren't a warrior; you are a cleanup operative armed with a mop and whatever magical gear the hero abandoned, forced to solve a hostile spatial puzzle on a turn-by-turn basis.

---

## Core Systems

### Movement & Interaction
Turn-based first-person grid. One action per turn, shared with enemies. Manual item and debris pickup — nothing is collected automatically. Items can be dropped freely but dropping restarts the revert timer on debris.

### Property Tags
Three counter pairs. Enemy tags describe threat behavior. Tool tags describe counter capability. `inert` bridges both as the universal post-combat debris state.

| Tag | Appears on | Counters | Countered by |
|---|---|---|---|
| `burning` | enemies, hazards | — | `soaked` tools |
| `soaked` | tools only | `burning` enemies | — |
| `corrosive` | enemies, hazards | — | `inert` tools |
| `inert` | tools, all debris | `corrosive` enemies | — |
| `cursed` | enemies, hazards | — | `cleansed` tools |
| `cleansed` | tools only | `cursed` enemies | — |

Post-combat, every neutralized enemy becomes `inert` debris regardless of which tag pair resolved the fight.

### Combat
Face an enemy, select a tool from inventory, resolve damage. Matching a tool's tag to the enemy's weakness deals bonus damage. Enemy retaliates on their turn. Neutralized enemies become `inert` debris on their tile.

`inert` debris can be used as a weapon against `corrosive` enemies in a pinch — it resolves the threat but the debris is consumed without contributing to clean%. A small professional penalty.

### Debris & Revert System

| Debris state | Revert timer |
|---|---|
| On floor | Ticking — N turns until reactivation |
| In inventory | Frozen |
| Dropped back on floor | Restarts from zero |
| Used as weapon | Consumed, no clean% gain |
| Disposed at chute | Gone, contributes to clean% |

Debris on the floor also blocks movement — tiles occupied by debris cannot be entered. In tight corridors this creates spatial pressure independent of the revert timer.

*Note on stacked debris:* Because debris occupies a cell and makes it non-walkable, two debris items should never logically occupy the same cell. A player dropping debris on an already debris-occupied cell is prevented by the drop logic filtering out impassable target cells.

### Inventory
Three generic slots shared between tools and debris. No dedicated slot types — the player decides the mix. Carrying debris consumes slots that could hold tools, creating a natural tension between combat readiness and cleanup progress.

| Slot state | Example |
|---|---|
| All tools | max combat readiness, no cleanup capacity |
| 2 tools + 1 debris | balanced |
| 1 tool + 2 debris | cleanup focus, vulnerable in combat |
| 3 debris | no tools, highly vulnerable |

Manual pickup costs one turn. Dropping is free but restarts the debris revert timer.

### HP
Single stat. Drains from enemy attacks and contact with hazards. Game over at zero. Partially recovers from high job rating between floors. Potions restore HP directly.

### Disposal Chutes
One per room cluster, visible from combat areas. Accepts `inert` debris only. Disposing earns clean% score weighted by enemy type. Debris consumed as weapon does not contribute to clean%.

### Job Rating
Letter grade per floor based on clean% at exit.

| Rating | Threshold | Between-floor reward |
|---|---|---|
| A | 90%+ | Full HP restore + item choice |
| B | 70–89% | Partial HP restore |
| C | 50–69% | Item choice only |
| D | Below 50% | Nothing |

---

## Property Tag Summary

| Tag | On enemies | On tools |
|---|---|---|
| `burning` | Damages on contact | Splash Flask |
| `soaked` | — | Splash Flask, Mop |
| `corrosive` | Degrades carried tools on contact | — |
| `inert` | — (debris state) | Iron Ward |
| `cursed` | Applies curse effect on hit | — |
| `cleansed` | — | Ritual Candle |

---

## Items

| Item | Tag | Type | Effect |
|---|---|---|---|
| Ritual Candle | `cleansed` | Attack | Standard damage, bonus vs `cursed` enemies |
| Splash Flask | `soaked` | Attack | AoE front tile, bonus vs `burning` enemies |
| Mop | `soaked` | Defense | Reduces incoming damage by 1 for one hit |
| Iron Ward | `inert` | Defense | Blocks next attack entirely, single use per floor |
| Potion | — | Utility | Restores HP, consumed from inventory |

---

## Hazards (Enemies)

**Speed** is an internal stat (not shown to player) that controls how many player turns pass before the enemy AI ticks. `speed=1` means the AI acts every player turn; `speed=2` means every other turn, etc. This allows slow/lumbering enemies and fast threats without changing the core 1-action-per-turn engine.

| Hazard Name | Class | Weakness | Speed | Behavior |
|---|---|---|---|---|
| **Burning Reanimated NPC** | `burning` | `soaked` | 2 (slow) | Animatronic NPC still running combat loop. Moves toward player every other turn. |
| **Thermal Overspill** | `burning` | `soaked` | — | Boss fight leftovers. Stationary, but deals damage if bumped. |
| **Cursed Combat Prop** | `cursed` | `cleansed` | 1 | Haunted armor abandoned by the hero. Patrols fixed paths every turn. |
| **Acid Crawler** | `corrosive` | `inert` | 1 (fast) | Escaped from the boss fight. Acts every player turn. Threatens adjacent tiles. |
| **Trap Module (Hot)** | `burning` | `soaked` | — | Left active. Stationary, triggers proximity blast if ignored. |

---

## Floor Design

**Known AI Limitations (Milestone 5 Polish):**
- **Patrol loops & walls:** Patrol enemies currently do not flip direction if they hit a wall before their step counter resets. They will lose turns until the step counter reaches the limit.

Five hand-crafted floors, each introducing one new element. Topology drawn from five room shapes: corridor, open room, T-junction, loop, dead end. Each floor combines two shapes. Enemy placement considers chute distance — enemies near chutes are easier to clean, enemies in dead ends create the hardest debris routing challenges.

| Floor | New element | Topology | Enemy count |
|---|---|---|---|
| 1 | Combat basics, manual pickup, inventory | Corridor | 2–3 |
| 2 | Disposal chute, clean%, job rating | Open room | 3–4 |
| 3 | Revert timer, debris blocking | T-junction | 4–5 |
| 4 | `corrosive` + `cursed` enemies | Loop | 5–6 |
| 5 | Full system, supply closet stakes | Two connected shapes | 7–8 |

---

## Between Floors: Supply Closet
Interstitial scene between floors. No grid navigation. Job rating determines what's available: potions, items, HP restore. Stretch goal: meta progression via persistent upgrades.

---

## Production Milestones

| # | Phase | Goal |
|---|---|---|
| 1 | Foundations | Engine stable: grid movement, 3-slot inventory, raycast interaction, pickup/drop, basic UI |
| 2 | Action & Combat | Combat action menu, damage resolution, RPS weakness definitions, enemy turn execution. |
| 3 | AI & Ecology | Enemy movement patterns, adjacency damage, patrol loops, **revert timers**. |
| 4 | Disposal & Progression | **Debris routing, inert state floor blocking, disposal chutes**, Clean% tracker, Job Rating. |
| 5 | Authoring I | Art pass, hand-crafting floors 1–3, tuning encounters. |
| 6 | Authoring II | Hand-crafting floors 4–5, final boss mess distribution, **supply closet**, win screen. |
| 7 | Polish | Playtesting, SFX, tuning, build export, itch.io packaging. |

---

## Asset List (Lean)

- **Environment:** Wall Texture, Floor Texture, Exit Hatch Node.
- **Item Billboards (5):** Ritual Candle, Splash Flask, Mop, Iron Ward, Potion.
- **Hazard Billboards (5):** Reanimated NPC, Thermal Overspill, Cursed Prop, Acid Crawler, Trap Module.
- **UI:** HP HUD, Clean% HUD, Belt Action Slots.

**Total Constraints:** Everything is represented as 2D sprite billboards in a simple retro 3D grid. No complex 3D modeling. 

---

## Scope Boundaries
No leveling during a run. No random generation. No sweeping narrative tree. Three strictly locked inventory slots. One HP stat governed by combat and hazard interaction. Six simplified RPS tags governing all mechanical interactions. Corporate KPI handles the primary objective. If it isn't listed here, it is out of scope.