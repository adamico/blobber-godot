extends Node3D
## Main world scene for The Sweep.
## Stripped of overlay systems. Combat happens in the dungeon viewport.
## Turn manager handles the sequential player → enemies flow.

@export var occupancy_wall_layer := 0
@export var auto_align_gridmap_visual := true
@export var show_debug_panel := false
@export var show_minimap_overlay := false
@export_enum("Snap", "Smooth") var active_movement_preset := "Smooth"
@export var preset_snap_config: MovementConfig
@export var preset_smooth_config: MovementConfig

@export_group("HUD Scenes")
@export var hp_hud_scene: PackedScene
@export var belt_hud_scene: PackedScene
@export var clean_hud_scene: PackedScene

@export_group("Entities & Items")
@export var hazard_scene: PackedScene
@export var mop_item: ItemData
@export var vac_item: ItemData
@export var sponge_item: ItemData

@export_group("Overlays")
@export_file("*.tscn") \
var overlay_victory_scene_path := "res://scenes/overlays/victory_overlay.tscn"
@export_file("*.tscn") \
var overlay_defeat_scene_path := "res://scenes/overlays/defeat_overlay.tscn"
@export_file("*.tscn") var title_scene_path := "res://scenes/title/title_screen.tscn"

const OVERLAY_VICTORY := &"victory"
const OVERLAY_DEFEAT := &"defeat"
const GAME_STATE_MENU := &"menu"
const GAME_STATE_GAMEPLAY := &"gameplay"
const GAME_STATE_GAMEOVER_FAILURE := &"gameover_failure"
const GAME_STATE_GAMEOVER_SUCCESS := &"gameover_success"
const NODE_TURN_ORCHESTRATOR := "TurnOrchestrator"
const NODE_COMPOSITION_ORCHESTRATOR := "CompositionOrchestrator"
const NODE_CONTEXT_ORCHESTRATOR := "ContextOrchestrator"
const NODE_EVENT_ROUTER_ORCHESTRATOR := "EventRouterOrchestrator"

var _player: Player
var _scene_initializer_module: WorldSceneInitializerModule
var _overlay_module: WorldOverlayModule
var _grid_module: WorldGridModule
var _encounter_module: WorldEncounterModule
@warning_ignore("unused_private_class_variable")
var _run_outcome_module: WorldRunOutcomeModule
var _ui_module: WorldUIModule
var _state_orchestrator: WorldStateOrchestrator
@warning_ignore("unused_private_class_variable")
var _turn_orchestrator: WorldTurnOrchestrator
var _composition_orchestrator: WorldCompositionOrchestrator
@warning_ignore("unused_private_class_variable")
var _input_orchestrator: WorldInputOrchestrator
var _movement_orchestrator: WorldMovementOrchestrator
var _context_orchestrator: WorldContextOrchestrator
@warning_ignore("unused_private_class_variable")
var _event_bus: WorldEventBus
var _event_router_orchestrator: WorldEventRouterOrchestrator
# New turn manager
var _turn_manager: WorldTurnManager


func _ready() -> void:
	_context_orchestrator = get_node_or_null(NODE_CONTEXT_ORCHESTRATOR) as WorldContextOrchestrator
	if _context_orchestrator == null:
		push_error("Missing required node: %s" % NODE_CONTEXT_ORCHESTRATOR)
		return

	var resolved_context := _context_orchestrator.resolve_world_context(
		self,
		_context_orchestrator.default_node_paths(),
	)
	_context_orchestrator.assign_resolved_world_context(self, resolved_context)
	if _event_router_orchestrator == null:
		push_error("Missing required node: %s" % NODE_EVENT_ROUTER_ORCHESTRATOR)
		return
	if _composition_orchestrator == null:
		push_error("Missing required node: %s" % NODE_COMPOSITION_ORCHESTRATOR)
		return
	if not _composition_orchestrator.bootstrap_world(
		self,
		_context_orchestrator,
		_context_orchestrator.build_required_modules_from_world(self),
		_context_orchestrator.build_overlay_paths_from_world(self),
		_composition_orchestrator.build_bootstrap_context(self, resolved_context),
	):
		return

	_setup_game_state_machine()
	_add_world_environment()
	apply_movement_preset(active_movement_preset)

	_author_floor_1()
	_wire_occupancy.call_deferred()
	_wire_enemies.call_deferred()
	_wire_turn_manager.call_deferred()
	_apply_debug_panel_visibility()
	_apply_minimap_overlay_visibility()
	_refresh_minimap_overlay()
	_add_huds.call_deferred()


func _add_world_environment() -> void:
	_scene_initializer_module.add_environment(self)


func _unhandled_input(_event: InputEvent) -> void:
	# All input is now handled by the Player directly
	pass


func has_active_overlay() -> bool:
	return _overlay_module.has_active_overlay()


func active_overlay_kind() -> StringName:
	return _overlay_module.active_overlay_kind()


func open_overlay(kind: StringName) -> void:
	if kind == OVERLAY_VICTORY or kind == OVERLAY_DEFEAT:
		if _overlay_module != null:
			_overlay_module.open_overlay(kind)


func close_active_overlay() -> void:
	if _overlay_module != null:
		_overlay_module.close_overlay()


func _apply_debug_panel_visibility() -> void:
	_ui_module.apply_debug_panel_visibility(show_debug_panel)


func _apply_minimap_overlay_visibility() -> void:
	_ui_module.apply_minimap_visibility(show_minimap_overlay)


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
	open_overlay(OVERLAY_DEFEAT)


func finish_with_success() -> void:
	_state_orchestrator.finish_with_success()
	open_overlay(OVERLAY_VICTORY)


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
	get_tree().change_scene_to_file(title_scene_path)


func restart_current_run() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene == self:
		tree.reload_current_scene()
		return

	var path := scene_file_path
	if path.is_empty():
		path = "res://scenes/world/main.tscn"

	var packed_scene := load(path) as PackedScene
	if packed_scene == null:
		start_gameplay()
		return
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


func get_enemies() -> Array:
	return _encounter_module.get_enemies()


func _is_player_cell_passable(cell: Vector2i) -> bool:
	return _grid_module.is_player_cell_passable(cell, get_enemies())


func _add_huds() -> void:
	var layer := get_node_or_null("OverlayLayer") as CanvasLayer
	if layer == null:
		return

	if hp_hud_scene != null:
		var hp_hud := hp_hud_scene.instantiate()
		layer.add_child(hp_hud)
		hp_hud.configure(_player)

	if belt_hud_scene != null:
		var belt_hud := belt_hud_scene.instantiate()
		layer.add_child(belt_hud)
		belt_hud.configure(_player)

	if clean_hud_scene != null:
		var clean_hud := clean_hud_scene.instantiate()
		layer.add_child(clean_hud)
		clean_hud.configure(_turn_manager)


func _author_floor_1() -> void:
	var old_enemy = get_node_or_null("FloorEnemy")
	if old_enemy:
		old_enemy.queue_free()
	var old_pickup = get_node_or_null("PotionPickup")
	if old_pickup:
		old_pickup.queue_free()

	var gm := get_node_or_null("GridMap") as GridMap
	var valid_cells: Array[Vector2i] = []
	if gm != null:
		for x in range(1, 13):
			for z in range(1, 11):
				if gm.get_cell_item(Vector3i(x, 0, z)) == -1:
					if x != 0 or z != -1: # Exclude typical player start
						valid_cells.append(Vector2i(x, z))

	valid_cells.shuffle()

	if valid_cells.size() >= 6:
		_spawn_pickup(valid_cells.pop_back(), mop_item)
		_spawn_pickup(valid_cells.pop_back(), vac_item)
		_spawn_pickup(valid_cells.pop_back(), sponge_item)

		_spawn_hazard(valid_cells.pop_back(), RpsSystem.HazardClass.FLAMMABLE)
		_spawn_hazard(valid_cells.pop_back(), RpsSystem.HazardClass.UNDEAD)
		_spawn_hazard(valid_cells.pop_back(), RpsSystem.HazardClass.CORROSIVE)


func _spawn_hazard(cell: Vector2i, htype: RpsSystem.HazardClass) -> void:
	if hazard_scene == null:
		return
	var h = hazard_scene.instantiate() as Hazard
	h.hazard_class = htype
	h.initial_cell = cell

	var ai = h.get_node_or_null("EnemyAI")
	if ai != null:
		if htype == RpsSystem.HazardClass.UNDEAD or htype == RpsSystem.HazardClass.CURSED:
			ai.set("behavior", 2) # HazardAI.Behavior.CHASE
		elif htype == RpsSystem.HazardClass.VOLATILE:
			ai.set("behavior", 1) # HazardAI.Behavior.PATROL

	add_child(h)


func _spawn_pickup(cell: Vector2i, item: ItemData) -> void:
	var p = WorldPickup.new()
	p.grid_cell = cell
	p.item_data = item

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	mesh.mesh = box
	mesh.position.y = 0.15

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.YELLOW
	mesh.set_surface_override_material(0, mat)

	var lbl := Label3D.new()
	lbl.text = item.item_name
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.005
	lbl.position = Vector3(0, 0.4, 0)
	p.add_child(lbl)

	p.add_child(mesh)
	add_child(p)


func _wire_occupancy() -> void:
	var gm := get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	_grid_module.build_occupancy(gm, occupancy_wall_layer, auto_align_gridmap_visual)

	_refresh_minimap_overlay()
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _is_player_cell_passable


func _wire_enemies() -> void:
	_encounter_module.wire_enemies()
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _is_player_cell_passable


func _wire_turn_manager() -> void:
	if _player == null:
		return

	_turn_manager = WorldTurnManager.new()
	_turn_manager.name = "TurnManager"
	add_child(_turn_manager)
	_turn_manager.configure(_player, _encounter_module, _grid_module, self)
	_turn_manager.initialize_floor()

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
		GridCommand.Type.USE_SLOT_1:
			_turn_manager.process_slot_use(0)
		GridCommand.Type.USE_SLOT_2:
			_turn_manager.process_slot_use(1)
		GridCommand.Type.USE_SLOT_3:
			_turn_manager.process_slot_use(2)
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

	# Check floor exit
	if _turn_manager.is_floor_clean():
		_check_exit_condition()


func _check_exit_condition() -> void:
	if _player == null or _player.grid_state == null:
		return

	for node in get_tree().get_nodes_in_group(&"world_exit_cells"):
		if node is WorldExit and node.matches_cell(_player.grid_state.cell):
			if node.can_trigger(not _turn_manager.is_floor_clean()):
				finish_with_success()
				return
