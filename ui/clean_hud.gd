extends Control
## Always-visible Clean% HUD. Shows hazards cleared / total.

@onready var _label: Label = %Label

var _turn_manager: WorldTurnManager
var _bump_tween: Tween


func configure(turn_manager: WorldTurnManager) -> void:
	_turn_manager = turn_manager
	if not _turn_manager.clean_status_changed.is_connected(_on_clean_changed):
		_turn_manager.clean_status_changed.connect(_on_clean_changed)
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
	_refresh()
	_bump_label()


func _bump_label() -> void:
	if _label == null:
		return
	if _bump_tween != null:
		_bump_tween.kill()
	_bump_tween = create_tween()
	_bump_tween.tween_property(_label, "modulate", Color(0.4, 1.0, 0.5), 0.0)
	_bump_tween.tween_property(_label, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)
