class_name MovementController
extends Node

signal action_completed(cmd: PlayerCommand.Type, new_state: GridState)

var grid_state: GridState
var is_busy: bool = false


func execute_command(cmd: PlayerCommand.Type) -> bool:
    if is_busy or grid_state == null:
        return false

    is_busy = true

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

    action_completed.emit(cmd, grid_state)
    is_busy = false
    return true

