class_name CameraShakePlayer
extends Node

var _camera: Camera3D
var _active_tween: Tween
var _rest_position: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func configure(camera: Camera3D) -> void:
	_camera = camera
	_sync_rest_position()


func play(entry) -> void:
	if _camera == null or entry == null:
		return

	_sync_rest_position()
	_reset_active_tween()

	var duration := maxf(entry.duration, 0.04)
	var amplitude := maxf(entry.intensity, 0.0)
	if amplitude <= 0.0:
		return

	var step_count := 4
	var step_duration := duration / float(step_count)

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for step_index in range(step_count - 1):
		var falloff := 1.0 - (float(step_index) / float(maxi(step_count - 1, 1)))
		var offset := Vector3(
			_rng.randf_range(-amplitude, amplitude) * falloff,
			_rng.randf_range(-amplitude * 0.5, amplitude * 0.5) * falloff,
			_rng.randf_range(-amplitude, amplitude) * falloff,
		)
		_active_tween.tween_property(_camera, "position", _rest_position + offset, step_duration)

	_active_tween.tween_property(_camera, "position", _rest_position, step_duration)
	_active_tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)


func _sync_rest_position() -> void:
	if _camera == null:
		return
	_rest_position = _camera.position


func _reset_active_tween() -> void:
	if _camera == null:
		return
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
	_camera.position = _rest_position


func _on_tween_finished() -> void:
	if _camera != null:
		_camera.position = _rest_position
	_active_tween = null
