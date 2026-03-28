extends Node3D

@export var occupancy_wall_layer := 0
@export var auto_align_gridmap_visual := true
@export var show_debug_panel := false
@export var show_grid_coordinates_overlay := false
@export var show_minimap_overlay := false
@export_enum(
	"menu",
	"gameplay",
	"gameover_failure",
	"gameover_success",
) var initial_game_state := "gameplay"
@export var enable_cell_end_conditions := true
@export var failure_goal_cell := Vector2i(-2, 2)
@export_enum("Snap", "Smooth") var active_movement_preset := "Smooth"
@export var preset_snap_path := "res://resources/presets/movement_config_snap.tres"
@export var preset_smooth_path := "res://resources/presets/movement_config_smooth.tres"
@export_file("*.tscn") var overlay_dialog_scene_path := "res://scenes/overlays/dialog_overlay.tscn"
@export_file("*.tscn") var overlay_victory_scene_path := \
	"res://scenes/overlays/victory_overlay.tscn"
@export_file("*.tscn") var overlay_defeat_scene_path := \
	"res://scenes/overlays/defeat_overlay.tscn"
@export_file("*.tscn") var title_scene_path := "res://scenes/title/title_screen.tscn"

const OVERLAY_DIALOG := &"dialog"
const OVERLAY_VICTORY := &"victory"
const OVERLAY_DEFEAT := &"defeat"
const GAME_STATE_MENU := &"menu"
const GAME_STATE_GAMEPLAY := &"gameplay"
const GAME_STATE_DIALOG := &"dialog"
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
var _run_outcome_module: WorldRunOutcomeModule
var _ui_module: WorldUIModule
var _state_orchestrator: WorldStateOrchestrator
var _turn_orchestrator: WorldTurnOrchestrator
var _composition_orchestrator: WorldCompositionOrchestrator
var _policy_orchestrator: WorldPolicyOrchestrator
var _input_orchestrator: WorldInputOrchestrator
var _movement_orchestrator: WorldMovementOrchestrator
var _context_orchestrator: WorldContextOrchestrator
var _event_bus: WorldEventBus
var _event_router_orchestrator: WorldEventRouterOrchestrator
var _level_manager := WorldLevelManager.new()
var _hazard_module: WorldHazardModule


func _ready() -> void:
	add_child(_level_manager)
	_context_orchestrator = get_node_or_null(NODE_CONTEXT_ORCHESTRATOR) as WorldContextOrchestrator
	if _context_orchestrator == null:
		push_error("Missing required node: %s" % NODE_CONTEXT_ORCHESTRATOR)
		return

	var resolved_context := _context_orchestrator.resolve_world_context(
		self,
		_context_orchestrator.default_node_paths(),
	)
	_context_orchestrator.assign_resolved_world_context(self, resolved_context)
	if _turn_orchestrator == null:
		push_error("Missing required node: %s" % NODE_TURN_ORCHESTRATOR)
		return
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
	_input_orchestrator.wire_overlay_controls()
	_setup_game_state_machine()
	# _add_world_environment()
	apply_movement_preset(active_movement_preset)

	# Wire immediately to ensure tests can execute commands right after bootstrap
	_wire_occupancy()
	_wire_end_conditions()
	_apply_debug_panel_visibility()
	_apply_grid_coordinates_overlay_visibility()
	_apply_minimap_overlay_visibility()
	_refresh_grid_coordinates_overlay()
	_refresh_minimap_overlay()
	_refresh_debug_buttons()
	_add_hud.call_deferred()


func _add_world_environment() -> void:
	_scene_initializer_module.add_environment(self)


func _unhandled_input(event: InputEvent) -> void:
	if _input_orchestrator.handle_unhandled_input(event, is_gameplay_state_active()):
		get_viewport().set_input_as_handled()
		return


func has_active_overlay() -> bool:
	return _overlay_module.has_active_overlay()


func active_overlay_kind() -> StringName:
	return _overlay_module.active_overlay_kind()


func open_dialog_overlay() -> void:
	open_overlay(OVERLAY_DIALOG)


func open_overlay(kind: StringName) -> void:
	_policy_orchestrator.open_overlay(kind, false, is_gameplay_state_active())


func close_active_overlay() -> void:
	_policy_orchestrator.close_overlay(true)


func _apply_debug_panel_visibility() -> void:
	_ui_module.apply_debug_panel_visibility(show_debug_panel)


func _apply_grid_coordinates_overlay_visibility() -> void:
	_ui_module.apply_grid_coords_visibility(show_grid_coordinates_overlay)


func _apply_minimap_overlay_visibility() -> void:
	_ui_module.apply_minimap_visibility(show_minimap_overlay)


func _refresh_grid_coordinates_overlay(cell: Vector2i = Vector2i.ZERO) -> void:
	_ui_module.refresh_coords(cell)


func toggle_minimap_overlay() -> void:
	show_minimap_overlay = _ui_module.toggle_minimap()


func _refresh_minimap_overlay(cell: Vector2i = Vector2i.ZERO) -> void:
	_ui_module.refresh_minimap(cell, _grid_module.occupancy())


func _refresh_debug_buttons() -> void:
	var overlay_open := has_active_overlay()
	_ui_module.refresh_debug_buttons(overlay_open)


func current_game_state() -> StringName:
	return _state_orchestrator.current_game_state()


func is_gameplay_state_active() -> bool:
	return _state_orchestrator.is_gameplay_state_active()


func is_dialog_state_active() -> bool:
	return _state_orchestrator.is_dialog_state_active()


func open_dialog() -> void:
	_state_orchestrator.open_dialog()
	_policy_orchestrator.open_overlay(OVERLAY_DIALOG, true, true)


func close_dialog() -> void:
	_state_orchestrator.close_dialog()
	if active_overlay_kind() == OVERLAY_DIALOG:
		_overlay_module.close_overlay()


func go_to_menu() -> void:
	_state_orchestrator.go_to_menu()


func start_gameplay() -> void:
	_composition_orchestrator.configure_run_outcome(
		_run_outcome_module,
		enable_cell_end_conditions,
		failure_goal_cell,
		self,
	)
	_state_orchestrator.start_gameplay()
	_refresh_grid_coordinates_overlay()


func finish_with_failure() -> void:
	_state_orchestrator.finish_with_failure()


func finish_with_success() -> void:
	if _level_manager.current_floor >= _level_manager.max_floor:
		_state_orchestrator.finish_with_success()
	else:
		_level_manager.advance_floor()


func _setup_game_state_machine() -> void:
	_state_orchestrator.configure(apply_state_side_effects)
	_state_orchestrator.setup(initial_game_state)


func apply_state_side_effects() -> void:
	_policy_orchestrator.apply_state_side_effects(
		current_game_state(),
		is_gameplay_state_active(),
		is_dialog_state_active(),
		OVERLAY_DIALOG,
		OVERLAY_VICTORY,
		OVERLAY_DEFEAT,
		GAME_STATE_GAMEOVER_FAILURE,
		GAME_STATE_GAMEOVER_SUCCESS,
	)


func apply_movement_preset(preset_name: String = "") -> bool:
	var result := _movement_orchestrator.apply_preset(
		_player,
		preset_name,
		active_movement_preset,
		preset_snap_path,
		preset_smooth_path,
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


func use_player_inventory_item(index: int) -> bool:
	if _player == null:
		return false
	return _player.use_item(index)


func rest_player() -> bool:
	if _player == null or _player.stats == null:
		return false
	_player.stats.fill()
	return true


func perform_interaction() -> void:
	if _player == null:
		return
		
	var current_cell := _player.grid_state.cell
	var facing_vec := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
	var target_cell := current_cell + facing_vec
	var grid_map := get_node_or_null("GridMap") as GridMap

	if grid_map == null:
		print("[Main] Warning: GridMap not found, cannot determine cell interactions.")
		return

	# 1. Try interaction at a specific cell
	var interaction_occurred := _try_cell_interaction(grid_map, target_cell)

	# 2. If no interaction at target cell, try current cell
	if not interaction_occurred:
		interaction_occurred = _try_cell_interaction(grid_map, current_cell)
	
	# 3. If still no interaction, check for hazards at both cells
	if not interaction_occurred and _hazard_module != null:
		# Check target cell first
		if _hazard_module.interact(_player, target_cell):
			print("[Main] Found hazard interaction at target_cell: %s" % target_cell)
			return
		# Check current cell next
		if _hazard_module.interact(_player, current_cell):
			print("[Main] Found hazard interaction at current_cell: %s" % current_cell)
			return
	
	if not interaction_occurred:
		print("[Main] No interaction occurred.")


func get_cleanup_score() -> float:
	return _level_manager.cleanup_score


func _try_cell_interaction(grid_map: GridMap, cell: Vector2i) -> bool:
	# Convert 2D cell to 3D for GridMap lookup
	var cell_3d := Vector3i(cell.x, 0, cell.y)
	var cell_id := grid_map.get_cell_item(cell_3d)

	match cell_id:
		1, 2, 3: # Receptacles: Smelter, Disposal, Ritual
			return _handle_receptacle_interaction(cell_id, cell)
		4, 5, 6: # Mess items: Slime, Rust, Grime
			return _handle_pickup_interaction(cell_id, cell, grid_map)
		_:
			return false


func _handle_receptacle_interaction(cell_id: int, cell: Vector2i) -> bool:
	if _player == null or _player.inventory == null:
		return false

	var required_property: StringName = _get_receptacle_property(cell_id)
	print("[Main] Attempting receptacle interaction at cell %s with required property '%s'" % [
		cell,
		required_property
	])

	var items := _player.inventory.get_items()
	for item in items:
		if required_property == &"" or item.has_property(required_property):
			if _player.inventory.remove_item(item):
				print("[Main] Item '%s' cleaned in receptacle at cell %s" % [item.item_name, cell])
				_on_item_cleaned(item, 10) # Award points for cleaning
				return true

	print("[Main] No suitable item found for receptacle interaction at cell %s" % cell)
	return false


func _handle_pickup_interaction(cell_id: int, cell: Vector2i, grid_map: GridMap) -> bool:
	if _player == null or _player.inventory == null:
		return false

	var item := _create_item_from_cell_id(cell_id)
	if item == null:
		print("[Main] No item created for cell_id %d at cell %s" % [cell_id, cell])
		return false

	print ("[Main] Attempting pickup interaction at cell %s for item '%s'" % [cell, item.item_name])

	if _player.add_item(item):
		print("[Main] Picked up item '%s' at cell %s" % [item.item_name, cell])
		# Clear the item from the grid
		grid_map.set_cell_item(Vector3i(cell.x, 0, cell.y), -1)
		return true
	else:
		print("[Main] Inventory full, cannot pick up item '%s' at cell %s" % [item.item_name, cell])
		return false


func _create_item_from_cell_id(cell_id: int) -> ItemData:
	var item := ItemData.new()

	match cell_id:
		4: # Slime
			item.item_name = "Slime"
			item.properties.append(&"volatile")
			item.properties.append(&"flammable")
		5: # Rust
			item.item_name = "Rust"
			item.properties.append(&"corrosive")
			item.properties.append(&"disposable")
		6: # Grime
			item.item_name = "Grime"
			item.properties.append(&"sticky")
			item.properties.append(&"disposable")
		_:
			return null

	return item


func _get_receptacle_property(cell_id: int) -> StringName:
	match cell_id:
		1: # Smelter
			return &"flammable"
		2: # Disposal
			return &"disposable"
		3: # Ritual
			return &"magical"
		_:
			return &""


func _wire_end_conditions() -> void:
	if _player == null or _player.movement_controller == null:
		return

	if _player.movement_controller.action_completed.is_connected(
		_event_bus.emit_player_action_completed,
	):
		return

	_player.movement_controller.action_completed.connect(_event_bus.emit_player_action_completed)

func _is_player_cell_passable(cell: Vector2i) -> bool:
	return _grid_module.is_player_cell_passable(cell)


func _add_hud() -> void:
	_ui_module.setup_stamina_and_inventory(get_node_or_null("OverlayLayer") as CanvasLayer)
	_ui_module.refresh_cleanup_score(_level_manager.cleanup_score, _level_manager.max_cleanup_score)


func _wire_occupancy() -> void:
	var gm := get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	_grid_module.build_occupancy(gm, occupancy_wall_layer, auto_align_gridmap_visual)

	_refresh_minimap_overlay()
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _is_player_cell_passable


func _on_item_cleaned(_item: ItemData, points: int) -> void:
	_level_manager.add_cleanup_points(points)
	_ui_module.refresh_cleanup_score(_level_manager.cleanup_score, _level_manager.max_cleanup_score)
	print("[Main] Cleanup progress: %.1f/%.1f" % [
		_level_manager.cleanup_score,
		_level_manager.max_cleanup_score
	])
