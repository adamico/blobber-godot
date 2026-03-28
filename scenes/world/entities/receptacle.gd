class_name Receptacle
extends Node3D

signal item_cleaned(item: ItemData, points: int)

enum Type { DISPOSAL, SMELTER, RITUAL }

@export var receptacle_type: Type = Type.DISPOSAL
@export var required_property: StringName = &""
@export var grid_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group(&"interactable")
	_sync_position()


func matches_cell(cell: Vector2i) -> bool:
	return cell == grid_cell


func interact(player: Player) -> void:
	var inventory = player.inventory
	if inventory == null:
		return

	var items = inventory.get_items()
	for item in items:
		if required_property == &"" or item.has_property(required_property):
			if inventory.remove_item(item):
				item_cleaned.emit(item, 10)
				_play_cleanup_feedback()
				return


func _sync_position() -> void:
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, 0.0)


func _play_cleanup_feedback() -> void:
	# Placeholder for future visual/audio feedback
	var msg := "Item cleaned!"
	match receptacle_type:
		Type.DISPOSAL:
			msg = "Item disposed of!"
		Type.SMELTER:
			msg = "Item incinerated!"
		Type.RITUAL:
			msg = "Item purified!"
	
	print("[Receptacle] %s" % msg)
