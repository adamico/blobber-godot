extends GutTest

const WORLD_SCENE := preload("res://scenes/world/manual_test_world.tscn")


func _spawn_world() -> Node3D:
	var world := WORLD_SCENE.instantiate() as Node3D
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	return world


func _player(world: Node3D) -> Player:
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player, "Manual test world must include Player")
	return player


func test_reaching_success_goal_cell_triggers_victory_overlay() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()

	world.success_goal_cell = Vector2i(0, -1)
	world.failure_goal_cell = Vector2i(99, 99)
	world.start_gameplay()

	assert_true(player.execute_command(PlayerCommand.Type.STEP_FORWARD))
	assert_eq(world.current_game_state(), &"gameover_success")
	assert_eq(world.active_overlay_kind(), &"victory")
	assert_true(world.has_active_overlay())


func test_reaching_failure_goal_cell_triggers_defeat_overlay() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()

	world.success_goal_cell = Vector2i(99, 99)
	world.failure_goal_cell = Vector2i(0, 1)
	world.start_gameplay()

	assert_true(player.execute_command(PlayerCommand.Type.STEP_BACK))
	assert_eq(world.current_game_state(), &"gameover_failure")
	assert_eq(world.active_overlay_kind(), &"defeat")
	assert_true(world.has_active_overlay())


func test_disabled_end_conditions_do_not_change_state() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()

	world.enable_cell_end_conditions = false
	world.success_goal_cell = Vector2i(0, -1)
	world.failure_goal_cell = Vector2i(0, 1)
	world.start_gameplay()

	assert_true(player.execute_command(PlayerCommand.Type.STEP_FORWARD))
	assert_eq(world.current_game_state(), &"gameplay")
	assert_false(world.has_active_overlay())
