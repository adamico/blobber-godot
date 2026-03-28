class_name WorldTurnOrchestrator
extends Node

const COMBAT_DEFEND_DIVISOR := 2
const COMBAT_USE_ITEM_HEAL_AMOUNT := 2
const PICKUP_GROUP := &"world_pickups"

var _ui_module: WorldUIModule
var _grid_module: WorldGridModule
var _run_outcome_module: WorldRunOutcomeModule
var _world_root: Node
var _player
var _is_gameplay_state_active_fn: Callable


func configure(
		ui_module: WorldUIModule,
		grid_module: WorldGridModule,
		run_outcome_module: WorldRunOutcomeModule,
		world_root: Node,
		player,
		is_gameplay_state_active_fn: Callable,
) -> void:
	_ui_module = ui_module
	_grid_module = grid_module
	_run_outcome_module = run_outcome_module
	_world_root = world_root
	_player = player
	_is_gameplay_state_active_fn = is_gameplay_state_active_fn


func process_player_action(new_state: GridState) -> void:
	_ui_module.refresh_coords(new_state.cell)
	_ui_module.refresh_minimap(new_state.cell, _grid_module.occupancy())
	_collect_pickups(new_state.cell)

	if not _is_gameplay_active():
		return

	if _run_outcome_module.is_resolved():
		return

	_run_outcome_module.evaluate(new_state.cell)
	if _run_outcome_module.is_resolved():
		return


func _collect_pickups(player_cell: Vector2i) -> void:
	if _world_root == null:
		return

	for node in _world_root.get_tree().get_nodes_in_group(PICKUP_GROUP):
		if node == null:
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		if not node.has_method("collect_if_player_on_cell"):
			continue
		node.call("collect_if_player_on_cell", _player, player_cell)


func is_run_resolved() -> bool:
	return _run_outcome_module.is_resolved()


func _is_gameplay_active() -> bool:
	if _is_gameplay_state_active_fn.is_valid():
		return bool(_is_gameplay_state_active_fn.call())
	return false
