extends Node

class_name WorldCompositionOrchestrator

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
		"ui_module": world.get("_ui_module"),
		"state_orchestrator": world.get("_state_orchestrator"),
		"turn_orchestrator": world.get("_turn_orchestrator"),
		"policy_orchestrator": world.get("_policy_orchestrator"),
		"input_orchestrator": world.get("_input_orchestrator"),
		"event_bus": world.get("_event_bus"),
		"event_router_orchestrator": world.get("_event_router_orchestrator"),
		"hazard_module": world.get("_hazard_module"),
		"overlay_mount": resolved_context.get("overlay_mount"),
		"debug_panel": resolved_context.get("debug_panel"),
		"grid_coords_label": resolved_context.get("grid_coords_label"),
		"minimap_overlay": resolved_context.get("minimap_overlay"),
		"btn_toggle_minimap": resolved_context.get("btn_toggle_minimap"),
		"btn_close_overlay": resolved_context.get("btn_close_overlay"),
		"toggle_minimap_overlay": Callable(world, "toggle_minimap_overlay"),
		"close_active_overlay": Callable(world, "close_active_overlay"),
		"enable_cell_end_conditions": world.get("enable_cell_end_conditions"),
		"failure_goal_cell": world.get("failure_goal_cell"),
		"restart_current_run": Callable(world, "restart_current_run"),
		"return_to_title": Callable(world, "return_to_title"),
		"finish_with_success": Callable(world, "finish_with_success"),
		"finish_with_failure": Callable(world, "finish_with_failure"),
		"process_player_action": Callable(world.get("_turn_orchestrator"), "process_player_action"),
		"on_state_side_effects": Callable(world, "apply_state_side_effects"),
		"is_gameplay_state_active": Callable(world, "is_gameplay_state_active"),
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
	var ui_module := ctx["ui_module"] as WorldUIModule
	var state_orchestrator := ctx["state_orchestrator"] as WorldStateOrchestrator
	var turn_orchestrator := ctx["turn_orchestrator"] as WorldTurnOrchestrator
	var policy_orchestrator := ctx["policy_orchestrator"] as WorldPolicyOrchestrator
	var input_orchestrator := ctx["input_orchestrator"] as WorldInputOrchestrator
	var event_bus := ctx["event_bus"] as WorldEventBus
	var event_router_orchestrator := \
		ctx["event_router_orchestrator"] as WorldEventRouterOrchestrator
	var hazard_module := ctx["hazard_module"] as WorldHazardModule
	if not overlay_module.restart_requested.is_connected(event_bus.emit_overlay_restart_requested):
		overlay_module.restart_requested.connect(event_bus.emit_overlay_restart_requested)
	if not overlay_module.return_to_title_requested.is_connected(
		event_bus.emit_overlay_return_to_title_requested,
	):
		overlay_module.return_to_title_requested.connect(
			event_bus.emit_overlay_return_to_title_requested,
		)

	overlay_module.configure(ctx["overlay_mount"], ctx["overlay_scene_paths"])

	run_outcome_module.call(
		"configure",
		ctx["enable_cell_end_conditions"],
		ctx["failure_goal_cell"],
		root,
	)
	run_outcome_module.reset_run()
	if not run_outcome_module.success_reached.is_connected(
		event_bus.emit_run_outcome_success_reached,
	):
		run_outcome_module.success_reached.connect(event_bus.emit_run_outcome_success_reached)
	if not run_outcome_module.failure_reached.is_connected(
		event_bus.emit_run_outcome_failure_reached,
	):
		run_outcome_module.failure_reached.connect(event_bus.emit_run_outcome_failure_reached)

	ui_module.configure(
		player,
		ctx["debug_panel"],
		ctx["grid_coords_label"],
		ctx["minimap_overlay"],
		ctx["btn_close_overlay"],
	)

	state_orchestrator.configure(ctx["on_state_side_effects"])
	turn_orchestrator.configure(
		ui_module,
		grid_module,
		run_outcome_module,
		hazard_module,
		root,
		player,
		ctx["is_gameplay_state_active"],
	)

	policy_orchestrator.configure(
		player,
		overlay_module,
		ui_module,
	)

	input_orchestrator.configure(
		ctx["btn_toggle_minimap"],
		ctx["btn_close_overlay"],
		ctx["toggle_minimap_overlay"],
		ctx["close_active_overlay"],
	)

	event_router_orchestrator.configure(
		event_bus,
		ctx["restart_current_run"],
		ctx["return_to_title"],
		ctx["finish_with_success"],
		ctx["finish_with_failure"],
		ctx["process_player_action"],
		ctx["is_gameplay_state_active"],
	)


func configure_run_outcome(
		run_outcome_module: WorldRunOutcomeModule,
		enable_cell_end_conditions: bool,
		failure_goal_cell: Vector2i,
		world_root: Node3D,
) -> void:
	run_outcome_module.call("configure", enable_cell_end_conditions, failure_goal_cell, world_root)
	run_outcome_module.reset_run()
