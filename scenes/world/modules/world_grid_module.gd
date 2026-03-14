extends Node
class_name WorldGridModule

var _occupancy: GridOccupancyMap


func configure(_player_ref, _grid_map: GridMap, _wall_layer: int, _auto_align_gridmap_visual: bool) -> void:
	pass


func occupancy() -> GridOccupancyMap:
	return _occupancy


func is_player_cell_passable(_cell: Vector2i, _enemies: Array) -> bool:
	return true


func is_enemy_cell_passable(_enemy, _cell: Vector2i, _enemies: Array) -> bool:
	return true
