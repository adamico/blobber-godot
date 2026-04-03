## Hostile definition refactor regression tests.
## Ensures hostiles are data-driven and revert uses definition IDs.
extends GutTest

const BurningHostile = preload("res://resources/hostiles/burning_hazard.tres")
const CorrosiveHostile = preload("res://resources/hostiles/corrosive_hazard.tres")
const CursedHostile = preload("res://resources/hostiles/cursed_hazard.tres")
const WorldPickupScript = preload("res://scenes/world/world_pickup.gd")
const WorldTurnManagerScript = preload("res://scenes/world/modules/world_turn_manager.gd")
const WorldEncounterModuleScript = preload("res://scenes/world/modules/world_encounter_module.gd")
const WorldMainScript = preload("res://scenes/world/main.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")


class FakeWorldRoot:
	extends Node

	var spawn_by_id_calls: Array = []


	func _spawn_hostile_by_id(cell: Vector2i, definition_id: StringName) -> void:
		spawn_by_id_calls.append([cell, definition_id])


class FakeHostile:
	extends Node

	var movement_controller = null


	func tick_ai(_player) -> void:
		pass


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


	func use_item(_index: int, _stats: CharacterStats) -> bool:
		return false


	func size() -> int:
		return _items.size()


class LegacyCorrosiveHostile:
	extends Node

	signal hostile_cleared(hostile)

	var grid_state: GridState
	var hazard_property: RpsSystem.HazardProperty = RpsSystem.HazardProperty.CORROSIVE
	var cleared := false
	var hostile_definition_id: StringName = StringName()
	var revert_turns_base: int = 5
	var cleanup_value: int = 1


	func _init(cell: Vector2i) -> void:
		grid_state = GridState.new(cell, GridDefinitions.Facing.NORTH)


	func is_cleared() -> bool:
		return cleared


	func deal_contact_damage(_target_stats) -> void:
		pass


	func receive_tool_hit(tool_property: RpsSystem.ToolProperty, _target_stats = null) -> bool:
		if tool_property == RpsSystem.ToolProperty.INERT:
			cleared = true
			hostile_cleared.emit(self)
			return true
		return false


func test_definition_capabilities_are_data_driven() -> void:
	assert_false(BurningHostile.instant_clear_on_debris)
	assert_true(CorrosiveHostile.instant_clear_on_debris)
	assert_false(CursedHostile.instant_clear_on_debris)


func test_definitions_use_resource_driven_hostile_visuals() -> void:
	assert_null(BurningHostile.actor_scene)
	assert_null(CursedHostile.actor_scene)
	assert_null(CorrosiveHostile.actor_scene)

	assert_not_null(BurningHostile.sprite_texture)
	assert_not_null(CursedHostile.sprite_texture)
	assert_not_null(CorrosiveHostile.sprite_texture)


func test_spawn_uses_shared_hazard_scene_with_definition_visual_data() -> void:
	var world := WorldMainScript.new()
	var actor: Hazard = world.call("_spawn_hostile", Vector2i(3, 2), BurningHostile) as Hazard

	assert_not_null(actor)
	assert_eq(actor.sprite_texture, BurningHostile.sprite_texture)

	world.free()


func test_world_pickup_revert_tracks_origin_definition_id() -> void:
	var pickup = add_child_autofree(WorldPickupScript.new())
	pickup.setup_revert(4, &"burning_hazard")
	assert_eq(pickup.revert_turns_remaining, 4)
	assert_eq(pickup.origin_hostile_definition_id, &"burning_hazard")


func test_debris_revert_respawns_by_definition_id() -> void:
	var world = add_child_autofree(FakeWorldRoot.new())
	var manager = add_child_autofree(WorldTurnManagerScript.new())
	manager.configure(null, null, null, world)

	var pickup = WorldPickupScript.new()
	pickup.grid_cell = Vector2i(7, 3)
	pickup.setup_revert(1, &"corrosive_hazard")
	world.add_child(pickup)
	watch_signals(pickup)

	manager.call("_tick_debris_revert")

	assert_eq(world.spawn_by_id_calls.size(), 1)
	assert_eq(world.spawn_by_id_calls[0], [Vector2i(7, 3), &"corrosive_hazard"])
	assert_true(pickup.is_queued_for_deletion())


func test_encounter_collect_uses_explicit_registration() -> void:
	var world = add_child_autofree(Node.new())
	var encounter = add_child_autofree(WorldEncounterModuleScript.new())
	encounter.configure(world, null, null)

	var hostile = FakeHostile.new()
	world.add_child(hostile)

	encounter.register_hostile(hostile)
	encounter.collect()

	assert_eq(encounter.get_hostiles().size(), 1)
	assert_true(encounter.get_hostiles().has(hostile))


func test_encounter_unregister_removes_enemy_from_active_list() -> void:
	var world = add_child_autofree(Node.new())
	var encounter = add_child_autofree(WorldEncounterModuleScript.new())
	encounter.configure(world, null, null)

	var hostile = FakeHostile.new()
	world.add_child(hostile)

	encounter.register_hostile(hostile)
	encounter.unregister_hostile(hostile)
	encounter.collect()

	assert_eq(encounter.get_hostiles().size(), 0)


func test_encounter_collect_prunes_freed_registered_enemy() -> void:
	var world = add_child_autofree(Node.new())
	var encounter = add_child_autofree(WorldEncounterModuleScript.new())
	encounter.configure(world, null, null)

	var hostile = FakeHostile.new()
	world.add_child(hostile)

	encounter.register_hostile(hostile)
	hostile.free()
	encounter.collect()

	assert_eq(encounter.get_hostiles().size(), 0)


func test_debris_clears_corrosive_even_without_definition_lookup() -> void:
	var world = add_child_autofree(Node.new())
	var manager = add_child_autofree(WorldTurnManagerScript.new())
	var player = add_child_autofree(PlayerScene.instantiate())
	player.grid_state = GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)

	var debris := ItemData.new()
	debris.item_type = ItemData.ItemType.DEBRIS
	debris.item_name = "Test Debris"
	player.inventory = FakeInventory.new([debris])

	var hostile = LegacyCorrosiveHostile.new(Vector2i(0, -1))
	world.add_child(hostile)
	hostile.add_to_group("grid_hostiles")

	manager.configure(player, null, null, world)
	watch_signals(manager)
	manager.process_slot_use(0)

	assert_true(hostile.cleared)
	assert_eq(player.inventory.size(), 0)
	assert_signal_emit_count(manager, "debris_consumed_as_weapon", 1)
