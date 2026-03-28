extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MESS_ITEM_SCENE := preload("res://scenes/world/entities/mess_item.gd")
const RECEPTACLE_SCENE := preload("res://scenes/world/entities/receptacle.gd")

func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player

func _make_item(item_name: String, properties: Array[StringName] = []) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.properties = properties
	return item

func test_pickup_mess_item() -> void:
	var player := _spawn_player()
	var item_data := _make_item("Biohazard", [&"volatile"])
	
	var mess := MessItem.new()
	mess.item_data = item_data
	mess.grid_cell = Vector2i(0, -1)
	add_child_autofree(mess)
	
	# Facing North, (0,0) -> (0,-1)
	player.grid_state.cell = Vector2i(0, 0)
	player.grid_state.facing = GridDefinitions.Facing.NORTH
	
	assert_eq(player.inventory.size(), 0)
	assert_true(player.interact())
	assert_eq(player.inventory.size(), 1)
	assert_eq(player.inventory.get_items()[0].item_name, "Biohazard")
	assert_true(mess.is_queued_for_deletion())

func test_receptacle_cleanup() -> void:
	var player := _spawn_player()
	var item_data := _make_item("Trash", [&"flammable"])
	player.add_item(item_data)
	
	var receptacle := Receptacle.new()
	receptacle.receptacle_type = Receptacle.Type.SMELTER
	receptacle.required_property = &"flammable"
	receptacle.grid_cell = Vector2i(0, -1)
	add_child_autofree(receptacle)
	
	player.grid_state.cell = Vector2i(0, 0)
	player.grid_state.facing = GridDefinitions.Facing.NORTH
	
	watch_signals(receptacle)
	
	assert_eq(player.inventory.size(), 1)
	assert_true(player.interact())
	assert_eq(player.inventory.size(), 0)
	assert_signal_emitted(receptacle, "item_cleaned")

func test_active_hazard_defusal() -> void:
	var player := _spawn_player()
	var counter_item := _make_item("Water Potion", [&"wet"])
	player.add_item(counter_item)
	
	var hazard_module := WorldHazardModule.new()
	hazard_module.hazardous_cells[Vector2i(0, -1)] = &"volatile"
	add_child_autofree(hazard_module)
	
	player.grid_state.cell = Vector2i(0, 0)
	player.grid_state.facing = GridDefinitions.Facing.NORTH
	
	# We simulate the Main.gd interaction logic here
	var target_cell = Vector2i(0, -1)
	assert_true(hazard_module.interact(player, target_cell))
	assert_false(hazard_module.hazardous_cells.has(target_cell))

func test_undefused_hazard_triggers_penalty() -> void:
	var player := _spawn_player()
	player.stats.stamina = 5
	
	var hazard_module := WorldHazardModule.new()
	hazard_module.hazardous_cells[Vector2i(0, 1)] = &"corrosive"
	add_child_autofree(hazard_module)
	
	# If we just move into it without defusing
	assert_false(hazard_module.evaluate_hazard(player, Vector2i(0, 1)))
	assert_eq(player.stats.stamina, 4)
