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

const _FALLBACK_PROFILE_PATHS := {
	"hostile": "res://resources/analysis/defaults/hostile_fallback.tres",
	"pickup": "res://resources/analysis/defaults/pickup_fallback.tres",
	"chute": "res://resources/analysis/features/disposal_chute_analysis.tres",
	"exit": "res://resources/analysis/features/world_exit_analysis.tres",
}

const _TARGETING_PROFILE_PATHS := {
	"hostile": "res://resources/analysis/targeting/hostile.tres",
	"pickup": "res://resources/analysis/targeting/pickup.tres",
	"chute": "res://resources/analysis/targeting/chute.tres",
	"exit": "res://resources/analysis/targeting/exit.tres",
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


func pickup_key(item: ItemData) -> StringName:
	return StringName("pickup:%s" % [_pickup_type_key(item)])


func build_pickup_target_data_from_item(item: ItemData):
	return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(
		_build_pickup_payload(item, Vector2i.ZERO, null),
	)


func build_chute_target_data(chute = null):
	return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(_build_chute_candidate(chute))


func build_exit_target_data(exit_node: WorldExit = null):
	return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(_build_exit_candidate(exit_node))


func candidate_hover_heights(candidate: Dictionary) -> Array[float]:
	if candidate.has("hover_heights"):
		var override_heights := _to_float_array(candidate.get("hover_heights"))
		if not override_heights.is_empty():
			return override_heights

	var kind := String(candidate.get("kind", ""))
	var profile := _load_targeting_profile(kind)
	if profile != null and not profile.hover_heights.is_empty():
		return _to_float_array(profile.hover_heights)
	return DEFAULT_HOVER_HEIGHT_SAMPLES.duplicate()


func indicator_height_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_height"):
		return float(candidate.get("indicator_height", DEFAULT_INDICATOR_HEIGHT))
	var profile := _load_targeting_profile(String(candidate.get("kind", "")))
	if profile != null:
		return profile.indicator_height
	return DEFAULT_INDICATOR_HEIGHT


func indicator_size_for_candidate(candidate: Dictionary) -> Vector2:
	if candidate.has("indicator_size"):
		return _to_vector2(candidate.get("indicator_size"), DEFAULT_INDICATOR_SIZE)
	var profile := _load_targeting_profile(String(candidate.get("kind", "")))
	if profile != null:
		return profile.indicator_size
	return DEFAULT_INDICATOR_SIZE


func indicator_alpha_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_alpha"):
		return clampf(float(candidate.get("indicator_alpha", DEFAULT_INDICATOR_ALPHA)), 0.05, 1.0)
	var profile := _load_targeting_profile(String(candidate.get("kind", "")))
	if profile != null:
		return clampf(profile.indicator_alpha, 0.05, 1.0)
	return DEFAULT_INDICATOR_ALPHA


func indicator_depth_ratio_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_depth_ratio"):
		return clampf(
			float(candidate.get("indicator_depth_ratio", DEFAULT_INDICATOR_DEPTH_RATIO)),
			0.01,
			1.0,
		)
	var profile := _load_targeting_profile(String(candidate.get("kind", "")))
	if profile != null:
		return clampf(profile.indicator_depth_ratio, 0.01, 1.0)
	return DEFAULT_INDICATOR_DEPTH_RATIO


func _build_hostile_candidate(hostile) -> Dictionary:
	var cell: Vector2i = hostile.grid_state.cell
	var definition = _get_hostile_definition(hostile)
	var hostile_property := hostile.hostile_property as RpsSystem.HostileProperty
	if definition != null:
		hostile_property = definition.hostile_property
	var weakness_tool := RpsSystem.effective_tool_for_hostile(hostile_property)
	var weakness_text := RpsSystem.humanize_tool_property(weakness_tool)

	var attached: Resource = definition.analysis_profile if definition != null else null
	var fallback := _load_fallback_profile("hostile")
	var summary_basic := _profile_field(attached, fallback, &"summary_basic")
	var summary_partial := _profile_field(attached, fallback, &"summary_partial")
	var summary_weakness := _profile_field(attached, fallback, &"summary_weakness")
	summary_weakness = summary_weakness.replace("{weakness_tool}", weakness_text)

	return {
		"key": _hostile_type_key(hostile),
		"kind": "hostile",
		"display_name": _hostile_display_name(hostile),
		"summary_basic": summary_basic,
		"summary_partial": summary_partial,
		"summary_weakness": summary_weakness,
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
		"node": hostile,
	}


func _non_empty_or(value: String, fallback: String) -> String:
	var trimmed := value.strip_edges()
	return trimmed if trimmed != "" else fallback


func _build_pickup_candidate(pickup: WorldPickup) -> Dictionary:
	return _build_pickup_payload(pickup.item_data, pickup.grid_cell, pickup)


func _build_pickup_payload(item: ItemData, cell: Vector2i, node) -> Dictionary:
	var fallback := _load_fallback_profile("pickup")
	var basic_summary := _first_non_empty_line(item.description)
	if basic_summary.is_empty():
		basic_summary = fallback.summary_basic

	var partial_summary := ""
	var full_desc := item.description.strip_edges()
	if item.tool_property != RpsSystem.ToolProperty.OTHER:
		var prop := RpsSystem.humanize_tool_property(item.tool_property)
		partial_summary = "Property: %s" % prop
		if not full_desc.is_empty():
			partial_summary += "\n" + full_desc
	else:
		partial_summary = full_desc

	var weakness_summary := ""
	if item.analysis_profile is AnalysisEntityProfile:
		var profile := item.analysis_profile as AnalysisEntityProfile
		basic_summary = _non_empty_or(profile.summary_basic, basic_summary)
		partial_summary = _non_empty_or(profile.summary_partial, partial_summary)
		weakness_summary = _non_empty_or(profile.summary_weakness, weakness_summary)

	return {
		"key": "pickup:%s" % [_pickup_type_key(item)],
		"kind": "pickup",
		"display_name": item.item_name,
		"summary_basic": basic_summary,
		"summary_partial": partial_summary,
		"summary_weakness": weakness_summary,
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
		"node": node,
	}


func _build_chute_candidate(chute) -> Dictionary:
	var cell: Vector2i = Vector2i.ZERO if chute == null else chute.grid_cell
	var attached: Resource = chute.analysis_profile if chute != null else null
	var fallback := _load_fallback_profile("chute")
	return {
		"key": String(ANALYSIS_CHUTE_KEY),
		"kind": "chute",
		"display_name": "Disposal Chute",
		"summary_basic": _profile_field(attached, fallback, &"summary_basic"),
		"summary_partial": _profile_field(attached, fallback, &"summary_partial"),
		"summary_weakness": _profile_field(attached, fallback, &"summary_weakness"),
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
		"node": chute,
	}


func _build_exit_candidate(exit_node: WorldExit) -> Dictionary:
	var cell := Vector2i.ZERO if exit_node == null else exit_node.grid_cell
	var attached: Resource = exit_node.analysis_profile if exit_node != null else null
	var fallback := _load_fallback_profile("exit")
	var summary_basic := _profile_field(attached, fallback, &"summary_basic")
	if exit_node != null and exit_node.requires_cleared_floor and attached == null:
		summary_basic = "Extraction point gated by floor conditions."
	return {
		"key": String(ANALYSIS_EXIT_KEY),
		"kind": "exit",
		"display_name": "World Exit",
		"summary_basic": summary_basic,
		"summary_partial": _profile_field(attached, fallback, &"summary_partial"),
		"summary_weakness": _profile_field(attached, fallback, &"summary_weakness"),
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
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


func _load_fallback_profile(kind: String) -> AnalysisEntityProfile:
	var path: String = _FALLBACK_PROFILE_PATHS.get(kind, "")
	if path != "" and ResourceLoader.exists(path):
		var res := load(path)
		if res is AnalysisEntityProfile:
			return res
	return AnalysisEntityProfile.new()


func _load_targeting_profile(kind: String) -> AnalysisTargetingProfile:
	var path: String = _TARGETING_PROFILE_PATHS.get(kind, "")
	if path != "" and ResourceLoader.exists(path):
		var res := load(path)
		if res is AnalysisTargetingProfile:
			return res
	return null


func _profile_field(
		primary: Resource,
		fallback: AnalysisEntityProfile,
		field: StringName,
) -> String:
	if primary is AnalysisEntityProfile:
		var value := String(primary.get(field)).strip_edges()
		if value != "":
			return value
	if fallback != null:
		return String(fallback.get(field)).strip_edges()
	return ""


func _to_float_array(value: Variant) -> Array[float]:
	var out: Array[float] = []
	if value is PackedFloat32Array:
		for item in value:
			out.append(item)
		return out
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
