extends Node
class_name WorldTurnOrchestrator

var _ui_module: WorldUIModule
var _grid_module: WorldGridModule
var _encounter_module: WorldEncounterModule
var _run_outcome_module: WorldRunOutcomeModule
var _is_gameplay_state_active_fn: Callable


func configure(
		ui_module: WorldUIModule,
		grid_module: WorldGridModule,
		encounter_module: WorldEncounterModule,
		run_outcome_module: WorldRunOutcomeModule,
		is_gameplay_state_active_fn: Callable) -> void:
	_ui_module = ui_module
	_grid_module = grid_module
	_encounter_module = encounter_module
	_run_outcome_module = run_outcome_module
	_is_gameplay_state_active_fn = is_gameplay_state_active_fn


func process_player_action(new_state: GridState) -> void:
	_ui_module.refresh_coords(new_state.cell)
	_ui_module.refresh_minimap(new_state.cell, _grid_module.occupancy())
	_encounter_module.collect()

	if not _is_gameplay_active():
		return

	if _run_outcome_module.is_resolved():
		return

	_run_outcome_module.evaluate(new_state.cell)
	if _run_outcome_module.is_resolved():
		return

	if _encounter_module.check_combat_trigger():
		return

	_encounter_module.tick_step_echo()
	_encounter_module.check_combat_trigger()


func process_enemy_action() -> void:
	if not _is_gameplay_active() or _run_outcome_module.is_resolved():
		return
	_encounter_module.check_combat_trigger()


func is_run_resolved() -> bool:
	return _run_outcome_module.is_resolved()


func _is_gameplay_active() -> bool:
	if _is_gameplay_state_active_fn.is_valid():
		return bool(_is_gameplay_state_active_fn.call())
	return false
