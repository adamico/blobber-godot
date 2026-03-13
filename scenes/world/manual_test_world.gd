extends Node3D

@export var occupancy_wall_layer := 0
@export var auto_align_gridmap_visual := true
@export var show_debug_panel := false

const INVENTORY_OVERLAY_PATH := "res://scenes/inventory/inventory_placeholder.tscn"
const COMBAT_OVERLAY_PATH := "res://scenes/combat/combat_placeholder.tscn"
const TOWN_OVERLAY_PATH := "res://scenes/town/town_placeholder.tscn"

const OVERLAY_INVENTORY := &"inventory"
const OVERLAY_COMBAT := &"combat"
const OVERLAY_TOWN := &"town"

var _occupancy: GridOccupancyMap
var _active_overlay: Control
var _active_overlay_kind: StringName = StringName()

@onready var _player: Player = get_node_or_null("Player")
@onready var _overlay_mount: Control = get_node_or_null("OverlayLayer/OverlayMount")
@onready var _debug_panel: Control = get_node_or_null("OverlayLayer/DebugPanel")
@onready var _btn_open_inventory: Button = get_node_or_null("OverlayLayer/DebugPanel/Margin/VBox/OpenInventory")
@onready var _btn_open_combat: Button = get_node_or_null("OverlayLayer/DebugPanel/Margin/VBox/OpenCombat")
@onready var _btn_open_town: Button = get_node_or_null("OverlayLayer/DebugPanel/Margin/VBox/OpenTown")
@onready var _btn_close_overlay: Button = get_node_or_null("OverlayLayer/DebugPanel/Margin/VBox/CloseOverlay")

func _ready() -> void:
	_add_light()
	_add_floor()

	# Defer to ensure all children (including Player) have finished _ready().
	_wire_occupancy.call_deferred()
	_apply_debug_panel_visibility()
	_wire_overlay_controls()
	_refresh_debug_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("open_inventory"):
		open_overlay(OVERLAY_INVENTORY)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("open_combat"):
		open_overlay(OVERLAY_COMBAT)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("open_town"):
		open_overlay(OVERLAY_TOWN)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("close_overlay") or event.is_action_pressed("ui_cancel"):
		close_active_overlay()
		get_viewport().set_input_as_handled()
		return


func has_active_overlay() -> bool:
	return is_instance_valid(_active_overlay)


func active_overlay_kind() -> StringName:
	return _active_overlay_kind


func open_inventory_overlay() -> void:
	open_overlay(OVERLAY_INVENTORY)


func open_combat_overlay() -> void:
	open_overlay(OVERLAY_COMBAT)


func open_town_overlay() -> void:
	open_overlay(OVERLAY_TOWN)


func open_overlay(kind: StringName) -> void:
	if _overlay_mount == null:
		return

	if _active_overlay_kind == kind and has_active_overlay():
		return

	_close_overlay_internal(false)

	var scene := _scene_for_overlay(kind)
	if scene == null:
		return

	var overlay := scene.instantiate() as Control
	if overlay == null:
		return

	_overlay_mount.add_child(overlay)
	if overlay.has_signal("close_requested"):
		overlay.connect("close_requested", _on_overlay_close_requested)

	_active_overlay = overlay
	_active_overlay_kind = kind
	_set_exploration_active(false)
	_refresh_debug_buttons()

	if overlay.has_method("request_overlay_focus"):
		overlay.call_deferred("request_overlay_focus")


func close_active_overlay() -> void:
	_close_overlay_internal(true)


func _wire_overlay_controls() -> void:
	if _btn_open_inventory != null:
		_btn_open_inventory.pressed.connect(open_inventory_overlay)
	if _btn_open_combat != null:
		_btn_open_combat.pressed.connect(open_combat_overlay)
	if _btn_open_town != null:
		_btn_open_town.pressed.connect(open_town_overlay)
	if _btn_close_overlay != null:
		_btn_close_overlay.pressed.connect(close_active_overlay)


func _apply_debug_panel_visibility() -> void:
	if _debug_panel != null:
		_debug_panel.visible = show_debug_panel


func _refresh_debug_buttons() -> void:
	var overlay_open := has_active_overlay()

	if _btn_open_inventory != null:
		_btn_open_inventory.disabled = overlay_open
	if _btn_open_combat != null:
		_btn_open_combat.disabled = overlay_open
	if _btn_open_town != null:
		_btn_open_town.disabled = overlay_open
	if _btn_close_overlay != null:
		_btn_close_overlay.disabled = not overlay_open


func _set_exploration_active(is_active: bool) -> void:
	if _player == null:
		return

	if is_active:
		_player.resume_exploration_commands()
	else:
		_player.pause_exploration_commands()


func _scene_for_overlay(kind: StringName) -> PackedScene:
	match kind:
		OVERLAY_INVENTORY:
			return load(INVENTORY_OVERLAY_PATH) as PackedScene
		OVERLAY_COMBAT:
			return load(COMBAT_OVERLAY_PATH) as PackedScene
		OVERLAY_TOWN:
			return load(TOWN_OVERLAY_PATH) as PackedScene
		_:
			return null


func _close_overlay_internal(restore_exploration: bool) -> void:
	if has_active_overlay():
		_active_overlay.queue_free()

	_active_overlay = null
	_active_overlay_kind = StringName()

	if restore_exploration:
		_set_exploration_active(true)
		if _btn_open_inventory != null:
			_btn_open_inventory.call_deferred("grab_focus")

	_refresh_debug_buttons()


func _on_overlay_close_requested() -> void:
	close_active_overlay()


func _add_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 45, 0)
	light.light_energy = 1.2
	add_child(light)


func _add_floor() -> void:
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


func _wire_occupancy() -> void:
	var gm := get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	if auto_align_gridmap_visual:
		_align_gridmap_to_player_grid(gm)

	_occupancy = GridOccupancyMap.from_grid_map(gm, occupancy_wall_layer)
	var player: Player = get_node_or_null("Player")
	if player != null and player.movement_controller != null:
		player.movement_controller.passability_fn = _occupancy.is_passable
		print("[Occupancy] layer=%d wired %d blocked cells" % [occupancy_wall_layer, _occupancy._blocked.size()])


func _align_gridmap_to_player_grid(gm: GridMap) -> void:
	# Keep painted visuals aligned with integer world cells used by player movement.
	var x_offset := -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var y_offset := 0.0
	var z_offset := -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	gm.position = Vector3(x_offset, y_offset, z_offset)
