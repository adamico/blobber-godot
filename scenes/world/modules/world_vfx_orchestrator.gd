class_name WorldVFXOrchestrator
extends Node

const KEY_ITEM_USED := &"item.used"
const KEY_ITEM_DROPPED := &"item.dropped"
const KEY_HOSTILE_KILLED := &"hostile.killed"
const KEY_HOSTILE_RESPAWNED := &"hostile.respawned"
const KEY_DEBRIS_DISPOSED := &"debris.disposed"
const KEY_PLAYER_BUMPED := &"player.bumped"
const KEY_PLAYER_HIT := &"player.hit"
const KEY_HOSTILE_HIT := &"hostile.hit"

const CAMERA_SHAKE_PLAYER_SCRIPT := preload("res://components/camera_shake_player.gd")
const ENTITY_FLASH_PLAYER_SCRIPT := preload("res://components/entity_flash_player.gd")
const PARTICLE_PLAYER_SCRIPT := preload("res://components/world_particle_player.gd")
const SCREEN_FLASH_PLAYER_SCRIPT := preload("res://ui/screen_flash_player.gd")

var _player: Player
var _turn_manager: Node
var _world_root: Node3D
var _profile: Resource
var _camera_shake_player: Node
var _screen_flash_player: Node
var _entity_flash_player: Node
var _particle_player: Node3D
var _last_triggered_ms_by_entry: Dictionary = {}


func configure(
		player: Player,
		turn_manager: Node,
		world_root: Node3D,
		profile: Resource,
) -> void:
	_player = player
	_turn_manager = turn_manager
	_world_root = world_root
	_profile = profile

	_ensure_players()
	_connect_signals()


func _ensure_players() -> void:
	if _camera_shake_player == null:
		_camera_shake_player = CAMERA_SHAKE_PLAYER_SCRIPT.new()
		_camera_shake_player.name = "CameraShakePlayer"
		add_child(_camera_shake_player)
	if _screen_flash_player == null:
		_screen_flash_player = SCREEN_FLASH_PLAYER_SCRIPT.new()
		_screen_flash_player.name = "ScreenFlashPlayer"
		add_child(_screen_flash_player)
	if _entity_flash_player == null:
		_entity_flash_player = ENTITY_FLASH_PLAYER_SCRIPT.new()
		_entity_flash_player.name = "EntityFlashPlayer"
		add_child(_entity_flash_player)
	if _particle_player == null:
		_particle_player = PARTICLE_PLAYER_SCRIPT.new()
		_particle_player.name = "WorldParticlePlayer"
		add_child(_particle_player)

	var camera := _player.get_node_or_null("Camera3D") as Camera3D if _player != null else null
	_camera_shake_player.configure(camera)


func _connect_signals() -> void:
	if _player != null:
		if not _player.wall_bumped.is_connected(_on_player_bumped):
			_player.wall_bumped.connect(_on_player_bumped)
		if _player.stats != null and not _player.stats.damaged.is_connected(_on_player_damaged):
			_player.stats.damaged.connect(_on_player_damaged)

	if _turn_manager == null:
		return

	if not _turn_manager.item_used.is_connected(_on_item_used):
		_turn_manager.item_used.connect(_on_item_used)
	if not _turn_manager.item_dropped.is_connected(_on_item_dropped):
		_turn_manager.item_dropped.connect(_on_item_dropped)
	if not _turn_manager.hostile_impacted.is_connected(_on_hostile_impacted):
		_turn_manager.hostile_impacted.connect(_on_hostile_impacted)
	if not _turn_manager.hostile_killed.is_connected(_on_hostile_killed):
		_turn_manager.hostile_killed.connect(_on_hostile_killed)
	if not _turn_manager.debris_respawned.is_connected(_on_hostile_respawned):
		_turn_manager.debris_respawned.connect(_on_hostile_respawned)
	if not _turn_manager.debris_disposed.is_connected(_on_debris_disposed):
		_turn_manager.debris_disposed.connect(_on_debris_disposed)


func _on_player_bumped() -> void:
	_dispatch(KEY_PLAYER_BUMPED, _player.global_position)


func _on_player_damaged(_amount: int, _old_health: int, _new_health: int) -> void:
	_dispatch(KEY_PLAYER_HIT, _player.global_position)


func _on_item_used(_item: ItemData, cell: Vector2i) -> void:
	_dispatch(KEY_ITEM_USED, _cell_to_world(cell))


func _on_item_dropped(cell: Vector2i) -> void:
	_dispatch(KEY_ITEM_DROPPED, _cell_to_world(cell))


func _on_hostile_impacted(hostile: Hostile, cell: Vector2i) -> void:
	var world_position := hostile.global_position if hostile != null else _cell_to_world(cell)
	_dispatch(KEY_HOSTILE_HIT, world_position, hostile)


func _on_hostile_killed(cell: Vector2i, _hostile_definition_id: StringName) -> void:
	_dispatch(KEY_HOSTILE_KILLED, _cell_to_world(cell))


func _on_hostile_respawned(cell: Vector2i, _hostile_definition_id: StringName) -> void:
	_dispatch(KEY_HOSTILE_RESPAWNED, _cell_to_world(cell))


func _on_debris_disposed(cell: Vector2i, _item: ItemData) -> void:
	_dispatch(KEY_DEBRIS_DISPOSED, _cell_to_world(cell))


func _dispatch(signal_key: StringName, world_position: Vector3, hostile: Hostile = null) -> void:
	if _profile == null:
		return

	var entries: Array[Resource] = _profile.find_all_by_signal_key(signal_key)
	for entry in entries:
		if entry == null:
			continue
		var cooldown_key := _cooldown_key_for(signal_key, entry)
		if not _cooldown_ready(cooldown_key, entry.cooldown_ms):
			continue
		_play_entry(entry, world_position, hostile)
		_last_triggered_ms_by_entry[cooldown_key] = Time.get_ticks_msec()


func _play_entry(entry, world_position: Vector3, hostile: Hostile) -> void:
	match entry.effect_type:
		0:
			_camera_shake_player.play(entry)
		1:
			_screen_flash_player.play(entry)
		2:
			_entity_flash_player.play_hostile(hostile, entry)
		3:
			_particle_player.play_at(world_position, entry)


func _cell_to_world(cell: Vector2i) -> Vector3:
	var cell_size := 1.0
	if _player != null and _player.movement_config != null:
		cell_size = _player.movement_config.cell_size
	return GridMapper.cell_to_world(cell, cell_size, 0.0)


func _cooldown_key_for(signal_key: StringName, entry) -> String:
	return "%s:%d" % [String(signal_key), entry.get_instance_id()]


func _cooldown_ready(cooldown_key: String, cooldown_ms: int) -> bool:
	if cooldown_ms <= 0:
		return true
	if not _last_triggered_ms_by_entry.has(cooldown_key):
		return true
	var last_ms := int(_last_triggered_ms_by_entry[cooldown_key])
	return Time.get_ticks_msec() - last_ms >= cooldown_ms
