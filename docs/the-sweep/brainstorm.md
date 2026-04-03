# The Sweep — Design Summary

## Concept

*"Thank you for choosing Veridian Sanitation Solutions — a proud subsidiary of Syndicate Floor Services LLC. Your assignment has been logged. Your safety waiver has been auto-signed. Good luck down there."*

The hero's done. The cameras are off. The dungeon is a disaster.

You are **Unit 7**, a contracted sanitation operative for **Veridian Sanitation Solutions** — the galaxy's most cost-efficient post-crawl cleanup service. The dungeon was a live broadcast event. The hero made it to Floor 5, collected the artifact, and got extracted. Nobody cleaned up after them.

The dungeon is still very much active. Animatronic NPC assets are still running their scripted loops. Overheated trap modules never powered down. Biohazardous residue from the final boss is crawling the hallways. You have a work order, a 3-slot utility belt, and a strict corporate KPI: **100% Clean per floor.**

First-person grid-based dungeon crawler (blobber). Turn-based movement. 5 hand-crafted floors.

> *Veridian Sanitation Solutions is not responsible for operative injury, dissolution, or spontaneous undeath incurred during scheduled cleanup operations.*

---

## Core Systems: Elemental Rock Paper Scissors (RPS)

Each piece of dungeon hazard has a **material class**. Your equipment is rated to handle specific classes. Using the right tool clears a hazard in one action. Using the wrong one barely makes a dent — and may cost you Stamina.

| Element | Equipment | Clearable Hazard Class | Protocol |
|---|---|---|---|
| **Aqueous** | Hydro-Mop, Splash Canister | `Flammable`, `Volatile` | Standard fire suppression. Rated for Class-F and Class-V materials. |
| **Spectral** | Aetheric Discharge Wand | `Undead`, `Cursed` | Approved for post-mortem NPC asset decommissioning. One charge per use. |
| **Inert** | Containment Shell | `Corrosive`, `Acid` | Encapsulates and neutralizes corrosive residue. Single-use per floor. |

---

## Mechanics

- **Clean%:** Your corporate KPI. Each hazard cleared increases this. Reaching 100% on a floor grants a HP ration for the next one. Failing to hit a threshold gets noted in your permanent record.
- **HP:** Your operative's biological integrity. Drains when hazards make contact. 0 HP = Game Over. Find a Synth-Gel Packet to recover.
- **Utility Belt (3 Slots):** Standard-issue loadout capacity. You carry what you pick up. You can't pick up everything. Plan accordingly.

---

## Equipment (Items — 5 Total Assets)

| Equipment | Class Rating | Effect |
|---|---|---|
| **Splash Canister** | `Aqueous` | **Ranged:** 1-tile range. Instant clear vs `Flammable` assets. AoE version of the Hydro-Mop. |
| **Aetheric Discharge Wand** | `Spectral` | **Melee:** Adjacent only. Instant clear vs `Undead`/`Cursed` assets. Single charge. |
| **Containment Shell** | `Inert` | **Defense:** Blocks next `Corrosive` contact entirely. One-use per floor. |
| **Hydro-Mop** | `Aqueous` | **Utility:** Coats a tile with Aqueous residue. Weakens `Flammable` hazards that enter it. |
| **Synth-Gel Packet** | `Utility` | **Consume:** Restores 2 Stamina. Tastes like synthetic citrus. One-time use. |

---

## Hazards (Enemies — 5 Total Assets)

| Hazard Name | Class | Weakness | Behavior |
|---|---|---|---|
| **Reanimated NPC (Corpse-Type)** | `Undead` | `Spectral` (Wand) | Still running patrol loops. Moves toward player every 2 turns. Slow. |
| **Thermal Overspill** | `Flammable` | `Aqueous` (Canister) | Boss fight leftovers. Stationary. Contact = Stamina loss. |
| **Acid Crawler** | `Corrosive` | `Inert` (Shell) | Escaped from the boss fight. Fast movement. Dissolves equipment on touch. |
| **Cursed Combat Prop** | `Cursed` | `Spectral` (Wand) | Hero left a cursed blade embedded in a suit of armor. It's still fighting. Patrols a corridor. |
| **Trap Module (Hot)** | `Volatile` | `Aqueous` (Canister) | Never powered down. Invisible until adjacent. Detonates on proximity. |

---

## Milestones

| # | Day | Goal |
|---|---|---|
| 1 | Day 1-2 | **Engine Foundations:** Grid movement, 3-slot inventory, raycast interaction. |
| 2 | Day 3 | **RPS Interaction:** Damage logic, property-matching bonus, 100% Clean system. |
| 3 | Day 4-5 | **Hostile AI & Leveling:** Patrol paths, proximity triggers, loading 5 floor layouts. |
| 4 | Day 6 | **Asset Pass:** 2D Billboards for the 5 items and 5 messes. Simple dungeon textures. |
| 5 | Day 7 | **Polishing:** UI (HP Bar, Clean%), SFX, Win/Fail screens. |

---

## Asset List (Lean)

- **Environment:** 1 Wall Texture, 1 Floor Texture, 1 Door Node.
- **Item Billboards (5):** Flask, Candle, Ward, Mop, Potion.
- **Mess Billboards (5):** Corpse, Fire, Slime, Armor, Trap.
- **UI:** HP Bar, Clean Counter, Tool Slots.

**Total: ~15-18 Assets.** No complex 3D models. Everything is represented as sprite billboards.
