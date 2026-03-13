class_name MovementController
extends Node

signal action_started(cmd: PlayerCommand.Type, previous_state: GridState, new_state: GridState, duration: float)
signal action_completed(cmd: PlayerCommand.Type, new_state: GridState)

var grid_state: GridState
var movement_config: MovementConfig
var is_busy: bool = false


func execute_command(cmd: PlayerCommand.Type) -> bool:
    if is_busy or grid_state == null:
        return false

    is_busy = true
    var previous_state := _clone_state(grid_state)

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

    if _is_smooth_mode_enabled() and duration > 0.0:
        action_started.emit(cmd, previous_state, new_state, duration)
        _complete_smooth_command(cmd, new_state, duration)
    else:
        action_completed.emit(cmd, new_state)
        is_busy = false

    return true


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


func _complete_smooth_command(cmd: PlayerCommand.Type, new_state: GridState, duration: float) -> void:
    await get_tree().create_timer(duration).timeout
    action_completed.emit(cmd, new_state)
    is_busy = false

