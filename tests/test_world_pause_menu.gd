extends GutTest

const WorldMainScript := preload("res://scenes/world/main.gd")
const WorldOverlayModuleScript := preload("res://scenes/world/modules/world_overlay_module.gd")
const WorldStateOrchestratorScript := preload(
	"res://scenes/world/modules/world_state_orchestrator.gd"
)


func test_pause_input_opens_pause_overlay_and_switches_state() -> void:
	var world := WorldMainScript.new()
	add_child_autofree(world)

	var overlay_mount := Control.new()
	overlay_mount.name = "OverlayMount"
	world.add_child(overlay_mount)

	var overlay_module := WorldOverlayModuleScript.new()
	world.add_child(overlay_module)
	overlay_module.configure(
		overlay_mount,
		{&"pause": "res://scenes/overlays/pause_menu_overlay.tscn"},
	)

	var state_orchestrator := WorldStateOrchestratorScript.new()
	world.add_child(state_orchestrator)
	state_orchestrator.configure(Callable())
	state_orchestrator.setup("Gameplay")

	world.set("_overlay_module", overlay_module)
	world.set("_state_orchestrator", state_orchestrator)
	world.call("_wire_pause_overlay_events")

	var pause_event := InputEventAction.new()
	pause_event.action = &"pause_menu"
	pause_event.pressed = true
	world.call("_input", pause_event)

	assert_true(world.is_pause_menu_open())
	assert_eq(state_orchestrator.current_game_state(), &"menu")


func test_closing_pause_overlay_restores_gameplay_state() -> void:
	var world := WorldMainScript.new()
	add_child_autofree(world)

	var overlay_mount := Control.new()
	overlay_mount.name = "OverlayMount"
	world.add_child(overlay_mount)

	var overlay_module := WorldOverlayModuleScript.new()
	world.add_child(overlay_module)
	overlay_module.configure(
		overlay_mount,
		{&"pause": "res://scenes/overlays/pause_menu_overlay.tscn"},
	)

	var state_orchestrator := WorldStateOrchestratorScript.new()
	world.add_child(state_orchestrator)
	state_orchestrator.configure(Callable())
	state_orchestrator.setup("Gameplay")

	world.set("_overlay_module", overlay_module)
	world.set("_state_orchestrator", state_orchestrator)
	world.call("_wire_pause_overlay_events")

	assert_true(world.open_pause_menu())
	assert_true(world.close_pause_menu())
	assert_eq(state_orchestrator.current_game_state(), &"gameplay")