class_name WorldAudioOrchestrator
extends Node

const KEY_STEP_COMPLETED := &"player.step_completed"
const KEY_WALL_BUMPED := &"player.wall_bumped"
const KEY_ITEM_ADDED := &"inventory.item_added"
const KEY_HOSTILE_HIT := &"combat.hostile_hit"
const KEY_PLAYER_DIED := &"player.died"
const KEY_DISPOSAL := &"world.disposal"
const KEY_ANALYSIS_NEW_KNOWLEDGE := &"analysis.new_knowledge"
const KEY_ANALYSIS_NO_NEW_KNOWLEDGE := &"analysis.no_new_knowledge"
const KEY_DIALOG_CONTINUE := &"ui.dialog_continue"
const KEY_MUSIC_GAMEPLAY := &"music.gameplay"

var _player: Player
var _turn_manager: WorldTurnManager
var _overlay_module: WorldOverlayModule
var _profile: Resource
var _music_player: AudioStreamPlayer
var _last_played_ms_by_key: Dictionary = { }


func configure(
		player: Player,
		turn_manager: WorldTurnManager,
		overlay_module: WorldOverlayModule,
		profile: Resource,
) -> void:
	_player = player
	_turn_manager = turn_manager
	_overlay_module = overlay_module
	_profile = profile

	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
		add_child(_music_player)

	_connect_signals()
	play_by_signal_key(KEY_MUSIC_GAMEPLAY)


func play_by_signal_key(signal_key: StringName) -> void:
	var entry: Variant = _entry_for_key(signal_key)
	if entry == null:
		return
	if not _cooldown_ready(signal_key, entry.cooldown_ms):
		return

	var stream := load(entry.stream_path) as AudioStream
	if stream == null:
		push_warning("Audio stream missing for key: %s" % String(signal_key))
		return

	if _is_music(entry):
		_play_music(stream, entry)
	else:
		_play_sfx(stream, entry)

	_last_played_ms_by_key[signal_key] = Time.get_ticks_msec()


func _connect_signals() -> void:
	if _player != null:
		if not _player.command_completed.is_connected(_on_player_command_completed):
			_player.command_completed.connect(_on_player_command_completed)
		if not _player.wall_bumped.is_connected(_on_player_wall_bumped):
			_player.wall_bumped.connect(_on_player_wall_bumped)
		if _player.inventory != null:
			if not _player.inventory.item_added.is_connected(_on_item_added):
				_player.inventory.item_added.connect(_on_item_added)

	if _turn_manager != null:
		if not _turn_manager.hostile_hit.is_connected(_on_hostile_hit):
			_turn_manager.hostile_hit.connect(_on_hostile_hit)
		if not _turn_manager.analysis_knowledge_updated.is_connected(
			_on_analysis_knowledge_updated,
		):
			_turn_manager.analysis_knowledge_updated.connect(_on_analysis_knowledge_updated)
		if not _turn_manager.player_died.is_connected(_on_player_died):
			_turn_manager.player_died.connect(_on_player_died)
		if not _turn_manager.action_feedback.is_connected(_on_action_feedback):
			_turn_manager.action_feedback.connect(_on_action_feedback)

	if _overlay_module != null:
		if not _overlay_module.overlay_opened.is_connected(_on_overlay_opened):
			_overlay_module.overlay_opened.connect(_on_overlay_opened)
		if not _overlay_module.restart_requested.is_connected(_on_overlay_action_requested):
			_overlay_module.restart_requested.connect(_on_overlay_action_requested)
		if not _overlay_module.return_to_title_requested.is_connected(
			_on_overlay_action_requested,
		):
			_overlay_module.return_to_title_requested.connect(_on_overlay_action_requested)


func debug_report_unmapped_keys(signal_keys: Array[StringName]) -> Array[StringName]:
	var missing: Array[StringName] = []
	for signal_key in signal_keys:
		if _entry_for_key(signal_key) != null:
			continue
		missing.append(signal_key)
		push_warning("Unmapped audio signal key: %s" % String(signal_key))
	return missing


func _on_player_command_completed(cmd: GridCommand.Type, _new_state: GridState) -> void:
	if cmd == GridCommand.Type.STEP_FORWARD:
		play_by_signal_key(KEY_STEP_COMPLETED)
		return
	if cmd == GridCommand.Type.STEP_BACK:
		play_by_signal_key(KEY_STEP_COMPLETED)
		return
	if cmd == GridCommand.Type.MOVE_LEFT:
		play_by_signal_key(KEY_STEP_COMPLETED)
		return
	if cmd == GridCommand.Type.MOVE_RIGHT:
		play_by_signal_key(KEY_STEP_COMPLETED)


func _on_player_wall_bumped() -> void:
	play_by_signal_key(KEY_WALL_BUMPED)


func _on_item_added(_item) -> void:
	play_by_signal_key(KEY_ITEM_ADDED)


func _on_hostile_hit(
		_definition_id: StringName,
		_used_item_name: String,
		_is_effective: bool,
		_item_consumed: bool,
		_item_is_aoe: bool,
) -> void:
	play_by_signal_key(KEY_HOSTILE_HIT)


func _on_analysis_knowledge_updated(
		_key: StringName,
		_snapshot: Dictionary,
		_unlock_flag: StringName,
) -> void:
	if _key == WorldTurnManager.ANALYSIS_CHUTE_KEY:
		return
	play_by_signal_key(KEY_ANALYSIS_NEW_KNOWLEDGE)


func _on_player_died() -> void:
	play_by_signal_key(KEY_PLAYER_DIED)


func _on_action_feedback(text: String, _is_positive: bool) -> void:
	if text == "DISPOSED":
		play_by_signal_key(KEY_DISPOSAL)
		return
	if text == "NO NEW INFORMATION":
		play_by_signal_key(KEY_ANALYSIS_NO_NEW_KNOWLEDGE)


func _on_overlay_opened(_kind: StringName) -> void:
	if _overlay_module == null:
		return
	var overlay := _overlay_module.active_overlay()
	if overlay == null:
		return
	if not overlay.has_signal("continue_pressed"):
		return
	if not overlay.continue_pressed.is_connected(_on_dialog_continue_pressed):
		overlay.continue_pressed.connect(_on_dialog_continue_pressed)


func _on_dialog_continue_pressed() -> void:
	play_by_signal_key(KEY_DIALOG_CONTINUE)


func _on_overlay_action_requested() -> void:
	play_by_signal_key(KEY_DIALOG_CONTINUE)


func _entry_for_key(signal_key: StringName):
	if _profile == null:
		return null
	return _profile.find_by_signal_key(signal_key)


func _cooldown_ready(signal_key: StringName, cooldown_ms: int) -> bool:
	if cooldown_ms <= 0:
		return true
	if not _last_played_ms_by_key.has(signal_key):
		return true
	var last_ms := int(_last_played_ms_by_key[signal_key])
	return Time.get_ticks_msec() - last_ms >= cooldown_ms


func _is_music(entry) -> bool:
	return String(entry.bus).to_lower() == "music" or String(entry.sound_name).begins_with("music.")


func _play_music(stream: AudioStream, entry) -> void:
	if _music_player == null:
		return
	_music_player.stop()
	_music_player.stream = stream
	_music_player.bus = String(entry.bus)
	_music_player.volume_db = entry.volume_db
	_music_player.pitch_scale = 1.0
	_music_player.play()


func _play_sfx(stream: AudioStream, entry) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if not tree.root.is_inside_tree():
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = String(entry.bus)
	player.volume_db = entry.volume_db
	if entry.pitch_variation > 0.0:
		player.pitch_scale = randf_range(1.0 - entry.pitch_variation, 1.0 + entry.pitch_variation)
	else:
		player.pitch_scale = 1.0
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
