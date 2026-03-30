class_name WorldPolicyOrchestrator
extends Node

var _player
var _overlay_module: WorldOverlayModule
var _ui_module: WorldUIModule


func configure(
		player,
		overlay_module: WorldOverlayModule,
		ui_module: WorldUIModule,
) -> void:
	_player = player
	_overlay_module = overlay_module
	_ui_module = ui_module


func open_overlay(kind: StringName, _allow_non_gameplay: bool, _gameplay_active: bool) -> bool:
	if _overlay_module == null:
		return false
	if _overlay_module.active_overlay_kind() == kind and _overlay_module.has_active_overlay():
		return false
	if not _overlay_module.open_overlay(kind):
		return false

	set_exploration_active(false)
	return true


func close_overlay(restore_exploration: bool) -> void:
	if _overlay_module != null:
		_overlay_module.close_overlay()

	if restore_exploration:
		set_exploration_active(true)


func apply_state_side_effects(
		current_state: StringName,
		is_gameplay_active: bool,
		_is_combat_active: bool,
		_overlay_combat: StringName,
		overlay_victory: StringName,
		overlay_defeat: StringName,
		state_gameover_failure: StringName,
		state_gameover_success: StringName,
) -> void:
	if is_gameplay_active:
		if not _overlay_module.has_active_overlay():
			set_exploration_active(true)
		return

	close_overlay(false)
	set_exploration_active(false)

	if current_state == state_gameover_failure:
		open_overlay(overlay_defeat, true, true)
	elif current_state == state_gameover_success:
		open_overlay(overlay_victory, true, true)


func set_exploration_active(is_active: bool) -> void:
	if _player == null:
		return
	if is_active:
		_player.resume_exploration_commands()
	else:
		_player.pause_exploration_commands()
