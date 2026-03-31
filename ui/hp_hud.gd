extends Control

@onready var _bar: ProgressBar = %ProgressBar
@onready var _label: Label = %Label
@onready var _status_label: Label = %StatusLabel

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
		_label.text = "HP: %d/%d" % [_player.stats.health, _player.stats.max_health]

	if _status_label != null:
		if _player.stats.health <= 0:
			_status_label.text = "⚠ OPERATIVE TERMINATED"
			_status_label.visible = true
			if _bar != null:
				_bar.modulate = Color(1.0, 0.3, 0.3)
		else:
			_status_label.visible = false
			if _bar != null:
				_bar.modulate = Color(0.3, 1.0, 0.5)
