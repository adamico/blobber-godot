class_name WorldEncounterModule
extends Node

signal encounter_detected(encountered: Array)
signal hostile_acted

const HOSTILE_GROUP := &"grid_hostiles"

var _hostiles: Array = []
var _registered_hostiles: Array = []
var _grid_module: WorldGridModule
var _world_root: Node
var _player


func configure(world_root: Node, player, grid_module: WorldGridModule) -> void:
	_world_root = world_root
	_player = player
	_grid_module = grid_module


func get_hostiles() -> Array:
	return _hostiles


func register_hostile(hostile) -> void:
	if hostile == null or not is_instance_valid(hostile):
		return
	if not hostile.has_method("tick_ai"):
		return
	if _registered_hostiles.has(hostile):
		return
	_registered_hostiles.append(hostile)
	_wire_hostile(hostile)


func unregister_hostile(hostile) -> void:
	if hostile == null:
		return
	_registered_hostiles.erase(hostile)
	_hostiles.erase(hostile)


func wire_hostiles() -> void:
	_bootstrap_registered_hostiles_from_group()
	collect()
	for hostile in _hostiles:
		_wire_hostile(hostile)


func collect() -> void:
	if _world_root == null or _world_root.get_tree() == null:
		return

	_hostiles.clear()
	var alive_registered: Array = []
	for node in _registered_hostiles:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		alive_registered.append(node)
		_hostiles.append(node)
	_registered_hostiles = alive_registered


func tick_step_echo() -> void:
	if _player == null:
		return

	collect()

	for hostile in _hostiles:
		if hostile == null:
			continue
		if not _is_hostile_alive(hostile):
			continue
		hostile.tick_ai(_player)


func check_combat_trigger() -> bool:
	if _player == null or _player.grid_state == null:
		return false

	collect()

	var encountered: Array = []
	for hostile in _hostiles:
		if hostile == null or hostile.grid_state == null:
			continue
		if not _is_hostile_alive(hostile):
			continue
		var delta: Vector2i = hostile.grid_state.cell - _player.grid_state.cell
		var manhattan: int = absi(delta.x) + absi(delta.y)
		if manhattan <= 1:
			encountered.append(hostile)

	if encountered.is_empty():
		return false

	encounter_detected.emit(encountered)
	return true


func _hostile_cell_passable(hostile, cell: Vector2i) -> bool:
	if _player != null and _player.grid_state != null and _player.grid_state.cell == cell:
		return false
	if _grid_module != null:
		var pickups := []
		if _world_root != null:
			pickups = _world_root.get_tree().get_nodes_in_group(&"world_pickups")
			pickups.append_array(_world_root.get_tree().get_nodes_in_group(&"world_chests"))
		return _grid_module.is_hostile_cell_passable(hostile, cell, _hostiles, pickups)
	return true


func _on_hostile_action_completed(_cmd, _new_state, _hostile) -> void:
	hostile_acted.emit()


func _bootstrap_registered_hostiles_from_group() -> void:
	if _world_root == null or _world_root.get_tree() == null:
		return
	for node in _world_root.get_tree().get_nodes_in_group(HOSTILE_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		if not node.has_method("tick_ai"):
			continue
		if _registered_hostiles.has(node):
			continue
		_registered_hostiles.append(node)


func _wire_hostile(hostile) -> void:
	if hostile == null or not is_instance_valid(hostile):
		return
	if hostile.movement_controller == null:
		return

	var captured_hostile = hostile
	hostile.movement_controller.passability_fn = func(cell: Vector2i) -> bool:
		return _hostile_cell_passable(captured_hostile, cell)

	if hostile.has_method("set_grid_module"):
		hostile.set_grid_module(_grid_module, _world_root)
	elif hostile.get_node_or_null("HostileAI") != null:
		var ai = hostile.get_node("HostileAI")
		if ai.has_method("set_grid_module"):
			ai.set_grid_module(_grid_module, _world_root)

	var action_sig: Signal = hostile.movement_controller.action_completed
	var bind_cb := _on_hostile_action_completed.bind(hostile)
	if not action_sig.is_connected(bind_cb):
		action_sig.connect(bind_cb)


func _is_hostile_alive(hostile) -> bool:
	if hostile == null:
		return false
	if not is_instance_valid(hostile):
		return false
	if hostile.stats == null:
		return true
	return not hostile.stats.is_dead()
