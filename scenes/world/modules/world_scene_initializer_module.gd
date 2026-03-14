extends Node
class_name WorldSceneInitializerModule


func add_environment(root: Node3D) -> void:
	_add_light(root)
	_add_floor(root)


func _add_light(root: Node3D) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 45, 0)
	light.light_energy = 1.2
	root.add_child(light)


func _add_floor(root: Node3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DebugFloor"

	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	plane.subdivide_depth = 9
	plane.subdivide_width = 9
	mesh_instance.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.35)
	mat.albedo_texture = _make_grid_texture()
	mesh_instance.material_override = mat

	root.add_child(mesh_instance)


func _make_grid_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.35, 0.35, 0.35))

	for x in range(size):
		img.set_pixel(x, 0, Color(0.15, 0.15, 0.15))
		img.set_pixel(x, size - 1, Color(0.15, 0.15, 0.15))

	for y in range(size):
		img.set_pixel(0, y, Color(0.15, 0.15, 0.15))
		img.set_pixel(size - 1, y, Color(0.15, 0.15, 0.15))

	var tex := ImageTexture.create_from_image(img)
	return tex
