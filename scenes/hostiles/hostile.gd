class_name Hostile
extends GridEntity

signal hostile_cleared(hostile: Hostile)

@export var hostile_definition_id: StringName
@export var ai_enabled: bool = true
## How many player turns pass between each AI tick.
## 1 = acts every turn, 2 = acts every other turn, etc.
@export var speed: int = 1
@export var hostile_property: RpsSystem.HostileProperty = RpsSystem.HostileProperty.BURNING
@export var display_name_override: String = ""
@export var sprite_texture: Texture2D
@export var contact_damage: int = 1
@export var hostile_hp: int = 3 ## Hits needed with non-matching tools
@export var revert_turns_base: int = 5 ## Default turns until debris reverts to this hazard
@export var cleanup_value: int = 1

@onready var _ai: HostileAI = get_node_or_null("HostileAI") as HostileAI
@onready var label: Label3D = get_node_or_null("Label3D") as Label3D
@onready var sprite: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

var _active_tween: Tween
var _turn_counter: int = 0
var _current_hp: int = 1


func _ready() -> void:
	super()
	add_to_group("grid_hostiles")
	if movement_controller != null:
		movement_controller.action_started.connect(_on_action_started)

	_current_hp = hostile_hp
	if label != null:
		if display_name_override != "":
			label.text = display_name_override
		else:
			label.text = RpsSystem.HostileProperty.keys()[hostile_property].capitalize()

	if sprite != null and sprite_texture != null:
		sprite.texture = sprite_texture
		var sprite_mat := sprite.material_override as ShaderMaterial
		if sprite_mat != null:
			sprite_mat = sprite_mat.duplicate() as ShaderMaterial
			sprite.material_override = sprite_mat
			sprite_mat.set_shader_parameter("sprite_texture", sprite_texture)
		if mesh != null:
			mesh.visible = false


func tick_ai(player) -> bool:
	if not ai_enabled or _ai == null:
		return false
	if movement_controller == null:
		return false

	var cadence := maxi(speed, 1)
	_turn_counter += 1
	if cadence > 1 and _turn_counter % cadence != 0:
		return false

	var cmd := _ai.choose_command(self, player)
	if cmd == HostileAI.NO_COMMAND:
		return false

	# If animation is still in-flight, GridEntity.execute_command will queue one command.
	return execute_command(cmd as GridCommand.Type)


func receive_tool_hit(
		tool_property: RpsSystem.ToolProperty,
		target_stats: CharacterStats = null,
) -> bool:
	if is_cleared():
		return false

	var damage := RpsSystem.compute_damage(tool_property, hostile_property)
	_current_hp -= damage
	if _current_hp <= 0:
		_clear()
		return true

	# Immediate retaliation if player is present
	if target_stats != null:
		deal_contact_damage(target_stats)

	return false


func deal_contact_damage(target_stats: CharacterStats) -> void:
	if target_stats == null:
		return
	if is_cleared():
		return
	target_stats.take_damage(contact_damage)


func is_cleared() -> bool:
	return _current_hp <= 0


func _clear() -> void:
	if is_cleared() and not visible:
		return
	_current_hp = 0
	hostile_cleared.emit(self)
	# Mark stats as dead so encounter module filters it out
	if stats != null:
		stats.take_damage(stats.max_health + 1)
	visible = false
	ai_enabled = false


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
