class_name Player
extends Node3D

@export var movement_config: MovementConfig
@export var eye_height := 0.6

var grid_state: GridState
var movement_controller: MovementController

func _ready() -> void:
    if movement_config == null:
        movement_config = MovementConfig.new()

    grid_state = GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)
    _apply_canonical_transform()

    movement_controller = MovementController.new()
    movement_controller.grid_state = grid_state
    add_child(movement_controller)

    movement_controller.action_completed.connect(_on_action_completed)


func execute_command(cmd: PlayerCommand.Type) -> bool:
    return movement_controller.execute_command(cmd)


func _apply_canonical_transform() -> void:
    var world_pos := GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
    global_position = world_pos
    rotation_degrees.y = grid_state.facing * 90.0


func _on_action_completed(_cmd: PlayerCommand.Type, new_state: GridState) -> void:
    grid_state = new_state
    _apply_canonical_transform()