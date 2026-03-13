extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func test_step_forward_advances_cell() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var executed := player.execute_command(PlayerCommand.Type.STEP_FORWARD)

    assert_true(executed)
    assert_eq(player.grid_state.cell, Vector2i(0, -1))


func test_step_back_retreats_cell() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var executed := player.execute_command(PlayerCommand.Type.STEP_BACK)

    assert_true(executed)
    assert_eq(player.grid_state.cell, Vector2i(0, 1))


func test_strafe_left_moves_perpendicular() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var executed := player.execute_command(PlayerCommand.Type.MOVE_LEFT)

    assert_true(executed)
    assert_eq(player.grid_state.cell, Vector2i(-1, 0))


func test_strafe_right_moves_perpendicular() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var executed := player.execute_command(PlayerCommand.Type.MOVE_RIGHT)

    assert_true(executed)
    assert_eq(player.grid_state.cell, Vector2i(1, 0))


func test_turn_left_updates_facing() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var executed := player.execute_command(PlayerCommand.Type.TURN_LEFT)

    assert_true(executed)
    assert_eq(player.grid_state.facing, GridDefinitions.Facing.WEST)


func test_turn_right_updates_facing() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var executed := player.execute_command(PlayerCommand.Type.TURN_RIGHT)

    assert_true(executed)
    assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)


func test_transform_sync_after_command() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var executed := player.execute_command(PlayerCommand.Type.STEP_FORWARD)
    var expected_pos := GridMapper.cell_to_world(player.grid_state.cell, player.movement_config.cell_size, 0.0)

    assert_true(executed)
    assert_eq(player.global_position, expected_pos)


func test_scripted_sequence_yields_expected_final_state() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    assert_true(player.execute_command(PlayerCommand.Type.STEP_FORWARD))
    assert_true(player.execute_command(PlayerCommand.Type.TURN_RIGHT))
    assert_true(player.execute_command(PlayerCommand.Type.STEP_FORWARD))
    assert_true(player.execute_command(PlayerCommand.Type.TURN_LEFT))
    assert_true(player.execute_command(PlayerCommand.Type.STEP_BACK))

    assert_eq(player.grid_state.cell, Vector2i(1, 0))
    assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)
    assert_eq(player.global_position, Vector3(1.0, 0.0, 0.0))


func test_execute_command_rejects_while_busy() -> void:
    var player: Player = PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    player.movement_controller.is_busy = true
    var before_cell := player.grid_state.cell
    var before_facing := player.grid_state.facing

    var executed := player.execute_command(PlayerCommand.Type.STEP_FORWARD)

    assert_false(executed)
    assert_eq(player.grid_state.cell, before_cell)
    assert_eq(player.grid_state.facing, before_facing)
