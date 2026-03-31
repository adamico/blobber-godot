class_name WorldCompositionOrchestrator
extends Node

func bootstrap_world(
		root: Node3D,
		context_orchestrator: WorldContextOrchestrator,
		module_requirements: Dictionary,
		overlay_paths: Dictionary,
		configure_context: Dictionary,
) -> bool:
	var requirements := _normalize_module_requirements(module_requirements)
	if not _validate_required_modules(requirements.get("required", {})):
		return false
	_warn_optional_modules(requirements.get("optional", {}))

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


func _normalize_module_requirements(module_requirements: Dictionary) -> Dictionary:
	if module_requirements.has("required") or module_requirements.has("optional"):
		return {
			"required": module_requirements.get("required", {}),
			"optional": module_requirements.get("optional", {}),
		}

	# Backward-compatible path: treat legacy input as all required.
	return {
		"required": module_requirements,
		"optional": {},
	}


func _validate_required_modules(required_nodes: Dictionary) -> bool:
	var missing: Array[String] = []
	for node_name in required_nodes.keys():
		if required_nodes[node_name] == null:
			missing.append(String(node_name))

	if missing.is_empty():
		return true

	for node_name in missing:
		push_error("Missing required node: %s" % node_name)
	return false


func _warn_optional_modules(optional_nodes: Dictionary) -> void:
	for node_name in optional_nodes.keys():
		if optional_nodes[node_name] == null:
			push_warning("Missing optional node: %s (startup continues)" % String(node_name))


func configure_modules(ctx: Dictionary) -> void:
	var root := ctx["root"] as Node3D
	var player = ctx["player"]
	var grid_module := ctx["grid_module"] as WorldGridModule
	var overlay_module := ctx["overlay_module"] as WorldOverlayModule
	var encounter_module := ctx["encounter_module"] as WorldEncounterModule
	var ui_module := ctx["ui_module"] as WorldUIModule
	var state_orchestrator := ctx["state_orchestrator"] as WorldStateOrchestrator
	var turn_orchestrator = ctx["turn_orchestrator"]
	var input_orchestrator := ctx["input_orchestrator"] as WorldInputOrchestrator
	var event_bus := ctx["event_bus"] as WorldEventBus
	var event_router := ctx["event_router_orchestrator"] as WorldEventRouterOrchestrator

	overlay_module.configure(ctx["overlay_mount"], ctx["overlay_scene_paths"])
	var _restart_sig := overlay_module.restart_requested
	var _title_sig := overlay_module.return_to_title_requested
	if event_bus != null:
		if not _restart_sig.is_connected(event_bus.emit_overlay_restart_requested):
			_restart_sig.connect(event_bus.emit_overlay_restart_requested)
		if not _title_sig.is_connected(event_bus.emit_overlay_return_to_title_requested):
			_title_sig.connect(event_bus.emit_overlay_return_to_title_requested)
	else:
		var restart_fn: Callable = ctx.get("restart_current_run", Callable())
		var title_fn: Callable = ctx.get("return_to_title", Callable())
		if restart_fn.is_valid() and not _restart_sig.is_connected(restart_fn):
			_restart_sig.connect(restart_fn)
		if title_fn.is_valid() and not _title_sig.is_connected(title_fn):
			_title_sig.connect(title_fn)

	encounter_module.configure(root, player, grid_module)

	ui_module.configure(
		player,
		ctx["debug_panel"],
		ctx["grid_coords_label"],
		ctx["minimap_overlay"],
	)

	state_orchestrator.configure(ctx["on_state_side_effects"])
	if turn_orchestrator != null and turn_orchestrator.has_method("configure"):
		turn_orchestrator.call(
			"configure",
			ui_module,
			grid_module,
			encounter_module,
			null,
			root,
			player,
			ctx["is_gameplay_state_active"],
			Callable(), # is_combat_state_active — no longer used
			Callable(), # end_combat — no longer used
			ctx["finish_with_failure"],
		)

	if input_orchestrator != null:
		input_orchestrator.configure(
			ctx.get("btn_toggle_minimap"),
			Callable(),
		)

	if event_router != null and event_bus != null:
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
