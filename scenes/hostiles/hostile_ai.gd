class_name HostileAI
extends Node

const NO_COMMAND := -1

enum Behavior {
	STATIONARY,
	PATROL,
	CHASE,
	PROXIMITY_TRIGGER,
}

@export var behavior: Behavior = Behavior.CHASE
@export_range(1, 8, 1) var patrol_length: int = 3
## Max tiles away the hostile can spot the player (requires LOS too).
@export_range(1, 20, 1) var view_distance: int = 5


## Turns the hostile can pursue without re-acquiring LOS before giving up the chase.
const CHASE_MEMORY_TURNS := 3

var _grid_module: WorldGridModule
var _world_root: Node
var _last_seen_player_pos: Vector2i = Vector2i(-1, -1)
var _los_lost_turns: int = 0
var _patrol_steps_taken: int = 0
var _patrol_direction: int = 1
var _triggered: bool = false


func set_grid_module(gm, world_root: Node = null) -> void:
	_grid_module = gm
	_world_root = world_root


func choose_command(hostile, player) -> int:
	match behavior:
		Behavior.STATIONARY:
			return NO_COMMAND
		Behavior.PATROL:
			return _patrol_command(hostile)
		Behavior.CHASE:
			return _choose_chase_command(hostile, player)
		Behavior.PROXIMITY_TRIGGER:
			return _proximity_check(hostile, player)
		_:
			return NO_COMMAND


func _choose_chase_command(hostile, player) -> int:
	if hostile == null or player == null:
		return NO_COMMAND
	if hostile.grid_state == null or player.grid_state == null:
		return NO_COMMAND

	var hostile_cell: Vector2i = hostile.grid_state.cell
	var player_cell: Vector2i = player.grid_state.cell

	# Acquire or maintain target only when player is within view_distance AND LOS is clear.
	# Out-of-range counts the same as LOS-blocked — both increment the memory timer.
	if _grid_module != null:
		var occ := _grid_module.occupancy()
		if occ != null:
			var dist := absi(player_cell.x - hostile_cell.x) + absi(player_cell.y - hostile_cell.y)
			var spotted := dist <= view_distance and occ.is_line_of_sight_clear(hostile_cell, player_cell)
			if spotted:
				_last_seen_player_pos = player_cell
				_los_lost_turns = 0
			else:
				_los_lost_turns += 1
				if _los_lost_turns > CHASE_MEMORY_TURNS:
					_last_seen_player_pos = Vector2i(-1, -1)

	# If we have no target, or have reached our last seen breadcrumb, give up.
	if _last_seen_player_pos == Vector2i(-1, -1):
		return NO_COMMAND

	if hostile_cell == _last_seen_player_pos:
		# Reached the breadcrumb — clear memory regardless of whether LOS re-established.
		_last_seen_player_pos = Vector2i(-1, -1)
		_los_lost_turns = 0
		return NO_COMMAND

	# Target the breadcrumb
	var target := _last_seen_player_pos
	var step := _choose_best_step(hostile, target)

	if step == Vector2i.ZERO:
		return NO_COMMAND

	return _step_vector_to_command(hostile.grid_state.facing, step)


func _patrol_command(hostile) -> int:
	if hostile == null or hostile.grid_state == null:
		return NO_COMMAND

	var forward_vec := GridDefinitions.facing_to_vec2i(hostile.grid_state.facing)
	var step_dir := forward_vec * _patrol_direction
	var next_cell: Vector2i = hostile.grid_state.cell + step_dir

	if not _is_cell_passable(next_cell):
		_patrol_direction *= -1
		_patrol_steps_taken = 0
		step_dir = forward_vec * _patrol_direction
		next_cell = hostile.grid_state.cell + step_dir

		if not _is_cell_passable(next_cell):
			_patrol_direction = 1

			var right_facing := GridDefinitions.rotate_right(hostile.grid_state.facing)
			var right_cell: Vector2i = hostile.grid_state.cell
			right_cell += GridDefinitions.facing_to_vec2i(right_facing)
			if _is_cell_passable(right_cell):
				return GridCommand.Type.TURN_RIGHT

			var left_facing := GridDefinitions.rotate_left(hostile.grid_state.facing)
			var left_cell: Vector2i = hostile.grid_state.cell
			left_cell += GridDefinitions.facing_to_vec2i(left_facing)
			if _is_cell_passable(left_cell):
				return GridCommand.Type.TURN_LEFT

			return NO_COMMAND

	_patrol_steps_taken += 1
	if _patrol_steps_taken >= patrol_length:
		_patrol_steps_taken = 0
		_patrol_direction *= -1

	if _patrol_direction > 0:
		return GridCommand.Type.STEP_FORWARD

	return GridCommand.Type.STEP_BACK


func _proximity_check(hostile, player) -> int:
	if _triggered:
		return NO_COMMAND
	if hostile == null or player == null:
		return NO_COMMAND
	if hostile.grid_state == null or player.grid_state == null:
		return NO_COMMAND

	var delta: Vector2i = player.grid_state.cell - hostile.grid_state.cell
	var manhattan := absi(delta.x) + absi(delta.y)
	if manhattan <= 1:
		_triggered = true
		return GridCommand.Type.PASS_TURN
	return NO_COMMAND


func is_triggered() -> bool:
	return _triggered


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

	if _is_cell_passable(_enemy.grid_state.cell + primary_step):
		return primary_step
	if _is_cell_passable(_enemy.grid_state.cell + secondary_step):
		if secondary_step != Vector2i.ZERO:
			return secondary_step

	return Vector2i.ZERO


func _is_cell_passable(cell: Vector2i) -> bool:
	if _grid_module == null:
		return true # Fallback if not wired
	# For AI choice, we check basic grid passability.
	# The move will still be fully validated by MovementController anyway.
	var occ := _grid_module.occupancy()
	if occ != null and not occ.is_passable(cell):
		return false

	if _world_root != null and _world_root.get_tree() != null:
		var pickups = _world_root.get_tree().get_nodes_in_group(&"world_pickups")
		pickups.append_array(_world_root.get_tree().get_nodes_in_group(&"world_chests"))
		for pickup in pickups:
			if pickup != null and is_instance_valid(pickup):
				if pickup.get("grid_cell") == cell and pickup.get("blocks_movement"):
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
