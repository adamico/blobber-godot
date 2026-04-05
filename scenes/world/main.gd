extends Node3D
## Main world scene for The Sweep.
## Stripped of overlay systems. Combat happens in the dungeon viewport.
## Turn manager handles the sequential player → enemies flow.

signal controls_ready

@export_group("Debug")
@export var enable_timing_logs := false
@export_group("")
@export var occupancy_wall_layer := 0
@export var auto_align_gridmap_visual := true
@export var show_debug_panel := false
@export var show_minimap_overlay := false
@export_enum("Snap", "Smooth") var active_movement_preset := "Smooth"
@export var preset_snap_config: MovementConfig
@export var preset_smooth_config: MovementConfig

@export_group("Entities & Items")
@export var hostile_definitions: Array[HostileActorDefinition] = []
@export var player_scene: PackedScene
@export var floor_scenes: Array[PackedScene] = []
@export var mop_item: ItemData
@export var holy_symbol_item: ItemData
@export var flask_item: ItemData
@export var ward_item: ItemData
@export var potion_item: ItemData
@export var debris_item: ItemData
@export var disposal_chute_scene: PackedScene
@export var chest_scene: PackedScene
@export var floor_exit_scene: PackedScene

@export_group("Overlays")
@export_file("*.tscn") \
var overlay_floor_complete_scene_path := "res://scenes/overlays/floor_complete_overlay.tscn"
@export_file("*.tscn") \
var overlay_victory_scene_path := "res://scenes/overlays/victory_overlay.tscn"
@export_file("*.tscn") \
var overlay_defeat_scene_path := "res://scenes/overlays/defeat_overlay.tscn"
@export_file("*.tscn") \
var overlay_dialog_scene_path := "res://scenes/overlays/dialog_message_overlay.tscn"
@export_file("*.tscn") var title_scene_path := "res://scenes/title/title_screen.tscn"
@export_group("Dialog")
@export var floor_number := 1
@export_group("Audio")
@export var audio_wiring_profile: AudioWiringProfile
@export_group("VFX")
@export var vfx_wiring_profile: Resource

const OVERLAY_FLOOR_COMPLETE := &"floor_complete"
const OVERLAY_VICTORY := &"victory"
const OVERLAY_DEFEAT := &"defeat"
const OVERLAY_DIALOG := &"dialog_message"
const GAME_STATE_MENU := &"menu"
const GAME_STATE_GAMEPLAY := &"gameplay"
const GAME_STATE_GAMEOVER_FAILURE := &"gameover_failure"
const GAME_STATE_GAMEOVER_SUCCESS := &"gameover_success"
const NODE_COMPOSITION_ORCHESTRATOR := "CompositionOrchestrator"
const NODE_CONTEXT_ORCHESTRATOR := "ContextOrchestrator"
const NODE_PLAYER := "Player"
const WORLD_TURN_MANAGER_SCRIPT := preload("res://scenes/world/modules/world_turn_manager.gd")
const WORLD_AUTHORED_FLOOR_LOADER_SCRIPT := preload(
	"res://scenes/world/modules/world_authored_floor_loader.gd"
)
const DEFAULT_PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HOSTILE_ID_BURNING := &"burning_hazard"
const HOSTILE_ID_CURSED := &"cursed_hazard"
const HOSTILE_ID_CORROSIVE := &"corrosive_hazard"
const WORLD_DIALOG_MODULE_SCRIPT := preload("res://scenes/world/modules/world_dialog_module.gd")
const DEFAULT_HOSTILE_SCENE := preload("res://scenes/hostiles/hostile.tscn")
const DEFAULT_HOSTILE_DEFINITIONS := [
	preload("res://resources/hostiles/burning_hazard.tres"),
	preload("res://resources/hostiles/cursed_hazard.tres"),
	preload("res://resources/hostiles/corrosive_hazard.tres"),
]

var _player: Player
var _scene_initializer_module: WorldSceneInitializerModule
var _overlay_module: WorldOverlayModule
var _grid_module: WorldGridModule
var _encounter_module: WorldEncounterModule
var _ui_module: WorldUIModule
var _state_orchestrator: WorldStateOrchestrator
var _composition_orchestrator: WorldCompositionOrchestrator
var _movement_orchestrator: WorldMovementOrchestrator
var _context_orchestrator: WorldContextOrchestrator
var _turn_manager: Node
var _dialog_module: Node
var _audio_orchestrator: Node
var _vfx_orchestrator: Node
var _belt_hud: Control
var _hostile_definitions_by_id: Dictionary = { }
var _authored_floor_layout: Dictionary = { }
var _controls_ready_emitted := false
var _floor_complete_heal_applied := false


func _ready() -> void:
	var scene_init_started_at := Time.get_ticks_msec()
	_log_timing("Instantiation", "_ready() start", 0)

	# Check if GameBoot has a persisted floor number
	var game_boot := get_node_or_null("/root/GameBoot")
	if game_boot != null and "current_floor_number" in game_boot:
		floor_number = game_boot.current_floor_number

	var phase_marker := Time.get_ticks_msec()
	_context_orchestrator = get_node_or_null(NODE_CONTEXT_ORCHESTRATOR) as WorldContextOrchestrator
	if _context_orchestrator == null:
		push_error("Missing required node: %s" % NODE_CONTEXT_ORCHESTRATOR)
		return
	_log_timing(
		"Instantiation",
		"_context_orchestrator resolved",
		Time.get_ticks_msec() - phase_marker,
	)

	phase_marker = Time.get_ticks_msec()
	_ensure_player_instance()
	_log_timing("Instantiation", "player ensured", Time.get_ticks_msec() - phase_marker)

	# Restore persisted HP from inter-floor heal (set by _advance_to_next_floor)
	if game_boot != null and "persisted_health" in game_boot and game_boot.persisted_health > 0:
		var restored_player := _player
		if restored_player == null:
			restored_player = get_node_or_null(NODE_PLAYER) as Player
		if restored_player != null and restored_player.stats != null:
			restored_player.stats.health = game_boot.persisted_health
		game_boot.persisted_health = 0

	phase_marker = Time.get_ticks_msec()
	var resolved_context := _context_orchestrator.resolve_world_context(
		self,
		_context_orchestrator.default_node_paths(),
	)
	_log_timing("Instantiation", "context resolved", Time.get_ticks_msec() - phase_marker)

	phase_marker = Time.get_ticks_msec()
	_context_orchestrator.assign_resolved_world_context(self, resolved_context)
	_log_timing("Instantiation", "context assigned", Time.get_ticks_msec() - phase_marker)

	if _composition_orchestrator == null:
		push_error("Missing required node: %s" % NODE_COMPOSITION_ORCHESTRATOR)
		return

	phase_marker = Time.get_ticks_msec()
	if not _composition_orchestrator.bootstrap_world(
		self,
		_context_orchestrator,
		_context_orchestrator.build_required_modules_from_world(self, resolved_context),
		_context_orchestrator.build_overlay_paths_from_world(self),
		_composition_orchestrator.build_bootstrap_context(self, resolved_context),
	):
		return
	_log_timing("Instantiation", "bootstrap_world complete", Time.get_ticks_msec() - phase_marker)

	phase_marker = Time.get_ticks_msec()
	_setup_game_state_machine()
	apply_movement_preset(active_movement_preset)
	_index_hostile_definitions()
	_mount_authored_floor_grid()
	_add_world_environment()
	_log_timing("Instantiation", "sync setup complete", Time.get_ticks_msec() - phase_marker)

	phase_marker = Time.get_ticks_msec()
	_run_staged_bootstrap.call_deferred(scene_init_started_at)
	_log_timing("Instantiation", "deferred calls queued", Time.get_ticks_msec() - phase_marker)
	_log_timing("Instantiation", "_ready() complete", Time.get_ticks_msec() - scene_init_started_at)
	_log_scene_init_time.call_deferred(scene_init_started_at)


func _run_staged_bootstrap(started_at_ms: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	# Keep turn-facing visuals warm before enabling controls.
	_author_floor_1()
	_wire_occupancy()
	_wire_turn_manager()
	_wire_hostiles()
	_initialize_floor()
	_configure_huds()
	_refresh_minimap_overlay()
	_emit_controls_ready_once()
	_log_timing("SceneInitTime", "controls_ready", Time.get_ticks_msec() - started_at_ms)

	# Defer non-critical world composition and presentation work across frames.
	await tree.process_frame

	_wire_dialog_module()
	_wire_audio_orchestrator()
	_wire_vfx_orchestrator()

	_log_timing("SceneInitTime", "staged_bootstrap.complete", Time.get_ticks_msec() - started_at_ms)


func _emit_controls_ready_once() -> void:
	if _controls_ready_emitted:
		return
	_controls_ready_emitted = true
	controls_ready.emit()


func is_controls_ready() -> bool:
	return _controls_ready_emitted


func _add_world_environment() -> void:
	_scene_initializer_module.add_environment(self)


func _ensure_player_instance() -> void:
	if get_node_or_null(NODE_PLAYER) != null:
		return

	var scene := player_scene if player_scene != null else DEFAULT_PLAYER_SCENE
	var player := scene.instantiate() as Player
	if player == null:
		push_error("Failed to instantiate Player scene.")
		return
	player.name = NODE_PLAYER
	add_child(player)


func has_active_overlay() -> bool:
	return _overlay_module.has_active_overlay()


func active_overlay_kind() -> StringName:
	return _overlay_module.active_overlay_kind()


func open_overlay(kind: StringName) -> void:
	if _overlay_module != null:
		_overlay_module.open_overlay(kind)


func close_active_overlay() -> void:
	if _overlay_module != null:
		_overlay_module.close_overlay()


func _refresh_minimap_overlay(cell: Vector2i = Vector2i.ZERO) -> void:
	_ui_module.refresh_minimap(cell, _grid_module.occupancy())


func current_game_state() -> StringName:
	return _state_orchestrator.current_game_state()


func is_gameplay_state_active() -> bool:
	return _state_orchestrator.is_gameplay_state_active()


func start_gameplay() -> void:
	_state_orchestrator.start_gameplay()


func finish_with_failure() -> void:
	_state_orchestrator.finish_with_failure()
	if _dialog_module != null:
		if _dialog_module.present_failure_then(Callable(self, "_open_defeat_overlay")):
			return
	_open_defeat_overlay()


func finish_with_success() -> void:
	_state_orchestrator.finish_with_success()
	if floor_number < floor_scenes.size():
		_open_floor_complete_overlay()
		return

	var pct: int = _turn_manager.get_clean_percent() if _turn_manager != null else 0

	if _dialog_module != null:
		if _dialog_module.present_success_then(pct, Callable(self, "_open_victory_overlay")):
			return
	_open_victory_overlay()


func _advance_to_next_floor() -> void:
	floor_number += 1
	# Persist floor number in GameBoot for next scene reload
	var game_boot := get_node_or_null("/root/GameBoot")
	if game_boot != null:
		game_boot.current_floor_number = floor_number
		if _player != null and _player.stats != null:
			game_boot.persisted_health = clampi(
				_player.stats.health,
				1,
				_player.stats.max_health,
			)
	if _player != null:
		_player.input_actions_enabled = false
	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene == self:
		tree.reload_current_scene.call_deferred()


func _open_defeat_overlay() -> void:
	open_overlay(OVERLAY_DEFEAT)
	if _overlay_module != null:
		var overlay := _overlay_module.active_overlay()
		if overlay != null and overlay.has_method("configure_summary"):
			var pct: int = _turn_manager.get_clean_percent() if _turn_manager != null else 0
			var cleaned: int = _turn_manager.get_clean_cleared() if _turn_manager != null else 0
			var total: int = _turn_manager.get_clean_total() if _turn_manager != null else 0
			overlay.call("configure_summary", pct, cleaned, total)


func _open_victory_overlay() -> void:
	open_overlay(OVERLAY_VICTORY)
	if _overlay_module != null:
		var overlay := _overlay_module.active_overlay()
		if overlay != null and overlay.has_method("configure_summary"):
			var pct: int = _turn_manager.get_clean_percent() if _turn_manager != null else 0
			var cleaned: int = _turn_manager.get_clean_cleared() if _turn_manager != null else 0
			var total: int = _turn_manager.get_clean_total() if _turn_manager != null else 0
			overlay.call("configure_summary", pct, cleaned, total)


func _open_floor_complete_overlay() -> void:
	_apply_floor_complete_heal_preview()
	open_overlay(OVERLAY_FLOOR_COMPLETE)
	# Pass the final clean% to the dedicated overlay so it can show the job rating.
	if _overlay_module != null:
		var overlay := _overlay_module.active_overlay()
		if overlay != null and overlay.has_method("configure_result"):
			var pct: int = _turn_manager.get_clean_percent() if _turn_manager != null else 0
			overlay.call("configure_result", pct)


func _apply_floor_complete_heal_preview() -> void:
	if _floor_complete_heal_applied:
		return
	if _player == null or _player.stats == null:
		return
	_player.stats.heal(3)
	_floor_complete_heal_applied = true


func _wire_dialog_module() -> void:
	var task_started := Time.get_ticks_msec()
	if _overlay_module == null:
		return
	if _turn_manager == null:
		return
	if _encounter_module == null:
		return
	if _player == null:
		return

	if _dialog_module == null:
		_dialog_module = WORLD_DIALOG_MODULE_SCRIPT.new()
		_dialog_module.name = "DialogModule"
		add_child(_dialog_module)

	_dialog_module.configure(_overlay_module, _turn_manager, _encounter_module, _player, self)
	_dialog_module.present_intro_then(Callable())
	_dialog_module.begin_floor(floor_number, floor_scenes.size())
	_log_task_timing("_wire_dialog_module", Time.get_ticks_msec() - task_started)


func _wire_audio_orchestrator() -> void:
	var task_started := Time.get_ticks_msec()
	if _player == null or _turn_manager == null:
		return

	if _audio_orchestrator == null:
		var audio_orchestrator_script := load(
			"res://scenes/world/modules/world_audio_orchestrator.gd",
		) as Script
		if audio_orchestrator_script == null:
			return
		_audio_orchestrator = audio_orchestrator_script.new()
		_audio_orchestrator.name = "AudioOrchestrator"
		add_child(_audio_orchestrator)

	_audio_orchestrator.configure(
		_player,
		_turn_manager,
		_overlay_module,
		audio_wiring_profile,
	)
	_log_task_timing("_wire_audio_orchestrator", Time.get_ticks_msec() - task_started)


func _wire_vfx_orchestrator() -> void:
	var task_started := Time.get_ticks_msec()
	if _player == null or _turn_manager == null:
		return

	if _vfx_orchestrator == null:
		var vfx_orchestrator_script := load(
			"res://scenes/world/modules/world_vfx_orchestrator.gd",
		) as Script
		if vfx_orchestrator_script == null:
			return
		_vfx_orchestrator = vfx_orchestrator_script.new()
		_vfx_orchestrator.name = "VFXOrchestrator"
		add_child(_vfx_orchestrator)

	_vfx_orchestrator.configure(
		_player,
		_turn_manager,
		self,
		_resolve_vfx_profile(),
	)
	_log_task_timing("_wire_vfx_orchestrator", Time.get_ticks_msec() - task_started)


func _resolve_vfx_profile() -> Resource:
	return vfx_wiring_profile


func _setup_game_state_machine() -> void:
	_state_orchestrator.setup("Gameplay")


func apply_state_side_effects() -> void:
	var state := current_game_state()
	if _player != null:
		if state == GAME_STATE_GAMEPLAY:
			_player.resume_exploration_commands()
		else:
			_player.pause_exploration_commands()


func apply_movement_preset(preset_name: String = "") -> bool:
	var result := _movement_orchestrator.apply_preset(
		_player,
		preset_name,
		active_movement_preset,
		preset_snap_config,
		preset_smooth_config,
	)
	active_movement_preset = String(result.get("active_name", active_movement_preset))
	return bool(result.get("ok", false))


func return_to_title() -> void:
	if title_scene_path.is_empty():
		return
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", title_scene_path)
		return
	get_tree().change_scene_to_file(title_scene_path)


func restart_current_run() -> void:
	if _overlay_module != null:
		if _overlay_module.active_overlay_kind() == OVERLAY_FLOOR_COMPLETE:
			_advance_to_next_floor()
			return

	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene == self:
		_log_timing("SceneRestartTiming", "reload_current_scene() called")
		tree.reload_current_scene()
		return

	var path := scene_file_path
	if path.is_empty():
		path = "res://scenes/world/main.tscn"

	var packed_scene := load(path) as PackedScene
	if packed_scene == null:
		start_gameplay()
		return
	_log_timing("SceneRestartTiming", "_deferred_restart_with_scene() queued | scene=%s" % path)
	call_deferred("_deferred_restart_with_scene", packed_scene)


func _deferred_restart_with_scene(packed_scene: PackedScene) -> void:
	if packed_scene == null:
		start_gameplay()
		return

	var parent := get_parent()
	if parent == null:
		start_gameplay()
		return

	var previous_name := name
	name = "%s_old" % previous_name

	var replacement := packed_scene.instantiate()
	replacement.name = previous_name
	parent.add_child(replacement)
	parent.move_child(replacement, get_index())
	queue_free()


func get_player_stats() -> CharacterStats:
	if _player == null:
		return null
	return _player.stats


func get_player_inventory_items() -> Array:
	if _player == null or _player.inventory == null:
		return []
	if not _player.inventory.has_method("get_items"):
		return []
	return _player.inventory.get_items()


func _log_timing(tag: String, label: String, elapsed_ms: int = -1) -> void:
	if not enable_timing_logs:
		return
	if elapsed_ms >= 0:
		print("[%s] %s | elapsed_ms=%d" % [tag, label, elapsed_ms])
	else:
		print("[%s] %s" % [tag, label])


func _log_scene_init_time(started_at_ms: int) -> void:
	_log_timing("SceneInitTime", "main._ready()", Time.get_ticks_msec() - started_at_ms)


func _log_task_timing(task_name: String, elapsed_ms: int = -1) -> void:
	_log_timing("DeferredTask", task_name, elapsed_ms)


func get_hostiles() -> Array:
	return _encounter_module.get_hostiles()


func get_pickups() -> Array:
	return get_tree().get_nodes_in_group(&"world_pickups")


func get_blockable_entities() -> Array:
	var entities: Array = get_pickups()
	entities.append_array(get_tree().get_nodes_in_group(&"world_chests"))
	return entities


func get_grid_occupancy() -> GridOccupancyMap:
	if _grid_module == null:
		return null
	return _grid_module.occupancy()


func _is_player_cell_passable(cell: Vector2i) -> bool:
	return _grid_module.is_player_cell_passable(cell, get_hostiles(), get_blockable_entities())


func _configure_huds() -> void:
	var task_started := Time.get_ticks_msec()
	var hud := get_node_or_null("OverlayLayer/HUD")
	if hud == null:
		return

	var hp_hud := hud.get_node_or_null("HPHUD")
	if hp_hud != null and hp_hud.has_method("configure"):
		hp_hud.configure(_player)

	var belt_hud := hud.get_node_or_null("BeltHUD")
	if belt_hud != null and belt_hud.has_method("configure"):
		belt_hud.configure(_player, _turn_manager)
	if belt_hud != null and belt_hud.has_signal("slot_clicked"):
		belt_hud.slot_clicked.connect(_on_belt_slot_clicked)
	_belt_hud = belt_hud

	var clean_hud := hud.get_node_or_null("CleanHUD")
	if clean_hud != null and clean_hud.has_method("configure"):
		clean_hud.configure(_turn_manager)

	var toast_hud := hud.get_node_or_null("ToastHUD")
	if toast_hud != null and toast_hud.has_method("configure"):
		toast_hud.configure(_turn_manager)

	var analysis_hud := hud.get_node_or_null("AnalysisHUD") as Control
	_ui_module.assign_analysis_hud(analysis_hud, _turn_manager)

	_log_task_timing("_configure_huds", Time.get_ticks_msec() - task_started)


func _author_floor_1() -> void:
	var task_started := Time.get_ticks_msec()
	if not _authored_floor_layout.is_empty():
		_apply_authored_player_spawn(_authored_floor_layout)
		_spawn_authored_floor_entities(_authored_floor_layout)
		_clear_authored_positioning_cells(_authored_floor_layout)
		_log_task_timing("_author_floor_1", Time.get_ticks_msec() - task_started)
		return

	var gm := get_node_or_null("GridMap") as GridMap
	var valid_cells: Array[Vector2i] = []
	if gm != null:
		for x in range(1, 13):
			for z in range(1, 11):
				if gm.get_cell_item(Vector3i(x, 0, z)) == -1:
					if x != 0 or z != -1:
						valid_cells.append(Vector2i(x, z))

	valid_cells.shuffle()

	if valid_cells.size() >= 8:
		_spawn_chest(valid_cells.pop_back(), mop_item)
		_spawn_chest(valid_cells.pop_back(), holy_symbol_item)
		_spawn_chest(valid_cells.pop_back(), flask_item)
		_spawn_chest(valid_cells.pop_back(), ward_item)

		_spawn_hostile_by_id(valid_cells.pop_back(), HOSTILE_ID_BURNING)
		_spawn_hostile_by_id(valid_cells.pop_back(), HOSTILE_ID_CURSED)
		_spawn_hostile_by_id(valid_cells.pop_back(), HOSTILE_ID_CORROSIVE)

		_spawn_chute(Vector2i(6, 5))
		_spawn_chest(valid_cells.pop_back(), potion_item)

	_log_task_timing("_author_floor_1", Time.get_ticks_msec() - task_started)


func _mount_authored_floor_grid() -> void:
	_authored_floor_layout.clear()
	if floor_scenes.is_empty():
		push_warning("No floor scenes configured.")
		return

	if floor_number < 1 or floor_number > floor_scenes.size():
		push_error("Floor number %d out of range [1, %d]." % [floor_number, floor_scenes.size()])
		return

	var floor_scene = floor_scenes[floor_number - 1]
	if floor_scene == null:
		push_warning("Floor %d scene is not assigned." % floor_number)
		return

	var loader = WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.new()
	if loader == null:
		push_error("Failed to create authored floor loader.")
		return

	var layout: Dictionary = loader.load_into_world(self, floor_scene)
	_report_authored_floor_messages(layout)
	if not bool(layout.get("ok", false)):
		return
	_authored_floor_layout = layout


func _report_authored_floor_messages(layout: Dictionary) -> void:
	for message in layout.get("warnings", []):
		push_warning(String(message))
	for message in layout.get("errors", []):
		push_error(String(message))


func _apply_authored_player_spawn(layout: Dictionary) -> void:
	if not bool(layout.get("has_player_spawn", false)):
		return
	if _player == null:
		push_warning("Authored floor loaded, but Player node is missing.")
		return

	var spawn_cell := layout.get("player_spawn", Vector2i.ZERO) as Vector2i
	_player.initial_cell = spawn_cell
	if _player.grid_state != null:
		_player.grid_state.cell = spawn_cell
		_player.grid_state.previous_cell = spawn_cell
		_player.apply_canonical_transform()
	if _player.movement_controller != null:
		_player.movement_controller.grid_state = _player.grid_state


func _spawn_authored_floor_entities(layout: Dictionary) -> void:
	for cell in layout.get("chute_cells", []):
		_spawn_chute(cell as Vector2i)

	for cell in layout.get("exit_cells", []):
		_spawn_exit(cell as Vector2i)

	for hostile_spawn in layout.get("hostile_spawns", []):
		if not (hostile_spawn is Dictionary):
			continue
		var hostile_cell := hostile_spawn.get("cell", Vector2i.ZERO) as Vector2i
		var marker_id := int(hostile_spawn.get("marker_id", -1))
		var hostile_id := _hostile_definition_id_for_marker(marker_id)
		if hostile_id == StringName():
			push_warning("Skipping hostile marker with unknown mapping at %s." % hostile_cell)
			continue
		var initial_facing := _hostile_initial_facing_for_marker(marker_id)
		_spawn_hostile_by_id(hostile_cell, hostile_id, initial_facing)

	for chest_spawn in layout.get("chest_spawns", []):
		if not (chest_spawn is Dictionary):
			continue
		var chest_cell := chest_spawn.get("cell", Vector2i.ZERO) as Vector2i
		var item := _item_for_marker(int(chest_spawn.get("marker_id", -1)))
		if item == null:
			push_warning("Skipping chest marker with unknown item mapping at %s." % chest_cell)
			continue
		_spawn_chest(chest_cell, item)


func _clear_authored_positioning_cells(layout: Dictionary) -> void:
	var gm := get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	var loader = WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.new()
	if loader == null:
		push_warning("Unable to clear authored positioning cells: loader unavailable.")
		return
	loader.clear_positioning_cells(gm, layout)


func _hostile_definition_id_for_marker(marker_id: int) -> StringName:
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOSTILE_BURNING:
		return HOSTILE_ID_BURNING
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOSTILE_BURNING_X:
		return HOSTILE_ID_BURNING
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOSTILE_CURSED:
		return HOSTILE_ID_CURSED
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOSTILE_CORROSIVE:
		return HOSTILE_ID_CORROSIVE
	return StringName()


func _item_for_marker(marker_id: int) -> ItemData:
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_MOP:
		return mop_item
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOLY_SYMBOL:
		return holy_symbol_item
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_SPLASH_FLASK:
		return flask_item
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_IRON_WARD:
		return ward_item
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_POTION:
		return potion_item
	if marker_id in [
		WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_DEBRIS,
		WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_DEBRIS_CURSED,
		WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_DEBRIS_BURNING_X,
		WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_DEBRIS_BURNING_Z,
		WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_DEBRIS_CORROSIVE,
	]:
		return debris_item
	return null


func _hostile_initial_facing_for_marker(marker_id: int) -> int:
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOSTILE_BURNING_X:
		return GridDefinitions.Facing.EAST
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOSTILE_BURNING:
		return GridDefinitions.Facing.NORTH
	if marker_id == WORLD_AUTHORED_FLOOR_LOADER_SCRIPT.MARKER_HOSTILE_BURNING_Z:
		return GridDefinitions.Facing.NORTH
	return -1


func _index_hostile_definitions() -> void:
	_hostile_definitions_by_id.clear()

	var source_definitions: Array = []
	if hostile_definitions.is_empty():
		source_definitions.assign(DEFAULT_HOSTILE_DEFINITIONS)
	else:
		source_definitions.assign(hostile_definitions)

	for entry in source_definitions:
		var def := entry as HostileActorDefinition
		if def == null:
			continue
		if def.definition_id == StringName():
			continue
		_hostile_definitions_by_id[def.definition_id] = def


func _spawn_hostile_by_id(
		cell: Vector2i,
		definition_id: StringName,
		initial_facing: int = -1,
) -> void:
	var def := _hostile_definitions_by_id.get(definition_id) as HostileActorDefinition
	if def == null:
		push_warning("Missing hostile definition id: %s" % String(definition_id))
		return
	_spawn_hostile(cell, def, initial_facing)


func _get_hostile_definition_by_id(definition_id: StringName) -> HostileActorDefinition:
	return _hostile_definitions_by_id.get(definition_id) as HostileActorDefinition


func _spawn_hostile(
		cell: Vector2i,
		definition: HostileActorDefinition,
		initial_facing: int = -1,
) -> Hostile:
	if definition == null:
		return null

	var hostile_scene := definition.actor_scene
	if hostile_scene == null:
		hostile_scene = DEFAULT_HOSTILE_SCENE

	var actor := hostile_scene.instantiate() as Hostile
	if actor == null:
		return null

	actor.hostile_definition_id = definition.definition_id
	actor.initial_cell = cell
	if initial_facing >= 0:
		actor.initial_facing = initial_facing as GridDefinitions.Facing
	actor.speed = maxi(definition.speed, 1)
	actor.hostile_property = definition.hostile_property
	actor.contact_damage = definition.contact_damage
	actor.hostile_hp = definition.hostile_hp
	actor.revert_turns_base = definition.revert_turns_base
	actor.cleanup_value = definition.cleanup_value
	actor.display_name_override = definition.display_name
	actor.sprite_texture = definition.sprite_texture

	var ai = actor.get_node_or_null("HostileAI")
	if ai != null:
		if "behavior" in ai:
			ai.set("behavior", definition.ai_behavior)
		if "patrol_length" in ai:
			ai.set("patrol_length", definition.patrol_length)
		if "view_distance" in ai:
			ai.set("view_distance", definition.view_distance)

	var mcfg = preset_smooth_config if active_movement_preset == "Smooth" else preset_snap_config
	if mcfg != null:
		actor.movement_config = mcfg

	add_child(actor)
	if _encounter_module != null:
		_encounter_module.register_hostile(actor)
	return actor


func _spawn_chute(cell: Vector2i) -> void:
	var chute: DisposalChute
	if disposal_chute_scene != null:
		chute = disposal_chute_scene.instantiate() as DisposalChute
	if chute == null:
		chute = DisposalChute.new()
	chute.grid_cell = cell
	chute.name = "DisposalChute_%d_%d" % [cell.x, cell.y]

	add_child(chute)


func _spawn_exit(cell: Vector2i) -> void:
	var floor_exit: WorldExit
	if floor_exit_scene != null:
		floor_exit = floor_exit_scene.instantiate() as WorldExit
	if floor_exit == null:
		floor_exit = WorldExit.new()
	floor_exit.grid_cell = cell
	floor_exit.name = "FloorExit_%d_%d" % [cell.x, cell.y]

	add_child(floor_exit)


func _spawn_chest(cell: Vector2i, item: ItemData) -> void:
	var chest
	if chest_scene != null:
		chest = chest_scene.instantiate()
	if chest == null:
		chest = preload("res://scenes/world/world_chest.gd").new()

	chest.grid_cell = cell
	chest.item_data = item
	chest.name = "Chest_%d_%d" % [cell.x, cell.y]
	add_child(chest)


func _wire_occupancy() -> void:
	var task_started := Time.get_ticks_msec()
	var gm := get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	_grid_module.build_occupancy(gm, occupancy_wall_layer, auto_align_gridmap_visual)

	_refresh_minimap_overlay()
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _is_player_cell_passable
	_log_task_timing("_wire_occupancy", Time.get_ticks_msec() - task_started)


func _wire_hostiles() -> void:
	var task_started := Time.get_ticks_msec()
	_encounter_module.wire_hostiles()
	var mcfg = preset_smooth_config if active_movement_preset == "Smooth" else preset_snap_config
	for hostile in get_hostiles():
		if mcfg != null:
			hostile.movement_config = mcfg
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _is_player_cell_passable
	_log_task_timing("_wire_hostiles", Time.get_ticks_msec() - task_started)


func _wire_turn_manager() -> void:
	var task_started := Time.get_ticks_msec()
	if _player == null:
		return

	_turn_manager = WORLD_TURN_MANAGER_SCRIPT.new()
	_turn_manager.name = "TurnManager"
	add_child(_turn_manager)
	_turn_manager.configure(_player, _encounter_module, _grid_module, self)
	_log_task_timing("_wire_turn_manager", Time.get_ticks_msec() - task_started)

	# Wire player signals to turn manager
	if not _player.turn_action_performed.is_connected(_on_player_turn_action):
		_player.turn_action_performed.connect(_on_player_turn_action)
	if not _player.wall_bumped.is_connected(_on_player_wall_bump):
		_player.wall_bumped.connect(_on_player_wall_bump)

	# Wire turn manager signals
	if not _turn_manager.player_died.is_connected(_on_player_died):
		_turn_manager.player_died.connect(_on_player_died)
	if not _turn_manager.turn_completed.is_connected(_on_turn_completed):
		_turn_manager.turn_completed.connect(_on_turn_completed)


func _on_player_turn_action(cmd: GridCommand.Type) -> void:
	if not is_gameplay_state_active():
		return

	match cmd:
		GridCommand.Type.CYCLE_TARGET_PREV:
			_turn_manager.process_cycle_target(-1)
		GridCommand.Type.CYCLE_TARGET_NEXT:
			_turn_manager.process_cycle_target(1)
		GridCommand.Type.ANALYZE_TARGET:
			_turn_manager.process_analyze_target()
		GridCommand.Type.USE_SLOT_1:
			_turn_manager.process_slot_use(0)
		GridCommand.Type.USE_SLOT_2:
			_turn_manager.process_slot_use(1)
		GridCommand.Type.USE_SLOT_3:
			_turn_manager.process_slot_use(2)
		GridCommand.Type.INTERACT, GridCommand.Type.PICKUP:
			_turn_manager.process_player_interact()
		GridCommand.Type.DROP_SLOT_1:
			_turn_manager.process_player_drop(0)
		GridCommand.Type.DROP_SLOT_2:
			_turn_manager.process_player_drop(1)
		GridCommand.Type.DROP_SLOT_3:
			_turn_manager.process_player_drop(2)
		GridCommand.Type.TURN_LEFT, GridCommand.Type.TURN_RIGHT:
			if _player != null and _player.grid_state != null:
				_ui_module.refresh_minimap(_player.grid_state.cell, _grid_module.occupancy())
		_:
			# Movement commands — grid state already updated
			if _player != null and _player.grid_state != null:
				_turn_manager.process_player_move(_player.grid_state)


func _on_player_wall_bump() -> void:
	if not is_gameplay_state_active():
		return
	_turn_manager.process_wall_bump()


func _on_player_died() -> void:
	finish_with_failure()


func _on_turn_completed() -> void:
	if _player != null and _player.grid_state != null:
		_ui_module.refresh_minimap(_player.grid_state.cell, _grid_module.occupancy())

	# Check floor exit after every turn (rated completion — exit is always possible).
	_check_exit_condition()


func _initialize_floor() -> void:
	var task_started := Time.get_ticks_msec()
	if _turn_manager != null:
		_turn_manager.initialize_floor()
	_log_task_timing("_initialize_floor", Time.get_ticks_msec() - task_started)


func _check_exit_condition() -> void:
	if _dialog_module != null and _dialog_module.has_method("has_blocking_dialog"):
		if bool(_dialog_module.call("has_blocking_dialog")):
			return
	if _player == null or _player.grid_state == null:
		return

	for node in get_tree().get_nodes_in_group(&"world_exit_cells"):
		if node is WorldExit and node.matches_cell(_player.grid_state.cell):
			if node.can_trigger(false):
				if _turn_manager != null:
					_turn_manager.notify_floor_exit_reached()
				finish_with_success()
				return


func _input(event: InputEvent) -> void:
	if not is_gameplay_state_active():
		return
	if _turn_manager == null or _player == null:
		return
	if not _player.input_actions_enabled:
		return
	if has_active_overlay():
		return

	var camera := _player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return

	if event is InputEventMouseMotion:
		_turn_manager.process_hover_target(event.position, camera)
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not mouse_event.pressed:
			return

		# Ignore clicks inside the belt HUD — those are slot use/drop actions.
		if _belt_hud != null and _belt_hud.get_global_rect().has_point(mouse_event.position):
			return

		# Ensure the click location becomes the active target before analysis.
		_turn_manager.process_hover_target(mouse_event.position, camera)
		_turn_manager.process_analyze_target()


func _on_belt_slot_clicked(slot_index: int, is_drop: bool) -> void:
	if not is_gameplay_state_active():
		return
	if _turn_manager == null:
		return
	if has_active_overlay():
		return

	if is_drop:
		_turn_manager.process_player_drop(slot_index)
	else:
		_turn_manager.process_slot_use(slot_index)
