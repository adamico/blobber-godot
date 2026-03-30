# Themes

1. Cleaning up the hero's mess
2. Dragons
3. Retrofuturism
4. Elemental Rock Paper Scissors - https://tvtropes.org/pmwiki/pmwiki.php/Main/ElementalRockPaperScissors

1 is my choice.

this is Claude attempt at the theme 1:

# The Sweep — Design Summary

You are a professional dungeon cleaner hired after an unnamed hero's rampage. The dungeon is intact but ecologically wrecked. Your job: restore each floor to working order by sorting, transforming, and disposing of the mess left behind.

The game is a **first-person grid-based dungeon crawler** with no combat. Tension comes from spatial reasoning and item sequencing, not threat of death.

---

## Core Systems

**Movement & Interaction** — turn-based first-person grid. One raycast interaction per facing direction. Pick up, drop, examine.

**Item Properties** — each item carries a small tag array (`flammable`, `wet`, `cursed`, `volatile`, `corrosive`, `heavy`, `inert`). No per-item scripting.

**Reaction System** — a single autoloaded rule table checks property pairs on adjacency or carry events. Items transform based on rules, not hardcoded cases. Chaining is emergent.

**Carry Limit** — N slots (3 is a good starting number). Forces routing decisions without a complex inventory UI.

**Receptacles** — three types per floor (disposal chute, smelter, ritual altar), each accepting specific property combos. Correct disposal advances clean%.

**Clean Score** — weighted percentage per floor. Weighted by item risk. No fail state — a messy run still completes the floor.

---

## Content

5 hand-crafted floors, each introducing one new property. Topology drawn from a vocabulary of 5 room shapes combined in pairs. Item count scales from 4 to 9. One new mechanic per floor, never two.

---

## Milestones

| # | Day | Goal |
|---|---|---|
| 1 | Day 1 | Engine stable: grid movement, turning, raycast interaction, item pickup/drop |
| 2 | Day 2 | Item system live: property tags, reaction table, carry limit, item transforms |
| 3 | Day 3 | Receptacle logic + clean% tracking + basic UI (slots, score counter) |
| 4 | Day 4 | Art pass: wall tile, 4 mess sprites, 3 receptacle sprites, floor/ceiling |
| 5 | Day 5 | Floors 1–3 authored and playable end to end |
| 6 | Day 6 | Floors 4–5 authored, win screen, score summary |
| 7 | Day 7 | Playtesting, tuning, build export, itch.io page |

---

Combat rule:

## Option A — Hazard Defusal (least disruptive)
Volatile and corrosive items **actively threaten you** if mishandled. Resolution becomes a **resource check**: do you have the right item in your inventory to neutralize the hazard before it triggers?

- Walk toward a volatile flask → a prompt appears, timer starts
- If you're carrying a `wet` item → auto-defuse, no damage
- If not → item explodes, transforms neighbors, you lose a carry slot temporarily (dazed)

This reframes item interactions as **encounters**. The reaction system you already have becomes the combat system. Almost zero extra code.

---

## Option B — Lingering Creatures (moderate disruption)
The hero left wounded but not dead enemies behind. They're not aggressive — they're **trapped, cornered, or cursed** — but they block corridors or receptacles.

Resolution uses your existing property system:
- Match the correct item property to the creature type to resolve it
- Fire creature + wet item → resolved, drops ash
- Cursed creature + ritual altar in sight → resolved, counts as cursed disposal

This is elemental RPS in disguise, fits a potential theme combo, and adds 3–4 billboard sprites. Creatures are **puzzles with legs**, not full combat AI.

---

## Option C — The Debt Collector (most disruptive, highest payoff)
A single recurring enemy — the dungeon's **original caretaker** — patrols each floor. It's not hostile by default but becomes aggressive if your clean% drops too low or you mishandle cursed items.

Resolution: you can't fight it directly. You must **lure it into a reaction** using placed items — lead it past a volatile flask, trigger a chain, it gets stunned long enough to pass.

This adds a stealth/puzzle layer and a strong narrative hook. Riskiest for 7 days but gives the game a memorable antagonist.

---

## Recommendation

**Option A for the jam, Option B as stretch goal.**

Option A costs you almost nothing — it's a reframe of existing mechanics. You can honestly describe it to jam judges as a combat-equivalent resolution system, which it is. If you finish floors 1–3 ahead of schedule, layer in one creature type from Option B on floor 4–5.

Stat modifying rule:

These rules slot in cleanly without bloat. Here's the leanest possible implementation that satisfies both requirements while staying true to The Sweep's identity.

---

## The Stat: Stamina

Rename "health" to **Stamina** — it fits the cleaner fantasy better than hit points. It represents physical and mental exhaustion, not injury.

Single bar, displayed in UI alongside inventory slots.

---

## How Stamina Drains

Ties directly to existing systems, no new mechanics needed:

| Event | Effect |
|---|---|
| Hazard defusal failure (Option A) | -1 stamina |
| Carrying `heavy` items | -1 stamina per N steps |
| Mishandling `cursed` item | -1 stamina |
| Floor completed below threshold clean% | -1 stamina |

Stamina becomes a **sloppiness tax**. Skilled play barely touches it.

---

## How Stamina Recovers

Two sources, both already fit the world:

**Potions** — the hero left half-used potions scattered around. A `wet` item variant that is safe to carry and can be consumed from inventory instead of disposed. Restores 1 stamina. Creates a tension: dispose it for clean% or drink it for stamina?

**Clean floor bonus** — completing a floor above the clean% threshold restores 1 stamina. Rewards thorough play over speedrunning.

---

## What Stamina Depletion Means

Avoid a hard game over if possible — jam audiences bounce off punishing failure states.

| Stamina | Effect |
|---|---|
| Full | Normal carry limit (3 slots) |
| Half | Carry limit reduced to 2 |
| Empty | Carry limit reduced to 1, move speed slowed |

Stamina at zero doesn't kill you — it **hobbles you**. The floor is still completable but miserable. That's more interesting than a restart screen.

---

## Asset Impact

One new item billboard: **Potion** (distinct from Potion Spill already in the list). That's your only addition.

---

## Updated Minimum Asset List

Adds 1 billboard, 1 UI element:
- Potion billboard (consumable, `wet` variant)
- Stamina bar (UI, can be same frame as inventory slot, just horizontal)

**17 assets total.**

---

## Updated Milestones Impact

Stamina system fits inside **Milestone 2** (item system day) with minimal extra work — it's a single integer with drain/restore hooks on events you're already handling. No milestone shift needed.