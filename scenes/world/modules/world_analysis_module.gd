class_name WorldAnalysisModule
extends Node

signal analysis_target_changed(target: Dictionary)
signal analysis_result_ready(result: Dictionary)
signal analysis_knowledge_updated(key: StringName, snapshot: Dictionary, unlock_flag: StringName)

const AnalysisCandidateCollectorModel = preload("res://models/analysis_candidate_collector.gd")
const AnalysisKnowledgeStateModel = preload("res://models/analysis_knowledge_state.gd")
const AnalysisResultBuilderModel = preload("res://models/analysis_result_builder.gd")
const AnalysisSelectionPresenterModel = preload("res://models/analysis_selection_presenter.gd")
const ANALYSIS_TARGET_DATA_SCRIPT := "res://models/analysis_target_data.gd"

const HOSTILE_GROUP := &"grid_hostiles"
const DISPOSAL_CHUTE_GROUP := &"disposal_chutes"
const ANALYSIS_CHUTE_KEY := &"chute:disposal"
const ANALYSIS_EXIT_KEY := &"exit:world"
const KNOWLEDGE_TIER_1 := AnalysisKnowledgeStateModel.KNOWLEDGE_TIER_1
const KNOWLEDGE_TIER_2 := AnalysisKnowledgeStateModel.KNOWLEDGE_TIER_2
const KNOWLEDGE_TIER_3 := AnalysisKnowledgeStateModel.KNOWLEDGE_TIER_3
const HOVER_SELECTION_RADIUS_PX := 100.0
const DEBUG_HOVER_SELECTION := true
const INDICATOR_HEIGHT := AnalysisSelectionPresenterModel.INDICATOR_HEIGHT

var _player: Player
var _world_root: Node
var _analysis_candidates: Array[Dictionary] = []
var _analysis_selected_index: int = -1
var _analysis_selected_key: StringName = StringName()
var _knowledge_state = null
var _result_builder = AnalysisResultBuilderModel.new()
var _candidate_collector = AnalysisCandidateCollectorModel.new()
var _selection_presenter = AnalysisSelectionPresenterModel.new()


func configure(player: Player, world_root: Node) -> void:
	_player = player
	_world_root = world_root
	_ensure_knowledge_state()
	_candidate_collector.configure(player, world_root)
	_selection_presenter.configure(player, world_root)


func cycle_target(direction: int) -> Dictionary:
	if _player == null or _player.grid_state == null:
		return { "ok": false, "reason": "UNAVAILABLE" }

	_refresh_analysis_candidates()
	if _analysis_candidates.is_empty():
		_analysis_selected_index = -1
		_analysis_selected_key = StringName()
		_selection_presenter.clear_selection()
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
	var target_data = _candidate_collector.build_target_data(selected)

	var new_information := _unlock_analysis_tier_for_target(selected, target_data)
	var payload: Dictionary = target_data.to_dict()
	var result: Dictionary = _build_analysis_result_from_target(target_data).to_dict()

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
		_deselect_hover_target()
		return false

	var ray_pick: Dictionary = _candidate_collector.pick_hover_candidate_by_ray(
		_analysis_candidates,
		mouse_position,
		camera,
	)
	if ray_pick.is_empty():
		_deselect_hover_target()
		return false

	var best_index := int(ray_pick.get("index", -1))

	if best_index < 0:
		_deselect_hover_target()
		return false

	var best_key := StringName(_analysis_candidates[best_index].get("key", ""))
	if best_key == _analysis_selected_key and best_key != StringName():
		return false

	_analysis_selected_index = best_index
	_emit_selected_analysis_target("hover")
	return true


func _deselect_hover_target() -> void:
	if _analysis_selected_index < 0 and _analysis_selected_key == StringName():
		return
	_analysis_selected_index = -1
	_analysis_selected_key = StringName()
	_selection_presenter.clear_selection()
	analysis_target_changed.emit({ })


func register_hostile_tool_interaction(hostile, is_effective: bool, cleared: bool) -> void:
	if hostile == null:
		return
	var key := StringName(_candidate_collector.hostile_type_key(hostile))
	_unlock_knowledge(key, KNOWLEDGE_TIER_1)
	if not cleared:
		return
	if is_effective:
		_unlock_knowledge(key, KNOWLEDGE_TIER_3)
	else:
		_unlock_knowledge(key, KNOWLEDGE_TIER_2)


func register_disposal(item: ItemData) -> void:
	if item == null or item.item_type != ItemData.ItemType.DEBRIS:
		return
	_unlock_next_available_tier(_candidate_collector.build_pickup_target_data_from_item(item))
	_unlock_next_available_tier(_candidate_collector.build_chute_target_data())


func get_knowledge_snapshot(key: StringName) -> Dictionary:
	return _get_knowledge_snapshot(key)


func build_analysis_result(payload: Dictionary) -> Dictionary:
	var target_data = load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(payload)
	return _build_analysis_result_from_target(target_data).to_dict()


func _refresh_analysis_candidates() -> void:
	var previous_key := _analysis_selected_key
	_analysis_candidates = _candidate_collector.collect_candidates()

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


func _emit_selected_analysis_target(
		source: String,
		indicator_height: float = INDICATOR_HEIGHT,
) -> Dictionary:
	if _analysis_selected_index < 0 or _analysis_selected_index >= _analysis_candidates.size():
		_selection_presenter.clear_selection()
		analysis_target_changed.emit({ })
		return { }

	var candidate := _analysis_candidates[_analysis_selected_index]
	var payload: Dictionary = _candidate_collector.strip_payload(candidate)
	payload["source"] = source
	_analysis_selected_key = StringName(payload.get("key", ""))
	_selection_presenter.present_candidate(
		candidate,
		source,
		indicator_height,
		_candidate_collector.indicator_height_for_candidate(candidate),
		_candidate_collector.indicator_depth_ratio_for_candidate(candidate),
		_candidate_collector.indicator_size_for_candidate(candidate),
		_candidate_collector.indicator_alpha_for_candidate(candidate),
	)
	analysis_target_changed.emit(payload)
	return payload


func _build_analysis_result(payload: Dictionary) -> Dictionary:
	var target_data = load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(payload)
	return _build_analysis_result_from_target(target_data).to_dict()


func _build_analysis_result_from_target(target_data):
	var key := StringName(target_data.key)
	var knowledge := _get_knowledge_snapshot(key)
	return _result_builder.build(target_data, knowledge)


func _ensure_knowledge_state() -> void:
	if _knowledge_state != null:
		return
	_knowledge_state = AnalysisKnowledgeStateModel.new()
	if not _knowledge_state.knowledge_updated.is_connected(_on_knowledge_state_updated):
		_knowledge_state.knowledge_updated.connect(_on_knowledge_state_updated)


func _unlock_knowledge(key: StringName, unlock_flag: StringName) -> bool:
	_ensure_knowledge_state()
	if _knowledge_state == null:
		return false
	return _knowledge_state.unlock(key, unlock_flag)


func _get_knowledge_snapshot(key: StringName) -> Dictionary:
	_ensure_knowledge_state()
	if _knowledge_state == null:
		return {
			KNOWLEDGE_TIER_1: false,
			KNOWLEDGE_TIER_2: false,
			KNOWLEDGE_TIER_3: false,
		}
	return _knowledge_state.snapshot(key)


func _unlock_analysis_tier_for_target(selected: Dictionary, target_data) -> bool:
	if String(selected.get("kind", "")) == "hostile":
		return _unlock_knowledge(StringName(target_data.key), KNOWLEDGE_TIER_1)
	return _unlock_next_available_tier(target_data)


func _unlock_next_available_tier(target_data) -> bool:
	if target_data == null:
		return false
	var key := StringName(target_data.key)
	if key == StringName():
		return false

	var knowledge := _get_knowledge_snapshot(key)
	for tier in _available_tiers_for_target(target_data):
		if not bool(knowledge.get(tier, false)):
			return _unlock_knowledge(key, tier)
	return false


func _available_tiers_for_target(target_data) -> Array[StringName]:
	var tiers: Array[StringName] = [KNOWLEDGE_TIER_1]
	if String(target_data.summary_partial).strip_edges() != "":
		tiers.append(KNOWLEDGE_TIER_2)
	if String(target_data.summary_weakness).strip_edges() != "":
		tiers.append(KNOWLEDGE_TIER_3)
	return tiers


func _on_knowledge_state_updated(
		key: StringName,
		snapshot: Dictionary,
		unlock_flag: StringName,
) -> void:
	analysis_knowledge_updated.emit(key, snapshot, unlock_flag)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_selection_presenter.cleanup()
