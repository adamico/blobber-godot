class_name WorldGridModule
extends Node

var _occupancy: GridOccupancyMap


func build_occupancy(grid_map: GridMap, wall_layer: int, auto_align: bool) -> void:
	if auto_align:
		_align_gridmap_to_player_grid(grid_map)
	_occupancy = GridOccupancyMap.from_grid_map(grid_map, wall_layer)
	print(
		"[Occupancy] layer=%d wired %d blocked cells" % [
			wall_layer,
			_occupancy.get_blocked_count(),
		],
	)


func occupancy() -> GridOccupancyMap:
	return _occupancy


func is_player_cell_passable(cell: Vector2i, hostiles: Array, pickups: Array = []) -> bool:
	if _occupancy != null and not _occupancy.is_passable(cell):
		return false

	for hostile in hostiles:
		if hostile == null or hostile.grid_state == null:
			continue
		if hostile.stats != null and hostile.stats.is_dead():
			continue
		if hostile.grid_state.cell == cell or hostile.grid_state.previous_cell == cell:
			return false

	for pickup in pickups:
		if pickup == null or not is_instance_valid(pickup):
			continue
		if "grid_cell" in pickup and "blocks_movement" in pickup:
			if pickup.grid_cell == cell and pickup.blocks_movement:
				return false

	return true


func is_hostile_cell_passable(
		hostile,
		cell: Vector2i,
		hostiles: Array,
		pickups: Array = [],
) -> bool:
	if _occupancy != null and not _occupancy.is_passable(cell):
		return false

	for other in hostiles:
		if other == null or other == hostile or other.grid_state == null:
			continue
		if other.stats != null and other.stats.is_dead():
			continue
		if other.grid_state.cell == cell or other.grid_state.previous_cell == cell:
			return false

	for pickup in pickups:
		if pickup == null or not is_instance_valid(pickup):
			continue
		if "grid_cell" in pickup and "blocks_movement" in pickup:
			if pickup.grid_cell == cell and pickup.blocks_movement:
				return false

	return true


func _align_gridmap_to_player_grid(gm: GridMap) -> void:
	# Keep painted visuals aligned with integer world cells used by player movement.
	var x_offset := -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var y_offset := 0.0
	var z_offset := -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	gm.position = Vector3(x_offset, y_offset, z_offset)
