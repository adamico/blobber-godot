# Receptacle Pivot: Grid-based Containers

The current billboard-based Receptacles easily get embedded in walls and lack architectural presence. We will pivot to using specialized `GridMap` cells for receptacles.

## Finalized Identity Mapping (GridMap IDs)

All environmental interaction is now purely ID-driven from the `GridMap`. The node-based entity system for mess/receptacles is being REMOVED.

**MeshLibrary ID Mapping:**
- **0**: Wall
- **1**: Smelter (Receptacle)
- **2**: Disposal (Receptacle)
- **3**: Ritual (Receptacle)
- **4**: Slime Mess (Collectible Quad)
- **5**: Rust Mess (Collectible Quad)
- **6**: Grime Mess (Collectible Quad)
- **7**: Floor Mesh

## Proposed Changes

### Visual Pass: MeshLibrary

#### [MODIFY] [simple_mesh_library.tres](file:///Users/kc00l/blobber-godot/resources/mesh_library/simple_mesh_library.tres)
- **Receptacles (1-3)**: Multi-surface `BoxMesh` or specialized shader to apply textures (`receptacle_smelter.png`, etc.) to the forward face only.
- **Mess Items (4-6)**: Create new entries using `QuadMesh` with `BILLBOARD_FIXED_Y` materials.
- **Floor/Wall (0, 7)**: Ensure these entries are preserved/moved to IDs 0 and 7.

### Logic Pass: Strict Grid Interaction

#### [MODIFY] [main.gd](file:///Users/kc00l/blobber-godot/scenes/world/main.gd)
- **Strict Interaction**: Refactor `perform_interaction()` to use *only* `GridMap.get_cell_item()`.
- **Workflow**:
    1. Check `GridMap` at `target_cell`.
    2. If ID ∈ {1, 2, 3}: Trigger Receptacle logic (checks inventory, removes mess if match).
    3. If ID ∈ {4, 5, 6}: Trigger Pickup logic (adds item to inventory, `set_cell_item(cell, -1)`).
    4. Otherwise: No interaction.

#### [DELETE] [receptacle.gd](file:///Users/kc00l/blobber-godot/scenes/world/entities/receptacle.gd) & [mess_item.gd](file:///Users/kc00l/blobber-godot/scenes/world/entities/mess_item.gd)
- Remove these scripts and the scenes that use them to lean fully into the data-driven grid approach.

## Verification Plan

### Automated Tests
- Update `test_day3_interactions.gd` to verify interaction with a `GridMap` cell instead of a `Receptacle` node.

### Manual Verification
- Walk to `(1, -1)` in the `Main` scene.
- Facing East, confirm the "Smelter" texture is visible on the wall/mesh.
- Interact with it while holding a `volatile` item.
