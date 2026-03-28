extends Node

class_name WorldEventRouterOrchestrator

var _event_bus: WorldEventBus
var _restart_run_fn: Callable
var _return_to_title_fn: Callable
var _finish_with_success_fn: Callable
var _finish_with_failure_fn: Callable
var _process_player_action_fn: Callable
var _is_gameplay_state_active_fn: Callable


func configure(
		event_bus: WorldEventBus,
		restart_run_fn: Callable,
		return_to_title_fn: Callable,
		finish_with_success_fn: Callable,
		finish_with_failure_fn: Callable,
		process_player_action_fn: Callable,
		is_gameplay_state_active_fn: Callable,
) -> void:
	_event_bus = event_bus
	_restart_run_fn = restart_run_fn
	_return_to_title_fn = return_to_title_fn
	_finish_with_success_fn = finish_with_success_fn
	_finish_with_failure_fn = finish_with_failure_fn
	_process_player_action_fn = process_player_action_fn
	_is_gameplay_state_active_fn = is_gameplay_state_active_fn

	_connect_bus()


func _connect_bus() -> void:
	if _event_bus == null:
		return

	if not _event_bus.overlay_restart_requested.is_connected(_on_overlay_restart_requested):
		_event_bus.overlay_restart_requested.connect(_on_overlay_restart_requested)
	if not _event_bus.overlay_return_to_title_requested.is_connected(
		_on_overlay_return_to_title_requested,
	):
		_event_bus.overlay_return_to_title_requested.connect(_on_overlay_return_to_title_requested)
	if not _event_bus.run_outcome_success_reached.is_connected(_on_run_outcome_success_reached):
		_event_bus.run_outcome_success_reached.connect(_on_run_outcome_success_reached)
	if not _event_bus.run_outcome_failure_reached.is_connected(_on_run_outcome_failure_reached):
		_event_bus.run_outcome_failure_reached.connect(_on_run_outcome_failure_reached)

	if not _event_bus.player_action_completed.is_connected(_on_player_action_completed):
		_event_bus.player_action_completed.connect(_on_player_action_completed)


func _on_overlay_restart_requested() -> void:
	if _restart_run_fn.is_valid():
		_restart_run_fn.call()


func _on_overlay_return_to_title_requested() -> void:
	if _return_to_title_fn.is_valid():
		_return_to_title_fn.call()


func _on_run_outcome_success_reached() -> void:
	if _finish_with_success_fn.is_valid():
		_finish_with_success_fn.call()


func _on_run_outcome_failure_reached() -> void:
	if _finish_with_failure_fn.is_valid():
		_finish_with_failure_fn.call()


func _on_player_action_completed(new_state: GridState) -> void:
	if _process_player_action_fn.is_valid():
		_process_player_action_fn.call(new_state)


func _is_gameplay_state_active() -> bool:
	if _is_gameplay_state_active_fn.is_valid():
		return bool(_is_gameplay_state_active_fn.call())
	return false
