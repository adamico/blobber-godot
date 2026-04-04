class_name CameraShakePlayer
extends Node

var _camera: Camera3D
var _active_tween: Tween
var _rest_h_offset: float = 0.0
var _rest_v_offset: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func configure(camera: Camera3D) -> void:
	_camera = camera
	_sync_rest_offsets()


func play(entry) -> void:
	if _camera == null or entry == null:
		return

	_sync_rest_offsets()
	_reset_active_tween()

	var duration := maxf(entry.duration, 0.04)
	var amplitude := maxf(entry.intensity, 0.0)
	if amplitude <= 0.0:
		return

	var step_count := 4
	var step_duration := duration / float(step_count)
	var current_h_offset := _rest_h_offset

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for step_index in range(step_count - 1):
		var falloff := 1.0 - (float(step_index) / float(maxi(step_count - 1, 1)))
		var target_h_offset := _rest_h_offset + _rng.randf_range(-amplitude, amplitude) * falloff
		_active_tween.tween_method(
			_apply_h_offset,
			current_h_offset,
			target_h_offset,
			step_duration,
		)
		current_h_offset = target_h_offset

	_active_tween.tween_method(
		_apply_h_offset,
		current_h_offset,
		_rest_h_offset,
		step_duration,
	)
	_active_tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)


func _sync_rest_offsets() -> void:
	if _camera == null:
		return
	_rest_h_offset = _camera.h_offset
	_rest_v_offset = _camera.v_offset


func _reset_active_tween() -> void:
	if _camera == null:
		return
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
	_camera.h_offset = _rest_h_offset
	_camera.v_offset = _rest_v_offset


func _on_tween_finished() -> void:
	if _camera != null:
		_camera.h_offset = _rest_h_offset
		_camera.v_offset = _rest_v_offset
	_active_tween = null


func _apply_h_offset(value: float) -> void:
	if _camera == null:
		return
	_camera.h_offset = value
	_camera.v_offset = _rest_v_offset
