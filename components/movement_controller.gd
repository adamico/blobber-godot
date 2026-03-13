class_name MovementController
extends Node

const MovementOutcomeData := preload("res://models/movement_outcome.gd")

signal action_started(cmd: PlayerCommand.Type, previous_state: GridState, new_state: GridState, duration: float)
signal action_completed(cmd: PlayerCommand.Type, new_state: GridState)
signal movement_outcome(outcome)

var grid_state: GridState
var movement_config: MovementConfig
var is_busy: bool = false
var passability_fn: Callable


func execute_command(cmd: PlayerCommand.Type) -> bool:
	if is_busy or grid_state == null:
		return false

	var previous_state := _clone_state(grid_state)

	if not _is_command_passable(cmd):
		_emit_outcome(cmd, MovementOutcomeData.TYPE_BLOCKED, MovementOutcomeData.PHASE_DECISION, previous_state, previous_state, 0.0)
		return false

	is_busy = true
	var outcome_type := _outcome_type_for_command(cmd)

	match cmd:
		PlayerCommand.Type.STEP_FORWARD:
			grid_state.cell += GridDefinitions.facing_to_vec2i(grid_state.facing)
		PlayerCommand.Type.STEP_BACK:
			grid_state.cell -= GridDefinitions.facing_to_vec2i(grid_state.facing)
		PlayerCommand.Type.MOVE_LEFT:
			var left_facing := GridDefinitions.rotate_left(grid_state.facing)
			grid_state.cell += GridDefinitions.facing_to_vec2i(left_facing)
		PlayerCommand.Type.MOVE_RIGHT:
			var right_facing := GridDefinitions.rotate_right(grid_state.facing)
			grid_state.cell += GridDefinitions.facing_to_vec2i(right_facing)
		PlayerCommand.Type.TURN_LEFT:
			grid_state.facing = GridDefinitions.rotate_left(grid_state.facing)
		PlayerCommand.Type.TURN_RIGHT:
			grid_state.facing = GridDefinitions.rotate_right(grid_state.facing)

	var new_state := _clone_state(grid_state)
	var duration := _command_duration(cmd)
	_emit_outcome(cmd, outcome_type, MovementOutcomeData.PHASE_START, previous_state, new_state, duration)

	if _is_smooth_mode_enabled() and duration > 0.0:
		action_started.emit(cmd, previous_state, new_state, duration)
		_complete_smooth_command(cmd, previous_state, new_state, outcome_type, duration)
	else:
		is_busy = false
		_emit_outcome(cmd, outcome_type, MovementOutcomeData.PHASE_COMPLETE, previous_state, new_state, duration)
		action_completed.emit(cmd, new_state)

	return true


func _compute_target_cell(cmd: PlayerCommand.Type) -> Vector2i:
	match cmd:
		PlayerCommand.Type.STEP_FORWARD:
			return grid_state.cell + GridDefinitions.facing_to_vec2i(grid_state.facing)
		PlayerCommand.Type.STEP_BACK:
			return grid_state.cell - GridDefinitions.facing_to_vec2i(grid_state.facing)
		PlayerCommand.Type.MOVE_LEFT:
			return grid_state.cell + GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_left(grid_state.facing))
		PlayerCommand.Type.MOVE_RIGHT:
			return grid_state.cell + GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_right(grid_state.facing))
		_:
			return grid_state.cell  # turns stay in place


func _is_command_passable(cmd: PlayerCommand.Type) -> bool:
	match cmd:
		PlayerCommand.Type.TURN_LEFT, PlayerCommand.Type.TURN_RIGHT:
			return true
		_:
			if passability_fn.is_null() or not passability_fn.is_valid():
				return true
			return passability_fn.call(_compute_target_cell(cmd))


func _is_smooth_mode_enabled() -> bool:
	return movement_config != null and movement_config.smooth_mode


func _command_duration(cmd: PlayerCommand.Type) -> float:
	if movement_config == null:
		return 0.0

	match cmd:
		PlayerCommand.Type.TURN_LEFT, PlayerCommand.Type.TURN_RIGHT:
			return maxf(movement_config.turn_duration, 0.0)
		_:
			return maxf(movement_config.step_duration, 0.0)


func _clone_state(state: GridState) -> GridState:
	return GridState.new(state.cell, state.facing)


func _complete_smooth_command(
	cmd: PlayerCommand.Type,
	previous_state: GridState,
	new_state: GridState,
	outcome_type: String,
	duration: float
) -> void:
	await get_tree().create_timer(duration).timeout
	is_busy = false
	_emit_outcome(cmd, outcome_type, MovementOutcomeData.PHASE_COMPLETE, previous_state, new_state, duration)
	action_completed.emit(cmd, new_state)


func _outcome_type_for_command(cmd: PlayerCommand.Type) -> String:
	match cmd:
		PlayerCommand.Type.TURN_LEFT, PlayerCommand.Type.TURN_RIGHT:
			return MovementOutcomeData.TYPE_TURNED
		_:
			return MovementOutcomeData.TYPE_MOVED


func _emit_outcome(
	cmd: PlayerCommand.Type,
	outcome_type: String,
	phase: String,
	state_before: GridState,
	state_after: GridState,
	duration: float
) -> void:
	var outcome := MovementOutcomeData.new(cmd, outcome_type, phase, state_before, state_after, duration)
	movement_outcome.emit(outcome)
