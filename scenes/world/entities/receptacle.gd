class_name Receptacle
extends Sprite3D

signal item_cleaned(item: ItemData, points: int)

enum Type { DISPOSAL, SMELTER, RITUAL }

@export var receptacle_type: Type = Type.DISPOSAL
@export var required_property: StringName = &""
@export var grid_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group(&"interactable")
	
	match receptacle_type:
		Type.DISPOSAL:
			texture = load("res://assets/textures/receptacle_disposal.png")
		Type.SMELTER:
			texture = load("res://assets/textures/receptacle_smelter.png")
		Type.RITUAL:
			texture = load("res://assets/textures/receptacle_ritual.png")

	billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	pixel_size = 0.0008 # Scale 1024px to ~0.8 units
	_sync_position()
	print("[Receptacle] Ready at grid %s, world %s, type %s" % [grid_cell, global_position, receptacle_type])


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
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, 0.4)


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
