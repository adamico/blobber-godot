class_name Hostile
extends GridEntity

@export var hostile_definition_id: StringName
@export var ai_enabled: bool = true
## How many player turns pass between each AI tick.
## 1 = acts every turn, 2 = acts every other turn, etc.
@export var speed: int = 1

@onready var _ai: HostileAI = get_node_or_null("HostileAI") as HostileAI

var _active_tween: Tween
var _turn_counter: int = 0


func _ready() -> void:
	super()
	add_to_group("grid_hostiles")
	movement_controller.action_started.connect(_on_action_started)


func tick_ai(player) -> bool:
	_turn_counter += 1
	if speed > 1 and _turn_counter % speed != 0:
		return false

	if not ai_enabled or _ai == null:
		return false
	if movement_controller == null or movement_controller.is_busy:
		return false

	var cmd := _ai.choose_command(self, player)
	if cmd == HostileAI.NO_COMMAND:
		return false

	return execute_command(cmd as GridCommand.Type)


func _on_action_started(
		_cmd: GridCommand.Type,
		previous_state: GridState,
		new_state: GridState,
		duration: float,
) -> void:
	if movement_config == null or not movement_config.smooth_mode or duration <= 0.0:
		return
	if not is_inside_tree():
		return

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


func _on_action_completed(cmd: GridCommand.Type, new_state: GridState) -> void:
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
	super(cmd, new_state)


func _set_yaw(value: float) -> void:
	rotation_degrees.y = value


func _resolve_target_yaw(start_yaw: float, base_target_yaw: float) -> float:
	var delta := fmod(base_target_yaw - start_yaw + 540.0, 360.0) - 180.0
	return start_yaw + delta
