class_name Player
extends Node3D

const MovementOutcomeData := preload("res://models/movement_outcome.gd")

signal blocked_feedback_cue(cmd: PlayerCommand.Type)

@export var movement_config: MovementConfig
@export var eye_height := 0.6
@export var input_actions_enabled := true
@export var command_processing_enabled := true
@export var debug_log_input_actions := false

const INVALID_COMMAND := -1

@onready var _camera: Camera3D = $Camera3D

var grid_state: GridState
var movement_controller: MovementController
var _active_tween: Tween
var _blocked_tween: Tween
var _queued_command: int = INVALID_COMMAND


func _ready() -> void:
    if movement_config == null:
        movement_config = MovementConfig.new()

    _sync_camera_height()

    grid_state = GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)
    _apply_canonical_transform()

    movement_controller = MovementController.new()
    movement_controller.grid_state = grid_state
    movement_controller.movement_config = movement_config
    add_child(movement_controller)

    movement_controller.action_started.connect(_on_action_started)
    movement_controller.action_completed.connect(_on_action_completed)
    movement_controller.movement_outcome.connect(_on_movement_outcome)


func execute_command(cmd: PlayerCommand.Type) -> bool:
    if movement_controller == null:
        return false

    if not command_processing_enabled:
        return false

    if movement_controller.is_busy:
        return _enqueue_command(cmd)

    return movement_controller.execute_command(cmd)


func pause_exploration_commands() -> void:
    input_actions_enabled = false
    command_processing_enabled = false


func resume_exploration_commands() -> void:
    command_processing_enabled = true
    input_actions_enabled = true
    _drain_queued_command()


func execute_action(action: StringName) -> bool:
    if not input_actions_enabled:
        return false

    var cmd: int = _command_for_action(action)
    if cmd == INVALID_COMMAND:
        return false

    var executed := execute_command(cmd as PlayerCommand.Type)
    if debug_log_input_actions:
        print("[PlayerInput] action=%s executed=%s busy=%s" % [action, executed, movement_controller.is_busy])

    return executed


func _unhandled_input(event: InputEvent) -> void:
    if not input_actions_enabled:
        return

    if event is InputEventKey and event.echo:
        return

    var action := _find_pressed_action(event)
    if action == StringName():
        return

    execute_action(action)

    get_viewport().set_input_as_handled()


func _apply_canonical_transform() -> void:
    var world_pos := GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
    global_position = world_pos
    rotation_degrees.y = -float(grid_state.facing) * 90.0
    _sync_camera_height()


func _on_action_started(_cmd: PlayerCommand.Type, previous_state: GridState, new_state: GridState, duration: float) -> void:
    if movement_config == null or not movement_config.smooth_mode or duration <= 0.0:
        return

    _cancel_blocked_feedback()

    if is_instance_valid(_active_tween):
        _active_tween.kill()

    var start_pos := GridMapper.cell_to_world(previous_state.cell, movement_config.cell_size, 0.0)
    var target_pos := GridMapper.cell_to_world(new_state.cell, movement_config.cell_size, 0.0)
    var start_yaw := -float(previous_state.facing) * 90.0
    var target_yaw := _resolve_target_yaw(start_yaw, -float(new_state.facing) * 90.0)

    global_position = start_pos
    rotation_degrees.y = start_yaw

    _active_tween = create_tween()
    _active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _active_tween.tween_property(self, "global_position", target_pos, duration)
    _active_tween.parallel().tween_method(_set_yaw, start_yaw, target_yaw, duration)


func _on_action_completed(_cmd: PlayerCommand.Type, new_state: GridState) -> void:
    _cancel_blocked_feedback()

    if is_instance_valid(_active_tween):
        _active_tween.kill()
    _active_tween = null

    grid_state = new_state
    _apply_canonical_transform()

    if debug_log_input_actions:
        print("[PlayerState] cell=%s facing=%s world_pos=%s yaw=%.1f" % [
            grid_state.cell,
            _facing_to_name(grid_state.facing),
            global_position,
            rotation_degrees.y,
        ])

    _drain_queued_command()


func _on_movement_outcome(outcome) -> void:
    if movement_config == null or not movement_config.blocked_feedback_enabled:
        return

    if outcome.outcome_type != MovementOutcomeData.TYPE_BLOCKED:
        return

    if outcome.phase != MovementOutcomeData.PHASE_DECISION:
        return

    _play_blocked_feedback(outcome.command)


func _set_yaw(value: float) -> void:
    rotation_degrees.y = value


func _sync_camera_height() -> void:
    if _camera == null:
        return
    _camera.position = Vector3(0.0, eye_height, 0.0)


func _resolve_target_yaw(start_yaw: float, base_target_yaw: float) -> float:
    var delta := fmod(base_target_yaw - start_yaw + 540.0, 360.0) - 180.0
    return start_yaw + delta


func _find_pressed_action(event: InputEvent) -> StringName:
    var actions: Array[StringName] = [
        &"move_forward",
        &"move_back",
        &"move_left",
        &"move_right",
        &"turn_left",
        &"turn_right",
    ]

    for action in actions:
        if event.is_action_pressed(action):
            return action

    return StringName()


func _enqueue_command(cmd: PlayerCommand.Type) -> bool:
    if _queued_command != INVALID_COMMAND:
        return false

    _queued_command = int(cmd)
    return true


func _drain_queued_command() -> void:
    if _queued_command == INVALID_COMMAND:
        return

    if not command_processing_enabled:
        return

    if movement_controller == null:
        return

    if movement_controller.is_busy:
        return

    var queued_cmd := _queued_command
    _queued_command = INVALID_COMMAND
    movement_controller.execute_command(queued_cmd as PlayerCommand.Type)


func _cancel_blocked_feedback() -> void:
    if is_instance_valid(_blocked_tween):
        _blocked_tween.kill()
    _blocked_tween = null


func _play_blocked_feedback(cmd: PlayerCommand.Type) -> void:
    if movement_config == null:
        return

    if movement_config.blocked_bump_distance <= 0.0 or movement_config.blocked_bump_duration <= 0.0:
        return

    if cmd != PlayerCommand.Type.STEP_FORWARD:
        _cancel_blocked_feedback()
        global_position = GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
        blocked_feedback_cue.emit(cmd)
        return

    _cancel_blocked_feedback()

    var base_pos := GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
    global_position = base_pos

    var facing_vec := GridDefinitions.facing_to_vec2i(grid_state.facing)
    var bump_dir := Vector3(float(facing_vec.x), 0.0, float(facing_vec.y)).normalized()
    if bump_dir == Vector3.ZERO:
        return

    var bump_target := base_pos + bump_dir * movement_config.blocked_bump_distance
    var half_duration := maxf(movement_config.blocked_bump_duration * 0.5, 0.001)

    _blocked_tween = create_tween()
    _blocked_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _blocked_tween.tween_property(self, "global_position", bump_target, half_duration)
    _blocked_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _blocked_tween.tween_property(self, "global_position", base_pos, half_duration)
    _blocked_tween.finished.connect(_on_blocked_feedback_finished)


func _on_blocked_feedback_finished() -> void:
    _blocked_tween = null


func _command_for_action(action: StringName) -> int:
    match action:
        &"move_forward":
            return PlayerCommand.Type.STEP_FORWARD
        &"move_back":
            return PlayerCommand.Type.STEP_BACK
        &"move_left":
            return PlayerCommand.Type.MOVE_LEFT
        &"move_right":
            return PlayerCommand.Type.MOVE_RIGHT
        &"turn_left":
            return PlayerCommand.Type.TURN_LEFT
        &"turn_right":
            return PlayerCommand.Type.TURN_RIGHT
        _:
            return INVALID_COMMAND


func _facing_to_name(facing: GridDefinitions.Facing) -> String:
    match facing:
        GridDefinitions.Facing.NORTH:
            return "NORTH"
        GridDefinitions.Facing.EAST:
            return "EAST"
        GridDefinitions.Facing.SOUTH:
            return "SOUTH"
        GridDefinitions.Facing.WEST:
            return "WEST"
        _:
            return "UNKNOWN"