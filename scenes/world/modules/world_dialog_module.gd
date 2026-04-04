class_name WorldDialogModule
extends Node

const OVERLAY_DIALOG := &"dialog_message"
const STORAGE_PATH := "user://dialog_seen.cfg"
const STORAGE_SECTION := "seen"
const LOW_HP_RATIO := 0.3
## TODO: Move this to settings menu as a "Reset Progress" action.
const ENABLE_SEEN_STATE_PERSISTENCE := true

var _phrases: Dictionary = {
	"intro.job_briefing": {
		"title": "Job Briefing",
		"text": (
			"SWEEP PROTOCOL INITIATED. The hero has vacated the premises.\n\n"
			+ "Structural integrity: nominal.\n"
			+ "Biological debris: significant.\n\n"
			+ "You have been contracted to restore dungeon conditions to pre-incursion standards.\n"
			+ "Protective equipment has been provided. Results are expected.\n\n"
			+ "Good luck. You will need it."
		),
		"once": true,
	},
	"onboarding.first_pickup": {
		"title": "Intake Notice",
		"text": (
			"That's a mop.\n\nIndustrial grade, pre-soaked.\nIt won't make you feel heroic. "
			+ "It will, however, make certain things stop being on fire.\nPick it up."
		),
		"once": true,
	},
	"onboarding.inventory_full": {
		"title": "Capacity Alert",
		"text": (
			"You are carrying the maximum recommended load.\n\nThis is a professional "
			+ "assessment, not a suggestion.\nPut something down."
		),
		"once": true,
	},
	"onboarding.first_enemy": {
		"title": "Hazard Contact",
		"text": (
			"Ah. The corpse is moving. This is, unfortunately, within expected parameters.\n\n"
			+ "The hero's residual magic has a half-life problem.\n"
			+ "Deal with it.\n\n"
			+ "Then pick it up.\n"
			+ "Then dispose of it properly.\n"
			+ "In that order."
		),
		"once": true,
	},
	"onboarding.debris_revert_warning": {
		"title": "Instability Warning",
		"text": (
			"That remains is becoming less inert by the second.\n\n"
			+ "You may want to address that."
		),
		"once": true,
	},
	"onboarding.debris_reverted": {
		"title": "Containment Failure",
		"text": "You left it too long.\nIt's angry now.\n\nThis one's on you.",
		"once": true,
	},
	"onboarding.debris_weapon": {
		"title": "Field Adjustment",
		"text": (
			"Unorthodox.\nEffective.\n\n"
			+ "The disposal report is going to be a nightmare to file."
		),
		"once": true,
	},
	"onboarding.disposal_chute": {
		"title": "Disposal Log",
		"text": (
			"Disposal logged.\n\n"
			+ "The dungeon thanks you for your responsible waste management.\n"
			+ "It will not say so directly."
		),
		"once": true,
	},
	"onboarding.low_hp": {
		"title": "Medical Advisory",
		"text": (
			"You are in suboptimal condition.\n\n"
			+ "The contract does not cover medical expenses."
		),
		"once": true,
	},
	"outcome.job_rating_a": {
		"title": "Performance Summary",
		"text": (
			"Floor certified clean. Impressive.\n\n"
			+ "The dungeon hasn't seen this level of professional conduct\n"
			+ "since... well. Ever, actually."
		),
		"once": false,
	},
	"outcome.job_rating_c": {
		"title": "Performance Summary",
		"text": (
			"Floor cleared. Technically.\n\n"
			+ "The word 'thorough' does not apply here.\n"
			+ "Moving on."
		),
		"once": false,
	},
	"outcome.job_rating_d": {
		"title": "Performance Summary",
		"text": (
			"This is not what was agreed upon.\n\n"
			+ "The remaining hazards will be someone else's problem.\n"
			+ "You know this.\n"
			+ "You did it anyway."
		),
		"once": false,
	},
	"onboarding.supply_closet": {
		"title": "Supply Closet",
		"text": (
			"Resupply station.\n\n"
			+ "Everything here was left by previous contractors.\n"
			+ "Most of them finished the job.\n"
			+ "Take what you need."
		),
		"once": true,
	},
	"outcome.final_floor_cleared": {
		"title": "Contract Status",
		"text": (
			"All floors cleared.\n"
			+ "Hazard index: nominal.\n\n"
			+ "The dungeon is ready to receive its next hero.\n"
			+ "They will make an enormous mess.\n"
			+ "You will not be surprised when they call again."
		),
		"once": false,
	},
	"onboarding.first_move": {
		"title": "Protocol Reminder",
		"text": (
			"The dungeon operates on a strict turn-based protocol.\n\n"
			+ "You move.\n"
			+ "Things move.\n"
			+ "Nobody moves at the same time.\n\n"
			+ "This is not a suggestion.\n"
			+ "This is physics."
		),
		"once": true,
	},
	"onboarding.first_revert_timer": {
		"title": "Instability Indicator",
		"text": (
			"Note the instability indicator.\n\n"
			+ "The remains are attempting to reconstitute.\n"
			+ "This is normal.\n"
			+ "This is also your problem."
		),
		"once": true,
	},
	"onboarding.pickup_debris": {
		"title": "Containment Update",
		"text": (
			"Contained. You now have possession of a biological debris.\n\n"
			+ "Try not to think about it too hard.\n\n"
			+ "Disposal is still recommended.\n"
			+ "You can do it.\n"
			+ "We believe in you.\n\n"
			+ "A disposal chute is available on this floor.\n"
			+ "It's not a suggestion.\n"
			+ "It's logistics."
		),
		"once": true,
	},
	"onboarding.drop_debris": {
		"title": "Containment Update",
		"text": (
			"You put it down.\n"
			+ "The clock restarted.\n"
			+ "You knew that.\n\n"
			+ "You did it anyway.\n"
			+ "Professional assessment pending."
		),
		"once": true,
	},
	"onboarding.first_floor_complete": {
		"title": "Initial Success",
		"text": (
			"You've cleared the floor.\n"
			+ "Congratulations.\n\n"
			+ "The dungeon is slightly less disaster-adjacent than it was before.\n"
			+ "Keep it up.\n\n"
			+ "You may proceed to the next floor.\n"
			+ "Don't worry about the next hero.\n"
			+ "They will make an enormous mess."
		),
		"once": true,
	},
	"onboarding.splash_aoe": {
		"title": "Efficiency Log",
		"text": "Efficient.\n\nThe quarterly report appreciates efficiency.",
		"once": true,
	},
	"onboarding.enter_floor": {
		"title": "Floor Intake",
		"text": (
			"Floor [N].\n"
			+ "Previous contractor status: unknown.\n\n"
			+ "Proceed with standard caution.\n"
			+ "Or non-standard caution.\n"
			+ "Results will vary."
		),
		"once": false,
	},
	"onboarding.hostile_survived": {
		"title": "Engagement Update",
		"text": (
			"Direct contact.\n"
			+ "Hazard remains active.\n\n"
			+ "Continue applying tools until it doesn't."
		),
		"once": true,
	},
	"onboarding.hostile_killed_noneffective": {
		"title": "Anomalous Clearance",
		"text": (
			"Hazard neutralised.\n\n"
			+ "The tool selection was technically incorrect.\n"
			+ "It worked anyway.\n\n"
			+ "The dungeon has logged this as a statistical anomaly and moved on."
		),
		"once": true,
	},
	"onboarding.hostile_killed_effective": {
		"title": "Protocol Confirmed",
		"text": (
			"Hazard neutralised.\n"
			+ "Correct tool.\n"
			+ "Correct result.\n\n"
			+ "This is what the contract describes.\n"
			+ "Keep doing this."
		),
		"once": true,
	},
	"onboarding.player_hit": {
		"title": "Contact Incident",
		"text": (
			"You have been hit.\n"
			+ "This is not ideal.\n\n"
			+ "Try to avoid being hit again.\n"
			+ "The contract does not cover injuries."
		),
		"once": true,
	},
	"outcome.death": {
		"title": "Contract Status",
		"text": (
			"Contract terminated.\n"
			+ "Cause: occupational.\n\n"
			+ "A replacement contractor will be sourced.\n"
			+ "The dungeon will wait."
		),
		"once": false,
	},
	"onboarding.potion_use": {
		"title": "Consumption Log",
		"text": (
			"Hero-grade restorative.\n"
			+ "Technically expired.\n\n"
			+ "Effective nonetheless.\n"
			+ "Don't read the label."
		),
		"once": true,
	},
	"onboarding.floor_visible_assessment": {
		"title": "Initial Assessment",
		"text": "Initial assessment: manageable.\n\nAdjust expectations accordingly.",
		"once": true,
	},
}

var _overlay_module: WorldOverlayModule
var _turn_manager: WorldTurnManager
var _encounter_module: WorldEncounterModule
var _player: Player
var _world_root: Node

var _queue: Array[Dictionary] = []
var _active_payload: Dictionary = { }
var _showing_dialog := false
var _seen: Dictionary = { }

var _floor_number := 1
var _max_floor_number := 1


func configure(
		overlay_module: WorldOverlayModule,
		turn_manager: WorldTurnManager,
		encounter_module: WorldEncounterModule,
		player: Player,
		world_root: Node,
) -> void:
	_overlay_module = overlay_module
	_turn_manager = turn_manager
	_encounter_module = encounter_module
	_player = player
	_world_root = world_root

	_load_seen_state()
	_connect_signals()


func present_intro_then(on_done: Callable) -> bool:
	return present_phrase_then("intro.job_briefing", on_done, { }, true)


func begin_floor(floor_number: int, max_floor_number: int) -> void:
	_floor_number = maxi(floor_number, 1)
	_max_floor_number = maxi(max_floor_number, 1)
	queue_phrase("onboarding.enter_floor", { "N": _floor_number }, false)
	queue_phrase("onboarding.floor_visible_assessment")


func present_failure_then(on_done: Callable) -> bool:
	return present_phrase_then("outcome.death", on_done, { }, true)


func present_success_then(clean_percent: int, on_done: Callable) -> bool:
	var phrase_key := _success_phrase_for_percent(clean_percent)
	if _floor_number >= _max_floor_number:
		phrase_key = "outcome.final_floor_cleared"
	return present_phrase_then(phrase_key, on_done, { }, true)


func queue_phrase(
		key: String,
		tokens: Dictionary = { },
		force_show := false,
		on_done: Callable = Callable(),
) -> bool:
	var meta: Dictionary = _phrases.get(key, { })
	if meta.is_empty():
		return false

	var once := bool(meta.get("once", true))
	if once and not force_show and _has_seen(key):
		return false

	_queue.append(
		{
			"key": key,
			"title": String(meta.get("title", "Notice")),
			"text": _format_text(String(meta.get("text", "")), tokens),
			"once": once,
			"on_done": on_done,
		},
	)
	_try_present_next.call_deferred()
	return true


func present_phrase_then(
		key: String,
		on_done: Callable,
		tokens: Dictionary = { },
		force_show := true,
) -> bool:
	return queue_phrase(key, tokens, force_show, on_done)


func _connect_signals() -> void:
	if _overlay_module != null:
		if not _overlay_module.overlay_closed.is_connected(_on_overlay_closed):
			_overlay_module.overlay_closed.connect(_on_overlay_closed)

	if _turn_manager != null:
		if not _turn_manager.action_feedback.is_connected(_on_action_feedback):
			_turn_manager.action_feedback.connect(_on_action_feedback)
		if not _turn_manager.turn_completed.is_connected(_on_turn_completed):
			_turn_manager.turn_completed.connect(_on_turn_completed)
		if not _turn_manager.debris_consumed_as_weapon.is_connected(_on_debris_weapon):
			_turn_manager.debris_consumed_as_weapon.connect(_on_debris_weapon)
		if _turn_manager.has_signal("debris_reverted"):
			if not _turn_manager.debris_reverted.is_connected(_on_debris_reverted):
				_turn_manager.debris_reverted.connect(_on_debris_reverted)
		if _turn_manager.has_signal("debris_dropped"):
			if not _turn_manager.debris_dropped.is_connected(_on_debris_dropped):
				_turn_manager.debris_dropped.connect(_on_debris_dropped)
		if _turn_manager.has_signal("hostile_hit"):
			if not _turn_manager.hostile_hit.is_connected(_on_hostile_hit):
				_turn_manager.hostile_hit.connect(_on_hostile_hit)
		if _turn_manager.has_signal("hostile_spotted_first_time"):
			if not _turn_manager.hostile_spotted_first_time.is_connected(
				_on_hostile_spotted_first_time,
			):
				_turn_manager.hostile_spotted_first_time.connect(_on_hostile_spotted_first_time)
		if _turn_manager.has_signal("aoe_multi_hit"):
			if not _turn_manager.aoe_multi_hit.is_connected(_on_aoe_multi_hit):
				_turn_manager.aoe_multi_hit.connect(_on_aoe_multi_hit)

	if _player != null:
		if not _player.turn_action_performed.is_connected(_on_player_turn_action):
			_player.turn_action_performed.connect(_on_player_turn_action)
		if _player.inventory != null:
			if not _player.inventory.item_added.is_connected(_on_item_added):
				_player.inventory.item_added.connect(_on_item_added)
			if not _player.inventory.item_used.is_connected(_on_item_used):
				_player.inventory.item_used.connect(_on_item_used)
		if _player.stats != null:
			if not _player.stats.damaged.is_connected(_on_player_damaged):
				_player.stats.damaged.connect(_on_player_damaged)


func _on_overlay_closed(previous_kind: StringName) -> void:
	if previous_kind != OVERLAY_DIALOG:
		return
	if not _showing_dialog:
		return

	var payload := _active_payload.duplicate(true)
	_showing_dialog = false
	_active_payload.clear()

	if bool(payload.get("once", false)):
		_mark_seen(String(payload.get("key", "")))

	if _player != null and _is_gameplay_active():
		_player.resume_exploration_commands()

	var cb: Callable = payload.get("on_done", Callable())
	if cb.is_valid():
		cb.call_deferred()

	_try_present_next.call_deferred()


func _try_present_next() -> void:
	if _overlay_module == null:
		return
	if _showing_dialog:
		return
	if _queue.is_empty():
		return

	if _overlay_module.has_active_overlay():
		if _overlay_module.active_overlay_kind() != OVERLAY_DIALOG:
			return

	var payload := _queue.pop_front() as Dictionary
	if payload.is_empty():
		return

	if _player != null:
		_player.pause_exploration_commands()

	if not _overlay_module.open_overlay(OVERLAY_DIALOG):
		if _player != null and _is_gameplay_active():
			_player.resume_exploration_commands()
		_queue.push_front(payload)
		return

	var overlay := _overlay_module.active_overlay()
	if overlay == null:
		_queue.push_front(payload)
		return

	if overlay.has_method("set_dialog"):
		overlay.call(
			"set_dialog",
			String(payload.get("title", "Notice")),
			String(payload.get("text", "")),
			"Continue",
		)

	_showing_dialog = true
	_active_payload = payload


func _on_player_turn_action(cmd: GridCommand.Type) -> void:
	if cmd == GridCommand.Type.STEP_FORWARD:
		queue_phrase("onboarding.first_move")
		return
	if cmd == GridCommand.Type.STEP_BACK:
		queue_phrase("onboarding.first_move")
		return
	if cmd == GridCommand.Type.MOVE_LEFT:
		queue_phrase("onboarding.first_move")
		return
	if cmd == GridCommand.Type.MOVE_RIGHT:
		queue_phrase("onboarding.first_move")
		return
	if cmd == GridCommand.Type.TURN_LEFT:
		queue_phrase("onboarding.first_move")
		return
	if cmd == GridCommand.Type.TURN_RIGHT:
		queue_phrase("onboarding.first_move")


func _on_hostile_spotted_first_time(_hostile) -> void:
	queue_phrase("onboarding.first_enemy")


func _on_action_feedback(text: String, _is_positive: bool) -> void:
	if text == "INVENTORY FULL":
		queue_phrase("onboarding.inventory_full")
		return
	if text == "DISPOSED":
		queue_phrase("onboarding.disposal_chute")
		if _turn_manager != null and _turn_manager.is_floor_clean():
			queue_phrase("onboarding.first_floor_complete")
		return


func _on_turn_completed() -> void:
	_check_debris_timer_prompts()


func _check_debris_timer_prompts() -> void:
	if _world_root == null or _world_root.get_tree() == null:
		return
	for node in _world_root.get_tree().get_nodes_in_group(&"world_pickups"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is WorldPickup):
			continue
		var pickup := node as WorldPickup
		if pickup.item_data == null:
			continue
		if pickup.item_data.item_type != ItemData.ItemType.DEBRIS:
			continue
		if pickup.revert_turns_remaining > 0:
			queue_phrase("onboarding.first_revert_timer")
		if pickup.revert_turns_remaining > 0 and pickup.revert_turns_remaining <= 2:
			queue_phrase("onboarding.debris_revert_warning")
		return


func _on_item_added(item) -> void:
	if item == null:
		return
	if item is ItemData:
		var item_data := item as ItemData
		queue_phrase("onboarding.first_pickup")
		if item_data.item_type == ItemData.ItemType.DEBRIS:
			queue_phrase("onboarding.pickup_debris")


func _on_item_used(item) -> void:
	if not (item is ItemData):
		return
	var item_data := item as ItemData
	if item_data.stat_effect.has("heal"):
		if int(item_data.stat_effect.get("heal", 0)) > 0:
			queue_phrase("onboarding.potion_use")


func _on_player_damaged(_amount: int, _old_health: int, new_health: int) -> void:
	if _player == null or _player.stats == null:
		return
	if _player.stats.max_health <= 0:
		return
	queue_phrase("onboarding.player_hit")
	var threshold := float(_player.stats.max_health) * LOW_HP_RATIO
	if float(new_health) <= threshold:
		queue_phrase("onboarding.low_hp")


func _on_debris_weapon(_cell: Vector2i) -> void:
	queue_phrase("onboarding.debris_weapon")


func _on_debris_reverted(_cell: Vector2i, _hostile_definition_id: StringName) -> void:
	queue_phrase("onboarding.debris_reverted")


func _on_debris_dropped(_cell: Vector2i) -> void:
	queue_phrase("onboarding.drop_debris")


func _on_hostile_hit(
		_definition_id: StringName,
		_used_item_name: String,
		is_effective: bool,
		_item_consumed: bool,
		_item_is_aoe: bool,
		hostile_cleared: bool,
) -> void:
	if not hostile_cleared:
		queue_phrase("onboarding.hostile_survived")
	elif is_effective:
		queue_phrase("onboarding.hostile_killed_effective")
	else:
		queue_phrase("onboarding.hostile_killed_noneffective")


func _on_aoe_multi_hit(item_name: String, hit_count: int) -> void:
	if hit_count <= 1:
		return
	if item_name.to_lower().contains("splash"):
		queue_phrase("onboarding.splash_aoe")


func _success_phrase_for_percent(clean_percent: int) -> String:
	var grade := JobRating.grade_for_percent(clean_percent)
	if grade == JobRating.Grade.A:
		return "outcome.job_rating_a"
	if grade == JobRating.Grade.C:
		return "outcome.job_rating_c"
	if grade == JobRating.Grade.D:
		return "outcome.job_rating_d"
	return "outcome.floor_complete"


func _format_text(raw: String, tokens: Dictionary) -> String:
	var result := raw
	if tokens.has("N"):
		result = result.replace("[N]", str(tokens["N"]))
	else:
		result = result.replace("[N]", str(_floor_number))
	for key in tokens.keys():
		var token := "{%s}" % String(key)
		result = result.replace(token, str(tokens[key]))
	return result


func _is_gameplay_active() -> bool:
	if _world_root == null:
		return false
	if not _world_root.has_method("is_gameplay_state_active"):
		return false
	return bool(_world_root.call("is_gameplay_state_active"))


func _load_seen_state() -> void:
	_seen.clear()
	if not ENABLE_SEEN_STATE_PERSISTENCE:
		return
	var config := ConfigFile.new()
	if config.load(STORAGE_PATH) != OK:
		return
	var keys := config.get_section_keys(STORAGE_SECTION)
	for key in keys:
		_seen[String(key)] = bool(config.get_value(STORAGE_SECTION, key, false))


func _save_seen_state() -> void:
	if not ENABLE_SEEN_STATE_PERSISTENCE:
		return
	var config := ConfigFile.new()
	# Load existing state first to preserve previously seen messages
	if config.load(STORAGE_PATH) == OK:
		var existing_keys := config.get_section_keys(STORAGE_SECTION)
		for key in existing_keys:
			if not _seen.has(key):
				_seen[String(key)] = bool(config.get_value(STORAGE_SECTION, key, false))
	# Now save all seen messages
	for key in _seen.keys():
		config.set_value(STORAGE_SECTION, key, bool(_seen[key]))
	config.save(STORAGE_PATH)


func _has_seen(key: String) -> bool:
	return bool(_seen.get(key, false))


func _mark_seen(key: String) -> void:
	if key.is_empty():
		return
	if _has_seen(key):
		return
	_seen[key] = true
	_save_seen_state()


func clear_all_seen_state() -> void:
	_seen.clear()
	if STORAGE_PATH.is_empty():
		return
	var file := FileAccess.open(STORAGE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("")
