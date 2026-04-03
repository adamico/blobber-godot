class_name AnalysisSelectionPresenter
extends RefCounted

const DEFAULT_INDICATOR_SIZE := Vector2(0.35, 0.35)
const DEFAULT_INDICATOR_ALPHA := 0.24
const DEFAULT_INDICATOR_DEPTH_RATIO := 1.5
const INDICATOR_HEIGHT := 0.9

var _player: Player
var _world_root: Node
var _target_indicator: MeshInstance3D
var _target_indicator_mesh: QuadMesh
var _target_indicator_material: StandardMaterial3D
var _current_outlined_node: Variant = null
var _outlined_sprite_material: ShaderMaterial = null
var _outlined_mesh_instance: MeshInstance3D = null
var _outlined_mesh_previous_overlay: Material = null
var _mesh_outline_material: StandardMaterial3D = null


func configure(player: Player, world_root: Node) -> void:
	_player = player
	_world_root = world_root
	_ensure_target_indicator()


func clear_selection() -> void:
	_hide_target_indicator()
	_remove_analysis_outline()


func cleanup() -> void:
	_remove_analysis_outline()
	if _target_indicator != null and is_instance_valid(_target_indicator):
		_target_indicator.queue_free()
	_target_indicator = null
	_target_indicator_mesh = null
	_target_indicator_material = null


func present_candidate(
		candidate: Dictionary,
		source: String,
		indicator_height: float,
		anchor_height: float,
		depth_ratio: float,
		indicator_size: Vector2,
		indicator_alpha: float,
) -> void:
	_hide_target_indicator()
	_apply_analysis_outline(candidate.get("node"))
	if _current_outlined_node == null:
		_apply_indicator_visual(indicator_size, indicator_alpha)
		var final_height := anchor_height
		if source != "hover":
			final_height = indicator_height
		_show_target_indicator(
			candidate.get("cell", Vector2i.ZERO),
			final_height,
			depth_ratio,
		)


func _ensure_target_indicator() -> void:
	if _target_indicator != null:
		return
	_target_indicator_mesh = QuadMesh.new()
	_target_indicator_mesh.size = DEFAULT_INDICATOR_SIZE
	_target_indicator_material = StandardMaterial3D.new()
	_target_indicator_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_indicator_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_indicator_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_target_indicator_material.albedo_color = Color(0.65, 1.0, 0.59, DEFAULT_INDICATOR_ALPHA)
	_target_indicator_mesh.material = _target_indicator_material
	_target_indicator = MeshInstance3D.new()
	_target_indicator.mesh = _target_indicator_mesh
	_target_indicator.visible = false
	if _world_root != null:
		_world_root.add_child(_target_indicator)


func _show_target_indicator(
		cell: Vector2i,
		y: float = INDICATOR_HEIGHT,
		depth_ratio: float = DEFAULT_INDICATOR_DEPTH_RATIO,
) -> void:
	if _target_indicator == null:
		return
	var entity_pos := GridMapper.cell_to_world(cell, 1.0, y)
	var camera := _player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		_target_indicator.global_position = entity_pos
		_target_indicator.visible = true
		return
	var toward_cam := camera.global_position - entity_pos
	toward_cam.y = 0.0
	var cam_len := toward_cam.length()
	if cam_len < 0.001:
		_target_indicator.global_position = entity_pos
		_target_indicator.visible = true
		return
	var cam_dir := toward_cam / cam_len
	var offset := (depth_ratio - 0.5) * 1.0
	_target_indicator.global_position = entity_pos + cam_dir * offset
	_target_indicator.visible = true


func _hide_target_indicator() -> void:
	if _target_indicator == null:
		return
	_target_indicator.visible = false


func _apply_indicator_visual(indicator_size: Vector2, indicator_alpha: float) -> void:
	if _target_indicator_mesh == null or _target_indicator_material == null:
		return
	_target_indicator_mesh.size = indicator_size
	var color := _target_indicator_material.albedo_color
	color.a = indicator_alpha
	_target_indicator_material.albedo_color = color


func _ensure_mesh_outline_material() -> void:
	if _mesh_outline_material != null:
		return
	_mesh_outline_material = StandardMaterial3D.new()
	_mesh_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_mesh_outline_material.grow = 0.06
	_mesh_outline_material.albedo_color = Color(0.65, 1.0, 0.59, 1.0)


func _apply_analysis_outline(target: Variant) -> void:
	if target == null or not is_instance_valid(target):
		return
	_remove_analysis_outline()
	var sprite := _find_outline_sprite(target)
	if sprite == null:
		var mesh := _find_outline_mesh(target)
		if mesh == null:
			return
		_ensure_mesh_outline_material()
		_outlined_mesh_previous_overlay = mesh.material_overlay
		mesh.material_overlay = _mesh_outline_material
		_outlined_mesh_instance = mesh
		_current_outlined_node = target
		return
	var mat := sprite.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glowSize", 1.0)
	_outlined_sprite_material = mat
	_current_outlined_node = target


func _remove_analysis_outline() -> void:
	if _current_outlined_node == null:
		return
	if not is_instance_valid(_current_outlined_node):
		_current_outlined_node = null
		_outlined_sprite_material = null
		_outlined_mesh_instance = null
		_outlined_mesh_previous_overlay = null
		return
	if _outlined_sprite_material != null:
		_outlined_sprite_material.set_shader_parameter("glowSize", 0.0)
	if _outlined_mesh_instance != null and is_instance_valid(_outlined_mesh_instance):
		_outlined_mesh_instance.material_overlay = _outlined_mesh_previous_overlay
	_outlined_sprite_material = null
	_outlined_mesh_instance = null
	_outlined_mesh_previous_overlay = null
	_current_outlined_node = null


func _find_outline_sprite(target: Variant) -> Sprite3D:
	if target is Sprite3D:
		return target as Sprite3D
	if not (target is Node):
		return null
	for child in (target as Node).get_children():
		if child is Sprite3D:
			return child as Sprite3D
	return null


func _find_outline_mesh(target: Variant) -> MeshInstance3D:
	if target is MeshInstance3D:
		return target as MeshInstance3D
	if not (target is Node):
		return null
	for child in (target as Node).get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			return child as MeshInstance3D
	return null