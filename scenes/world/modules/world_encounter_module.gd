class_name WorldEncounterModule
extends Node

signal encounter_detected(encountered: Array)
signal enemy_acted

const ENEMY_GROUP := &"grid_enemies"

var _enemies: Array = []
var _registered_hostiles: Array = []
var _grid_module: WorldGridModule
var _world_root: Node
var _player


func configure(world_root: Node, player, grid_module: WorldGridModule) -> void:
	_world_root = world_root
	_player = player
	_grid_module = grid_module


func get_enemies() -> Array:
	return _enemies


func register_hostile(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("tick_ai"):
		return
	if _registered_hostiles.has(enemy):
		return
	_registered_hostiles.append(enemy)
	_wire_enemy(enemy)


func unregister_hostile(enemy) -> void:
	if enemy == null:
		return
	_registered_hostiles.erase(enemy)
	_enemies.erase(enemy)


func wire_enemies() -> void:
	_bootstrap_registered_hostiles_from_group()
	collect()
	for enemy in _enemies:
		_wire_enemy(enemy)


func collect() -> void:
	if _world_root == null or _world_root.get_tree() == null:
		return

	_enemies.clear()
	var alive_registered: Array = []
	for node in _registered_hostiles:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		alive_registered.append(node)
		_enemies.append(node)
	_registered_hostiles = alive_registered


func tick_step_echo() -> void:
	if _player == null:
		return

	collect()

	for enemy in _enemies:
		if enemy == null:
			continue
		if not _is_enemy_alive(enemy):
			continue
		enemy.tick_ai(_player)


func check_combat_trigger() -> bool:
	if _player == null or _player.grid_state == null:
		return false

	collect()

	var encountered: Array = []
	for enemy in _enemies:
		if enemy == null or enemy.grid_state == null:
			continue
		if not _is_enemy_alive(enemy):
			continue
		var delta: Vector2i = enemy.grid_state.cell - _player.grid_state.cell
		var manhattan: int = absi(delta.x) + absi(delta.y)
		if manhattan <= 1:
			encountered.append(enemy)

	if encountered.is_empty():
		return false

	encounter_detected.emit(encountered)
	return true


func _enemy_cell_passable(enemy, cell: Vector2i) -> bool:
	if _player != null and _player.grid_state != null and _player.grid_state.cell == cell:
		return false
	if _grid_module != null:
		var pickups := []
		if _world_root != null:
			pickups = _world_root.get_tree().get_nodes_in_group(&"world_pickups")
		return _grid_module.is_enemy_cell_passable(enemy, cell, _enemies, pickups)
	return true


func _on_enemy_action_completed(_cmd, _new_state, _enemy) -> void:
	enemy_acted.emit()


func _bootstrap_registered_hostiles_from_group() -> void:
	if _world_root == null or _world_root.get_tree() == null:
		return
	for node in _world_root.get_tree().get_nodes_in_group(ENEMY_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		if not node.has_method("tick_ai"):
			continue
		if _registered_hostiles.has(node):
			continue
		_registered_hostiles.append(node)


func _wire_enemy(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.movement_controller == null:
		return

	var captured_enemy = enemy
	enemy.movement_controller.passability_fn = func(cell: Vector2i) -> bool:
		return _enemy_cell_passable(captured_enemy, cell)

	if enemy.has_method("set_grid_module"):
		enemy.set_grid_module(_grid_module, _world_root)
	elif enemy.get_node_or_null("EnemyAI") != null:
		var ai = enemy.get_node("EnemyAI")
		if ai.has_method("set_grid_module"):
			ai.set_grid_module(_grid_module, _world_root)

	var action_sig: Signal = enemy.movement_controller.action_completed
	var bind_cb := _on_enemy_action_completed.bind(enemy)
	if not action_sig.is_connected(bind_cb):
		action_sig.connect(bind_cb)


func _is_enemy_alive(enemy) -> bool:
	if enemy == null:
		return false
	if not is_instance_valid(enemy):
		return false
	if enemy.stats == null:
		return true
	return not enemy.stats.is_dead()
