# The Sweep — Full Design Summary

## Concept
You are a professional dungeon cleaner hired after an unnamed hero's rampage. The dungeon is structurally intact but filled with reanimated remnants of the hero's battles — corpses, broken traps, spilled magic that didn't fully die. Your job: put them down properly and get out.

First-person grid-based dungeon crawler. Turn-based movement and actions. No random generation. 5 hand-crafted floors.

---

## Core Systems

**Movement & Interaction** — turn-based first-person grid. One action per turn, shared with enemies.

**Property System** — enemies and items carry property tags. Matching an item's tag to an enemy's weakness deals bonus damage. Same system, two uses.

**Combat** — face an enemy, select a tool from inventory, resolve damage. Enemy retaliates on their turn. Bonus damage if property matches weakness.

**Stamina** — single bar. Drains on hits received, heavy carries, cursed mishandling. Recovers from potions and clean floor bonuses. Low stamina reduces carry limit and movement options.

**Carry Limit** — 3 slots. Forces loadout decisions before entering a room.

**Clean%** — weighted floor completion score. Replaces puzzle disposal. Now tracks enemies defeated + items correctly handled.

---

## Items

| Item | Type | Property | Effect |
|---|---|---|---|
| Ritual Candle | Attack | `cursed` | Standard damage, bonus vs cursed enemies |
| Splash Flask | Attack | `wet` | AoE, hits all enemies in front tile, bonus vs burning enemies |
| Mop | Defense | `wet` | Reduces incoming damage by 1 for one hit, bonus vs corrosive enemies |
| Iron Ward | Defense | `inert` | Blocks next attack entirely, single use per floor |
| Potion | Utility | `wet` | Restores 1 stamina, consumed from inventory |

---

## Enemies

| Enemy | Properties | Weakness | Behavior |
|---|---|---|---|
| Reanimated Corpse | `flammable`, `heavy` | `wet` | Moves toward player every 2 turns, slow |
| Burning Remains | `flammable`, `volatile` | `wet` | Stays in place, deals damage if you enter adjacent tile |
| Cursed Armor | `cursed`, `heavy` | `cursed` (ritual candle) | Patrols fixed path, blocks corridor |
| Spill Crawler | `wet`, `corrosive` | `inert` (iron ward) | Moves randomly, corrodes items in adjacent tiles |
| Echo Trap | `volatile` | `wet` | Stationary, triggers when walked past, single hit |

---

## Level Layouts

**Floor 1 — The Antechamber** — single long corridor with a branching dead end. Two Reanimated Corpses, one Echo Trap at the branch entrance. Teaches movement, basic combat, property matching. No cursed or corrosive enemies. Potion placed mid-corridor.

**Floor 3 — The Vault** — open central room with three radiating corridors, each ending in a locked door. A Cursed Armor patrols each corridor. Player must defeat all three to unlock exit. Burning Remains placed in the central room as a toll. Forces loadout planning — you can't carry tools for every situation.

**Floor 5 — The Sanctum** — loop topology with a collapsed shortcut that forces backtracking. All enemy types present. Spill Crawler roams freely, threatening to corrode your tools mid-run. Iron Ward almost mandatory. Clean% threshold for stamina bonus is highest here.

---

## Milestones

| # | Day | Goal |
|---|---|---|
| 1 | Day 1 | Engine stable: grid movement, turning, raycast interaction, item pickup/drop |
| 2 | Day 2 | Combat system: action menu, damage resolution, property weakness bonus, enemy turn |
| 3 | Day 3 | Enemy behaviors: movement patterns, adjacency damage, patrol paths |
| 4 | Day 4 | Art pass: wall tile, 5 enemy billboards, 5 item billboards, 3 receptacle sprites, UI |
| 5 | Day 5 | Floors 1–3 authored and playable end to end |
| 6 | Day 6 | Floors 4–5 authored, stamina tuning, win screen, score summary |
| 7 | Day 7 | Playtesting, build export, itch.io page |

---

## Asset List

**Environment**
- Wall texture (1 base)
- Floor texture (1 base)
- Door (open + closed)

**Item Billboards**
- Ritual Candle
- Splash Flask
- Mop
- Iron Ward
- Potion

**Enemy Billboards**
- Reanimated Corpse
- Burning Remains
- Cursed Armor
- Spill Crawler
- Echo Trap

**UI**
- Inventory slot frame (tiled ×3)
- Stamina bar
- Crosshair
- Action menu frame

**Total: 21 assets**

---

## Scope Boundaries
No leveling, no random generation, no dialogue, no complex inventory stats. Property system does all heavy lifting for both combat and encounter variety. If it isn't on this page, it isn't in the game.