extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func _make_item(
		item_name: String,
		effects: Dictionary,
		item_type: int = ItemData.ItemType.CONSUMABLE,
):
	var item := ItemData.new()
	item.item_name = item_name
	item.stat_effect = effects
	item.item_type = item_type as ItemData.ItemType
	return item


func test_player_initializes_inventory() -> void:
	var player := _spawn_player()
	assert_not_null(player.inventory)
	assert_eq(player.inventory.size(), 0)


func test_add_and_remove_item_through_player() -> void:
	var player := _spawn_player()
	var potion: Variant = _make_item("Potion", { "heal": 2 })

	assert_true(player.add_item(potion))
	assert_eq(player.inventory.size(), 1)
	assert_true(player.remove_item(potion))
	assert_eq(player.inventory.size(), 0)
