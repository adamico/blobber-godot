class_name HazardAI
extends EnemyAI

enum Behavior {
	STATIONARY,
	PATROL,
	CHASE,
	PROXIMITY_TRIGGER,
}

@export var behavior: Behavior = Behavior.STATIONARY
@export var patrol_length: int = 3

var _patrol_steps_taken: int = 0
var _patrol_direction: int = 1 ## 1 = forward, -1 = backward
var _triggered: bool = false


func choose_command(enemy, player) -> int:
	match behavior:
		Behavior.STATIONARY:
			return NO_COMMAND
		Behavior.CHASE:
			return super.choose_command(enemy, player)
		Behavior.PATROL:
			return _patrol_command(enemy)
		Behavior.PROXIMITY_TRIGGER:
			return _proximity_check(enemy, player)
		_:
			return NO_COMMAND


func _patrol_command(enemy) -> int:
	if enemy == null or enemy.grid_state == null:
		return NO_COMMAND

	var forward_vec := GridDefinitions.facing_to_vec2i(enemy.grid_state.facing)
	var step_dir := forward_vec * _patrol_direction
	var next_cell: Vector2i = enemy.grid_state.cell + step_dir

	if not _is_cell_passable(enemy, next_cell):
		_patrol_direction *= -1
		_patrol_steps_taken = 0
		step_dir = forward_vec * _patrol_direction
		next_cell = enemy.grid_state.cell + step_dir

		# If trapped on both forward and back axes, try re-orienting to an open axis
		if not _is_cell_passable(enemy, next_cell):
			_patrol_direction = 1 # Reset so once turned, it steps forward newly

			var right_facing := GridDefinitions.rotate_right(enemy.grid_state.facing)
			var right_cell: Vector2i = enemy.grid_state.cell + GridDefinitions.facing_to_vec2i(right_facing)
			if _is_cell_passable(enemy, right_cell):
				return GridCommand.Type.TURN_RIGHT

			var left_facing := GridDefinitions.rotate_left(enemy.grid_state.facing)
			var left_cell: Vector2i = enemy.grid_state.cell + GridDefinitions.facing_to_vec2i(left_facing)
			if _is_cell_passable(enemy, left_cell):
				return GridCommand.Type.TURN_LEFT

			return NO_COMMAND

	_patrol_steps_taken += 1
	if _patrol_steps_taken >= patrol_length:
		_patrol_steps_taken = 0
		_patrol_direction *= -1

	if _patrol_direction > 0:
		return GridCommand.Type.STEP_FORWARD

	return GridCommand.Type.STEP_BACK


func _proximity_check(enemy, player) -> int:
	if _triggered:
		return NO_COMMAND
	if enemy == null or player == null:
		return NO_COMMAND
	if enemy.grid_state == null or player.grid_state == null:
		return NO_COMMAND

	var delta: Vector2i = player.grid_state.cell - enemy.grid_state.cell
	var manhattan := absi(delta.x) + absi(delta.y)
	if manhattan <= 1:
		_triggered = true
		return GridCommand.Type.PASS_TURN # Signal detonation
	return NO_COMMAND


func is_triggered() -> bool:
	return _triggered
