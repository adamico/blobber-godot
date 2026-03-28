# Implementation Plan - The Sweep (DCJam 2026)

Adapt the existing blobber-godot engine into a first-person grid-based dungeon cleaner.

## Proposed Changes

### [Day 1: Engine Stable, Dialog, & Level Progression]

#### [MODIFY] [main.gd](file:///Users/kc00l/blobber-godot/scenes/world/main.gd)
- Remove combat orchestrators and modules.
- Remove town and character stats references.
- Simplify state machine to Menu, Gameplay, and Dialog.
- Add support for basic interactions.
- Modify `finish_with_success()` to trigger level transition instead of just a victory overlay.

#### [NEW] [level_manager.gd](file:///Users/kc00l/blobber-godot/autoloads/level_manager.gd)
- Autoload to manage the sequence of floors (1 through 5).
- Handles loading the next [.tscn](file:///Users/kc00l/blobber-godot/test_scene.tscn) file when a floor is 100% cleaned and the player reaches the exit (e.g., stairs or elevator).

#### [NEW] [dialog_overlay.tscn](file:///Users/kc00l/blobber-godot/scenes/overlays/dialog_overlay.tscn)
- Scene for basic interactions and game introduction.

### [Day 2: Item System (Property-based)]

#### [NEW] [item_data.gd](file:///Users/kc00l/blobber-godot/resources/item_data.gd)
- Resource to define item properties (e.g., `flammable`, `wet`, `cursed`).
- Stores sprite and name.

#### [NEW] [reaction_orchestrator.gd](file:///Users/kc00l/blobber-godot/scenes/world/reaction_orchestrator.gd)
- Orchestrator for property-based reactions (replacing autoload).
- `react(item_a, item_b)` function that returns a new item or transformation.

#### [MODIFY] [player.gd](file:///Users/kc00l/blobber-godot/scenes/player/player.gd)
- Update inventory to strictly enforce 3 slots.

### [Day 3: Interaction & Receptacles]

#### [MODIFY] [player.gd](file:///Users/kc00l/blobber-godot/scenes/player/player.gd) (Continued)
- Implement `interact` action using cell position comparison (not raycast).

#### [NEW] [mess_item.gd](file:///Users/kc00l/blobber-godot/scenes/world/mess_item.gd)
- Grid-aligned entity representing the "mess" left by the hero.
- Holds `ItemData`.

#### [NEW] [receptacle.gd](file:///Users/kc00l/blobber-godot/scenes/world/receptacle.gd)
- Wall-embedded entity that accepts certain item types (Disposal Chute, Smelter, Ritual Altar).
- Interacted with via dedicated action or mouse click on the wall.
- Updates cleanup percentage when items are disposed of.

## Verification Plan

### Automated Tests
- Unit tests for `ReactionOrchestrator` to ensure property combos yield correct transformations.
- Player inventory tests for the 3-slot limit.

### Manual Verification
- Walk through a small test level, pick up items with different tags, and dispose of them in receptacles.
- Observe clean% counter updates.
- Verify basic dialog overlays appear correctly.
