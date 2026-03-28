extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func _make_item(item_name: String, properties: Array[StringName] = []) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.properties = properties
	return item


func test_player_initializes_inventory() -> void:
	var player := _spawn_player()
	assert_not_null(player.inventory)
	assert_eq(player.inventory.size(), 0)


func test_add_and_remove_item_through_player() -> void:
	var player := _spawn_player()
	var trash := _make_item("Trash", [&"messy"])

	assert_true(player.add_item(trash))
	assert_eq(player.inventory.size(), 1)
	assert_true(player.remove_item(trash))
	assert_eq(player.inventory.size(), 0)


func test_inventory_capacity_scaling() -> void:
	var player := _spawn_player()
	player.inventory.max_capacity = 3

	var item1 := _make_item("Item1")
	var item2 := _make_item("Item2")
	var item3 := _make_item("Item3")

	player.add_item(item1)
	player.add_item(item2)
	player.add_item(item3)

	assert_eq(player.inventory.size(), 3)

	# Simulate stamina drop to 50%
	player.inventory.max_capacity = 2
	# Force enforcement
	player.call(&"_enforce_inventory_capacity")

	assert_eq(player.inventory.size(), 2)
	assert_eq(player.inventory.get_items()[0], item1)
	assert_eq(player.inventory.get_items()[1], item2)


func test_add_item_at_capacity_returns_false() -> void:
	var player := _spawn_player()
	player.inventory.max_capacity = 1

	var item1 := _make_item("Item1")
	var item2 := _make_item("Item2")

	assert_true(player.add_item(item1))
	assert_false(player.add_item(item2))
	assert_eq(player.inventory.size(), 1)


func test_use_item_invalid_index_returns_false() -> void:
	var player := _spawn_player()
	assert_false(player.use_item(0))
