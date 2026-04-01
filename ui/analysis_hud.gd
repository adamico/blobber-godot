extends Control

@onready var _analysis_name_label: Label = %AnalysisNameLabel
@onready var _analysis_meta_label: Label = %AnalysisMetaLabel
@onready var _analysis_body_label: Label = %AnalysisBodyLabel
@onready var _analysis_toast_panel: PanelContainer = %AnalysisToastPanel
@onready var _analysis_toast_label: Label = %AnalysisToastLabel
@onready var _analysis_toast_timer: Timer = %AnalysisToastTimer

var _turn_manager: WorldTurnManager
var _analysis_target: Dictionary = { }
var _analysis_known_names_by_key: Dictionary = { }


func _ready() -> void:
	if _analysis_toast_timer != null and not _analysis_toast_timer.timeout.is_connected(
		_on_analysis_toast_timeout,
	):
		_analysis_toast_timer.timeout.connect(_on_analysis_toast_timeout)
	_show_analysis_placeholder()
	if _analysis_toast_panel != null:
		_analysis_toast_panel.visible = false


func configure(turn_manager: WorldTurnManager) -> void:
	_turn_manager = turn_manager
	if _turn_manager == null:
		return

	if not _turn_manager.analysis_target_changed.is_connected(_on_analysis_target_changed):
		_turn_manager.analysis_target_changed.connect(_on_analysis_target_changed)
	if not _turn_manager.analysis_result_ready.is_connected(_on_analysis_result_ready):
		_turn_manager.analysis_result_ready.connect(_on_analysis_result_ready)
	if not _turn_manager.analysis_knowledge_updated.is_connected(_on_analysis_knowledge_updated):
		_turn_manager.analysis_knowledge_updated.connect(_on_analysis_knowledge_updated)

	_show_analysis_placeholder()


func _show_analysis_placeholder() -> void:
	if _analysis_name_label == null or _analysis_meta_label == null or _analysis_body_label == null:
		return
	_analysis_name_label.text = "No target selected"
	_analysis_meta_label.text = "Hover or cycle targets, then analyze to deepen field notes."
	_analysis_body_label.text = "Known details for the current target will appear here."


func _render_analysis_result(result: Dictionary) -> void:
	if _analysis_name_label == null or _analysis_meta_label == null or _analysis_body_label == null:
		return
	if result.is_empty():
		_show_analysis_placeholder()
		return

	var display_name := String(result.get("display_name", "Target"))
	var kind := String(result.get("kind", "unknown")).capitalize()
	var distance := int(result.get("distance", 0))
	var cell: Vector2i = result.get("cell", Vector2i.ZERO)
	var summary := String(result.get("summary", "No reliable field notes yet."))

	_analysis_name_label.text = display_name
	_analysis_meta_label.text = "%s  |  Cell %d,%d  |  Range %d" % [
		kind,
		cell.x,
		cell.y,
		distance,
	]
	_analysis_body_label.text = summary
	_remember_analysis_target(result)


func _refresh_analysis_view() -> void:
	if _turn_manager == null:
		return
	if _analysis_target.is_empty():
		_show_analysis_placeholder()
		return
	_render_analysis_result(_turn_manager.get_analysis_result_for_target(_analysis_target))


func _on_analysis_target_changed(target: Dictionary) -> void:
	_analysis_target = target.duplicate(true)
	_remember_analysis_target(target)
	_refresh_analysis_view()


func _on_analysis_result_ready(result: Dictionary) -> void:
	_analysis_target = result.duplicate(true)
	_render_analysis_result(result)


func _on_analysis_knowledge_updated(
		key: StringName,
		_snapshot: Dictionary,
		unlock_flag: StringName,
) -> void:
	_show_analysis_toast(_analysis_unlock_message(key, unlock_flag))
	if _analysis_target.is_empty():
		return
	if StringName(_analysis_target.get("key", "")) != key:
		return
	_refresh_analysis_view()


func _remember_analysis_target(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var key := StringName(payload.get("key", ""))
	if key == StringName():
		return
	var display_name := String(payload.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		return
	_analysis_known_names_by_key[key] = display_name


func _analysis_unlock_message(key: StringName, unlock_flag: StringName) -> String:
	var target_name := String(_analysis_known_names_by_key.get(key, _fallback_analysis_name(key)))
	match unlock_flag:
		WorldTurnManager.KNOWLEDGE_BASIC:
			return "FIELD NOTE ADDED: %s" % [target_name]
		WorldTurnManager.KNOWLEDGE_PARTIAL:
			return "PARTIAL CLUE LOGGED: %s" % [target_name]
		WorldTurnManager.KNOWLEDGE_WEAKNESS:
			return "WEAKNESS CONFIRMED: %s" % [target_name]
		WorldTurnManager.KNOWLEDGE_DISPOSAL:
			return "DISPOSAL NOTE LOGGED: %s" % [target_name]
		_:
			return "FIELD NOTES UPDATED: %s" % [target_name]


func _fallback_analysis_name(key: StringName) -> String:
	var raw := String(key)
	if raw == String(WorldTurnManager.ANALYSIS_CHUTE_KEY):
		return "Disposal Chute"
	if raw == String(WorldTurnManager.ANALYSIS_EXIT_KEY):
		return "World Exit"

	var normalized := raw
	for prefix in ["hostile:", "pickup:"]:
		if normalized.begins_with(prefix):
			normalized = normalized.trim_prefix(prefix)
			break
	if normalized.contains("/"):
		normalized = normalized.get_file().get_basename()
	normalized = normalized.replace("_", " ")
	return normalized.capitalize()


func _show_analysis_toast(text: String) -> void:
	if _analysis_toast_panel == null or _analysis_toast_label == null:
		return
	_analysis_toast_label.text = text
	_analysis_toast_panel.visible = true
	if _analysis_toast_timer != null:
		_analysis_toast_timer.start()


func _on_analysis_toast_timeout() -> void:
	if _analysis_toast_panel != null:
		_analysis_toast_panel.visible = false