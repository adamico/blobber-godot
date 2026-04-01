class_name WorldAnalysisModule
extends Node

signal analysis_target_changed(target: Dictionary)
signal analysis_result_ready(result: Dictionary)
signal analysis_knowledge_updated(key: StringName, snapshot: Dictionary, unlock_flag: StringName)

const HOSTILE_GROUP := &"grid_enemies"
const DISPOSAL_CHUTE_GROUP := &"disposal_chutes"

const ANALYSIS_CHUTE_KEY := &"chute:disposal"
const ANALYSIS_EXIT_KEY := &"exit:world"
const KNOWLEDGE_BASIC := &"basic_known"
const KNOWLEDGE_PARTIAL := &"partial_clue_known"
const KNOWLEDGE_WEAKNESS := &"weakness_known"
const KNOWLEDGE_DISPOSAL := &"disposal_known"
const HOVER_SELECTION_RADIUS_PX := 72.0

var _player: Player
var _world_root: Node
var _analysis_candidates: Array[Dictionary] = []
var _analysis_selected_index: int = -1
var _analysis_selected_key: StringName = StringName()
var _analysis_knowledge_by_key: Dictionary = { }


func configure(player: Player, world_root: Node) -> void:
	_player = player
	_world_root = world_root


func cycle_target(direction: int) -> Dictionary:
	if _player == null or _player.grid_state == null:
		return { "ok": false, "reason": "UNAVAILABLE" }

	_refresh_analysis_candidates()
	if _analysis_candidates.is_empty():
		_analysis_selected_index = -1
		_analysis_selected_key = StringName()
		analysis_target_changed.emit({ })
		return { "ok": false, "reason": "NO_TARGETS" }

	var step := -1 if direction < 0 else 1
	if _analysis_selected_index < 0:
		_analysis_selected_index = 0 if step > 0 else _analysis_candidates.size() - 1
	else:
		_analysis_selected_index = wrapi(
			_analysis_selected_index + step,
			0,
			_analysis_candidates.size(),
		)

	var payload := _emit_selected_analysis_target("cycle")
	return { "ok": true, "target": payload }


func analyze_target() -> Dictionary:
	if _player == null or _player.grid_state == null:
		return { "ok": false, "reason": "UNAVAILABLE" }

	_refresh_analysis_candidates()
	if _analysis_candidates.is_empty():
		return { "ok": false, "reason": "NOTHING_TO_ANALYZE" }

	if _analysis_selected_index < 0 or _analysis_selected_index >= _analysis_candidates.size():
		_analysis_selected_index = 0

	var selected := _analysis_candidates[_analysis_selected_index]
	_analysis_selected_key = StringName(selected.get("key", ""))
	_unlock_knowledge(_analysis_selected_key, KNOWLEDGE_BASIC)

	var payload := _strip_analysis_payload(selected)
	var result := _build_analysis_result(payload)

	analysis_target_changed.emit(payload)
	analysis_result_ready.emit(result)
	return { "ok": true, "payload": payload, "result": result }


func hover_target(mouse_position: Vector2, camera: Camera3D) -> bool:
	if camera == null:
		return false

	_refresh_analysis_candidates()
	if _analysis_candidates.is_empty():
		return false

	var best_index := -1
	var best_distance := INF

	for i in range(_analysis_candidates.size()):
		var cell: Vector2i = _analysis_candidates[i].get("cell", Vector2i.ZERO)
		var world_pos := GridMapper.cell_to_world(cell, 1.0, 0.1)
		if camera.is_position_behind(world_pos):
			continue

		var screen_pos := camera.unproject_position(world_pos)
		var distance := mouse_position.distance_to(screen_pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i

	if best_index < 0 or best_distance > HOVER_SELECTION_RADIUS_PX:
		return false

	if _analysis_selected_index == best_index:
		return false

	_analysis_selected_index = best_index
	_emit_selected_analysis_target("hover")
	return true


func register_hazard_tool_interaction(hostile, is_effective: bool, cleared: bool) -> void:
	if hostile == null:
		return
	var key := StringName(_hostile_type_key(hostile))
	_unlock_knowledge(key, KNOWLEDGE_BASIC)
	if not cleared:
		return
	if is_effective:
		_unlock_knowledge(key, KNOWLEDGE_WEAKNESS)
	else:
		_unlock_knowledge(key, KNOWLEDGE_PARTIAL)


func register_disposal(item: ItemData) -> void:
	if item == null or item.item_type != ItemData.ItemType.DEBRIS:
		return
	_unlock_knowledge(ANALYSIS_CHUTE_KEY, KNOWLEDGE_DISPOSAL)
	if item.origin_hostile_definition_id != StringName():
		_unlock_knowledge(
			StringName("hostile:%s" % [String(item.origin_hostile_definition_id)]),
			KNOWLEDGE_DISPOSAL,
		)


func unlock_knowledge_for_test(key: StringName, unlock_flag: StringName) -> void:
	_unlock_knowledge(key, unlock_flag)


func get_knowledge_snapshot_for_test(key: StringName) -> Dictionary:
	return _get_knowledge_snapshot(key)


func build_analysis_result_for_test(payload: Dictionary) -> Dictionary:
	return _build_analysis_result(payload)


func _refresh_analysis_candidates() -> void:
	var previous_key := _analysis_selected_key
	_analysis_candidates = _collect_analysis_candidates()

	if _analysis_candidates.is_empty():
		_analysis_selected_index = -1
		_analysis_selected_key = StringName()
		return

	if previous_key != StringName():
		for i in range(_analysis_candidates.size()):
			if StringName(_analysis_candidates[i].get("key", "")) == previous_key:
				_analysis_selected_index = i
				_analysis_selected_key = previous_key
				return

	if _analysis_selected_index < 0 or _analysis_selected_index >= _analysis_candidates.size():
		_analysis_selected_index = 0
	_analysis_selected_key = StringName(
		_analysis_candidates[_analysis_selected_index].get("key", ""),
	)


func _collect_analysis_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if _world_root == null or _player == null or _player.grid_state == null:
		return candidates

	for node in _world_root.get_tree().get_nodes_in_group(HOSTILE_GROUP):
		if not _is_hostile_node(node):
			continue
		if node.is_cleared() or node.grid_state == null:
			continue
		if not _is_node_visible_for_analysis(node, node.grid_state.cell):
			continue
		candidates.append(_build_hostile_candidate(node))

	for node in _world_root.get_tree().get_nodes_in_group(&"world_pickups"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is WorldPickup):
			continue
		if not _is_node_visible_for_analysis(node, node.grid_cell):
			continue
		if node.item_data != null:
			candidates.append(_build_pickup_candidate(node))

	for node in _world_root.get_tree().get_nodes_in_group(DISPOSAL_CHUTE_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if not (node.has_method("matches_cell") and "grid_cell" in node):
			continue
		if not _is_node_visible_for_analysis(node, node.grid_cell):
			continue
		candidates.append(_build_chute_candidate(node))

	for node in _world_root.get_tree().get_nodes_in_group(&"world_exit_cells"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is WorldExit):
			continue
		if not _is_node_visible_for_analysis(node, node.grid_cell):
			continue
		candidates.append(_build_exit_candidate(node))

	candidates.sort_custom(_analysis_candidate_less)
	return candidates


func _build_hostile_candidate(hostile) -> Dictionary:
	var cell: Vector2i = hostile.grid_state.cell
	var definition = _get_hostile_definition(hostile)
	var hazard_property := hostile.hazard_property as RpsSystem.HazardProperty
	if definition != null:
		hazard_property = definition.hazard_property
	var weakness_tool := RpsSystem.effective_tool_for_hazard(hazard_property)
	var weakness_text := "Unknown"
	if weakness_tool != RpsSystem.ToolProperty.OTHER:
		weakness_text = _humanize_tool_property(weakness_tool)

	return {
		"key": _hostile_type_key(hostile),
		"kind": "hostile",
		"display_name": _hostile_display_name(hostile),
		"summary_basic": "Unknown threat profile.",
		"summary_partial": "It can be cleared with pressure, but some tools underperform.",
		"summary_weakness": "Most effective counter: %s." % [weakness_text],
		"summary_disposal": "Clearing this threat creates debris that can be disposed for cleanup.",
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
	}


func _build_pickup_candidate(pickup: WorldPickup) -> Dictionary:
	var item := pickup.item_data
	var summary := _first_non_empty_line(item.description)
	if summary.is_empty():
		summary = "Recoverable field object."
	return {
		"key": "pickup:%s" % [_pickup_type_key(item)],
		"kind": "pickup",
		"display_name": item.item_name,
		"summary_basic": summary,
		"summary_disposal": "Some recovered debris can be routed into a disposal chute.",
		"cell": pickup.grid_cell,
		"distance": _manhattan_to_player(pickup.grid_cell),
		"facing_score": _facing_score(pickup.grid_cell),
	}


func _build_chute_candidate(chute) -> Dictionary:
	var cell: Vector2i = chute.grid_cell
	return {
		"key": String(ANALYSIS_CHUTE_KEY),
		"kind": "chute",
		"display_name": "Disposal Chute",
		"summary_basic": "Accepts debris for cleanup credit.",
		"summary_disposal": "Depositing debris here improves floor cleanup score.",
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
	}


func _build_exit_candidate(exit_node: WorldExit) -> Dictionary:
	var summary := "Extraction point."
	if exit_node.requires_cleared_floor:
		summary = "Extraction point gated by floor conditions."
	return {
		"key": String(ANALYSIS_EXIT_KEY),
		"kind": "exit",
		"display_name": "World Exit",
		"summary_basic": summary,
		"cell": exit_node.grid_cell,
		"distance": _manhattan_to_player(exit_node.grid_cell),
		"facing_score": _facing_score(exit_node.grid_cell),
	}


func _analysis_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var ad := int(a.get("distance", 0))
	var bd := int(b.get("distance", 0))
	if ad != bd:
		return ad < bd

	var af := int(a.get("facing_score", 1))
	var bf := int(b.get("facing_score", 1))
	if af != bf:
		return af < bf

	return String(a.get("key", "")) < String(b.get("key", ""))


func _emit_selected_analysis_target(source: String) -> Dictionary:
	if _analysis_selected_index < 0 or _analysis_selected_index >= _analysis_candidates.size():
		analysis_target_changed.emit({ })
		return { }

	var payload := _strip_analysis_payload(_analysis_candidates[_analysis_selected_index])
	payload["source"] = source
	_analysis_selected_key = StringName(payload.get("key", ""))
	analysis_target_changed.emit(payload)
	return payload


func _strip_analysis_payload(candidate: Dictionary) -> Dictionary:
	return {
		"key": String(candidate.get("key", "")),
		"kind": String(candidate.get("kind", "")),
		"display_name": String(candidate.get("display_name", "")),
		"summary_basic": String(candidate.get("summary_basic", "")),
		"summary_partial": String(candidate.get("summary_partial", "")),
		"summary_weakness": String(candidate.get("summary_weakness", "")),
		"summary_disposal": String(candidate.get("summary_disposal", "")),
		"cell": candidate.get("cell", Vector2i.ZERO),
		"distance": int(candidate.get("distance", 0)),
	}


func _build_analysis_result(payload: Dictionary) -> Dictionary:
	var key := StringName(payload.get("key", ""))
	var knowledge := _get_knowledge_snapshot(key)
	var summary := "No reliable field notes yet."

	if bool(knowledge.get(KNOWLEDGE_BASIC, false)):
		summary = String(payload.get("summary_basic", "No details available."))

	var details: Array[String] = []
	if bool(knowledge.get(KNOWLEDGE_PARTIAL, false)):
		details.append(String(payload.get("summary_partial", "")))
	if bool(knowledge.get(KNOWLEDGE_WEAKNESS, false)):
		details.append(String(payload.get("summary_weakness", "")))
	if bool(knowledge.get(KNOWLEDGE_DISPOSAL, false)):
		details.append(String(payload.get("summary_disposal", "")))

	var full_summary := "%s: %s" % [
		String(payload.get("display_name", "Target")),
		summary,
	]
	if not details.is_empty():
		full_summary += "\n" + "\n".join(details)

	var result := payload.duplicate(true)
	result["summary"] = full_summary
	result["knowledge"] = knowledge
	return result


func _hostile_display_name(hostile) -> String:
	var definition = _get_hostile_definition(hostile)
	if definition != null and String(definition.display_name) != "":
		return definition.display_name
	return "Hostile"


func _hostile_type_key(hostile) -> String:
	if hostile == null:
		return "unknown"
	if "hostile_definition_id" in hostile and hostile.hostile_definition_id != StringName():
		return "hostile:%s" % [String(hostile.hostile_definition_id)]
	return str(hostile.get_instance_id())


func _pickup_type_key(item: ItemData) -> String:
	if item == null:
		return "unknown"
	if item.resource_path != "":
		return item.resource_path
	if item.item_name != "":
		return item.item_name
	return "item_%d" % [item.get_instance_id()]


func _manhattan_to_player(cell: Vector2i) -> int:
	if _player == null or _player.grid_state == null:
		return 0
	var delta := cell - _player.grid_state.cell
	return absi(delta.x) + absi(delta.y)


func _facing_score(cell: Vector2i) -> int:
	if _player == null or _player.grid_state == null:
		return 1

	var to_target := cell - _player.grid_state.cell
	if to_target == Vector2i.ZERO:
		return 0

	var facing := GridDefinitions.facing_to_vec2i(_player.grid_state.facing)
	var facing_dot := (facing.x * to_target.x) + (facing.y * to_target.y)
	return 0 if facing_dot > 0 else 1


func _first_non_empty_line(text: String) -> String:
	if text.strip_edges().is_empty():
		return ""
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	return ""


func _humanize_tool_property(tool_property: int) -> String:
	match tool_property:
		RpsSystem.ToolProperty.SOAKED:
			return "Soaked"
		RpsSystem.ToolProperty.INERT:
			return "Inert"
		RpsSystem.ToolProperty.CLEANSED:
			return "Cleansed"
		_:
			return "Other"


func _ensure_knowledge_entry(key: StringName) -> Dictionary:
	if key == StringName():
		return { }
	if _analysis_knowledge_by_key.has(key):
		return _analysis_knowledge_by_key[key]

	var entry := {
		KNOWLEDGE_BASIC: false,
		KNOWLEDGE_PARTIAL: false,
		KNOWLEDGE_WEAKNESS: false,
		KNOWLEDGE_DISPOSAL: false,
	}
	_analysis_knowledge_by_key[key] = entry
	return entry


func _unlock_knowledge(key: StringName, unlock_flag: StringName) -> void:
	if key == StringName() or unlock_flag == StringName():
		return
	var entry := _ensure_knowledge_entry(key)
	if entry.is_empty():
		return

	if bool(entry.get(unlock_flag, false)):
		return

	entry[unlock_flag] = true
	_analysis_knowledge_by_key[key] = entry
	analysis_knowledge_updated.emit(key, entry.duplicate(true), unlock_flag)


func _get_knowledge_snapshot(key: StringName) -> Dictionary:
	if key == StringName():
		return {
			KNOWLEDGE_BASIC: false,
			KNOWLEDGE_PARTIAL: false,
			KNOWLEDGE_WEAKNESS: false,
			KNOWLEDGE_DISPOSAL: false,
		}
	var entry := _ensure_knowledge_entry(key)
	if entry.is_empty():
		return {
			KNOWLEDGE_BASIC: false,
			KNOWLEDGE_PARTIAL: false,
			KNOWLEDGE_WEAKNESS: false,
			KNOWLEDGE_DISPOSAL: false,
		}
	return entry.duplicate(true)


func _get_hostile_definition(hostile):
	if _world_root == null or hostile == null:
		return null
	if "hostile_definition_id" in hostile and hostile.hostile_definition_id != StringName():
		if _world_root.has_method("_get_hostile_definition_by_id"):
			return _world_root.call("_get_hostile_definition_by_id", hostile.hostile_definition_id)
	return null


func _is_hostile_node(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method("is_cleared"):
		return false
	if not node.has_method("deal_contact_damage"):
		return false
	if node.get("hazard_property") == null:
		return false
	return true


func _is_node_visible_for_analysis(node: Node, cell: Vector2i) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return false

	if not _is_cell_visible_to_player_camera(cell):
		return false

	var occupancy := _resolve_grid_occupancy()
	if occupancy == null or _player == null or _player.grid_state == null:
		return true

	return occupancy.is_line_of_sight_clear(_player.grid_state.cell, cell)


func _is_cell_visible_to_player_camera(cell: Vector2i) -> bool:
	var camera := _player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return true

	var world_pos := GridMapper.cell_to_world(cell, 1.0, 0.1)
	if camera.is_position_behind(world_pos):
		return false

	return camera.is_position_in_frustum(world_pos)


func _resolve_grid_occupancy() -> GridOccupancyMap:
	if _world_root == null:
		return null

	if _world_root.has_method("get_grid_occupancy"):
		return _world_root.call("get_grid_occupancy") as GridOccupancyMap

	var grid_module = _world_root.get("_grid_module")
	if grid_module != null and grid_module.has_method("occupancy"):
		return grid_module.call("occupancy") as GridOccupancyMap

	return null
