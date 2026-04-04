extends GutTest

const LoaderScript = preload("res://scenes/world/modules/world_authored_floor_loader.gd")


func _make_grid_map() -> GridMap:
	var grid_map := GridMap.new()
	grid_map.set_cell_item(Vector3i(2, 0, 3), LoaderScript.MARKER_WALL)
	grid_map.set_cell_item(Vector3i(4, 1, 5), LoaderScript.MARKER_PLAYER_SPAWN)
	grid_map.set_cell_item(Vector3i(7, 1, 8), LoaderScript.MARKER_DISPOSAL_CHUTE)
	grid_map.set_cell_item(Vector3i(9, 1, 2), LoaderScript.MARKER_FLOOR_EXIT)
	grid_map.set_cell_item(Vector3i(5, 2, 4), LoaderScript.MARKER_HOSTILE_BURNING)
	grid_map.set_cell_item(Vector3i(6, 2, 4), LoaderScript.MARKER_HOSTILE_CURSED)
	grid_map.set_cell_item(Vector3i(7, 2, 4), LoaderScript.MARKER_HOSTILE_CORROSIVE)
	grid_map.set_cell_item(Vector3i(1, 1, 1), LoaderScript.MARKER_MOP)
	grid_map.set_cell_item(Vector3i(1, 1, 2), LoaderScript.MARKER_DEBRIS)
	return grid_map


func test_parse_grid_map_collects_authored_markers() -> void:
	var loader = LoaderScript.new()
	var result: Dictionary = loader.parse_grid_map(_make_grid_map())

	assert_true(bool(result.get("ok", false)))
	assert_true(bool(result.get("has_player_spawn", false)))
	assert_eq(result.get("player_spawn"), Vector2i(4, 5))
	assert_eq(result.get("chute_cells").size(), 1)
	assert_eq(result.get("exit_cells").size(), 1)
	assert_eq(result.get("hostile_spawns").size(), 3)
	assert_eq(result.get("chest_spawns").size(), 2)


func test_parse_grid_map_requires_player_spawn() -> void:
	var loader = LoaderScript.new()
	var grid_map := GridMap.new()
	grid_map.set_cell_item(Vector3i(1, 1, 1), LoaderScript.MARKER_MOP)

	var result: Dictionary = loader.parse_grid_map(grid_map)

	assert_false(bool(result.get("ok", true)))
	assert_eq(result.get("errors").size(), 1)


func test_duplicate_player_spawn_warns_and_keeps_first() -> void:
	var loader = LoaderScript.new()
	var grid_map := GridMap.new()
	grid_map.set_cell_item(Vector3i(1, 1, 1), LoaderScript.MARKER_PLAYER_SPAWN)
	grid_map.set_cell_item(Vector3i(2, 1, 2), LoaderScript.MARKER_PLAYER_SPAWN)

	var result: Dictionary = loader.parse_grid_map(grid_map)

	assert_true(bool(result.get("has_player_spawn", false)))
	assert_eq(result.get("player_spawn"), Vector2i(1, 1))
	assert_eq(result.get("warnings").size(), 1)


func test_load_into_world_mounts_grid_map() -> void:
	var loader = LoaderScript.new()
	var world_root: Node3D = add_child_autofree(Node3D.new())
	var grid_map := _make_grid_map()
	var packed_scene := PackedScene.new()
	assert_eq(packed_scene.pack(grid_map), OK)

	var result: Dictionary = loader.load_into_world(world_root, packed_scene)

	assert_true(bool(result.get("ok", false)))
	assert_true(world_root.has_node("GridMap"))
	assert_true(result.get("grid_map") is GridMap)


func test_clear_positioning_cells_removes_authoring_markers_only() -> void:
	var loader = LoaderScript.new()
	var grid_map := _make_grid_map()
	var layout: Dictionary = loader.parse_grid_map(grid_map)

	loader.clear_positioning_cells(grid_map, layout)

	assert_eq(grid_map.get_cell_item(Vector3i(4, 1, 5)), -1)
	assert_eq(grid_map.get_cell_item(Vector3i(7, 1, 8)), -1)
	assert_eq(grid_map.get_cell_item(Vector3i(9, 1, 2)), -1)
	assert_eq(grid_map.get_cell_item(Vector3i(5, 2, 4)), -1)
	assert_eq(grid_map.get_cell_item(Vector3i(1, 1, 1)), -1)
	assert_eq(grid_map.get_cell_item(Vector3i(2, 0, 3)), LoaderScript.MARKER_WALL)
