class_name WorldPickup
extends Node3D

signal collected(item: ItemData)

@export var grid_cell: Vector2i = Vector2i.ZERO
@export var item_data: ItemData
@export var world_y: float = 0.0

var blocks_movement: bool = false
var revert_turns_remaining: int = 0
var origin_hostile_definition_id: StringName = StringName()
var spawned_from_player_drop: bool = false

var _timer_label: Label3D


func _ready() -> void:
	if item_data != null and item_data.item_type == ItemData.ItemType.DEBRIS:
		blocks_movement = true
	add_to_group(&"world_pickups")
	add_to_group(&"world_interactables")
	_timer_label = get_node_or_null("TimerLabel") as Label3D

	_update_label()

	_sync_world_position()


func setup_revert(turns: int, origin_definition_id: StringName) -> void:
	revert_turns_remaining = turns
	origin_hostile_definition_id = origin_definition_id
	_update_label()


func tick_revert() -> bool:
	if revert_turns_remaining <= 0:
		return false
	revert_turns_remaining -= 1
	_update_label()
	return revert_turns_remaining <= 0


func _update_label() -> void:
	if _timer_label != null:
		if revert_turns_remaining > 0:
			_timer_label.text = str(revert_turns_remaining)
		else:
			_timer_label.text = ""


func collect_if_player_on_cell(player, player_cell: Vector2i) -> bool:
	if item_data == null:
		return false
	if player == null:
		return false
	if player_cell != grid_cell:
		return false
	if not player.has_method("add_item"):
		return false
	if not bool(player.call("add_item", item_data)):
		return false

	collected.emit(item_data)
	queue_free()
	return true


func interact(player) -> Dictionary:
	if item_data == null:
		return {
			"ok": false,
			"feedback": "NOTHING HERE",
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

	if not bool(player.call("add_item", item_data)):
		return {
			"ok": false,
			"feedback": "INVENTORY FULL",
			"is_positive": false,
			"costs_turn": false,
		}

	collected.emit(item_data)
	queue_free()
	return {
		"ok": true,
		"feedback": "PICKED UP",
		"is_positive": true,
		"costs_turn": true,
	}


func _sync_world_position() -> void:
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, world_y)
