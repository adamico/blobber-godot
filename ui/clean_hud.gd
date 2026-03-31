extends Control
## Always-visible Clean% HUD. Shows hazards cleared / total.

@onready var _label: Label = %Label

var _turn_manager: WorldTurnManager
var _feedback_timer: Timer


func _ready() -> void:
	_feedback_timer = Timer.new()
	_feedback_timer.one_shot = true
	_feedback_timer.wait_time = 2.0
	_feedback_timer.timeout.connect(_on_feedback_timeout)
	add_child(_feedback_timer)


func configure(turn_manager: WorldTurnManager) -> void:
	_turn_manager = turn_manager
	if not _turn_manager.clean_status_changed.is_connected(_on_clean_changed):
		_turn_manager.clean_status_changed.connect(_on_clean_changed)
	if not _turn_manager.action_feedback.is_connected(_on_action_feedback):
		_turn_manager.action_feedback.connect(_on_action_feedback)
	_refresh()


func _refresh() -> void:
	if _turn_manager == null or _label == null:
		return

	var cleared := _turn_manager.get_clean_cleared()
	var total := _turn_manager.get_clean_total()
	var pct := 0
	if total > 0:
		pct = int(float(cleared) / float(total) * 100.0)

	_label.text = "CLEAN: %d/%d — %d%%" % [cleared, total, pct]

	if pct >= 100:
		_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		_label.remove_theme_color_override("font_color")


func _on_clean_changed(_cleared: int, _total: int) -> void:
	# Only refresh if not showing feedback
	if _feedback_timer.is_stopped():
		_refresh()


func _on_action_feedback(text: String, is_positive: bool) -> void:
	_label.text = text
	if is_positive:
		_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4)) # Gold
	else:
		_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Red/Pink
	_feedback_timer.start()


func _on_feedback_timeout() -> void:
	_refresh()
