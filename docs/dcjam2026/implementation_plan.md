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

### [Day 2: Item System & Stamina Architecture]

#### [NEW] [item_data.gd](file:///Users/kc00l/blobber-godot/resources/item_data.gd)
- **Type**: Custom `Resource`
- **Fields**: 
  - `item_name: String`
  - `texture: Texture2D` (for UI and billboard)
  - `properties: Array[StringName]` (e.g., `["flammable", "heavy"]`)
  - `is_potion: bool` (special flag for consumables)
- **Role**: Pure data container. Easy to create and edit variants in Godot inspector.

#### [NEW] [reaction_module.gd](file:///Users/kc00l/blobber-godot/scenes/world/modules/world_reaction_module.gd)
- **Type**: Node (Orchestrator Module)
- **Role**: Replaces complex item scripts. Maintains a Resource-based rule table mapping pairs of `StringName` tags to resulting transformations.
- **Key Method**: `react(item_a: ItemData, item_b: ItemData) -> ItemData`
- It will be dependency-injected via `WorldCompositionOrchestrator`.

#### [MODIFY] [player.gd](file:///Users/kc00l/blobber-godot/scenes/player/player.gd) & [player_stats.gd]
- **Stamina System**: Rename `PlayerStats::hp` to `stamina`. Update `max_stamina` (e.g., 6).
- **Hooks**:
  - Expose `drain_stamina(amount)` and `restore_stamina(amount)` on `PlayerStats`.
  - Listen to `movement_controller.action_completed`: if `inventory` contains a `heavy` item, increment a step counter; modulo N = `drain_stamina(1)`.
- **Dynamic Inventory Limit**:
  - `Inventory` (currently attached to Player) will subscribe to `PlayerStats.stamina_changed`.
  - Calculate `max_capacity`: 3 (Full stamina), 2 (<= Half stamina), 1 (Empty stamina).
  - If capacity decreases below current item count, the player must be forced to drop an item (or it drops automatically).
  - Empty stamina also modifies `movement_config` to increase step duration (slower movement).

#### [MODIFY] [inventory.gd]
- **Role**: Handles item storage (up to `max_capacity`).
- **UI Element**: Inventory slots are always visible in the GUI, even if empty. The visible slots dynamically update based on `max_capacity`.
- **Methods**: `add_item(ItemData)`, `remove_item(index)`, `use_item(index)` (for potions to trigger `restore_stamina(1)`).

### [Day 3: Interaction, Receptacles & Hazards]

#### [MODIFY] [player.gd](file:///Users/kc00l/blobber-godot/scenes/player/player.gd) (Continued)
- Implement `interact` action using cell position comparison (not raycast).

#### [NEW] [mess_item.gd](file:///Users/kc00l/blobber-godot/scenes/world/mess_item.gd)
- Grid-aligned entity representing the "mess" left by the hero.
- Holds `ItemData`.

#### [NEW] [receptacle.gd](file:///Users/kc00l/blobber-godot/scenes/world/receptacle.gd)
- Wall-embedded entity that accepts certain item types (Disposal Chute, Smelter, Ritual Altar).
- Interacted with via dedicated action or mouse click on the wall.
- Updates cleanup percentage when items are disposed of. Floor completion above threshold restores 1 Stamina.

#### [NEW] [hazard_logic.gd]
- Implement Option A Hazard Defusal: Volatile/corrosive items create an encounter prompt.
- Perform inventory resource checks (e.g. having a `wet` item auto-defuses).
- Failures cause an explosion, daze effect, and -1 Stamina.

## Verification Plan

### Automated Tests
- Unit tests for `ReactionOrchestrator` to ensure property combos yield correct transformations.
- Player inventory tests for the 3-slot limit.

### Manual Verification
- Walk through a small test level, pick up items with different tags, and dispose of them in receptacles.
- Observe clean% counter updates.
- Verify basic dialog overlays appear correctly.
