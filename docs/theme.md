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

## Scope Boundaries
No combat, no leveling, no random generation, no dialogue, no complex inventory. If it isn't on this page, it isn't in the game.