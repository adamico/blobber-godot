class_name WorldContextOrchestrator
extends Node

func default_node_paths() -> Dictionary:
	return {
		"context_orchestrator": "ContextOrchestrator",
		"player": "Player",
		"scene_initializer_module": "SceneInitializerModule",
		"overlay_module": "OverlayModule",
		"grid_module": "GridModule",
		"encounter_module": "EncounterModule",
		"ui_module": "UIModule",
		"state_orchestrator": "StateOrchestrator",
		"composition_orchestrator": "CompositionOrchestrator",
		"movement_orchestrator": "MovementOrchestrator",
		"event_bus": "EventBus",
		"event_router_orchestrator": "EventRouterOrchestrator",
		"overlay_mount": "OverlayLayer/OverlayMount",
		"debug_panel": "OverlayLayer/DebugPanel",
		"grid_coords_label": "OverlayLayer/HUD/MinimapOverlay/GridCoordsLabel",
		"minimap_overlay": "OverlayLayer/HUD/MinimapOverlay",
		"btn_toggle_minimap": "OverlayLayer/DebugPanel/Margin/VBox/ToggleMinimap",
	}


func resolve_world_context(root: Node, node_paths: Dictionary) -> Dictionary:
	var resolved := { }
	for key in node_paths.keys():
		resolved[key] = root.get_node_or_null(String(node_paths[key]))
	return resolved


func assign_resolved_world_context(world: Node, resolved: Dictionary) -> void:
	world.set("_context_orchestrator", resolved.get("context_orchestrator"))
	world.set("_player", resolved.get("player"))
	world.set("_scene_initializer_module", resolved.get("scene_initializer_module"))
	world.set("_overlay_module", resolved.get("overlay_module"))
	world.set("_grid_module", resolved.get("grid_module"))
	world.set("_encounter_module", resolved.get("encounter_module"))
	world.set("_ui_module", resolved.get("ui_module"))
	world.set("_state_orchestrator", resolved.get("state_orchestrator"))
	world.set("_composition_orchestrator", resolved.get("composition_orchestrator"))
	world.set("_movement_orchestrator", resolved.get("movement_orchestrator"))


func build_required_modules_from_world(world: Node, resolved: Dictionary) -> Dictionary:
	return {
		"SceneInitializerModule": world.get("_scene_initializer_module"),
		"OverlayModule": world.get("_overlay_module"),
		"GridModule": world.get("_grid_module"),
		"EncounterModule": world.get("_encounter_module"),
		"UIModule": world.get("_ui_module"),
		"StateOrchestrator": world.get("_state_orchestrator"),
		"CompositionOrchestrator": world.get("_composition_orchestrator"),
		"MovementOrchestrator": world.get("_movement_orchestrator"),
		"EventBus": resolved.get("event_bus"),
		"EventRouterOrchestrator": resolved.get("event_router_orchestrator"),
		"ContextOrchestrator": world.get("_context_orchestrator"),
	}


func build_overlay_paths_from_world(world: Node) -> Dictionary:
	return {
		&"floor_complete": world.get("overlay_floor_complete_scene_path"),
		&"defeat": world.get("overlay_defeat_scene_path"),
		&"dialog_message": world.get("overlay_dialog_scene_path"),
	}


func build_overlay_registry(overlay_paths: Dictionary) -> Dictionary:
	return overlay_paths.duplicate(true)
