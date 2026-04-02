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
const HOVER_SELECTION_RADIUS_PX := 100.0
const HOVER_RAY_HIT_RADIUS := 0.45
const DEBUG_HOVER_SELECTION := true

const DEFAULT_HOVER_HEIGHT_SAMPLES: Array[float] = [0.1, 0.3, 0.5]
const DEFAULT_INDICATOR_HEIGHT := 0.5
const DEFAULT_INDICATOR_SIZE := Vector2(0.35, 0.35)
const DEFAULT_INDICATOR_ALPHA := 0.24
const DEFAULT_INDICATOR_DEPTH_RATIO := 1.5
const TARGETING_PROFILE_BY_KIND := {
	"pickup": {
		"hover_heights": [0.3, 0.3, 0.3],
		"indicator_height": 0.3,
		"indicator_size": Vector2(0.24, 0.24),
		"indicator_alpha": 0.20,
		"indicator_depth_ratio": DEFAULT_INDICATOR_DEPTH_RATIO,
	},
	"hostile": {
		"hover_heights": [0.1, 0.3, 0.5, 0.75],
		"indicator_height": 0.5,
		"indicator_size": Vector2(0.38, 0.38),
		"indicator_alpha": 0.22,
		"indicator_depth_ratio": DEFAULT_INDICATOR_DEPTH_RATIO,
	},
	"chute": {
		"hover_heights": [0.2, 0.5, 0.3],
		"indicator_height": 0.15,
		"indicator_size": Vector2(0.5, 0.6),
		"indicator_alpha": 0.18,
		"indicator_depth_ratio": DEFAULT_INDICATOR_DEPTH_RATIO,
	},
	"exit": {
		"hover_heights": [0.02, 0.1, 0.2],
		"indicator_height": 0.1,
		"indicator_size": Vector2(0.6, 0.6),
		"indicator_alpha": 0.16,
		"indicator_depth_ratio": DEFAULT_INDICATOR_DEPTH_RATIO,
	},
}

const INDICATOR_HEIGHT := 0.9

var _player: Player
var _world_root: Node
var _analysis_candidates: Array[Dictionary] = []
var _analysis_selected_index: int = -1
var _analysis_selected_key: StringName = StringName()
var _analysis_knowledge_by_key: Dictionary = { }
var _target_indicator: MeshInstance3D
var _target_indicator_mesh: QuadMesh
var _target_indicator_material: StandardMaterial3D
var _current_outlined_node: Variant = null
var _outlined_sprite_material: ShaderMaterial = null
var _outlined_mesh_instance: MeshInstance3D = null
var _outlined_mesh_previous_overlay: Material = null
var _mesh_outline_material: StandardMaterial3D = null


func configure(player: Player, world_root: Node) -> void:
	_player = player
	_world_root = world_root
	_create_target_indicator()


func cycle_target(direction: int) -> Dictionary:
	if _player == null or _player.grid_state == null:
		return { "ok": false, "reason": "UNAVAILABLE" }

	_refresh_analysis_candidates()
	if _analysis_candidates.is_empty():
		_analysis_selected_index = -1
		_analysis_selected_key = StringName()
		_hide_target_indicator()
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

	var new_information := false
	if selected.get("kind", "") == "pickup":
		var snapshot := _get_knowledge_snapshot(_analysis_selected_key)
		if not bool(snapshot.get(KNOWLEDGE_BASIC, false)):
			new_information = _unlock_knowledge(_analysis_selected_key, KNOWLEDGE_BASIC)
		else:
			new_information = _unlock_knowledge(_analysis_selected_key, KNOWLEDGE_PARTIAL)
	else:
		new_information = _unlock_knowledge(_analysis_selected_key, KNOWLEDGE_BASIC)

	var payload := _strip_analysis_payload(selected)
	var result := _build_analysis_result(payload)

	analysis_target_changed.emit(payload)
	analysis_result_ready.emit(result)
	return {
		"ok": true,
		"payload": payload,
		"result": result,
		"new_information": new_information,
	}


func hover_target(mouse_position: Vector2, camera: Camera3D) -> bool:
	if camera == null:
		return false

	_refresh_analysis_candidates()
	if _analysis_candidates.is_empty():
		_debug_hover("no candidates; clearing hover selection")
		_deselect_hover_target()
		return false

	var ray_pick := _pick_hover_candidate_by_ray(mouse_position, camera)
	if ray_pick.is_empty():
		_debug_hover("no hover target near ray")
		_deselect_hover_target()
		return false

	var best_index := int(ray_pick.get("index", -1))
	var best_distance := float(ray_pick.get("distance", INF))

	if best_index < 0:
		_deselect_hover_target()
		return false

	var best_key := StringName(_analysis_candidates[best_index].get("key", ""))
	if best_key == _analysis_selected_key and best_key != StringName():
		return false

	_analysis_selected_index = best_index
	_debug_hover(
		"hover selected key=%s ray_distance=%.3f index=%d" % [
			String(best_key),
			best_distance,
			best_index,
		],
	)
	_emit_selected_analysis_target("hover")
	return true


func _deselect_hover_target() -> void:
	if _analysis_selected_index < 0 and _analysis_selected_key == StringName():
		return
	_debug_hover("hover deselected")
	_analysis_selected_index = -1
	_analysis_selected_key = StringName()
	_hide_target_indicator()
	_remove_analysis_outline()
	analysis_target_changed.emit({ })


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

	# Keep hover/cycle/analyze behavior explicit: do not auto-select index 0 during refresh.
	_analysis_selected_index = -1
	_analysis_selected_key = StringName()


func _debug_hover(message: String) -> void:
	if not DEBUG_HOVER_SELECTION:
		return
	print("[AnalysisHover] %s" % [message])


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
		"node": hostile,
	}


func _build_pickup_candidate(pickup: WorldPickup) -> Dictionary:
	var item := pickup.item_data
	var basic_summary := _first_non_empty_line(item.description)
	if basic_summary.is_empty():
		basic_summary = "Recoverable field object."

	var partial_summary := ""
	var full_desc := item.description.strip_edges()
	if item.tool_property != RpsSystem.ToolProperty.OTHER:
		var prop := _humanize_tool_property(item.tool_property)
		partial_summary = "Property: %s" % prop
		if not full_desc.is_empty():
			partial_summary += "\n" + full_desc
	else:
		partial_summary = full_desc

	return {
		"key": "pickup:%s" % [_pickup_type_key(item)],
		"kind": "pickup",
		"display_name": item.item_name,
		"summary_basic": basic_summary,
		"summary_partial": partial_summary,
		"summary_disposal": "Some recovered debris can be routed into a disposal chute.",
		"cell": pickup.grid_cell,
		"distance": _manhattan_to_player(pickup.grid_cell),
		"facing_score": _facing_score(pickup.grid_cell),
		"node": pickup,
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
		"node": chute,
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
		"node": exit_node,
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


func _emit_selected_analysis_target(
		source: String,
		indicator_height: float = INDICATOR_HEIGHT,
) -> Dictionary:
	if _analysis_selected_index < 0 or _analysis_selected_index >= _analysis_candidates.size():
		_hide_target_indicator()
		analysis_target_changed.emit({ })
		return { }

	var candidate := _analysis_candidates[_analysis_selected_index]
	var payload := _strip_analysis_payload(candidate)
	payload["source"] = source
	_analysis_selected_key = StringName(payload.get("key", ""))
	_hide_target_indicator()
	_apply_analysis_outline(candidate.get("node"))
	if _current_outlined_node == null:
		_apply_indicator_visual_for_candidate(candidate)
		var anchor_height := _indicator_height_for_candidate(candidate)
		var depth_ratio := _indicator_depth_ratio_for_candidate(candidate)
		if source != "hover":
			anchor_height = indicator_height
		_show_target_indicator(
			payload.get("cell", Vector2i.ZERO),
			anchor_height,
			depth_ratio,
		)
	analysis_target_changed.emit(payload)
	return payload


func _pick_hover_candidate_by_ray(mouse_position: Vector2, camera: Camera3D) -> Dictionary:
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_dir := camera.project_ray_normal(mouse_position)
	if ray_dir.length_squared() <= 0.000001:
		return { }

	var best_index := -1
	var best_lateral_distance := INF
	var best_ray_depth := INF

	for i in range(_analysis_candidates.size()):
		var candidate := _analysis_candidates[i]
		var cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
		for sample_height in _candidate_hover_heights(candidate):
			var world_pos := GridMapper.cell_to_world(cell, 1.0, sample_height)
			if camera.is_position_behind(world_pos):
				continue
			var ray_sample := _ray_sample_to_point(world_pos, ray_origin, ray_dir)
			if ray_sample.is_empty():
				continue

			var depth := float(ray_sample.get("depth", INF))
			var lateral_distance := float(ray_sample.get("distance", INF))
			if lateral_distance > HOVER_RAY_HIT_RADIUS:
				continue

			var is_better_depth := depth < best_ray_depth - 0.001
			var is_equal_depth := absf(depth - best_ray_depth) <= 0.001
			var is_better_lateral := lateral_distance < best_lateral_distance
			if is_better_depth or (is_equal_depth and is_better_lateral):
				best_ray_depth = depth
				best_lateral_distance = lateral_distance
				best_index = i

	if best_index < 0:
		return { }

	return {
		"index": best_index,
		"distance": best_lateral_distance,
		"depth": best_ray_depth,
	}


func _candidate_hover_heights(candidate: Dictionary) -> Array[float]:
	if candidate.has("hover_heights"):
		var override_heights := _to_float_array(candidate.get("hover_heights"))
		if not override_heights.is_empty():
			return override_heights

	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	var heights := _to_float_array(profile.get("hover_heights", DEFAULT_HOVER_HEIGHT_SAMPLES))
	if not heights.is_empty():
		return heights
	return DEFAULT_HOVER_HEIGHT_SAMPLES.duplicate()


func _indicator_height_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_height"):
		return float(candidate.get("indicator_height", DEFAULT_INDICATOR_HEIGHT))

	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	return float(profile.get("indicator_height", DEFAULT_INDICATOR_HEIGHT))


func _targeting_profile_for_kind(kind: String) -> Dictionary:
	if TARGETING_PROFILE_BY_KIND.has(kind):
		return TARGETING_PROFILE_BY_KIND[kind]
	return {
		"hover_heights": DEFAULT_HOVER_HEIGHT_SAMPLES,
		"indicator_height": DEFAULT_INDICATOR_HEIGHT,
		"indicator_size": DEFAULT_INDICATOR_SIZE,
		"indicator_alpha": DEFAULT_INDICATOR_ALPHA,
		"indicator_depth_ratio": DEFAULT_INDICATOR_DEPTH_RATIO,
	}


func _indicator_size_for_candidate(candidate: Dictionary) -> Vector2:
	if candidate.has("indicator_size"):
		return _to_vector2(candidate.get("indicator_size"), DEFAULT_INDICATOR_SIZE)
	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	return _to_vector2(
		profile.get("indicator_size", DEFAULT_INDICATOR_SIZE),
		DEFAULT_INDICATOR_SIZE,
	)


func _indicator_alpha_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_alpha"):
		return clampf(float(candidate.get("indicator_alpha", DEFAULT_INDICATOR_ALPHA)), 0.05, 1.0)
	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	return clampf(float(profile.get("indicator_alpha", DEFAULT_INDICATOR_ALPHA)), 0.05, 1.0)


func _indicator_depth_ratio_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_depth_ratio"):
		return clampf(
			float(candidate.get("indicator_depth_ratio", DEFAULT_INDICATOR_DEPTH_RATIO)),
			0.01,
			1.0,
		)
	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	return clampf(
		float(profile.get("indicator_depth_ratio", DEFAULT_INDICATOR_DEPTH_RATIO)),
		0.01,
		1.0,
	)


func _apply_indicator_visual_for_candidate(candidate: Dictionary) -> void:
	if _target_indicator_mesh == null or _target_indicator_material == null:
		return
	_target_indicator_mesh.size = _indicator_size_for_candidate(candidate)
	var color := _target_indicator_material.albedo_color
	color.a = _indicator_alpha_for_candidate(candidate)
	_target_indicator_material.albedo_color = color


func _to_float_array(value: Variant) -> Array[float]:
	var out: Array[float] = []
	if not (value is Array):
		return out
	for item in value:
		out.append(float(item))
	return out


func _to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		var raw := value as Array
		return Vector2(float(raw[0]), float(raw[1]))
	if value is float or value is int:
		var size := float(value)
		return Vector2(size, size)
	return fallback


func _ray_sample_to_point(point: Vector3, ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	var to_point := point - ray_origin
	var t := to_point.dot(ray_dir)
	if t < 0.0:
		return { }
	var closest := ray_origin + (ray_dir * t)
	return {
		"depth": t,
		"distance": point.distance_to(closest),
	}


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


func _unlock_knowledge(key: StringName, unlock_flag: StringName) -> bool:
	if key == StringName() or unlock_flag == StringName():
		return false
	var entry := _ensure_knowledge_entry(key)
	if entry.is_empty():
		return false

	if bool(entry.get(unlock_flag, false)):
		return false

	entry[unlock_flag] = true
	_analysis_knowledge_by_key[key] = entry
	analysis_knowledge_updated.emit(key, entry.duplicate(true), unlock_flag)
	return true


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


func _create_target_indicator() -> void:
	if _target_indicator != null:
		return
	_target_indicator_mesh = QuadMesh.new()
	_target_indicator_mesh.size = DEFAULT_INDICATOR_SIZE
	_target_indicator_material = StandardMaterial3D.new()
	_target_indicator_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_indicator_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_indicator_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_target_indicator_material.albedo_color = Color(0.65, 1.0, 0.59, DEFAULT_INDICATOR_ALPHA)
	_target_indicator_mesh.material = _target_indicator_material
	_target_indicator = MeshInstance3D.new()
	_target_indicator.mesh = _target_indicator_mesh
	_target_indicator.visible = false
	if _world_root != null:
		_world_root.add_child(_target_indicator)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_remove_analysis_outline()
		if _target_indicator != null and is_instance_valid(_target_indicator):
			_target_indicator.queue_free()


func _show_target_indicator(
		cell: Vector2i,
		y: float = INDICATOR_HEIGHT,
		depth_ratio: float = DEFAULT_INDICATOR_DEPTH_RATIO,
) -> void:
	if _target_indicator == null:
		return
	var entity_pos := GridMapper.cell_to_world(cell, 1.0, y)
	var camera := _player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		_target_indicator.global_position = entity_pos
		_target_indicator.visible = true
		return
	# depth_ratio maps within the cell along the camera axis:
	#   0.0 = back edge (far from camera)
	#   0.5 = cell centre (entity position)
	#   1.0 = front edge (toward camera)
	var toward_cam := (camera.global_position - entity_pos)
	toward_cam.y = 0.0
	var cam_len := toward_cam.length()
	if cam_len < 0.001:
		_target_indicator.global_position = entity_pos
		_target_indicator.visible = true
		return
	var cam_dir := toward_cam / cam_len
	var offset := (depth_ratio - 0.5) * 1.0 # ±0.5 cell units
	_target_indicator.global_position = entity_pos + cam_dir * offset
	_target_indicator.visible = true


func _hide_target_indicator() -> void:
	if _target_indicator == null:
		return
	_target_indicator.visible = false


func _ensure_mesh_outline_material() -> void:
	if _mesh_outline_material != null:
		return
	_mesh_outline_material = StandardMaterial3D.new()
	_mesh_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_mesh_outline_material.grow = 0.06
	_mesh_outline_material.albedo_color = Color(0.65, 1.0, 0.59, 1.0)


func _apply_analysis_outline(target: Variant) -> void:
	if target == null or not is_instance_valid(target):
		return
	_remove_analysis_outline()
	var sprite := _find_outline_sprite(target)
	if sprite == null:
		var mesh := _find_outline_mesh(target)
		if mesh == null:
			return
		_ensure_mesh_outline_material()
		_outlined_mesh_previous_overlay = mesh.material_overlay
		mesh.material_overlay = _mesh_outline_material
		_outlined_mesh_instance = mesh
		_current_outlined_node = target
		return
	var mat := sprite.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glowSize", 1.0)
	_outlined_sprite_material = mat
	_current_outlined_node = target


func _remove_analysis_outline() -> void:
	if _current_outlined_node == null:
		return
	if not is_instance_valid(_current_outlined_node):
		_current_outlined_node = null
		_outlined_sprite_material = null
		_outlined_mesh_instance = null
		_outlined_mesh_previous_overlay = null
		return
	if _outlined_sprite_material != null:
		_outlined_sprite_material.set_shader_parameter("glowSize", 0.0)
	if _outlined_mesh_instance != null and is_instance_valid(_outlined_mesh_instance):
		_outlined_mesh_instance.material_overlay = _outlined_mesh_previous_overlay
	_outlined_sprite_material = null
	_outlined_mesh_instance = null
	_outlined_mesh_previous_overlay = null
	_current_outlined_node = null


func _find_outline_sprite(target: Variant) -> Sprite3D:
	if target is Sprite3D:
		return target as Sprite3D
	if not (target is Node):
		return null
	for child in (target as Node).get_children():
		if child is Sprite3D:
			return child as Sprite3D
	return null


func _find_outline_mesh(target: Variant) -> MeshInstance3D:
	if target is MeshInstance3D:
		return target as MeshInstance3D
	if not (target is Node):
		return null
	for child in (target as Node).get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			return child as MeshInstance3D
	return null
