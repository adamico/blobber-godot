extends Node3D

@export var occupancy_wall_layer := 0
@export var auto_align_gridmap_visual := true

var _occupancy: GridOccupancyMap

func _ready() -> void:
	# Defer to ensure all children (including Player) have finished _ready().
	_wire_occupancy.call_deferred()


func _wire_occupancy() -> void:
	var gm := get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	if auto_align_gridmap_visual:
		_align_gridmap_to_player_grid(gm)

	_occupancy = GridOccupancyMap.from_grid_map(gm, occupancy_wall_layer)
	var player: Player = get_node_or_null("Player")
	if player != null and player.movement_controller != null:
		player.movement_controller.passability_fn = _occupancy.is_passable
		print("[Occupancy] layer=%d wired %d blocked cells" % [occupancy_wall_layer, _occupancy._blocked.size()])


func _align_gridmap_to_player_grid(gm: GridMap) -> void:
	# Keep painted visuals aligned with integer world cells used by player movement.
	var x_offset := -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var y_offset := 0.0
	var z_offset := -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	gm.position = Vector3(x_offset, y_offset, z_offset)
