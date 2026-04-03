class_name AnalysisCandidateCollector
extends RefCounted

const ANALYSIS_TARGET_DATA_SCRIPT := "res://models/analysis_target_data.gd"

const HOSTILE_GROUP := &"grid_hostiles"
const DISPOSAL_CHUTE_GROUP := &"disposal_chutes"
const ANALYSIS_CHUTE_KEY := &"chute:disposal"
const ANALYSIS_EXIT_KEY := &"exit:world"

const HOVER_RAY_HIT_RADIUS := 0.45
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

var _player: Player
var _world_root: Node


func configure(player: Player, world_root: Node) -> void:
	_player = player
	_world_root = world_root


func collect_candidates() -> Array[Dictionary]:
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


func pick_hover_candidate_by_ray(
		candidates: Array[Dictionary],
		mouse_position: Vector2,
		camera: Camera3D,
) -> Dictionary:
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_dir := camera.project_ray_normal(mouse_position)
	if ray_dir.length_squared() <= 0.000001:
		return { }

	var best_index := -1
	var best_lateral_distance := INF
	var best_ray_depth := INF

	for i in range(candidates.size()):
		var candidate := candidates[i]
		var cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
		for sample_height in candidate_hover_heights(candidate):
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


func strip_payload(candidate: Dictionary) -> Dictionary:
	return build_target_data(candidate).to_dict()


func build_target_data(candidate: Dictionary):
	return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(candidate)


func hostile_type_key(hostile) -> String:
	return _hostile_type_key(hostile)


func candidate_hover_heights(candidate: Dictionary) -> Array[float]:
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


func indicator_height_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_height"):
		return float(candidate.get("indicator_height", DEFAULT_INDICATOR_HEIGHT))

	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	return float(profile.get("indicator_height", DEFAULT_INDICATOR_HEIGHT))


func indicator_size_for_candidate(candidate: Dictionary) -> Vector2:
	if candidate.has("indicator_size"):
		return _to_vector2(candidate.get("indicator_size"), DEFAULT_INDICATOR_SIZE)
	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	return _to_vector2(
		profile.get("indicator_size", DEFAULT_INDICATOR_SIZE),
		DEFAULT_INDICATOR_SIZE,
	)


func indicator_alpha_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_alpha"):
		return clampf(float(candidate.get("indicator_alpha", DEFAULT_INDICATOR_ALPHA)), 0.05, 1.0)
	var kind := String(candidate.get("kind", ""))
	var profile := _targeting_profile_for_kind(kind)
	return clampf(float(profile.get("indicator_alpha", DEFAULT_INDICATOR_ALPHA)), 0.05, 1.0)


func indicator_depth_ratio_for_candidate(candidate: Dictionary) -> float:
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


func _build_hostile_candidate(hostile) -> Dictionary:
	var cell: Vector2i = hostile.grid_state.cell
	var definition = _get_hostile_definition(hostile)
	var hostile_property := hostile.hostile_property as RpsSystem.HostileProperty
	if definition != null:
		hostile_property = definition.hostile_property
	var weakness_tool := _effective_tool_for_hostile_property(hostile_property)
	var weakness_text := "Unknown"
	if weakness_tool != RpsSystem.ToolProperty.OTHER:
		weakness_text = _humanize_tool_property(weakness_tool)
	var summary_basic := "Unknown threat profile."
	var summary_partial := "It can be cleared with pressure, but some tools underperform."
	var summary_weakness := "Most effective counter: %s." % [weakness_text]
	var summary_disposal := "Clearing this threat creates debris that can be disposed for cleanup."
	if definition != null and definition.analysis_profile != null:
		var profile = definition.analysis_profile
		summary_basic = _definition_or_fallback(
			String(profile.summary_basic),
			summary_basic,
		)
		summary_partial = _definition_or_fallback(
			String(profile.summary_partial),
			summary_partial,
		)
		summary_weakness = _definition_or_fallback(
			String(profile.summary_weakness),
			summary_weakness,
		)
		summary_disposal = _definition_or_fallback(
			String(profile.summary_disposal),
			summary_disposal,
		)
	summary_weakness = summary_weakness.replace("{weakness_tool}", weakness_text)

	return {
		"key": _hostile_type_key(hostile),
		"kind": "hostile",
		"display_name": _hostile_display_name(hostile),
		"summary_basic": summary_basic,
		"summary_partial": summary_partial,
		"summary_weakness": summary_weakness,
		"summary_disposal": summary_disposal,
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
		"node": hostile,
	}


func _definition_or_fallback(value: String, fallback: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed == "":
		return fallback
	return trimmed


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


func _effective_tool_for_hostile_property(
		hostile_property: RpsSystem.HostileProperty,
) -> RpsSystem.ToolProperty:
	for tool_property in RpsSystem.WEAKNESS_TABLE.keys():
		var weaknesses = RpsSystem.WEAKNESS_TABLE.get(tool_property, [])
		if weaknesses.has(hostile_property):
			return tool_property as RpsSystem.ToolProperty
	return RpsSystem.ToolProperty.OTHER


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
	if _player == null:
		return true
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


func _get_hostile_definition(hostile):
	if _world_root == null or hostile == null:
		return null
	if "hostile_definition_id" in hostile and hostile.hostile_definition_id != StringName():
		if _world_root.has_method("_get_hostile_definition_by_id"):
			return _world_root.call("_get_hostile_definition_by_id", hostile.hostile_definition_id)
	return null


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