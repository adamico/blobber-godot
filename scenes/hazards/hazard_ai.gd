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
var _patrol_direction: int = 1  ## 1 = forward, -1 = backward
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

	_patrol_steps_taken += 1
	if _patrol_steps_taken >= patrol_length:
		_patrol_steps_taken = 0
		_patrol_direction *= -1

	if _patrol_direction > 0:
		return GridCommand.Type.STEP_FORWARD
	else:
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
		return GridCommand.Type.PASS_TURN  # Signal detonation
	return NO_COMMAND


func is_triggered() -> bool:
	return _triggered
