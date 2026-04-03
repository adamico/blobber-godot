extends GutTest

const WorldChestScript = preload("res://scenes/world/world_chest.gd")
const WorldTurnManagerScript = preload("res://scenes/world/modules/world_turn_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")


func _make_item(item_name: String = "Chest Item") -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.item_type = ItemData.ItemType.TOOL
	return item


func _make_player(cell: Vector2i = Vector2i.ZERO) -> Player:
	var player: Player = PlayerScene.instantiate()
	add_child_autofree(player)
	player.grid_state = GridState.new(cell, GridDefinitions.Facing.NORTH)
	player.apply_canonical_transform()
	return player


func test_chest_is_registered_as_interactable() -> void:
	var chest: WorldChest = WorldChestScript.new()
	add_child_autofree(chest)
	assert_true(chest.is_in_group(&"world_interactables"))
	assert_true(chest.is_in_group(&"world_chests"))
	assert_true(chest.blocks_movement)


func test_chest_interact_transfers_item_and_opens() -> void:
	var chest: WorldChest = WorldChestScript.new()
	chest.item_data = _make_item()
	add_child_autofree(chest)

	var player := _make_player()
	var result := chest.interact(player)

	assert_true(bool(result.get("ok", false)))
	assert_true(chest.is_open)
	assert_true(chest.is_queued_for_deletion())
	assert_eq(player.inventory.size(), 1)


func test_chest_interact_fails_when_inventory_full() -> void:
	var chest: WorldChest = WorldChestScript.new()
	chest.item_data = _make_item()
	add_child_autofree(chest)

	var player := _make_player()
	player.add_item(_make_item("A"))
	player.add_item(_make_item("B"))
	player.add_item(_make_item("C"))

	var result := chest.interact(player)
	assert_false(bool(result.get("ok", true)))
	assert_false(chest.is_open)
	assert_eq(player.inventory.size(), 3)


func test_turn_manager_interact_advances_turn_on_success() -> void:
	var world: Node = add_child_autofree(Node.new())
	var player := _make_player()
	var manager: WorldTurnManager = add_child_autofree(WorldTurnManagerScript.new())
	manager.configure(player, null, null, world)

	var chest: WorldChest = WorldChestScript.new()
	chest.grid_cell = Vector2i(0, -1)
	chest.item_data = _make_item()
	world.add_child(chest)
	watch_signals(manager)

	manager.process_player_interact()

	assert_signal_emit_count(manager, "turn_completed", 1)
	assert_eq(player.inventory.size(), 1)
	assert_true(chest.is_queued_for_deletion())


func test_turn_manager_interact_no_target_does_not_advance_turn() -> void:
	var world: Node = add_child_autofree(Node.new())
	var player := _make_player()
	var manager: WorldTurnManager = add_child_autofree(WorldTurnManagerScript.new())
	manager.configure(player, null, null, world)
	watch_signals(manager)

	manager.process_player_interact()

	assert_signal_emit_count(manager, "turn_completed", 0)
