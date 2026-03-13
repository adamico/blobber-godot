extends GutTest

const WORLD_SCENE := preload("res://scenes/world/main.tscn")


func _spawn_world(show_coords: bool) -> Node3D:
	var world := WORLD_SCENE.instantiate() as Node3D
	world.show_grid_coordinates_overlay = show_coords
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	return world


func test_grid_coords_overlay_hidden_by_default_toggle() -> void:
	var world := await _spawn_world(false)
	var label := world.get_node_or_null("OverlayLayer/GridCoordsLabel") as Label
	assert_not_null(label)
	assert_false(label.visible)


func test_grid_coords_overlay_updates_after_player_move() -> void:
	var world := await _spawn_world(true)
	var player := world.get_node_or_null("Player") as Player
	var label := world.get_node_or_null("OverlayLayer/GridCoordsLabel") as Label
	assert_not_null(player)
	assert_not_null(label)

	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()
	world.enable_cell_end_conditions = false

	assert_true(label.visible)
	assert_eq(label.text, "Grid X: 0  Y: 0")

	assert_true(player.execute_command(PlayerCommand.Type.STEP_FORWARD))
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(label.text, "Grid X: 0  Y: -1")
