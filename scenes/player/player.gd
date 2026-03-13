class_name Player
extends Node3D

@export var movement_config: MovementConfig
@export var eye_height := 0.6

var grid_state: GridState
var movement_controller: MovementController
var _active_tween: Tween

func _ready() -> void:
    if movement_config == null:
        movement_config = MovementConfig.new()

    grid_state = GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)
    _apply_canonical_transform()

    movement_controller = MovementController.new()
    movement_controller.grid_state = grid_state
    movement_controller.movement_config = movement_config
    add_child(movement_controller)

    movement_controller.action_started.connect(_on_action_started)
    movement_controller.action_completed.connect(_on_action_completed)

func execute_command(cmd: PlayerCommand.Type) -> bool:
    return movement_controller.execute_command(cmd)

func _apply_canonical_transform() -> void:
    var world_pos := GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
    global_position = world_pos
    rotation_degrees.y = grid_state.facing * 90.0

func _on_action_started(_cmd: PlayerCommand.Type, previous_state: GridState, new_state: GridState, duration: float) -> void:
    if movement_config == null or not movement_config.smooth_mode or duration <= 0.0:
        return

    if is_instance_valid(_active_tween):
        _active_tween.kill()

    var start_pos := GridMapper.cell_to_world(previous_state.cell, movement_config.cell_size, 0.0)
    var target_pos := GridMapper.cell_to_world(new_state.cell, movement_config.cell_size, 0.0)
    var start_yaw := float(previous_state.facing) * 90.0
    var target_yaw := _resolve_target_yaw(start_yaw, float(new_state.facing) * 90.0)

    global_position = start_pos
    rotation_degrees.y = start_yaw

    _active_tween = create_tween()
    _active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _active_tween.tween_property(self, "global_position", target_pos, duration)
    _active_tween.parallel().tween_method(_set_yaw, start_yaw, target_yaw, duration)

func _on_action_completed(_cmd: PlayerCommand.Type, new_state: GridState) -> void:
    if is_instance_valid(_active_tween):
        _active_tween.kill()
        _active_tween = null
        grid_state = new_state
        _apply_canonical_transform()

func _set_yaw(value: float) -> void:
    rotation_degrees.y = value

func _resolve_target_yaw(start_yaw: float, base_target_yaw: float) -> float:
    var delta := fmod(base_target_yaw - start_yaw + 540.0, 360.0) - 180.0
    return start_yaw + delta