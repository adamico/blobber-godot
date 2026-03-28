extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func _make_heavy_item() -> ItemData:
	var item := ItemData.new()
	item.item_name = "Heavy Trash"
	item.properties = [&"heavy"]
	return item


func test_stamina_drain_and_restore() -> void:
	var player := _spawn_player()
	assert_not_null(player.stats)
	
	var initial_stamina := player.stats.stamina
	player.stats.drain_stamina(2)
	assert_eq(player.stats.stamina, initial_stamina - 2)
	
	player.stats.restore_stamina(1)
	assert_eq(player.stats.stamina, initial_stamina - 1)


func test_heavy_item_drain_over_steps() -> void:
	var player := _spawn_player()
	var heavy_item := _make_heavy_item()
	player.add_item(heavy_item)
	
	var initial_stamina := player.stats.stamina
	
	# Carry over heavy item for 3 steps
	player.call(&"_tick_heavy_items") # step 1
	assert_eq(player.stats.stamina, initial_stamina)
	player.call(&"_tick_heavy_items") # step 2
	assert_eq(player.stats.stamina, initial_stamina)
	player.call(&"_tick_heavy_items") # step 3
	assert_eq(player.stats.stamina, initial_stamina - 1)


func test_exhaustion_slowdown() -> void:
	var player := _spawn_player()
	assert_eq(player.movement_config.step_duration, 0.2)
	
	# Drain stamina to zero
	player.stats.drain_stamina(player.stats.max_stamina)
	assert_true(player.stats.is_exhausted())
	
	# Wait for signal processing if needed, but Player.gd connect(_on_stamina_changed)
	# so we can check it immediately after drain
	assert_eq(player.movement_config.step_duration, 0.4)
