class_name Player
extends Node3D

@export var movement_config: MovementConfig
@export var eye_eight:= 0.6

var grid_state: GridState


func _read() -> void:
    if movement_config == null:
        movement_config = MovementConfig.new()
    grid_state = GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)
    _apply_canonical_transform()


func _apply_canonical_transform() -> void:
    var world_pos := GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
    global_position = world_pos
    rotation_degrees.y = grid_state.facing * 90.0