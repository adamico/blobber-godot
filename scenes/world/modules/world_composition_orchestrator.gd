class_name WorldCompositionOrchestrator
extends Node

func bootstrap_world(
		root: Node3D,
		context_orchestrator: WorldContextOrchestrator,
		required_nodes: Dictionary,
		overlay_paths: Dictionary,
		configure_context: Dictionary,
) -> bool:
	if not assert_required_modules(root, required_nodes):
		return false

	var overlay_scene_paths := context_orchestrator.build_overlay_registry(overlay_paths)
	var overlay_module := configure_context["overlay_module"] as WorldOverlayModule
	overlay_module.set_overlay_scene_paths(overlay_scene_paths)

	var ctx := configure_context.duplicate(true)
	ctx["root"] = root
	ctx["overlay_scene_paths"] = overlay_scene_paths
	configure_modules(ctx)
	return true


func build_bootstrap_context(world: Node3D, resolved_context: Dictionary) -> Dictionary:
	return {
		"player": world.get("_player"),
		"grid_module": world.get("_grid_module"),
		"overlay_module": world.get("_overlay_module"),
		"run_outcome_module": world.get("_run_outcome_module"),
		"encounter_module": world.get("_encounter_module"),
		"ui_module": world.get("_ui_module"),
		"state_orchestrator": world.get("_state_orchestrator"),
		"turn_orchestrator": world.get("_turn_orchestrator"),
		"input_orchestrator": world.get("_input_orchestrator"),
		"event_bus": world.get("_event_bus"),
		"event_router_orchestrator": world.get("_event_router_orchestrator"),
		"overlay_mount": resolved_context.get("overlay_mount"),
		"debug_panel": resolved_context.get("debug_panel"),
		"grid_coords_label": resolved_context.get("grid_coords_label"),
		"minimap_overlay": resolved_context.get("minimap_overlay"),
		"btn_toggle_minimap": resolved_context.get("btn_toggle_minimap"),
		"on_state_side_effects": Callable(world, "apply_state_side_effects"),
		"is_gameplay_state_active": Callable(world, "is_gameplay_state_active"),
		"restart_current_run": Callable(world, "restart_current_run"),
		"return_to_title": Callable(world, "return_to_title"),
		"finish_with_success": Callable(world, "finish_with_success"),
		"finish_with_failure": Callable(world, "finish_with_failure"),
	}


func assert_required_modules(_root: Node, required_nodes: Dictionary) -> bool:
	for node_name in required_nodes.keys():
		if required_nodes[node_name] == null:
			push_error("Missing required node: %s" % String(node_name))
			return false
	return true


func configure_modules(ctx: Dictionary) -> void:
	var root := ctx["root"] as Node3D
	var player = ctx["player"]
	var grid_module := ctx["grid_module"] as WorldGridModule
	var overlay_module := ctx["overlay_module"] as WorldOverlayModule
	var run_outcome_module := ctx["run_outcome_module"] as WorldRunOutcomeModule
	var encounter_module := ctx["encounter_module"] as WorldEncounterModule
	var ui_module := ctx["ui_module"] as WorldUIModule
	var state_orchestrator := ctx["state_orchestrator"] as WorldStateOrchestrator
	var turn_orchestrator := ctx["turn_orchestrator"] as WorldTurnOrchestrator
	var input_orchestrator := ctx["input_orchestrator"] as WorldInputOrchestrator
	var event_bus := ctx["event_bus"] as WorldEventBus
	var event_router := ctx["event_router_orchestrator"] as WorldEventRouterOrchestrator

	overlay_module.configure(
			ctx["overlay_mount"], ctx["overlay_scene_paths"])
	var _restart_sig := overlay_module.restart_requested
	var _title_sig := overlay_module.return_to_title_requested
	if not _restart_sig.is_connected(event_bus.emit_overlay_restart_requested):
		_restart_sig.connect(event_bus.emit_overlay_restart_requested)
	if not _title_sig.is_connected(event_bus.emit_overlay_return_to_title_requested):
		_title_sig.connect(event_bus.emit_overlay_return_to_title_requested)

	encounter_module.configure(root, player, grid_module)

	ui_module.configure(
		player,
		ctx["debug_panel"],
		ctx["grid_coords_label"],
		ctx["minimap_overlay"],
	)

	state_orchestrator.configure(ctx["on_state_side_effects"])
	turn_orchestrator.configure(
		ui_module,
		grid_module,
		encounter_module,
		run_outcome_module,
		root,
		player,
		ctx["is_gameplay_state_active"],
		Callable(), # is_combat_state_active — no longer used
		Callable(), # end_combat — no longer used
		ctx["finish_with_failure"],
	)

	input_orchestrator.configure(
		ctx.get("btn_toggle_minimap"),
		Callable(),
	)

	event_router.configure(
			event_bus,
			ctx["restart_current_run"],
			ctx["return_to_title"],
			ctx["finish_with_success"],
			ctx["finish_with_failure"],
			Callable(),
			Callable(),
			Callable(),
			ctx["is_gameplay_state_active"],
	)


func configure_run_outcome(
		run_outcome_module: WorldRunOutcomeModule,
		enable_cell_end_conditions: bool,
		failure_goal_cell: Vector2i,
		world_root: Node3D,
		get_enemies_fn: Callable,
) -> void:
	run_outcome_module.call(
			"configure",
			enable_cell_end_conditions,
			failure_goal_cell,
			world_root,
			get_enemies_fn,
	)
	run_outcome_module.reset_run()
