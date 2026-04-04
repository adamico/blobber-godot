class_name WorldAuthoredFloorLoader
extends RefCounted

const MARKER_WALL := 0
const MARKER_PLAYER_SPAWN := 1
const MARKER_FLOOR := 2
const MARKER_DISPOSAL_CHUTE := 3
const MARKER_FLOOR_EXIT := 4
const MARKER_HOSTILE_CURSED := 5
const MARKER_HOSTILE_CORROSIVE := 6
const MARKER_HOSTILE_BURNING := 7
const MARKER_POTION := 8
const MARKER_HOLY_SYMBOL := 9
const MARKER_IRON_WARD := 10
const MARKER_MOP := 11
const MARKER_SPLASH_FLASK := 12
const MARKER_DEBRIS := 13

const GRIDMAP_NODE_NAME := "GridMap"


func load_into_world(world_root: Node3D, floor_scene: PackedScene) -> Dictionary:
	var result := _empty_result()
	if world_root == null:
		result.errors.append("Authored floor load requires a world root.")
		result.ok = false
		return result
	if floor_scene == null:
		result.errors.append("Missing authored floor scene.")
		result.ok = false
		return result

	var floor_instance := floor_scene.instantiate()
	if floor_instance == null:
		result.errors.append("Failed to instantiate authored floor scene.")
		result.ok = false
		return result

	var grid_map := _extract_grid_map(floor_instance)
	if grid_map == null:
		floor_instance.free()
		result.errors.append("Authored floor scene does not contain a GridMap.")
		result.ok = false
		return result

	_clear_existing_grid_map(world_root)
	if grid_map.get_parent() != null:
		grid_map.get_parent().remove_child(grid_map)
	grid_map.name = GRIDMAP_NODE_NAME
	world_root.add_child(grid_map)

	if floor_instance != grid_map:
		floor_instance.free()

	result = parse_grid_map(grid_map)
	result.grid_map = grid_map
	return result


func parse_grid_map(grid_map: GridMap) -> Dictionary:
	var result := _empty_result()
	if grid_map == null:
		result.errors.append("Cannot parse authored floor without a GridMap.")
		result.ok = false
		return result

	for cell_3d: Vector3i in grid_map.get_used_cells():
		var marker_id := grid_map.get_cell_item(cell_3d)
		var cell := Vector2i(cell_3d.x, cell_3d.z)
		match marker_id:
			MARKER_WALL, MARKER_FLOOR:
				pass
			MARKER_PLAYER_SPAWN:
				result.positioning_cells_3d.append(cell_3d)
				if result.has_player_spawn:
					var warning := "Duplicate PlayerSpawn marker at %s; keeping %s." % [
						cell,
						result.player_spawn,
					]
					result.warnings.append(warning)
				else:
					result.has_player_spawn = true
					result.player_spawn = cell
			MARKER_DISPOSAL_CHUTE:
				result.positioning_cells_3d.append(cell_3d)
				result.chute_cells.append(cell)
			MARKER_FLOOR_EXIT:
				result.positioning_cells_3d.append(cell_3d)
				result.exit_cells.append(cell)
			MARKER_HOSTILE_CURSED, MARKER_HOSTILE_CORROSIVE, MARKER_HOSTILE_BURNING:
				result.positioning_cells_3d.append(cell_3d)
				result.hostile_spawns.append({
					"cell": cell,
					"marker_id": marker_id,
				})
			MARKER_POTION, MARKER_HOLY_SYMBOL, MARKER_IRON_WARD, MARKER_MOP, \
			MARKER_SPLASH_FLASK, MARKER_DEBRIS:
				result.positioning_cells_3d.append(cell_3d)
				result.chest_spawns.append({
					"cell": cell,
					"marker_id": marker_id,
				})
			_:
				result.warnings.append(
					"Unknown authored floor marker id %d at %s." % [marker_id, cell],
				)

	if not result.has_player_spawn:
		result.errors.append("Authored floor is missing a PlayerSpawn marker.")
		result.ok = false

	return result


func clear_positioning_cells(grid_map: GridMap, layout: Dictionary) -> void:
	if grid_map == null:
		return

	for cell_3d in layout.get("positioning_cells_3d", []):
		if not (cell_3d is Vector3i):
			continue
		grid_map.set_cell_item(cell_3d as Vector3i, -1)


func _extract_grid_map(node: Node) -> GridMap:
	if node is GridMap:
		return node as GridMap
	return node.find_child(GRIDMAP_NODE_NAME, true, false) as GridMap


func _clear_existing_grid_map(world_root: Node3D) -> void:
	var existing := world_root.get_node_or_null(GRIDMAP_NODE_NAME)
	if existing == null:
		return
	if existing.get_parent() != null:
		existing.get_parent().remove_child(existing)
	existing.free()


func _empty_result() -> Dictionary:
	return {
		"ok": true,
		"grid_map": null,
		"has_player_spawn": false,
		"player_spawn": Vector2i.ZERO,
		"chute_cells": [],
		"exit_cells": [],
		"hostile_spawns": [],
		"chest_spawns": [],
		"positioning_cells_3d": [],
		"warnings": [],
		"errors": [],
	}