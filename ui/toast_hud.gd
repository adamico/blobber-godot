extends Control
## Universal toast notification HUD.
## Listens to WorldTurnManager.action_feedback and analysis_knowledge_updated
## so all in-game toasts flow through a single overlay.

@onready var _panel: PanelContainer = %ToastPanel
@onready var _label: Label = %ToastLabel
@onready var _timer: Timer = %ToastTimer

var _known_names_by_key: Dictionary = { }


func _ready() -> void:
	if _panel != null:
		_panel.visible = false
	if _timer != null and not _timer.timeout.is_connected(_on_timer_timeout):
		_timer.timeout.connect(_on_timer_timeout)


func configure(turn_manager: WorldTurnManager) -> void:
	if turn_manager == null:
		return
	if not turn_manager.action_feedback.is_connected(_on_action_feedback):
		turn_manager.action_feedback.connect(_on_action_feedback)
	if not turn_manager.analysis_knowledge_updated.is_connected(_on_knowledge_updated):
		turn_manager.analysis_knowledge_updated.connect(_on_knowledge_updated)
	if not turn_manager.analysis_target_changed.is_connected(_on_target_changed):
		turn_manager.analysis_target_changed.connect(_on_target_changed)


func show_toast(text: String, is_positive: bool) -> void:
	if _panel == null or _label == null:
		return
	_label.text = text
	if is_positive:
		_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4)) # Gold
	else:
		_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Red/Pink
	_panel.visible = true
	if _timer != null:
		_timer.start()

# --- Signal handlers ---


func _on_action_feedback(text: String, is_positive: bool) -> void:
	show_toast(text, is_positive)


func _on_target_changed(target: Dictionary) -> void:
	if target.is_empty():
		return
	var key := StringName(target.get("key", ""))
	if key == StringName():
		return
	var display_name := String(target.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		_known_names_by_key[key] = display_name


func _on_knowledge_updated(
		key: StringName,
		_snapshot: Dictionary,
		unlock_flag: StringName,
) -> void:
	show_toast(_unlock_message(key, unlock_flag), true)


func _on_timer_timeout() -> void:
	if _panel != null:
		_panel.visible = false

# --- Helpers ---


func _unlock_message(key: StringName, unlock_flag: StringName) -> String:
	var target_name := String(_known_names_by_key.get(key, _fallback_name(key)))
	match unlock_flag:
		WorldTurnManager.KNOWLEDGE_BASIC:
			return "FIELD NOTE ADDED: %s" % target_name
		WorldTurnManager.KNOWLEDGE_PARTIAL:
			return "PARTIAL CLUE LOGGED: %s" % target_name
		WorldTurnManager.KNOWLEDGE_WEAKNESS:
			return "WEAKNESS CONFIRMED: %s" % target_name
		WorldTurnManager.KNOWLEDGE_DISPOSAL:
			return "DISPOSAL NOTE LOGGED: %s" % target_name
		_:
			return "FIELD NOTES UPDATED: %s" % target_name


func _fallback_name(key: StringName) -> String:
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
