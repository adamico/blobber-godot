class_name WorldTurnManager
extends Node
## Sequential turn manager: player acts → resolve → enemies act → resolve → check state.
## Replaces the overlay-based CombatRoundManager.

signal turn_completed
signal clean_status_changed(cleared: int, total: int)
signal player_died
signal debris_consumed_as_weapon(cell: Vector2i)
signal action_feedback(text: String, is_positive: bool)

const HAZARD_GROUP := &"hazards"

var _player: Player
var _encounter_module: WorldEncounterModule
var _grid_module: WorldGridModule
var _world_root: Node

const DEBRIS_ITEM := preload("res://resources/items/debris_base.tres")

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


func process_player_move(_new_state: GridState) -> void:
	## Called after player successfully moved/turned on the grid.
	if _player != null and _player.grid_state != null:
		_check_contact_damage_from_tile(_player.grid_state.cell)
	_tick_enemies()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_slot_use(slot_index: int) -> void:
	## Called when player presses 1/2/3 to use a belt item.
	if _player == null or _player.inventory == null:
		return

	var item = _player.inventory.get_item_at(slot_index) as ItemData
	if item == null:
		return

	if item.item_type == ItemData.ItemType.CONSUMABLE:
		_player.inventory.use_item(slot_index, _player.stats)
	else:
		_use_tool_on_facing(item, slot_index)

	_tick_enemies()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_wall_bump() -> void:
	## Pass turn when player bumps a wall or stationary hazard.
	if _player != null and _player.stats != null:
		var facing_vec := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
		var target_cell := _player.grid_state.cell + facing_vec
		var hazards = _get_hazards_at(target_cell)

		if hazards.size() > 0:
			for h in hazards:
				h.deal_contact_damage(_player.stats)

	_tick_enemies()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_player_pickup() -> void:
	## Manual pickup action (costs one turn).
	if _player == null or _player.grid_state == null:
		return
	var facing_vec := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
	var target_cell := _player.grid_state.cell + facing_vec
	var picked_any := false

	if _world_root != null:
		for node in _world_root.get_tree().get_nodes_in_group(&"world_pickups"):
			if node is WorldPickup and node.grid_cell == target_cell:
				# Use existing collection logic but manually triggered
				if _player.add_item(node.item_data):
					node.collected.emit(node.item_data)
					node.queue_free()
					picked_any = true
					break

	if picked_any:
		_tick_enemies()
		_check_contact_damage_from_enemies()
		_post_turn_checks()
		turn_completed.emit()


func process_player_drop(slot_index: int) -> void:
	## Drop item from inventory (free action).
	if _player == null or _player.inventory == null or _player.grid_state == null:
		return

	var item: ItemData = _player.inventory.get_item_at(slot_index)
	if item == null:
		return

	var facing_vec := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
	var target_cell := _player.grid_state.cell + facing_vec

	# Logic: Can only drop into empty/passable tiles (not walls)
	if _grid_module != null and _grid_module.occupancy() != null:
		if not _grid_module.occupancy().is_passable(target_cell):
			return

	if _player.inventory.remove_at(slot_index):
		spawn_pickup(target_cell, item)
		# Free action: no turn tick, but emit completion for UI sync
		turn_completed.emit()


func spawn_pickup(cell: Vector2i, item: ItemData) -> void:
	if _world_root == null:
		return

	var p := WorldPickup.new()
	p.grid_cell = cell
	p.item_data = item
	p.name = "Pickup_%s_%d_%d" % [item.item_name.replace(" ", "_"), cell.x, cell.y]

	# Add visual representation (placeholder until art pass)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	mesh.mesh = box
	mesh.position.y = 0.15

	var mat := StandardMaterial3D.new()
	if item.item_type == ItemData.ItemType.DEBRIS:
		mat.albedo_color = Color.GRAY
	else:
		mat.albedo_color = Color.YELLOW
	mesh.set_surface_override_material(0, mat)

	var lbl := Label3D.new()
	lbl.text = item.item_name
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.005
	lbl.position = Vector3(0, 0.4, 0)
	p.add_child(lbl)
	p.add_child(mesh)

	_world_root.add_child(p)


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
	var debris_consumed := false

	for cell in cells_to_check:
		for hazard in _get_hazards_at(cell):
			if hazard.is_cleared():
				continue

			# Special logic for Debris as a weapon
			if item.item_type == ItemData.ItemType.DEBRIS:
				if hazard.hazard_class == RpsSystem.HazardClass.CORROSIVE:
					# Instantly clear corrosive hazard
					hazard.receive_tool_hit(RpsSystem.ToolClass.INERT, _player.stats)
					debris_consumed_as_weapon.emit(cell)
					action_feedback.emit("DEBRIS WEAPON!", true)
					debris_consumed = true
					hit_any = true
					break
				else:
					# Debris does nothing to other hazards
					continue

			# Normal tool logic
			var is_effective := RpsSystem.is_effective(item.tool_class, hazard.hazard_class)
			var cleared = hazard.receive_tool_hit(item.tool_class, _player.stats) as bool
			hit_any = true

			if is_effective:
				action_feedback.emit("EFFECTIVE!", true)
			else:
				action_feedback.emit("HIT!", false)

			if cleared:
				break

	if (hit_any and not item.is_reusable) or debris_consumed:
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
	if _player != null and _player.stats != null:
		if _player.stats.health <= 0:
			player_died.emit()


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


func _on_hazard_cleared(hazard: Hazard) -> void:
	_cleared_hazards += 1
	clean_status_changed.emit(_cleared_hazards, _total_hazards)

	# Spawn debris on cleared hazard cell
	if hazard != null and hazard.grid_state != null:
		spawn_pickup(hazard.grid_state.cell, DEBRIS_ITEM)
