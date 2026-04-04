class_name WorldParticlePlayer
extends Node3D

const MAX_ACTIVE_PARTICLES := 12

var _active_effect_nodes: Array[Node3D] = []


func play_at(world_position: Vector3, entry) -> void:
	if entry == null:
		return

	_prune_finished_effect_nodes()
	if _active_effect_nodes.size() >= MAX_ACTIVE_PARTICLES:
		var oldest: Node3D = _active_effect_nodes.pop_front()
		if oldest != null:
			oldest.queue_free()

	var scene_instance := _instantiate_particle_scene(entry)
	if scene_instance != null:
		add_child(scene_instance)
		scene_instance.global_position = world_position + entry.position_offset
		_active_effect_nodes.append(scene_instance)

		var scene_particles := _find_first_particles(scene_instance)
		if scene_particles != null:
			_align_particles_to_camera(scene_particles)
			scene_particles.finished.connect(
				_on_effect_node_finished.bind(scene_instance),
				CONNECT_ONE_SHOT,
			)
			scene_particles.restart()
			scene_particles.emitting = true
		else:
			_schedule_cleanup(scene_instance, maxf(entry.duration, 0.25))
		return

	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = maxi(entry.particle_amount, 1)
	particles.lifetime = maxf(entry.duration, 0.15)
	particles.explosiveness = 1.0
	particles.draw_pass_1 = _build_particle_mesh(entry)
	particles.process_material = _build_process_material(entry)
	_align_particles_to_camera(particles)
	particles.finished.connect(_on_effect_node_finished.bind(particles), CONNECT_ONE_SHOT)
	add_child(particles)
	particles.global_position = world_position + entry.position_offset
	particles.emitting = true
	_active_effect_nodes.append(particles)


func _align_particles_to_camera(particles: GPUParticles3D) -> void:
	if particles == null:
		return

	var process := particles.process_material as ParticleProcessMaterial
	if process == null:
		return

	var direction := _camera_forward_direction()
	if direction == Vector3.ZERO:
		return

	var process_copy := process.duplicate() as ParticleProcessMaterial
	if process_copy == null:
		return

	process_copy.direction = direction
	particles.process_material = process_copy


func _camera_forward_direction() -> Vector3:
	var viewport := get_viewport()
	if viewport == null:
		return Vector3.ZERO

	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector3.ZERO

	return (-camera.global_transform.basis.z).normalized()


func _instantiate_particle_scene(entry) -> Node3D:
	if not ("particle_scene" in entry):
		return null
	if entry.particle_scene == null:
		return null
	var instance: Node = entry.particle_scene.instantiate()
	return instance as Node3D


func _build_particle_mesh(entry) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = maxf(0.02, 0.04 * maxf(entry.intensity, 0.5))
	mesh.height = mesh.radius * 2.0

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = entry.color
	material.emission_enabled = true
	material.emission = entry.color
	mesh.material = material
	return mesh


func _build_process_material(entry) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = maxf(0.03, 0.08 * maxf(entry.intensity, 0.5))
	process.gravity = Vector3(0.0, -1.0, 0.0)
	process.initial_velocity_min = maxf(0.6, 2.0 * maxf(entry.intensity, 0.4))
	process.initial_velocity_max = maxf(1.0, 3.5 * maxf(entry.intensity, 0.4))
	process.scale_min = 0.4
	process.scale_max = 1.1
	process.color = entry.color
	return process


func _prune_finished_effect_nodes() -> void:
	var survivors: Array[Node3D] = []
	for effect_node in _active_effect_nodes:
		if effect_node == null or not is_instance_valid(effect_node):
			continue
		survivors.append(effect_node)
	_active_effect_nodes = survivors


func _find_first_particles(node: Node) -> GPUParticles3D:
	if node is GPUParticles3D:
		return node as GPUParticles3D
	for child in node.get_children():
		if child is Node:
			var found := _find_first_particles(child as Node)
			if found != null:
				return found
	return null


func _schedule_cleanup(node: Node3D, after_seconds: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(maxf(after_seconds, 0.05))
	timer.timeout.connect(_on_effect_node_finished.bind(node), CONNECT_ONE_SHOT)


func _on_effect_node_finished(effect_node: Node3D) -> void:
	if effect_node != null:
		effect_node.queue_free()
	_active_effect_nodes.erase(effect_node)
