## Hostile definition refactor regression tests.
## Ensures hostiles are data-driven and revert uses definition IDs.
extends GutTest

const BurningHostile = preload("res://resources/hostiles/burning_hazard.tres")
const CorrosiveHostile = preload("res://resources/hostiles/corrosive_hazard.tres")
const CursedHostile = preload("res://resources/hostiles/cursed_hazard.tres")
const WorldPickupScript = preload("res://components/world_pickup.gd")
const WorldTurnManagerScript = preload("res://scenes/world/modules/world_turn_manager.gd")
const WorldEncounterModuleScript = preload("res://scenes/world/modules/world_encounter_module.gd")


class FakeWorldRoot:
	extends Node

	var spawn_by_id_calls: Array = []


	func _spawn_hostile_by_id(cell: Vector2i, definition_id: StringName) -> void:
		spawn_by_id_calls.append([cell, definition_id])


class FakeEnemy:
	extends Node

	var movement_controller = null


	func tick_ai(_player) -> void:
		pass


func test_definition_capabilities_are_data_driven() -> void:
	assert_false(BurningHostile.instant_clear_on_debris)
	assert_true(CorrosiveHostile.instant_clear_on_debris)
	assert_false(CursedHostile.instant_clear_on_debris)


func test_definitions_point_to_dedicated_scenes() -> void:
	assert_eq(BurningHostile.actor_scene.resource_path, "res://scenes/hostiles/burning_hazard.tscn")
	assert_eq(CursedHostile.actor_scene.resource_path, "res://scenes/hostiles/cursed_hazard.tscn")
	assert_eq(
		CorrosiveHostile.actor_scene.resource_path,
		"res://scenes/hostiles/corrosive_hazard.tscn",
	)


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

	var enemy = FakeEnemy.new()
	world.add_child(enemy)

	encounter.register_hostile(enemy)
	encounter.collect()

	assert_eq(encounter.get_enemies().size(), 1)
	assert_true(encounter.get_enemies().has(enemy))


func test_encounter_unregister_removes_enemy_from_active_list() -> void:
	var world = add_child_autofree(Node.new())
	var encounter = add_child_autofree(WorldEncounterModuleScript.new())
	encounter.configure(world, null, null)

	var enemy = FakeEnemy.new()
	world.add_child(enemy)

	encounter.register_hostile(enemy)
	encounter.unregister_hostile(enemy)
	encounter.collect()

	assert_eq(encounter.get_enemies().size(), 0)


func test_encounter_collect_prunes_freed_registered_enemy() -> void:
	var world = add_child_autofree(Node.new())
	var encounter = add_child_autofree(WorldEncounterModuleScript.new())
	encounter.configure(world, null, null)

	var enemy = FakeEnemy.new()
	world.add_child(enemy)

	encounter.register_hostile(enemy)
	enemy.free()
	encounter.collect()

	assert_eq(encounter.get_enemies().size(), 0)
