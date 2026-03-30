class_name EnemyAI
extends Node

const NO_COMMAND := -1


var _grid_module: WorldGridModule
var _last_seen_player_pos: Vector2i = Vector2i(-1, -1)


func set_grid_module(gm) -> void:
	_grid_module = gm


func choose_command(enemy, player) -> int:
	if enemy == null or player == null:
		return NO_COMMAND
	if enemy.grid_state == null or player.grid_state == null:
		return NO_COMMAND

	var enemy_cell: Vector2i = enemy.grid_state.cell
	var player_cell: Vector2i = player.grid_state.cell

	# Re-acquire LOS or update memory
	if _grid_module != null:
		var occ := _grid_module.occupancy()
		if occ != null and occ.is_line_of_sight_clear(enemy_cell, player_cell):
			_last_seen_player_pos = player_cell

	# If we have no target, or have reached our last seen breadcrumb, give up.
	if _last_seen_player_pos == Vector2i(-1, -1):
		return NO_COMMAND
	
	if enemy_cell == _last_seen_player_pos:
		# We reached the corner but still can't see the player
		_last_seen_player_pos = Vector2i(-1, -1)
		return NO_COMMAND

	# Target the breadcrumb
	var target := _last_seen_player_pos
	var step := _choose_best_step(enemy, target)
	
	if step == Vector2i.ZERO:
		return NO_COMMAND

	return _step_vector_to_command(enemy.grid_state.facing, step)


func _choose_best_step(_enemy, target: Vector2i) -> Vector2i:
	var delta: Vector2i = target - _enemy.grid_state.cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO

	var primary_step := Vector2i.ZERO
	var secondary_step := Vector2i.ZERO

	if absi(delta.x) >= absi(delta.y):
		primary_step = Vector2i(signi(delta.x), 0)
		secondary_step = Vector2i(0, signi(delta.y))
	else:
		primary_step = Vector2i(0, signi(delta.y))
		secondary_step = Vector2i(signi(delta.x), 0)

	if _is_cell_passable(_enemy, _enemy.grid_state.cell + primary_step):
		return primary_step
	if _is_cell_passable(_enemy, _enemy.grid_state.cell + secondary_step):
		if secondary_step != Vector2i.ZERO:
			return secondary_step

	return Vector2i.ZERO


func _is_cell_passable(_enemy, cell: Vector2i) -> bool:
	if _grid_module == null:
		return true # Fallback if not wired
	# For AI choice, we check basic grid passability.
	# The move will still be fully validated by MovementController anyway.
	var occ := _grid_module.occupancy()
	if occ != null and not occ.is_passable(cell):
		return false
	return true


func _step_vector_to_command(facing: GridDefinitions.Facing, step: Vector2i) -> int:
	if step == Vector2i.ZERO:
		return NO_COMMAND

	var forward := GridDefinitions.facing_to_vec2i(facing)
	var right := GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_right(facing))

	if step == forward:
		return GridCommand.Type.STEP_FORWARD
	if step == -forward:
		return GridCommand.Type.STEP_BACK
	if step == -right:
		return GridCommand.Type.MOVE_LEFT
	if step == right:
		return GridCommand.Type.MOVE_RIGHT

	return NO_COMMAND
