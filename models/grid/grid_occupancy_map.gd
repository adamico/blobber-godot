class_name GridOccupancyMap
extends RefCounted

var _blocked: Dictionary # Vector2i -> true


static func from_grid_map(gm: GridMap, wall_layer: int = 0) -> GridOccupancyMap:
	var om := GridOccupancyMap.new()
	for cell_3i: Vector3i in gm.get_used_cells():
		if cell_3i.y == wall_layer:
			om._blocked[Vector2i(cell_3i.x, cell_3i.z)] = true
	return om


func is_passable(cell: Vector2i) -> bool:
	return not _blocked.has(cell)


func get_blocked_count() -> int:
	return _blocked.size()


func set_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)


func is_line_of_sight_clear(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true

	var start := Vector2(a) + Vector2(0.5, 0.5)
	var end := Vector2(b) + Vector2(0.5, 0.5)
	var diff := end - start
	var dist := diff.length()
	var step_count := int(ceil(dist * 3.0)) # Supersampling to ensure we don't miss diagonals

	for i in range(1, step_count):
		var t := float(i) / float(step_count)
		var sample := start.lerp(end, t)
		var cell := Vector2i(floor(sample.x), floor(sample.y))
		if cell == a or cell == b:
			continue
		if not is_passable(cell):
			return false

	return true
