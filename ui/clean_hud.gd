extends Control
## Always-visible Clean% HUD. Shows hazards cleared / total.

@onready var _label: Label = %Label

var _turn_manager: WorldTurnManager


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
