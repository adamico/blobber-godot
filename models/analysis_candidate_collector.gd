class_name AnalysisCandidateCollector
extends RefCounted

const ANALYSIS_TARGET_DATA_SCRIPT := "res://models/analysis_target_data.gd"

const ANALYSIS_KIND_DEFINITION_PATHS := [
	"res://resources/analysis/kinds/hostile.tres",
	"res://resources/analysis/kinds/pickup.tres",
	"res://resources/analysis/kinds/chute.tres",
	"res://resources/analysis/kinds/exit.tres",
]

const HOVER_RAY_HIT_RADIUS := 0.45
const MAX_ANALYSIS_DISTANCE_CELLS := 2
const DEFAULT_HOVER_HEIGHT_SAMPLES: Array[float] = [0.1, 0.3, 0.5]
const DEFAULT_INDICATOR_HEIGHT := 0.5
const DEFAULT_INDICATOR_SIZE := Vector2(0.35, 0.35)
const DEFAULT_INDICATOR_ALPHA := 0.24
const DEFAULT_INDICATOR_DEPTH_RATIO := 1.5

var _player: Player
var _world_root: Node
var _kind_definitions: Array[AnalysisCandidateKindDefinition] = []
var _kind_definitions_by_kind: Dictionary = {}
var _resource_cache: Dictionary = {}


func configure(player: Player, world_root: Node) -> void:
	_player = player
	_world_root = world_root
	_ensure_kind_definitions_loaded()


func collect_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if _world_root == null or _player == null or _player.grid_state == null:
		return candidates

	_ensure_kind_definitions_loaded()
	for def in _kind_definitions:
		for node in _world_root.get_tree().get_nodes_in_group(def.group_name):
			if not _passes_kind_requirements(node, def):
				continue
			var cell_value: Variant = resolve_path(node, def.cell_path)
			if not (cell_value is Vector2i):
				continue
			var cell := cell_value as Vector2i
			if not _is_node_visible_for_analysis(node, cell):
				continue
			candidates.append(_build_candidate_from_kind(def, node, cell))

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
	_ensure_kind_definitions_loaded()
	var def := _kind_definitions_by_kind.get("pickup", null) as AnalysisCandidateKindDefinition
	if def == null:
		return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict({})
	return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(
		_build_candidate_from_kind(def, null, Vector2i.ZERO, item),
	)


func build_chute_target_data(chute = null):
	_ensure_kind_definitions_loaded()
	var def := _kind_definitions_by_kind.get("chute", null) as AnalysisCandidateKindDefinition
	if def == null:
		return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict({})
	var cell: Vector2i = Vector2i.ZERO if chute == null else chute.grid_cell
	return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(_build_candidate_from_kind(def, chute, cell))


func build_exit_target_data(exit_node: WorldExit = null):
	_ensure_kind_definitions_loaded()
	var def := _kind_definitions_by_kind.get("exit", null) as AnalysisCandidateKindDefinition
	if def == null:
		return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict({})
	var cell := Vector2i.ZERO if exit_node == null else exit_node.grid_cell
	return load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(
		_build_candidate_from_kind(def, exit_node, cell)
	)


func candidate_hover_heights(candidate: Dictionary) -> Array[float]:
	if candidate.has("hover_heights"):
		var override_heights := _to_float_array(candidate.get("hover_heights"))
		if not override_heights.is_empty():
			return override_heights

	var profile := _targeting_profile_for_candidate(candidate)
	if profile != null and not profile.hover_heights.is_empty():
		return _to_float_array(profile.hover_heights)
	return DEFAULT_HOVER_HEIGHT_SAMPLES.duplicate()


func indicator_height_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_height"):
		return float(candidate.get("indicator_height", DEFAULT_INDICATOR_HEIGHT))
	var profile := _targeting_profile_for_candidate(candidate)
	if profile != null:
		return profile.indicator_height
	return DEFAULT_INDICATOR_HEIGHT


func indicator_size_for_candidate(candidate: Dictionary) -> Vector2:
	if candidate.has("indicator_size"):
		return _to_vector2(candidate.get("indicator_size"), DEFAULT_INDICATOR_SIZE)
	var profile := _targeting_profile_for_candidate(candidate)
	if profile != null:
		return profile.indicator_size
	return DEFAULT_INDICATOR_SIZE


func indicator_alpha_for_candidate(candidate: Dictionary) -> float:
	if candidate.has("indicator_alpha"):
		return clampf(float(candidate.get("indicator_alpha", DEFAULT_INDICATOR_ALPHA)), 0.05, 1.0)
	var profile := _targeting_profile_for_candidate(candidate)
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
	var profile := _targeting_profile_for_candidate(candidate)
	if profile != null:
		return clampf(profile.indicator_depth_ratio, 0.01, 1.0)
	return DEFAULT_INDICATOR_DEPTH_RATIO


func _build_candidate_from_kind(
		def: AnalysisCandidateKindDefinition,
		node,
		cell: Vector2i,
		item_override: ItemData = null,
) -> Dictionary:
	var item := item_override
	if item == null and def.item_path != "":
		var resolved_item: Variant = resolve_path(node, def.item_path)
		if resolved_item is ItemData:
			item = resolved_item

	var summary := _resolve_summary(def, node, item)
	return {
		"key": _resolve_key(def, node, item),
		"kind": def.kind,
		"display_name": _resolve_display_name(def, node, item),
		"summary_basic": summary.get("basic", ""),
		"summary_partial": summary.get("partial", ""),
		"summary_weakness": summary.get("weakness", ""),
		"cell": cell,
		"distance": _manhattan_to_player(cell),
		"facing_score": _facing_score(cell),
		"node": node,
	}


func _resolve_summary(
		def: AnalysisCandidateKindDefinition,
		node,
		item: ItemData,
) -> Dictionary:
	var resolver := _load_summary_resolver(def)
	if resolver != null:
		var resolved := resolver.resolve(self, def, node, item)
		if resolved is Dictionary:
			return resolved
	return {
		"basic": "",
		"partial": "",
		"weakness": "",
	}


func _resolve_key(def: AnalysisCandidateKindDefinition, node, item: ItemData) -> String:
	match def.key_mode:
		"literal":
			return def.key_literal
		"definition_id_or_instance":
			var definition_id := StringName(resolve_path(node, def.definition_id_path))
			if definition_id != StringName():
				return "%s%s" % [def.key_prefix, String(definition_id)]
			return str(node.get_instance_id()) if node != null else "unknown"
		"pickup_item":
			return "%s%s" % [def.key_prefix, _pickup_type_key(item)]
		"path_prefixed":
			var raw := String(resolve_path(node, def.key_path)).strip_edges()
			return "%s%s" % [def.key_prefix, raw]
		"instance_id":
			return str(node.get_instance_id()) if node != null else "unknown"
		_:
			return str(node.get_instance_id()) if node != null else "unknown"


func _resolve_display_name(def: AnalysisCandidateKindDefinition, node, item: ItemData) -> String:
	match def.display_name_mode:
		"constant":
			return def.display_name_default
		"hostile_definition_or_default":
			if node != null:
				return _hostile_display_name(node)
			return def.display_name_default
		"item_name_or_default":
			if item != null and String(item.item_name) != "":
				return item.item_name
			return def.display_name_default
		"path_or_default":
			var raw := String(resolve_path(node, def.display_name_path)).strip_edges()
			return raw if raw != "" else def.display_name_default
		_:
			return def.display_name_default


func _targeting_profile_for_candidate(candidate: Dictionary) -> AnalysisTargetingProfile:
	_ensure_kind_definitions_loaded()
	var kind := String(candidate.get("kind", ""))
	var def := _kind_definitions_by_kind.get(kind, null) as AnalysisCandidateKindDefinition
	if def == null or def.targeting_profile_path == "":
		return null
	var profile := _load_resource(def.targeting_profile_path)
	if profile is AnalysisTargetingProfile:
		return profile
	return null


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


func _passes_kind_requirements(node, def: AnalysisCandidateKindDefinition) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not _matches_required_class(node, def.required_class_name):
		return false

	for method_name in def.required_methods:
		if not node.has_method(method_name):
			return false

	for path in def.required_non_null_paths:
		if resolve_path(node, String(path)) == null:
			return false

	if def.skip_if_method_true != StringName() and node.has_method(def.skip_if_method_true):
		if bool(node.call(def.skip_if_method_true)):
			return false

	return true


func _matches_required_class(node, required_class: String) -> bool:
	if required_class == "":
		return true
	if node.is_class(required_class):
		return true
	var script: Variant = node.get_script()
	if script != null and script.has_method("get_global_name"):
		return String(script.call("get_global_name")) == required_class
	return false


func resolve_path(root: Variant, path: String) -> Variant:
	if root == null:
		return null
	if path == "":
		return root

	var current: Variant = root
	for segment in path.split("."):
		if current == null:
			return null
		if current is Dictionary:
			current = (current as Dictionary).get(segment)
			continue
		if current is Object:
			var obj := current as Object
			if obj.has_method(segment):
				current = obj.call(segment)
				continue
			if _object_has_property(obj, segment):
				current = obj.get(segment)
				continue
			return null
		return null

	return current


func _object_has_property(obj: Object, property_name: String) -> bool:
	for item in obj.get_property_list():
		if String(item.get("name", "")) == property_name:
			return true
	return false


func _ensure_kind_definitions_loaded() -> void:
	if not _kind_definitions.is_empty():
		return

	for path in ANALYSIS_KIND_DEFINITION_PATHS:
		var resource := _load_resource(path)
		if resource is AnalysisCandidateKindDefinition:
			var def := resource as AnalysisCandidateKindDefinition
			_kind_definitions.append(def)
			_kind_definitions_by_kind[def.kind] = def


func _load_resource(path: String) -> Resource:
	if path == "":
		return null
	if _resource_cache.has(path):
		var cached: Variant = _resource_cache.get(path)
		if cached is Resource:
			return cached
		return null
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	_resource_cache[path] = resource
	if resource is Resource:
		return resource
	return null


func load_entity_profile(path: String) -> AnalysisEntityProfile:
	var profile := _load_resource(path)
	if profile is AnalysisEntityProfile:
		return profile
	return AnalysisEntityProfile.new()


func _load_summary_resolver(def: AnalysisCandidateKindDefinition) -> AnalysisSummaryResolver:
	if def == null or def.summary_resolver_path == "":
		return null
	var resolver := _load_resource(def.summary_resolver_path)
	if resolver is AnalysisSummaryResolver:
		return resolver
	return null


func weakness_tool_for_hostile_node(node) -> RpsSystem.ToolProperty:
	if node == null:
		return RpsSystem.ToolProperty.OTHER
	var hostile_property := node.hostile_property as RpsSystem.HostileProperty
	var definition = _get_hostile_definition(node)
	if definition != null:
		hostile_property = definition.hostile_property
	return RpsSystem.effective_tool_for_hostile(hostile_property)


func profile_field(
		primary: Resource,
		fallback: AnalysisEntityProfile,
		field: StringName,
		default_value: String,
) -> String:
	if primary is AnalysisEntityProfile:
		var value := String(primary.get(field)).strip_edges()
		if value != "":
			return value
	if fallback != null:
		var fallback_value := String(fallback.get(field)).strip_edges()
		if fallback_value != "":
			return fallback_value
	return default_value.strip_edges()


func non_empty_or(value: String, fallback: String) -> String:
	var trimmed := value.strip_edges()
	return trimmed if trimmed != "" else fallback


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


func first_non_empty_line(text: String) -> String:
	if text.strip_edges().is_empty():
		return ""
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	return ""


func _is_node_visible_for_analysis(node: Node, cell: Vector2i) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if (
		_player != null
		and _player.grid_state != null
		and _manhattan_to_player(cell) > MAX_ANALYSIS_DISTANCE_CELLS
	):
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
