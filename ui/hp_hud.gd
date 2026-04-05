extends Control

@onready var _bar: ProgressBar = %ProgressBar
@onready var _label: Label = %Label
@onready var _status_label: Label = %StatusLabel

var _player: Player
var _value_tween: Tween
var _flash_tween: Tween


func configure(player: Player) -> void:
	_player = player
	_refresh()
	if _player == null or _player.stats == null:
		return
	# Seed the bar to the current value without animation.
	if _bar != null:
		_bar.value = float(_player.stats.health)
		_bar.modulate = Color(0.3, 1.0, 0.5)
	if not _player.stats.damaged.is_connected(_on_damaged):
		_player.stats.damaged.connect(_on_damaged)
	if not _player.stats.healed.is_connected(_on_healed):
		_player.stats.healed.connect(_on_healed)


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _player == null or _player.stats == null:
		return

	if _bar != null:
		_bar.max_value = _player.stats.max_health
		# bar.value and bar.modulate are driven by _animate_bar; do not poll them here.

	if _label != null:
		_label.text = "HP: %d/%d" % [_player.stats.health, _player.stats.max_health]

	if _status_label != null:
		if _player.stats.health <= 0:
			_status_label.text = "⚠ OPERATIVE TERMINATED"
			_status_label.visible = true
		else:
			_status_label.visible = false


func _on_damaged(_amount: int, _old_h: int, new_h: int) -> void:
	_animate_bar(new_h, true)


func _on_healed(_amount: int, _old_h: int, new_h: int) -> void:
	_animate_bar(new_h, false)


func _animate_bar(target: int, is_damage: bool) -> void:
	if _bar == null:
		return

	var resting_color := Color(1.0, 0.3, 0.3) if target <= 0 else Color(0.3, 1.0, 0.5)
	var flash_color := Color(1.0, 0.2, 0.2) if is_damage else Color(0.8, 1.0, 0.8)

	if _value_tween != null:
		_value_tween.kill()
	_value_tween = create_tween()
	_value_tween.tween_property(_bar, "value", float(target), 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_bar, "modulate", flash_color, 0.0)
	_flash_tween.tween_property(_bar, "modulate", resting_color, 0.4).set_ease(Tween.EASE_OUT)
