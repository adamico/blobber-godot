extends GutTest

const WORLD_SCENE := preload("res://scenes/world/main.tscn")


func _spawn_world() -> Node3D:
	var world := WORLD_SCENE.instantiate() as Node3D
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	return world

func _player(world: Node3D) -> Player:
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player, "Expected Player node in world scene")
	return player

func _grid_map(world: Node3D) -> GridMap:
	var grid_map := world.get_node_or_null("GridMap") as GridMap
	assert_not_null(grid_map, "Expected GridMap node in world scene")
	return grid_map

func _set_player_state(player: Player, cell: Vector2i, facing: GridDefinitions.Facing) -> void:
	player.grid_state.cell = cell
	player.grid_state.facing = facing
	player.apply_canonical_transform()

func _cell3(cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x, 0, cell.y)


func _north(cell: Vector2i) -> Vector2i:
	return cell + GridDefinitions.facing_to_vec2i(GridDefinitions.Facing.NORTH)

func _make_item(item_name: String, properties: Array[StringName] = []) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.properties = properties
	return item

func test_pickup_mess_item_from_target_cell() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	var grid_map := _grid_map(world)

	var start := Vector2i(40, 40)
	var target := _north(start)
	_set_player_state(player, start, GridDefinitions.Facing.NORTH)

	# Place Slime by ID 4
	grid_map.set_cell_item(_cell3(target), 4)

	assert_eq(player.inventory.size(), 0)
	world.perform_interaction()
	assert_eq(player.inventory.size(), 1)

	var item := player.inventory.get_items()[0] as ItemData
	assert_eq(item.item_name, "Slime")
	assert_eq(grid_map.get_cell_item(_cell3(target)), -1) # Cell should be cleared after pickup


func test_pickup_mess_item_from_current_cell() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	var grid_map := _grid_map(world)

	var start := Vector2i(40, 40)
	var target := _north(start)
	_set_player_state(player, start, GridDefinitions.Facing.NORTH)
	
	grid_map.set_cell_item(_cell3(target), -1) # Ensure target cell is empty
	grid_map.set_cell_item(_cell3(start), 5) # Place Rust on current cell
	
	assert_eq(player.inventory.size(), 0)
	world.perform_interaction()
	assert_eq(player.inventory.size(), 1)
	assert_eq(player.inventory.get_items()[0].item_name, "Rust")
	assert_eq(grid_map.get_cell_item(_cell3(start)), -1) # Cell should be cleared after pickup

func test_receptacle_cleanup_from_target_cell() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	var grid_map := _grid_map(world)

	var start := Vector2i(44, 44)
	var target := _north(start)
	_set_player_state(player, start, GridDefinitions.Facing.NORTH)

	var flammable_item := _make_item("Trash", [&"flammable"])
	assert_true(player.add_item(flammable_item))
	assert_eq(player.inventory.size(), 1)

	grid_map.set_cell_item(_cell3(target), 1)

	var before_score := world.get_cleanup_score() as float
	world.perform_interaction()

	assert_eq(player.inventory.size(), 0)
	assert_eq(world.get_cleanup_score() as float, before_score + 10) # Assuming flammable item gives 10 points
