extends Node3D

func _ready() -> void:
	_add_light()
	_add_floor()
	_add_direction_markers()


func _add_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 45, 0)
	light.light_energy = 1.2
	add_child(light)


func _add_floor() -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	plane.subdivide_depth = 9
	plane.subdivide_width = 9
	mesh_instance.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.35)
	mat.albedo_texture = _make_grid_texture()
	mesh_instance.material_override = mat
	add_child(mesh_instance)


func _add_direction_markers() -> void:
	# Each pillar is 2 cells away from origin in its cardinal direction.
	# Facing NORTH (yaw=0) => blue pillar dead ahead.
	_add_pillar(Vector3(0.0, 0.75, -2.0), Color(0.2, 0.4, 1.0), "North_Blue")
	_add_pillar(Vector3(2.0, 0.75,  0.0), Color(1.0, 0.2, 0.2), "East_Red")
	_add_pillar(Vector3(0.0, 0.75,  2.0), Color(0.2, 0.8, 0.2), "South_Green")
	_add_pillar(Vector3(-2.0, 0.75, 0.0), Color(1.0, 0.85, 0.1), "West_Yellow")


func _add_pillar(pos: Vector3, color: Color, label: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 1.5, 0.3)
	mesh_instance.mesh = box
	mesh_instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	add_child(mesh_instance)


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
