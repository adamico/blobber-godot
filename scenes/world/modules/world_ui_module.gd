extends Node
class_name WorldUIModule


func configure(_player_ref, _debug_panel: Control, _grid_coords_label: Label, _minimap_overlay: Control) -> void:
	pass


func refresh_grid_coordinates_overlay(_cell: Vector2i = Vector2i.ZERO) -> void:
	pass


func refresh_minimap_overlay(_cell: Vector2i = Vector2i.ZERO) -> void:
	pass
