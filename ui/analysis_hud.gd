extends Control

@onready var _analysis_panel: PanelContainer = %AnalysisPanel
@onready var _analysis_name_label: Label = %AnalysisNameLabel
@onready var _analysis_meta_label: Label = %AnalysisMetaLabel
@onready var _analysis_body_label: Label = %AnalysisBodyLabel

const ANALYSIS_PANEL_IDLE_TIMEOUT := 3.0

var _turn_manager: WorldTurnManager
var _analysis_target: Dictionary = { }
var _analysis_known_names_by_key: Dictionary = { }
var _analysis_idle_timer: Timer


func _ready() -> void:
	_show_analysis_placeholder()
	_analysis_idle_timer = Timer.new()
	_analysis_idle_timer.one_shot = true
	_analysis_idle_timer.wait_time = ANALYSIS_PANEL_IDLE_TIMEOUT
	_analysis_idle_timer.timeout.connect(_on_analysis_idle_timeout)
	add_child(_analysis_idle_timer)

	_hide_analysis_panel()


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


func _show_analysis_panel() -> void:
	if _analysis_panel != null:
		_analysis_panel.visible = true
		if _analysis_idle_timer != null:
			_analysis_idle_timer.stop()
			_analysis_idle_timer.start()


func _hide_analysis_panel() -> void:
	if _analysis_panel != null:
		_analysis_panel.visible = false
	if _analysis_idle_timer != null:
		_analysis_idle_timer.stop()


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
	if _analysis_target.is_empty():
		_hide_analysis_panel()
		return
	_show_analysis_panel()
	_refresh_analysis_view()


func _on_analysis_result_ready(result: Dictionary) -> void:
	_analysis_target = result.duplicate(true)
	if not result.is_empty():
		_show_analysis_panel()
	_render_analysis_result(result)


func _on_analysis_knowledge_updated(
		key: StringName,
		_snapshot: Dictionary,
		_unlock_flag: StringName,
) -> void:
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


func _on_analysis_idle_timeout() -> void:
	_hide_analysis_panel()
