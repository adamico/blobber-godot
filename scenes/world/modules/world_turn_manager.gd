class_name WorldTurnManager
extends Node
## Sequential turn manager: player acts → resolve → enemies act → resolve → check state.
## Replaces the overlay-based CombatRoundManager.

signal turn_completed
signal clean_status_changed(cleared: int, total: int)
signal player_exhausted
signal player_died

const HAZARD_GROUP := &"hazards"
const WALL_BUMP_STAMINA_COST := 1

var _player: Player
var _encounter_module: WorldEncounterModule
var _grid_module: WorldGridModule
var _world_root: Node

var _total_hazards: int = 0
var _cleared_hazards: int = 0


func configure(
		player: Player,
		encounter_module: WorldEncounterModule,
		grid_module: WorldGridModule,
		world_root: Node,
) -> void:
	_player = player
	_encounter_module = encounter_module
	_grid_module = grid_module
	_world_root = world_root


func initialize_floor() -> void:
	_cleared_hazards = 0
	_total_hazards = _count_hazards()
	_connect_hazard_signals()
	clean_status_changed.emit(_cleared_hazards, _total_hazards)


func process_player_move(new_state: GridState) -> void:
	## Called after player successfully moved/turned on the grid.
	_collect_pickups(new_state.cell)
	_check_contact_damage_from_tile(new_state.cell)
	_tick_enemies()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_slot_use(slot_index: int) -> void:
	## Called when player presses 1/2/3 to use a belt item.
	if _player == null or _player.inventory == null:
		return

	if _player.is_exhausted:
		return # Tools locked while exhausted

	var item = _player.inventory.get_item_at(slot_index) as ItemData
	if item == null:
		return

	if item.item_type == ItemData.ItemType.CONSUMABLE:
		_player.inventory.use_item(slot_index, _player.stats)
		_update_exhausted_state()
	else:
		_use_tool_on_facing(item, slot_index)
		if _player.stats != null:
			_player.stats.take_damage(1)

	_tick_enemies()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_wall_bump() -> void:
	## Called when player bumps a wall or stationary hazard (pass turn).
	if _player != null and _player.stats != null and not _player.is_exhausted:
		var target_cell := _player.grid_state.cell + GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
		var hazards = _get_hazards_at(target_cell)
		
		if hazards.size() > 0:
			for h in hazards:
				h.deal_contact_damage(_player.stats)
		else:
			_player.stats.take_damage(WALL_BUMP_STAMINA_COST)

	_tick_enemies()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func get_clean_cleared() -> int:
	return _cleared_hazards


func get_clean_total() -> int:
	return _total_hazards


func is_floor_clean() -> bool:
	return _total_hazards > 0 and _cleared_hazards >= _total_hazards

# --- Private ---


func _use_tool_on_facing(item: ItemData, slot_index: int) -> void:
	if _player == null or _player.grid_state == null:
		return

	var facing_vec := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
	var target_cell := _player.grid_state.cell + facing_vec

	# Check range 2 items
	var cells_to_check: Array[Vector2i] = [target_cell]
	if item.use_range >= 2:
		cells_to_check.append(target_cell + facing_vec)

	var hit_any := false
	for cell in cells_to_check:
		for hazard in _get_hazards_at(cell):
			if hazard.is_cleared():
				continue
			var cleared = hazard.receive_tool_hit(item.tool_class) as bool
			hit_any = true
			if cleared:
				break

	if hit_any and not item.is_reusable:
		_player.inventory.remove_at(slot_index)


func _get_hazards_at(cell: Vector2i) -> Array:
	var result: Array = []
	if _world_root == null:
		return result
	for node in _world_root.get_tree().get_nodes_in_group(HAZARD_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if node is Hazard and node.grid_state != null and node.grid_state.cell == cell:
			if not node.is_cleared():
				result.append(node)
	return result


func _tick_enemies() -> void:
	if _encounter_module == null or _player == null:
		return
	_encounter_module.collect()
	_encounter_module.tick_step_echo()


func _check_contact_damage_from_tile(player_cell: Vector2i) -> void:
	## Check if player walked onto a stationary hazard.
	for hazard in _get_hazards_at(player_cell):
		hazard.deal_contact_damage(_player.stats)


func _check_contact_damage_from_enemies() -> void:
	## Check if any enemy is now adjacent and deals contact damage.
	if _player == null or _player.grid_state == null:
		return
	for hazard in _get_all_active_hazards():
		if hazard.grid_state == null:
			continue
			
		var ai = hazard.get_node_or_null("EnemyAI")
		var is_mobile := false
		if ai != null and "behavior" in ai and ai.behavior != 0: # 0 = STATIONARY
			is_mobile = true
			
		var delta: Vector2i = hazard.grid_state.cell - _player.grid_state.cell
		var manhattan := absi(delta.x) + absi(delta.y)
		
		if is_mobile and manhattan == 1:
			hazard.deal_contact_damage(_player.stats)


func _post_turn_checks() -> void:
	_update_exhausted_state()

	if _player != null and _player.stats != null:
		if _player.is_exhausted and _player.stats.health <= 0:
			player_died.emit()


func _update_exhausted_state() -> void:
	if _player == null or _player.stats == null:
		return
	var was_exhausted := _player.is_exhausted
	_player.is_exhausted = _player.stats.health <= 0
	if _player.is_exhausted and not was_exhausted:
		player_exhausted.emit()


func _collect_pickups(player_cell: Vector2i) -> void:
	if _world_root == null or _player == null:
		return
	for node in _world_root.get_tree().get_nodes_in_group(&"world_pickups"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("collect_if_player_on_cell"):
			continue
		node.call("collect_if_player_on_cell", _player, player_cell)


func _count_hazards() -> int:
	if _world_root == null:
		return 0
	var count := 0
	for node in _world_root.get_tree().get_nodes_in_group(HAZARD_GROUP):
		if node is Hazard and not node.is_cleared():
			count += 1
	return count


func _get_all_active_hazards() -> Array:
	var result: Array = []
	if _world_root == null:
		return result
	for node in _world_root.get_tree().get_nodes_in_group(HAZARD_GROUP):
		if node is Hazard and not node.is_cleared():
			result.append(node)
	return result


func _connect_hazard_signals() -> void:
	if _world_root == null:
		return
	for node in _world_root.get_tree().get_nodes_in_group(HAZARD_GROUP):
		if node is Hazard and not node.hazard_cleared.is_connected(_on_hazard_cleared):
			node.hazard_cleared.connect(_on_hazard_cleared)


func _on_hazard_cleared(_hazard: Hazard) -> void:
	_cleared_hazards += 1
	clean_status_changed.emit(_cleared_hazards, _total_hazards)
