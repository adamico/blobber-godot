class_name DisposalChute
extends Node3D

const CHUTE_GROUP := &"disposal_chutes"

@export var grid_cell: Vector2i = Vector2i.ZERO
@export var world_y: float = 0.0


func _ready() -> void:
	add_to_group(CHUTE_GROUP)
	_sync_world_position()


func matches_cell(cell: Vector2i) -> bool:
	return cell == grid_cell


func accepts_item(item: ItemData) -> bool:
	if item == null:
		return false
	return item.item_type == ItemData.ItemType.DEBRIS


func _sync_world_position() -> void:
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, world_y)
