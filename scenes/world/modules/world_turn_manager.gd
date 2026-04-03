class_name WorldTurnManager
extends Node
## Sequential turn manager: player acts → resolve → enemies act → resolve → check state.

signal turn_completed
signal clean_status_changed(cleared: int, total: int)
signal player_died
signal debris_consumed_as_weapon(cell: Vector2i)
signal action_feedback(text: String, is_positive: bool)
signal analysis_target_changed(target: Dictionary)
signal analysis_result_ready(result: Dictionary)
signal analysis_knowledge_updated(key: StringName, snapshot: Dictionary, unlock_flag: StringName)

const HOSTILE_GROUP := &"grid_hostiles"
const DISPOSAL_CHUTE_GROUP := &"disposal_chutes"
const WORLD_PICKUP_SCENE := preload("res://scenes/world/world_pickup.tscn")

var _player: Player
var _encounter_module: WorldEncounterModule
var _grid_module: WorldGridModule
var _world_root: Node
var _analysis_module: WorldAnalysisModule

const DEBRIS_ITEM := preload("res://resources/items/debris_base.tres")

var _total_cleanup_value: int = 0
var _disposed_cleanup_value: int = 0

const ANALYSIS_CHUTE_KEY := &"chute:disposal"
const ANALYSIS_EXIT_KEY := &"exit:world"
const KNOWLEDGE_BASIC := &"basic_known"
const KNOWLEDGE_PARTIAL := &"partial_clue_known"
const KNOWLEDGE_WEAKNESS := &"weakness_known"
const KNOWLEDGE_DISPOSAL := &"disposal_known"
const HOVER_SELECTION_RADIUS_PX := 72.0


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
	_ensure_analysis_module()


func initialize_floor() -> void:
	_disposed_cleanup_value = 0
	_total_cleanup_value = _count_cleanup_value()
	_connect_hostile_signals()
	clean_status_changed.emit(_disposed_cleanup_value, _total_cleanup_value)


func process_player_move(_new_state: GridState) -> void:
	## Called after player successfully moved/turned on the grid.
	if _player != null and _player.grid_state != null:
		_check_contact_damage_from_tile(_player.grid_state.cell)
	_tick_hostiles()
	_tick_debris_revert()
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

	_tick_hostiles()
	_tick_debris_revert()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_wall_bump() -> void:
	## Pass turn when player bumps a wall or stationary hostile.
	if _player != null and _player.stats != null:
		var facing_vec := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
		var target_cell := _player.grid_state.cell + facing_vec
		var hostiles = _get_hostiles_at(target_cell)

		if hostiles.size() > 0:
			for h in hostiles:
				h.deal_contact_damage(_player.stats)

	_tick_hostiles()
	_tick_debris_revert()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_player_pickup() -> void:
	## Manual pickup action (costs one turn).
	if _player == null or _player.grid_state == null:
		return
	var facing_vec := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
	var current_tile := _player.grid_state.cell
	var target_cell := current_tile + facing_vec
	var picked_any := false

	if _world_root != null:
		var pickups = _world_root.get_tree().get_nodes_in_group(&"world_pickups")

		# Priority 1: Current tile
		for node in pickups:
			if node is WorldPickup and node.grid_cell == current_tile:
				if _player.add_item(node.item_data):
					node.collected.emit(node.item_data)
					node.queue_free()
					picked_any = true
					break

		# Priority 2: Facing tile
		if not picked_any:
			for node in pickups:
				if node is WorldPickup and node.grid_cell == target_cell:
					if _player.add_item(node.item_data):
						node.collected.emit(node.item_data)
						node.queue_free()
						picked_any = true
						break

	if picked_any:
		# TODO: unify with a single turn-advance method that can be called from all actions
		_tick_hostiles()
		_tick_debris_revert()
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

	# If facing a disposal chute, route eligible debris into it instead of floor-dropping.
	var chute = _get_disposal_chute_at(target_cell)
	if chute != null:
		if not chute.accepts_item(item):
			action_feedback.emit("CHUTE REJECTED", false)
			turn_completed.emit()
			return
		if _player.inventory.remove_at(slot_index):
			_register_disposal(item)
			action_feedback.emit("DISPOSED", true)
			turn_completed.emit()
		return

	# Logic: Can only drop into empty/passable tiles (not walls)
	if _grid_module != null and _grid_module.occupancy() != null:
		if not _grid_module.occupancy().is_passable(target_cell):
			return

	if _player.inventory.remove_at(slot_index):
		var p = spawn_pickup(target_cell, item)
		if p != null and item.origin_hostile_definition_id != StringName():
			p.setup_revert(item.revert_turns_base, item.origin_hostile_definition_id)
		# Free action: no turn tick, but emit completion for UI sync
		turn_completed.emit()


func process_cycle_target(direction: int) -> void:
	_ensure_analysis_module()
	if _analysis_module == null:
		return

	var cycle_result := _analysis_module.cycle_target(direction)
	if not bool(cycle_result.get("ok", false)):
		action_feedback.emit("NO TARGETS", false)


func process_analyze_target() -> void:
	_ensure_analysis_module()
	if _analysis_module == null:
		return

	var analysis_result := _analysis_module.analyze_target()
	if not bool(analysis_result.get("ok", false)):
		action_feedback.emit("NOTHING TO ANALYZE", false)
		return

	var new_information := bool(analysis_result.get("new_information", false))
	if new_information:
		action_feedback.emit("ANALYZED", true)
	else:
		action_feedback.emit("NO NEW INFORMATION", false)
		return

	_tick_hostiles()
	_tick_debris_revert()
	_check_contact_damage_from_enemies()
	_post_turn_checks()
	turn_completed.emit()


func process_hover_target(mouse_position: Vector2, camera: Camera3D) -> void:
	_ensure_analysis_module()
	if _analysis_module == null or camera == null:
		return
	_analysis_module.hover_target(mouse_position, camera)


func spawn_pickup(cell: Vector2i, item: ItemData) -> WorldPickup:
	if _world_root == null:
		return null
	if WORLD_PICKUP_SCENE == null:
		push_error("Missing world pickup scene: res://scenes/world/world_pickup.tscn")
		return null

	var p := WORLD_PICKUP_SCENE.instantiate() as WorldPickup
	if p == null:
		push_error("Failed to instantiate world pickup scene")
		return null
	p.grid_cell = cell
	p.item_data = item
	p.name = "Pickup_%s_%d_%d" % [item.item_name.replace(" ", "_"), cell.x, cell.y]
	var label := p.get_node_or_null("ItemLabel") as Label3D
	if label != null:
		label.text = item.item_name

	var sprite := p.get_node_or_null("Sprite3D") as Sprite3D
	if sprite != null:
		if item.pickup_texture != null:
			sprite.texture = item.pickup_texture
		if item.item_type == ItemData.ItemType.DEBRIS:
			sprite.modulate = Color(0.8, 0.8, 0.8, 1.0)
		else:
			sprite.modulate = Color(1.0, 0.9, 0.3, 1.0)
		var sprite_mat := sprite.material_override as ShaderMaterial
		if sprite_mat != null:
			sprite_mat = sprite_mat.duplicate() as ShaderMaterial
			sprite.material_override = sprite_mat
			sprite_mat.set_shader_parameter("sprite_texture", sprite.texture)

	_world_root.add_child(p)
	return p


func get_clean_cleared() -> int:
	return _disposed_cleanup_value


func get_clean_total() -> int:
	return _total_cleanup_value


func get_clean_percent() -> int:
	if _total_cleanup_value <= 0:
		return 0
	return int(round(float(_disposed_cleanup_value) / float(_total_cleanup_value) * 100.0))


func is_floor_clean() -> bool:
	return _total_cleanup_value > 0 and _disposed_cleanup_value >= _total_cleanup_value


func get_analysis_result_for_target(payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return { }
	return _build_analysis_result(payload)


func get_knowledge_snapshot(key: StringName) -> Dictionary:
	return _get_knowledge_snapshot(key)

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
		for hostile in _get_hostiles_at(cell):
			if hostile.is_cleared():
				continue

			# Special logic for Debris as a weapon
			if item.item_type == ItemData.ItemType.DEBRIS:
				var definition = _get_hostile_definition(hostile)
				var instant_clear := definition != null and bool(definition.instant_clear_on_debris)

				if instant_clear:
					# Instantly clear hostile via definition capability
					hostile.receive_tool_hit(RpsSystem.ToolProperty.INERT, _player.stats)
					debris_consumed_as_weapon.emit(cell)
					action_feedback.emit("DEBRIS WEAPON!", true)
					debris_consumed = true
					hit_any = true
					break
				else:
					# Debris does nothing to other hostiles
					continue

			# Normal tool logic
			var is_effective := RpsSystem.is_effective(item.tool_property, hostile.hostile_property)
			var cleared = hostile.receive_tool_hit(item.tool_property, _player.stats) as bool
			hit_any = true
			_register_hostile_tool_interaction(hostile, is_effective, cleared)

			if is_effective:
				action_feedback.emit("EFFECTIVE!", true)
			else:
				action_feedback.emit("HIT!", false)

			if cleared:
				break

	if (hit_any and not item.is_reusable) or debris_consumed:
		_player.inventory.remove_at(slot_index)


func _get_hostiles_at(cell: Vector2i) -> Array:
	var result: Array = []
	if _world_root == null:
		return result
	for node in _world_root.get_tree().get_nodes_in_group(HOSTILE_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if not _is_hostile_node(node):
			continue
		if node.grid_state != null and node.grid_state.cell == cell and not node.is_cleared():
			result.append(node)
	return result


func _tick_hostiles() -> void:
	if _encounter_module == null or _player == null:
		return
	_encounter_module.collect()
	_encounter_module.tick_step_echo()


func _check_contact_damage_from_tile(player_cell: Vector2i) -> void:
	## Check if player walked onto a stationary hostile.
	for hostile in _get_hostiles_at(player_cell):
		hostile.deal_contact_damage(_player.stats)


func _check_contact_damage_from_enemies() -> void:
	## Check if any enemy is now adjacent and deals contact damage.
	if _player == null or _player.grid_state == null:
		return
	for hostile in _get_all_active_hostiles():
		if hostile.grid_state == null:
			continue

		var ai = hostile.get_node_or_null("HostileAI")
		var is_mobile := false
		if ai != null and "behavior" in ai and ai.behavior != 0: # 0 = STATIONARY
			is_mobile = true

		var delta: Vector2i = hostile.grid_state.cell - _player.grid_state.cell
		var prev_delta: Vector2i = hostile.grid_state.previous_cell - _player.grid_state.cell
		var manhattan := absi(delta.x) + absi(delta.y)
		var prev_manhattan := absi(prev_delta.x) + absi(prev_delta.y)

		if is_mobile and (manhattan <= 1 or prev_manhattan <= 1):
			hostile.deal_contact_damage(_player.stats)


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


func _count_cleanup_value() -> int:
	if _world_root == null:
		return 0
	var total := 0
	for node in _world_root.get_tree().get_nodes_in_group(HOSTILE_GROUP):
		if not _is_hostile_node(node):
			continue
		if not node.is_cleared():
			total += maxi(int(node.cleanup_value), 1)
	return total


func _get_all_active_hostiles() -> Array:
	var result: Array = []
	if _world_root == null:
		return result
	for node in _world_root.get_tree().get_nodes_in_group(HOSTILE_GROUP):
		if _is_hostile_node(node) and not node.is_cleared():
			result.append(node)
	return result


func _connect_hostile_signals() -> void:
	if _world_root == null:
		return
	for node in _world_root.get_tree().get_nodes_in_group(HOSTILE_GROUP):
		if not _is_hostile_node(node):
			continue
		if not node.has_signal("hostile_cleared"):
			continue
		if not node.hostile_cleared.is_connected(_on_hostile_cleared):
			node.hostile_cleared.connect(_on_hostile_cleared)


func _on_hostile_cleared(hostile) -> void:
	if hostile != null and hostile.grid_state != null:
		var dupe := DEBRIS_ITEM.duplicate() as ItemData
		dupe.origin_hostile_definition_id = hostile.hostile_definition_id
		dupe.revert_turns_base = int(hostile.revert_turns_base)
		dupe.cleanup_value = maxi(int(hostile.cleanup_value), 1)
		var p = spawn_pickup(hostile.grid_state.cell, dupe)
		if p != null:
			p.setup_revert(int(hostile.revert_turns_base), hostile.hostile_definition_id)


func _tick_debris_revert() -> void:
	if _world_root == null:
		return
	var pickups = _world_root.get_tree().get_nodes_in_group(&"world_pickups")
	for node in pickups:
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node is WorldPickup and node.revert_turns_remaining > 0:
			if node.tick_revert():
				_respawn_hostile_from_revert(node)
				node.queue_free()


func _respawn_hostile_from_revert(pickup: WorldPickup) -> void:
	if _world_root == null:
		return

	if pickup.origin_hostile_definition_id == StringName():
		push_warning("Revert pickup has no origin hostile definition ID")
		return

	if _world_root.has_method("_spawn_hostile_by_id"):
		_world_root.call(
			"_spawn_hostile_by_id",
			pickup.grid_cell,
			pickup.origin_hostile_definition_id,
		)
		_connect_hostile_signals()


func _get_hostile_definition(hostile: Hostile):
	if _world_root == null or hostile == null:
		return null
	if "hostile_definition_id" in hostile and hostile.hostile_definition_id != StringName():
		if _world_root.has_method("_get_hostile_definition_by_id"):
			return _world_root.call("_get_hostile_definition_by_id", hostile.hostile_definition_id)
	return null


func _get_disposal_chute_at(cell: Vector2i):
	if _world_root == null or _world_root.get_tree() == null:
		return null
	for node in _world_root.get_tree().get_nodes_in_group(DISPOSAL_CHUTE_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("matches_cell") and bool(node.call("matches_cell", cell)):
			return node
	return null


func _register_disposal(item: ItemData) -> void:
	if item == null or item.item_type != ItemData.ItemType.DEBRIS:
		return
	_ensure_analysis_module()
	if _analysis_module != null:
		_analysis_module.register_disposal(item)
	_disposed_cleanup_value = mini(
		_disposed_cleanup_value + maxi(item.cleanup_value, 1),
		_total_cleanup_value,
	)
	clean_status_changed.emit(_disposed_cleanup_value, _total_cleanup_value)


func _register_hostile_tool_interaction(hostile, is_effective: bool, cleared: bool) -> void:
	_ensure_analysis_module()
	if _analysis_module != null:
		_analysis_module.register_hostile_tool_interaction(hostile, is_effective, cleared)


func _ensure_analysis_module() -> void:
	if _analysis_module == null:
		_analysis_module = get_node_or_null("AnalysisModule") as WorldAnalysisModule
	if _analysis_module == null:
		_analysis_module = WorldAnalysisModule.new()
		_analysis_module.name = "AnalysisModule"
		add_child(_analysis_module)

	_analysis_module.configure(_player, _world_root)

	if not _analysis_module.analysis_target_changed.is_connected(_on_analysis_target_changed):
		_analysis_module.analysis_target_changed.connect(_on_analysis_target_changed)
	if not _analysis_module.analysis_result_ready.is_connected(_on_analysis_result_ready):
		_analysis_module.analysis_result_ready.connect(_on_analysis_result_ready)
	if not _analysis_module.analysis_knowledge_updated.is_connected(_on_analysis_knowledge_updated):
		_analysis_module.analysis_knowledge_updated.connect(_on_analysis_knowledge_updated)


func _unlock_knowledge(key: StringName, unlock_flag: StringName) -> void:
	_ensure_analysis_module()
	if _analysis_module == null:
		return
	_analysis_module.unlock_knowledge_for_test(key, unlock_flag)


func _get_knowledge_snapshot(key: StringName) -> Dictionary:
	_ensure_analysis_module()
	if _analysis_module == null:
		return {
			KNOWLEDGE_BASIC: false,
			KNOWLEDGE_PARTIAL: false,
			KNOWLEDGE_WEAKNESS: false,
			KNOWLEDGE_DISPOSAL: false,
		}
	return _analysis_module.get_knowledge_snapshot_for_test(key)


func _build_analysis_result(payload: Dictionary) -> Dictionary:
	_ensure_analysis_module()
	if _analysis_module == null:
		return payload.duplicate(true)
	return _analysis_module.build_analysis_result_for_test(payload)


func _on_analysis_target_changed(target: Dictionary) -> void:
	analysis_target_changed.emit(target)


func _on_analysis_result_ready(result: Dictionary) -> void:
	analysis_result_ready.emit(result)


func _on_analysis_knowledge_updated(
		key: StringName,
		snapshot: Dictionary,
		unlock_flag: StringName,
) -> void:
	analysis_knowledge_updated.emit(key, snapshot, unlock_flag)


func _is_hostile_node(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method("is_cleared"):
		return false
	if not node.has_method("deal_contact_damage"):
		return false
	if node.get("hostile_property") == null:
		return false
	return true
