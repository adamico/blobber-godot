class_name WorldTurnOrchestrator
extends Node
## Legacy turn orchestrator — kept as a stub for compatibility with
## WorldCompositionOrchestrator and WorldEventRouterOrchestrator.
## Actual turn logic is now in WorldTurnManager.

const PICKUP_GROUP := &"world_pickups"

var _ui_module: WorldUIModule
var _grid_module: WorldGridModule
var _encounter_module: WorldEncounterModule
var _run_outcome_module: WorldRunOutcomeModule
var _world_root: Node
var _player


func configure(
		ui_module: WorldUIModule,
		grid_module: WorldGridModule,
		encounter_module: WorldEncounterModule,
		run_outcome_module: WorldRunOutcomeModule,
		world_root: Node,
		player,
		_is_gameplay_state_active_fn: Callable,
		_is_combat_state_active_fn: Callable,
		_end_combat_fn: Callable,
		_finish_with_failure_fn: Callable,
) -> void:
	_ui_module = ui_module
	_grid_module = grid_module
	_encounter_module = encounter_module
	_run_outcome_module = run_outcome_module
	_world_root = world_root
	_player = player


func process_player_action(new_state: GridState) -> void:
	if _ui_module != null:
		_ui_module.refresh_coords(new_state.cell)
		_ui_module.refresh_minimap(new_state.cell, _grid_module.occupancy())


func process_enemy_action() -> void:
	pass


func start_combat_round(_enemies: Array) -> void:
	pass


func handle_combat_input(_event: InputEvent) -> bool:
	return false


func submit_player_combat_intent(_cmd: GridCommand.Type) -> bool:
	return false


func is_run_resolved() -> bool:
	if _run_outcome_module == null:
		return false
	return _run_outcome_module.is_resolved()
