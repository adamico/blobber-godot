class_name WorldChest
extends Node3D

@export var grid_cell: Vector2i = Vector2i.ZERO
@export var item_data: ItemData
@export var world_y: float = 0.0
@export var blocks_movement: bool = true
@export var analysis_profile: Resource

var is_open: bool = false

var _state_label: Label3D
var _sprite: Sprite3D


func _ready() -> void:
	add_to_group(&"world_interactables")
	add_to_group(&"world_chests")
	_state_label = get_node_or_null("StateLabel") as Label3D
	_sprite = get_node_or_null("Sprite3D") as Sprite3D
	_update_visual_state()
	_sync_world_position()


func matches_cell(cell: Vector2i) -> bool:
	return cell == grid_cell


func interact(player) -> Dictionary:
	if is_open:
		return {
			"ok": false,
			"feedback": "CHEST EMPTY",
			"is_positive": false,
			"costs_turn": false,
		}
	if player == null or not player.has_method("add_item"):
		return {
			"ok": false,
			"feedback": "NO ACCESS",
			"is_positive": false,
			"costs_turn": false,
		}
	if item_data == null:
		return {
			"ok": false,
			"feedback": "CHEST EMPTY",
			"is_positive": false,
			"costs_turn": false,
		}

	if not bool(player.call("add_item", item_data)):
		return {
			"ok": false,
			"feedback": "INVENTORY FULL",
			"is_positive": false,
			"costs_turn": false,
		}

	item_data = null
	is_open = true
	_update_visual_state()
	queue_free()
	return {
		"ok": true,
		"feedback": "ITEM FOUND",
		"is_positive": true,
		"costs_turn": true,
	}


func _update_visual_state() -> void:
	if _state_label != null:
		_state_label.text = "Open" if is_open else "Chest"
	if _sprite != null:
		_sprite.modulate = Color(0.55, 0.55, 0.55, 1.0) if is_open else Color(1.0, 1.0, 1.0, 1.0)


func _sync_world_position() -> void:
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, world_y)
