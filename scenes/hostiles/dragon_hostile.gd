class_name DragonHostile
extends Hostile

enum BreathState {
	READY,
	WINDUP,
	COOLDOWN,
}

@export var breath_enabled: bool = true
@export_range(0, 6, 1) var breath_windup_turns: int = 3
@export_range(0, 8, 1) var breath_cooldown_turns: int = 2
@export_range(1, 10, 1) var breath_damage: int = 2
@export_range(1, 20, 1) var breath_trigger_distance: int = 4
@export var breath_requires_line_of_sight: bool = true
@export var breath_flash_color: Color = Color(1.0, 0.45, 0.2, 1.0)
@export_range(0.0, 1.0, 0.01) var breath_flash_intensity: float = 0.75
@export_range(0.03, 0.6, 0.01) var breath_flash_duration: float = 0.12
@export var breath_label_enabled: bool = true
@export var breath_label_show_cooldown: bool = false
@export var breath_particles_enabled: bool = true
@export var breath_particles_on_windup: bool = false
@export var breath_particles_on_strike: bool = true
@export var breath_particle_color: Color = Color(1.0, 0.35, 0.12, 1.0)
@export_range(0.05, 1.0, 0.01) var breath_particle_lifetime: float = 0.22
@export_range(1, 32, 1) var breath_particle_amount: int = 12
@export_range(0.02, 0.3, 0.01) var breath_particle_radius: float = 0.08
@export_range(0.0, 1.0, 0.01) var breath_particle_height: float = 0.06

var _dragon_turn_counter: int = 0
var _breath_state: BreathState = BreathState.READY
var _breath_turns_remaining: int = 0
var _breath_acted_this_turn: bool = false
var _breath_locked_step: Vector2i = Vector2i.ZERO
var _flash_tween: Tween


func receive_tool_hit(
		_tool_property: RpsSystem.ToolProperty,
		_target_stats: CharacterStats = null,
) -> bool:
	if is_cleared():
		return false

	# Jam balancing: dragon ignores RPS and takes flat damage from any tool.
	# No retaliation on hit — dragon already has breath + adjacency contact damage.
	_current_hp -= 1
	if _current_hp <= 0:
		_clear()
		return true

	return false


func deal_contact_damage(_target_stats: CharacterStats) -> void:
	# Dragon deals damage only through breath, never through adjacency contact.
	return


func tick_ai(player) -> bool:
	if not ai_enabled or _ai == null:
		return false
	if movement_controller == null:
		return false

	_breath_acted_this_turn = false
	var cadence := maxi(speed, 1)
	_dragon_turn_counter += 1
	if cadence > 1 and _dragon_turn_counter % cadence != 0:
		return false

	var breath_executed := _tick_breath(player)
	if breath_executed:
		return true

	var cmd := _ai.choose_command(self, player)
	if cmd == HostileAI.NO_COMMAND:
		return false

	return execute_command(cmd as GridCommand.Type)


func _tick_breath(player) -> bool:
	if not breath_enabled or grid_state == null:
		_update_breath_label()
		return false

	match _breath_state:
		BreathState.READY:
			if _should_begin_windup(player):
				var breath_executed := _begin_windup_or_strike(player)
				if breath_executed:
					_update_breath_label()
					return true
		BreathState.WINDUP:
			_play_breath_windup_flash()
			if breath_particles_on_windup:
				_emit_breath_cell_particles(_front_arc_cells(player), 0.7)
			if _breath_turns_remaining > 0:
				_breath_turns_remaining -= 1
			if _breath_turns_remaining <= 0:
				_execute_breath(player)
				_breath_acted_this_turn = true
				_enter_cooldown()
				_update_breath_label()
				return true
		BreathState.COOLDOWN:
			if _breath_turns_remaining > 0:
				_breath_turns_remaining -= 1
			if _breath_turns_remaining <= 0:
				_breath_state = BreathState.READY

	_update_breath_label()
	return false


func _should_begin_windup(player) -> bool:
	if player == null or player.grid_state == null:
		return false

	var delta: Vector2i = player.grid_state.cell - grid_state.cell
	var manhattan := absi(delta.x) + absi(delta.y)
	if manhattan > breath_trigger_distance:
		return false

	if not breath_requires_line_of_sight:
		return true

	var occupancy: Variant = _world_occupancy()
	if occupancy == null:
		return true
	return occupancy.is_line_of_sight_clear(grid_state.cell, player.grid_state.cell)


func _begin_windup_or_strike(player) -> bool:
	_breath_state = BreathState.WINDUP
	_breath_turns_remaining = maxi(breath_windup_turns, 0)
	_breath_locked_step = _compute_step_toward(player)
	_play_breath_windup_flash()
	if _breath_turns_remaining <= 0:
		_execute_breath(player)
		_breath_acted_this_turn = true
		_enter_cooldown()
		return true
	_update_breath_label()
	return false


func _play_breath_windup_flash() -> void:
	if sprite == null:
		return

	if is_instance_valid(_flash_tween):
		_flash_tween.kill()

	var base_modulate := sprite.modulate
	var flash_modulate := base_modulate.lerp(
		breath_flash_color,
		clampf(breath_flash_intensity, 0.0, 1.0),
	)
	flash_modulate.a = base_modulate.a
	sprite.modulate = flash_modulate

	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(
		sprite,
		"modulate",
		base_modulate,
		maxf(breath_flash_duration, 0.03),
	)


func _execute_breath(player) -> void:
	if player == null or player.grid_state == null or player.stats == null:
		return

	var target_cells := _front_arc_cells(player)
	if breath_particles_on_strike:
		_emit_breath_cell_particles(target_cells, 1.2)
	for cell in target_cells:
		if cell == player.grid_state.cell:
			player.stats.take_damage(breath_damage)
			break


func _enter_cooldown() -> void:
	_breath_state = BreathState.COOLDOWN
	_breath_turns_remaining = maxi(breath_cooldown_turns, 0)
	_breath_locked_step = Vector2i.ZERO
	if _breath_turns_remaining <= 0:
		_breath_state = BreathState.READY
	_update_breath_label()


func _compute_step_toward(player) -> Vector2i:
	if player == null or player.grid_state == null:
		var forward := GridDefinitions.facing_to_vec2i(grid_state.facing)
		return forward
	var delta: Vector2i = player.grid_state.cell - grid_state.cell
	if absi(delta.x) > absi(delta.y):
		return Vector2i(sign(delta.x), 0)
	return Vector2i(0, sign(delta.y))


func _front_arc_cells(player) -> Array[Vector2i]:
	# Use locked direction during windup/strike; otherwise compute live
	var step: Vector2i
	if _breath_locked_step != Vector2i.ZERO:
		step = _breath_locked_step
	else:
		step = _compute_step_toward(player)

	var center := grid_state.cell + step
	var left := Vector2i(-step.y, step.x)
	var right := Vector2i(step.y, -step.x)

	return [center + left, center, center + right]


func _world_occupancy():
	var tree := get_tree()
	if tree == null:
		return null
	var world := tree.current_scene
	if world == null or not world.has_method("get_grid_occupancy"):
		return null
	return world.call("get_grid_occupancy")


func _emit_breath_cell_particles(cells: Array[Vector2i], intensity: float) -> void:
	if not breath_particles_enabled:
		return
	var tree := get_tree()
	if tree == null:
		return
	var world := tree.current_scene
	if world == null:
		return

	for cell in cells:
		var particles := GPUParticles3D.new()
		particles.one_shot = true
		particles.amount = maxi(
			int(round(float(breath_particle_amount) * intensity)),
			1,
		)
		particles.lifetime = maxf(breath_particle_lifetime, 0.05)
		particles.explosiveness = 1.0
		particles.draw_pass_1 = _build_breath_particle_mesh(intensity)
		particles.process_material = _build_breath_particle_process(intensity)
		particles.finished.connect(
			_on_breath_particles_finished.bind(particles),
			CONNECT_ONE_SHOT,
		)

		world.add_child(particles)
		particles.global_position = _cell_to_world_for_particles(cell)
		particles.emitting = true


func _build_breath_particle_mesh(intensity: float) -> Mesh:
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = maxf(0.02, breath_particle_radius * maxf(intensity, 0.3))
	particle_mesh.height = particle_mesh.radius * 2.0

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = breath_particle_color
	material.emission_enabled = true
	material.emission = breath_particle_color
	particle_mesh.material = material
	return particle_mesh


func _build_breath_particle_process(intensity: float) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = maxf(0.03, breath_particle_radius * maxf(intensity, 0.3))
	process.gravity = Vector3(0.0, 0.0, 0.0)
	process.initial_velocity_min = maxf(0.2, 0.8 * intensity)
	process.initial_velocity_max = maxf(0.4, 1.6 * intensity)
	process.scale_min = 0.5
	process.scale_max = 1.1
	process.color = breath_particle_color
	return process


func _cell_to_world_for_particles(cell: Vector2i) -> Vector3:
	var cell_size := movement_config.cell_size if movement_config != null else 1.0
	var world_pos := GridMapper.cell_to_world(cell, cell_size, 0.0)
	return world_pos + Vector3(0.0, breath_particle_height, 0.0)


func _on_breath_particles_finished(particles: GPUParticles3D) -> void:
	if particles == null:
		return
	particles.queue_free()


func _update_breath_label() -> void:
	if label == null:
		return
	if not breath_label_enabled:
		label.visible = false
		return

	match _breath_state:
		BreathState.WINDUP:
			label.visible = true
			var countdown := clampi(maxi(_breath_turns_remaining, 1), 1, 3)
			label.text = str(countdown)
		BreathState.COOLDOWN:
			if breath_label_show_cooldown:
				label.visible = true
				label.text = "COOLDOWN %d" % maxi(_breath_turns_remaining, 0)
			else:
				label.visible = false
		_:
			label.visible = false
