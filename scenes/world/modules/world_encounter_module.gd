class_name WorldEncounterModule
extends Node

signal encounter_detected(encountered: Array)
signal hostile_acted

const HOSTILE_GROUP := &"grid_hostiles"

@export var debug_overlap_diagnostics: bool = false

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
	_debug_log(
		"register hostile=%s has_mc=%s" % [
			_hostile_label(hostile),
			hostile.movement_controller != null,
		]
	)
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

	# Sort hostiles by initiative (lower = acts first)
	var sorted_hostiles: Array = _hostiles.duplicate()
	sorted_hostiles.sort_custom(
		func(a, b) -> bool:
			var a_init := 50 # default
			var b_init := 50
			var a_ai: HostileAI = a.get_node_or_null("HostileAI")
			var b_ai: HostileAI = b.get_node_or_null("HostileAI")
			if a_ai != null and "initiative" in a_ai:
				a_init = a_ai.initiative
			if b_ai != null and "initiative" in b_ai:
				b_init = b_ai.initiative
			return a_init < b_init
	)
	_debug_log("tick order=%s" % [_hostile_order_summary(sorted_hostiles)])

	for hostile in sorted_hostiles:
		if hostile == null:
			continue
		if not _is_hostile_alive(hostile):
			continue
		_wire_hostile(hostile)
		_debug_log(
			"tick hostile=%s cell=%s prev=%s has_passability=%s busy=%s" % [
				_hostile_label(hostile),
				hostile.grid_state.cell if hostile.grid_state != null else Vector2i(-999, -999),
				(
					hostile.grid_state.previous_cell
					if hostile.grid_state != null
					else Vector2i(-999, -999)
				),
				hostile.movement_controller != null \
					and not hostile.movement_controller.passability_fn.is_null() \
					and hostile.movement_controller.passability_fn.is_valid(),
				hostile.movement_controller != null and hostile.movement_controller.is_busy,
			]
		)
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
		_debug_log(
			"passable=false hostile=%s target=%s blocked_by=player@%s" % [
				_hostile_label(hostile),
				cell,
				_player.grid_state.cell,
			]
		)
		return false
	if _grid_module != null:
		var pickups := []
		if _world_root != null:
			pickups = _world_root.get_tree().get_nodes_in_group(&"world_pickups")
			pickups.append_array(_world_root.get_tree().get_nodes_in_group(&"world_chests"))
		var passable := _grid_module.is_hostile_cell_passable(hostile, cell, _hostiles, pickups)
		if not passable:
			_debug_log(
				"passable=false hostile=%s target=%s blockers=%s" % [
					_hostile_label(hostile),
					cell,
					_blockers_summary(hostile, cell, pickups),
				]
			)
		return passable
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
		_debug_log(
			"wire skipped hostile=%s reason=no_movement_controller" % [
				_hostile_label(hostile),
			]
		)
		return

	var captured_hostile = hostile
	hostile.movement_controller.passability_fn = func(cell: Vector2i) -> bool:
		return _hostile_cell_passable(captured_hostile, cell)
	_debug_log("wire hostile=%s passability_attached=true" % [_hostile_label(hostile)])

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


func _debug_log(message: String) -> void:
	if not debug_overlap_diagnostics:
		return
	print("[HostileOverlapDebug] %s" % message)


func _hostile_label(hostile) -> String:
	if hostile == null or not is_instance_valid(hostile):
		return "<invalid>"
	var hostile_name: String = String(hostile.name)
	var hostile_id: int = hostile.get_instance_id()
	return "%s#%s" % [hostile_name, hostile_id]


func _hostile_order_summary(hostiles: Array) -> String:
	var parts: Array[String] = []
	for hostile in hostiles:
		if hostile == null or not is_instance_valid(hostile):
			continue
		var ai: HostileAI = hostile.get_node_or_null("HostileAI")
		var initiative := ai.initiative if ai != null else 50
		var cell: Vector2i = (
			hostile.grid_state.cell if hostile.grid_state != null else Vector2i(-999, -999)
		)
		parts.append(
			"%s(i=%d cell=%s)" % [
				_hostile_label(hostile),
				initiative,
				cell,
			]
		)
	return ", ".join(parts)


func _blockers_summary(hostile, cell: Vector2i, pickups: Array) -> String:
	var blockers: Array[String] = []
	if _grid_module != null \
	and _grid_module.occupancy() != null \
	and not _grid_module.occupancy().is_passable(cell):
		blockers.append("wall")
	for other in _hostiles:
		if other == null or other == hostile or other.grid_state == null:
			continue
		if other.stats != null and other.stats.is_dead():
			continue
		if other.grid_state.cell == cell or other.grid_state.previous_cell == cell:
			blockers.append(
				"hostile=%s cell=%s prev=%s" % [
					_hostile_label(other),
					other.grid_state.cell,
					other.grid_state.previous_cell,
				]
			)
	for pickup in pickups:
		if pickup == null or not is_instance_valid(pickup):
			continue
		if "grid_cell" in pickup and "blocks_movement" in pickup:
			if pickup.grid_cell == cell and pickup.blocks_movement:
				blockers.append("pickup=%s" % pickup.name)
	return ", ".join(blockers)
