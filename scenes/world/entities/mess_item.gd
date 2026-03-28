class_name MessItem
extends Sprite3D

@export var item_data: ItemData
@export var grid_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group(&"interactable")
	if item_data != null and item_data.texture != null:
		texture = item_data.texture

	billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	_sync_position()


func matches_cell(cell: Vector2i) -> bool:
	return cell == grid_cell


func interact(player: Player) -> void:
	if player.add_item(item_data):
		queue_free()


func _sync_position() -> void:
	# Assuming cell size 1.0 for now, same as WorldExit
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, 0.2)
