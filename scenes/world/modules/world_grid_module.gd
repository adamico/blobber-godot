extends Node

class_name WorldGridModule

var _occupancy: GridOccupancyMap


func build_occupancy(grid_map: GridMap, wall_layer: int, auto_align: bool) -> void:
	if auto_align:
		_align_gridmap_to_player_grid(grid_map)
	_occupancy = GridOccupancyMap.from_grid_map(grid_map, wall_layer)
	print("[Occupancy] layer=%d wired" % [wall_layer])


func occupancy() -> GridOccupancyMap:
	return _occupancy


func is_player_cell_passable(cell: Vector2i) -> bool:
	if _occupancy != null and not _occupancy.is_passable(cell):
		return false
	return true


func _align_gridmap_to_player_grid(gm: GridMap) -> void:
	# Keep painted visuals aligned with integer world cells used by player movement.
	var x_offset := -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var y_offset := 0.0
	var z_offset := -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	gm.position = Vector3(x_offset, y_offset, z_offset)
