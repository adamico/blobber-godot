extends Node3D

@export var occupancy_wall_layer := 0
@export var auto_align_gridmap_visual := true
@export var show_debug_panel := false
@export var show_grid_coordinates_overlay := false
@export_enum("Menu", "Gameplay", "GameOverFailure", "GameOverSuccess") var initial_game_state := "Gameplay"
@export var enable_cell_end_conditions := true
@export var success_goal_cell := Vector2i(2, -2)
@export var failure_goal_cell := Vector2i(-2, 2)
@export_enum("Snap", "Smooth") var active_movement_preset := "Smooth"
@export var preset_snap_path := "res://resources/presets/movement_config_snap.tres"
@export var preset_smooth_path := "res://resources/presets/movement_config_smooth.tres"
@export_file("*.tscn") var overlay_inventory_scene_path := "res://scenes/inventory/inventory_placeholder.tscn"
@export_file("*.tscn") var overlay_combat_scene_path := "res://scenes/combat/combat_placeholder.tscn"
@export_file("*.tscn") var overlay_town_scene_path := "res://scenes/town/town_placeholder.tscn"
@export_file("*.tscn") var overlay_victory_scene_path := "res://scenes/overlays/victory_overlay.tscn"
@export_file("*.tscn") var overlay_defeat_scene_path := "res://scenes/overlays/defeat_overlay.tscn"
@export_file("*.tscn") var title_scene_path := "res://scenes/title/title_screen.tscn"

const OVERLAY_INVENTORY := &"inventory"
const OVERLAY_COMBAT := &"combat"
const OVERLAY_TOWN := &"town"
const OVERLAY_VICTORY := &"victory"
const OVERLAY_DEFEAT := &"defeat"
const PRESET_SNAP := &"snap"
const PRESET_SMOOTH := &"smooth"
const GAME_STATE_MENU := &"menu"
const GAME_STATE_GAMEPLAY := &"gameplay"
const GAME_STATE_GAMEOVER_FAILURE := &"gameover_failure"
const GAME_STATE_GAMEOVER_SUCCESS := &"gameover_success"
const NODE_PLAYER := "Player"
const NODE_OVERLAY_MOUNT := "OverlayLayer/OverlayMount"
const NODE_DEBUG_PANEL := "OverlayLayer/DebugPanel"
const NODE_GRID_COORDS_LABEL := "OverlayLayer/GridCoordsLabel"
const NODE_BTN_OPEN_INVENTORY := "OverlayLayer/DebugPanel/Margin/VBox/OpenInventory"
const NODE_BTN_OPEN_COMBAT := "OverlayLayer/DebugPanel/Margin/VBox/OpenCombat"
const NODE_BTN_OPEN_TOWN := "OverlayLayer/DebugPanel/Margin/VBox/OpenTown"
const NODE_BTN_CLOSE_OVERLAY := "OverlayLayer/DebugPanel/Margin/VBox/CloseOverlay"

var _occupancy: GridOccupancyMap
var _active_overlay: Control
var _active_overlay_kind: StringName = StringName()
var _overlay_scene_paths: Dictionary = {}
var _game_state_machine: GameStateMachine
var _run_is_resolved := false

var _player: Player
var _overlay_mount: Control
var _debug_panel: Control
var _grid_coords_label: Label
var _btn_open_inventory: Button
var _btn_open_combat: Button
var _btn_open_town: Button
var _btn_close_overlay: Button

func _ready() -> void:
	_resolve_world_nodes()
	_rebuild_overlay_registry()
	_setup_game_state_machine()
	_add_light()
	_add_floor()
	apply_movement_preset(active_movement_preset)

	# Defer to ensure all children (including Player) have finished _ready().
	_wire_occupancy.call_deferred()
	_wire_end_conditions.call_deferred()
	_apply_debug_panel_visibility()
	_apply_grid_coordinates_overlay_visibility()
	_refresh_grid_coordinates_overlay()
	_wire_overlay_controls()
	_refresh_debug_buttons()


func _resolve_world_nodes() -> void:
	_player = get_node_or_null(NODE_PLAYER) as Player
	_overlay_mount = get_node_or_null(NODE_OVERLAY_MOUNT) as Control
	_debug_panel = get_node_or_null(NODE_DEBUG_PANEL) as Control
	_grid_coords_label = get_node_or_null(NODE_GRID_COORDS_LABEL) as Label
	_btn_open_inventory = get_node_or_null(NODE_BTN_OPEN_INVENTORY) as Button
	_btn_open_combat = get_node_or_null(NODE_BTN_OPEN_COMBAT) as Button
	_btn_open_town = get_node_or_null(NODE_BTN_OPEN_TOWN) as Button
	_btn_close_overlay = get_node_or_null(NODE_BTN_CLOSE_OVERLAY) as Button


func _rebuild_overlay_registry() -> void:
	_overlay_scene_paths = {
		OVERLAY_INVENTORY: overlay_inventory_scene_path,
		OVERLAY_COMBAT: overlay_combat_scene_path,
		OVERLAY_TOWN: overlay_town_scene_path,
		OVERLAY_VICTORY: overlay_victory_scene_path,
		OVERLAY_DEFEAT: overlay_defeat_scene_path,
	}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not is_gameplay_state_active():
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
	_open_overlay(kind, false)


func _open_overlay(kind: StringName, allow_non_gameplay: bool) -> void:
	if not allow_non_gameplay and not is_gameplay_state_active():
		return

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
	if overlay.has_signal("restart_requested"):
		overlay.connect("restart_requested", _on_overlay_restart_requested)
	if overlay.has_signal("return_to_title_requested"):
		overlay.connect("return_to_title_requested", _on_overlay_return_to_title_requested)

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


func _apply_grid_coordinates_overlay_visibility() -> void:
	if _grid_coords_label != null:
		_grid_coords_label.visible = show_grid_coordinates_overlay


func _refresh_grid_coordinates_overlay(cell: Vector2i = Vector2i.ZERO) -> void:
	if _grid_coords_label == null:
		return

	var coords := cell
	if _player != null and _player.grid_state != null:
		coords = _player.grid_state.cell

	_grid_coords_label.text = "Grid X: %d  Y: %d" % [coords.x, coords.y]


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


func current_game_state() -> StringName:
	if _game_state_machine == null:
		return GAME_STATE_MENU

	return _game_state_machine.state_name()


func is_gameplay_state_active() -> bool:
	return current_game_state() == GAME_STATE_GAMEPLAY


func go_to_menu() -> void:
	_set_game_state(GAME_STATE_MENU)


func start_gameplay() -> void:
	_run_is_resolved = false
	_set_game_state(GAME_STATE_GAMEPLAY)
	_refresh_grid_coordinates_overlay()


func finish_with_failure() -> void:
	_set_game_state(GAME_STATE_GAMEOVER_FAILURE)


func finish_with_success() -> void:
	_set_game_state(GAME_STATE_GAMEOVER_SUCCESS)


func _setup_game_state_machine() -> void:
	_game_state_machine = GameStateMachine.new()
	add_child(_game_state_machine)
	_game_state_machine.state_changed.connect(_on_game_state_changed)
	_set_game_state(_normalized_game_state_name(initial_game_state))


func _set_game_state(state_name: StringName) -> void:
	if _game_state_machine == null:
		return

	match state_name:
		GAME_STATE_MENU:
			_game_state_machine.to_menu()
		GAME_STATE_GAMEPLAY:
			_game_state_machine.to_gameplay()
		GAME_STATE_GAMEOVER_FAILURE:
			_game_state_machine.to_gameover_failure()
		GAME_STATE_GAMEOVER_SUCCESS:
			_game_state_machine.to_gameover_success()
		_:
			_game_state_machine.to_menu()

	_apply_state_side_effects()


func _normalized_game_state_name(raw_name: String) -> StringName:
	var key := raw_name.strip_edges().to_lower()
	match key:
		"menu":
			return GAME_STATE_MENU
		"gameplay":
			return GAME_STATE_GAMEPLAY
		"gameoverfailure", "gameover_failure", "failure":
			return GAME_STATE_GAMEOVER_FAILURE
		"gameoversuccess", "gameover_success", "success":
			return GAME_STATE_GAMEOVER_SUCCESS
		_:
			return GAME_STATE_MENU


func _on_game_state_changed(_previous_state: int, _new_state: int) -> void:
	_apply_state_side_effects()


func _apply_state_side_effects() -> void:
	if is_gameplay_state_active():
		if _active_overlay_kind == OVERLAY_VICTORY or _active_overlay_kind == OVERLAY_DEFEAT:
			_close_overlay_internal(false)
		if not has_active_overlay():
			_set_exploration_active(true)
		return

	_close_overlay_internal(false)
	_set_exploration_active(false)

	if current_game_state() == GAME_STATE_GAMEOVER_FAILURE:
		_open_overlay(OVERLAY_DEFEAT, true)
	elif current_game_state() == GAME_STATE_GAMEOVER_SUCCESS:
		_open_overlay(OVERLAY_VICTORY, true)


func apply_movement_preset(preset_name: String = "") -> bool:
	if _player == null:
		return false

	var selected_name := preset_name if not preset_name.is_empty() else active_movement_preset
	var preset_key := selected_name.strip_edges().to_lower()
	var selected_path := preset_smooth_path

	if preset_key == PRESET_SNAP:
		selected_path = preset_snap_path
		active_movement_preset = "Snap"
	else:
		selected_path = preset_smooth_path
		active_movement_preset = "Smooth"

	var selected_preset := load(selected_path) as MovementConfig

	if selected_preset == null:
		return false

	if _player.movement_config == null:
		_player.movement_config = MovementConfig.new()

	_copy_movement_config_values(selected_preset, _player.movement_config)
	if _player.movement_controller != null:
		_player.movement_controller.movement_config = _player.movement_config
	if _player.grid_state != null:
		_player._apply_canonical_transform()

	return true


func _copy_movement_config_values(source: MovementConfig, target: MovementConfig) -> void:
	target.cell_size = source.cell_size
	target.smooth_mode = source.smooth_mode
	target.step_duration = source.step_duration
	target.turn_duration = source.turn_duration
	target.blocked_feedback_enabled = source.blocked_feedback_enabled
	target.blocked_bump_distance = source.blocked_bump_distance
	target.blocked_bump_duration = source.blocked_bump_duration


func _scene_for_overlay(kind: StringName) -> PackedScene:
	var scene_path := String(_overlay_scene_paths.get(kind, ""))
	if scene_path.is_empty():
		return null

	return load(scene_path) as PackedScene


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


func _on_overlay_restart_requested() -> void:
	start_gameplay()


func _on_overlay_return_to_title_requested() -> void:
	if title_scene_path.is_empty():
		return

	get_tree().change_scene_to_file(title_scene_path)


func _wire_end_conditions() -> void:
	if _player == null or _player.movement_controller == null:
		return

	if _player.movement_controller.action_completed.is_connected(_on_player_action_completed):
		return

	_player.movement_controller.action_completed.connect(_on_player_action_completed)


func _on_player_action_completed(_cmd: PlayerCommand.Type, new_state: GridState) -> void:
	_refresh_grid_coordinates_overlay(new_state.cell)

	if not enable_cell_end_conditions:
		return

	if not is_gameplay_state_active():
		return

	if _run_is_resolved:
		return

	if new_state.cell == success_goal_cell:
		_run_is_resolved = true
		finish_with_success()
		return

	if new_state.cell == failure_goal_cell:
		_run_is_resolved = true
		finish_with_failure()


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
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _occupancy.is_passable
		print("[Occupancy] layer=%d wired %d blocked cells" % [occupancy_wall_layer, _occupancy._blocked.size()])


func _align_gridmap_to_player_grid(gm: GridMap) -> void:
	# Keep painted visuals aligned with integer world cells used by player movement.
	var x_offset := -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var y_offset := 0.0
	var z_offset := -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	gm.position = Vector3(x_offset, y_offset, z_offset)
