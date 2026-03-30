extends Control

## Always-visible Stamina bar. Shows "EXHAUSTED" warning when Stamina = 0.

@onready var _bar: ProgressBar = $VBox/ProgressBar
@onready var _label: Label = $VBox/Label
@onready var _status_label: Label = $VBox/StatusLabel

var _player: Player


func configure(player: Player) -> void:
	_player = player
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _player == null or _player.stats == null:
		return

	if _bar != null:
		_bar.max_value = _player.stats.max_health
		_bar.value = _player.stats.health

	if _label != null:
		_label.text = "STAMINA: %d/%d" % [_player.stats.health, _player.stats.max_health]

	if _status_label != null:
		if _player.is_exhausted:
			_status_label.text = "⚠ EXHAUSTED — TOOLS LOCKED"
			_status_label.visible = true
			if _bar != null:
				_bar.modulate = Color(1.0, 0.3, 0.3)
		else:
			_status_label.visible = false
			if _bar != null:
				_bar.modulate = Color(0.3, 1.0, 0.5)
