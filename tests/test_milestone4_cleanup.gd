## Milestone 4 regression suite — Disposal & Progression.
##
## Covers:
##   - DisposalChute.accepts_item filters correctly
##   - JobRating grade thresholds (boundary values)
##   - JobRating grade_label / flavor_text return correct strings
##   - ItemData.cleanup_value defaults to 1 and can be overridden
extends GutTest

const JobRatingModel = preload("res://models/job_rating.gd")
const WorldPickupScene = preload("res://scenes/world/world_pickup.gd")
const WorldAnalysisModuleScript = preload("res://scenes/world/modules/world_analysis_module.gd")
const BurningHostileDefinition = preload("res://resources/hostiles/burning_hazard.tres")
const WorldTurnManagerScript = preload("res://scenes/world/modules/world_turn_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")


class FakeInventory:
	extends RefCounted

	var _items: Array[ItemData] = []


	func _init(items: Array[ItemData] = []) -> void:
		_items = items.duplicate()


	func get_item_at(index: int) -> ItemData:
		if index < 0 or index >= _items.size():
			return null
		return _items[index]


	func remove_at(index: int) -> bool:
		if index < 0 or index >= _items.size():
			return false
		_items.remove_at(index)
		return true


	func size() -> int:
		return _items.size()


class FakeWorldRoot:
	extends Node

	var spawn_by_id_calls: Array = []


	func _spawn_hostile_by_id(cell: Vector2i, definition_id: StringName) -> void:
		spawn_by_id_calls.append([cell, definition_id])


class FakeHostileTarget:
	extends Node3D

	var grid_state: GridState
	var hostile_property: int = RpsSystem.HostileProperty.BURNING
	var hostile_definition_id: StringName = &"burning_hazard"
	var cleanup_value: int = 1
	var revert_turns_base: int = 5
	var _cleared := false


	func _init(cell: Vector2i = Vector2i.ZERO) -> void:
		grid_state = GridState.new(cell, GridDefinitions.Facing.NORTH)


	func is_cleared() -> bool:
		return _cleared


	func deal_contact_damage(_stats: CharacterStats) -> void:
		pass


	func receive_tool_hit(_tool_property: int, _stats: CharacterStats = null) -> bool:
		return false


class TestWorldTurnManager:
	extends WorldTurnManager

	func set_total_cleanup_value_for_test(value: int) -> void:
		_total_cleanup_value = value


	func register_disposal_for_test(item: ItemData) -> void:
		_register_disposal(item)


	func tick_debris_revert_for_test() -> void:
		_tick_debris_revert()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_debris(cleanup_val: int = 1) -> ItemData:
	var item := ItemData.new()
	item.item_name = "Test Debris"
	item.item_type = ItemData.ItemType.DEBRIS
	item.cleanup_value = cleanup_val
	return item


func _make_tool() -> ItemData:
	var item := ItemData.new()
	item.item_name = "Test Tool"
	item.item_type = ItemData.ItemType.TOOL
	return item


func _make_consumable() -> ItemData:
	var item := ItemData.new()
	item.item_name = "Test Consumable"
	item.item_type = ItemData.ItemType.CONSUMABLE
	return item


func _make_chute(cell: Vector2i) -> DisposalChute:
	var chute := DisposalChute.new()
	chute.grid_cell = cell
	add_child_autofree(chute)
	return chute


func _make_turn_manager() -> TestWorldTurnManager:
	var manager: TestWorldTurnManager = add_child_autofree(TestWorldTurnManager.new())
	return manager


func _make_analysis_module() -> WorldAnalysisModule:
	var module: WorldAnalysisModule = add_child_autofree(WorldAnalysisModuleScript.new())
	return module


func _make_player(cell: Vector2i = Vector2i.ZERO) -> Player:
	var player: Player = PlayerScene.instantiate()
	add_child_autofree(player)
	player.grid_state = GridState.new(cell, GridDefinitions.Facing.NORTH)
	player.apply_canonical_transform()
	return player


func _make_world_root() -> FakeWorldRoot:
	var root := FakeWorldRoot.new()
	add_child_autofree(root)
	return root

# ---------------------------------------------------------------------------
# DisposalChute — cell matching
# ---------------------------------------------------------------------------


func test_chute_matches_its_own_cell() -> void:
	var chute := _make_chute(Vector2i(3, 4))
	assert_true(chute.matches_cell(Vector2i(3, 4)))


func test_chute_does_not_match_different_cell() -> void:
	var chute := _make_chute(Vector2i(3, 4))
	assert_false(chute.matches_cell(Vector2i(2, 4)))

# ---------------------------------------------------------------------------
# DisposalChute — item acceptance
# ---------------------------------------------------------------------------


func test_chute_accepts_debris() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	var debris := _make_debris()
	assert_true(chute.accepts_item(debris))


func test_chute_rejects_tool() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	var tool := _make_tool()
	assert_false(chute.accepts_item(tool))


func test_chute_rejects_consumable() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	var consumable := _make_consumable()
	assert_false(chute.accepts_item(consumable))


func test_chute_rejects_null_item() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	assert_false(chute.accepts_item(null))

# ---------------------------------------------------------------------------
# DisposalChute — group membership
# ---------------------------------------------------------------------------


func test_chute_is_in_disposal_chutes_group() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	assert_true(chute.is_in_group(&"disposal_chutes"))

# ---------------------------------------------------------------------------
# ItemData — cleanup_value
# ---------------------------------------------------------------------------


func test_item_data_cleanup_value_defaults_to_one() -> void:
	var item := ItemData.new()
	assert_eq(item.cleanup_value, 1)


func test_item_data_cleanup_value_can_be_set() -> void:
	var item := _make_debris(3)
	assert_eq(item.cleanup_value, 3)


func test_item_data_definition_id_defaults_empty() -> void:
	var item := ItemData.new()
	assert_eq(item.origin_hostile_definition_id, StringName())


func test_world_pickup_revert_tracks_definition_id() -> void:
	var pickup := WorldPickupScene.new()
	add_child_autofree(pickup)
	pickup.setup_revert(4, &"burning_hazard")
	assert_eq(pickup.revert_turns_remaining, 4)
	assert_eq(pickup.origin_hostile_definition_id, &"burning_hazard")


func test_burning_definition_uses_shared_scene_pattern_data() -> void:
	assert_null(BurningHostileDefinition.actor_scene)
	assert_not_null(BurningHostileDefinition.sprite_texture)

# ---------------------------------------------------------------------------
# WorldTurnManager — disposal and debris reversion
# ---------------------------------------------------------------------------


func test_disposal_caps_cleanup_credit_at_total() -> void:
	var manager := _make_turn_manager()
	manager.set_total_cleanup_value_for_test(3)

	watch_signals(manager)
	manager.register_disposal_for_test(_make_debris(2))
	manager.register_disposal_for_test(_make_debris(2))

	assert_eq(manager.get_clean_cleared(), 3)
	assert_eq(manager.get_clean_percent(), 100)
	assert_signal_emit_count(manager, "clean_status_changed", 2)
	assert_eq(get_signal_parameters(manager, "clean_status_changed"), [3, 3])


func test_drop_into_chute_disposes_debris_without_spawning_pickup() -> void:
	var manager := _make_turn_manager()
	var player := _make_player(Vector2i.ZERO)
	player.inventory = FakeInventory.new([_make_debris(2)])

	var root := _make_world_root()
	var chute := DisposalChute.new()
	chute.grid_cell = Vector2i(0, -1)
	root.add_child(chute)

	manager.configure(player, null, null, root)
	manager.set_total_cleanup_value_for_test(2)

	watch_signals(manager)
	manager.process_player_drop(0)

	assert_eq(player.inventory.size(), 0)
	assert_eq(manager.get_clean_cleared(), 2)
	assert_eq(manager.get_clean_percent(), 100)
	assert_eq(root.get_tree().get_nodes_in_group(&"world_pickups").size(), 0)
	assert_signal_emitted_with_parameters(manager, "action_feedback", ["DISPOSED", true])


func test_debris_revert_respawns_from_definition_id() -> void:
	var manager := _make_turn_manager()
	var root := _make_world_root()
	manager.configure(null, null, null, root)

	var pickup := WorldPickupScene.new()
	pickup.item_data = _make_debris()
	pickup.grid_cell = Vector2i(4, 5)
	root.add_child(pickup)
	pickup.setup_revert(1, &"burning_hazard")

	manager.tick_debris_revert_for_test()

	assert_eq(root.spawn_by_id_calls.size(), 1)
	assert_eq(root.spawn_by_id_calls[0], [Vector2i(4, 5), &"burning_hazard"])


func test_disposal_advances_chute_and_debris_item_knowledge() -> void:
	var module: WorldAnalysisModule = _make_analysis_module()

	var debris := _make_debris(1)
	debris.description = (
		"Inert waste that obstructs movement.\n"
		+ "Dispose it at a chute to convert it into cleanup credit."
	)
	module.register_disposal(debris)
	var chute_snapshot: Dictionary = module.get_knowledge_snapshot(module.ANALYSIS_CHUTE_KEY)
	var debris_snapshot: Dictionary = module.get_knowledge_snapshot(&"pickup:Test Debris")

	assert_true(bool(chute_snapshot.get(module.KNOWLEDGE_TIER_1, false)))
	assert_true(bool(debris_snapshot.get(module.KNOWLEDGE_TIER_1, false)))


func test_repeated_disposal_advances_debris_knowledge_to_next_tier() -> void:
	var module: WorldAnalysisModule = _make_analysis_module()

	var debris := _make_debris(1)
	debris.description = (
		"Inert waste that obstructs movement.\n"
		+ "Dispose it at a chute to convert it into cleanup credit."
	)
	module.register_disposal(debris)
	module.register_disposal(debris)
	var debris_snapshot: Dictionary = module.get_knowledge_snapshot(&"pickup:Test Debris")

	assert_true(bool(debris_snapshot.get(module.KNOWLEDGE_TIER_2, false)))


func test_analyze_consumes_turn_when_new_information_unlocked() -> void:
	var manager := _make_turn_manager()
	var player := _make_player(Vector2i.ZERO)
	var root := _make_world_root()
	var hostile := FakeHostileTarget.new(Vector2i(0, -1))
	root.add_child(hostile)
	hostile.add_to_group(&"grid_hostiles")
	manager.configure(player, null, null, root)

	watch_signals(manager)
	manager.process_analyze_target()

	assert_signal_emit_count(manager, "turn_completed", 1)


func test_analyze_without_new_information_is_free_action() -> void:
	var manager := _make_turn_manager()
	var player := _make_player(Vector2i.ZERO)
	var root := _make_world_root()
	var hostile := FakeHostileTarget.new(Vector2i(0, -1))
	root.add_child(hostile)
	hostile.add_to_group(&"grid_hostiles")
	manager.configure(player, null, null, root)

	watch_signals(manager)
	manager.process_analyze_target()
	manager.process_analyze_target()

	assert_signal_emit_count(manager, "turn_completed", 1)

# ---------------------------------------------------------------------------
# JobRating — grade thresholds (boundary values)
# ---------------------------------------------------------------------------


func test_grade_90_is_a() -> void:
	assert_eq(JobRatingModel.grade_for_percent(90), JobRatingModel.Grade.A)


func test_grade_100_is_a() -> void:
	assert_eq(JobRatingModel.grade_for_percent(100), JobRatingModel.Grade.A)


func test_grade_89_is_b() -> void:
	assert_eq(JobRatingModel.grade_for_percent(89), JobRatingModel.Grade.B)


func test_grade_70_is_b() -> void:
	assert_eq(JobRatingModel.grade_for_percent(70), JobRatingModel.Grade.B)


func test_grade_69_is_c() -> void:
	assert_eq(JobRatingModel.grade_for_percent(69), JobRatingModel.Grade.C)


func test_grade_50_is_c() -> void:
	assert_eq(JobRatingModel.grade_for_percent(50), JobRatingModel.Grade.C)


func test_grade_49_is_d() -> void:
	assert_eq(JobRatingModel.grade_for_percent(49), JobRatingModel.Grade.D)


func test_grade_0_is_d() -> void:
	assert_eq(JobRatingModel.grade_for_percent(0), JobRatingModel.Grade.D)

# ---------------------------------------------------------------------------
# JobRating — grade_label
# ---------------------------------------------------------------------------


func test_grade_label_a() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.A), "A")


func test_grade_label_b() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.B), "B")


func test_grade_label_c() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.C), "C")


func test_grade_label_d() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.D), "D")

# ---------------------------------------------------------------------------
# JobRating — flavor_text returns non-empty strings per grade
# ---------------------------------------------------------------------------


func test_flavor_text_a_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.A), "")


func test_flavor_text_b_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.B), "")


func test_flavor_text_c_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.C), "")


func test_flavor_text_d_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.D), "")


func test_flavor_text_grades_are_distinct() -> void:
	var texts := [
		JobRatingModel.flavor_text(JobRatingModel.Grade.A),
		JobRatingModel.flavor_text(JobRatingModel.Grade.B),
		JobRatingModel.flavor_text(JobRatingModel.Grade.C),
		JobRatingModel.flavor_text(JobRatingModel.Grade.D),
	]
	# All four strings should be unique.
	for i in range(texts.size()):
		for j in range(i + 1, texts.size()):
			assert_ne(
				texts[i],
				texts[j],
				"Grades at indices %d and %d share the same flavor text" % [i, j],
			)
