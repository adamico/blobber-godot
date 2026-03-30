extends SceneTree
func _init():
    var tmpl = load("res://scenes/world/main.tscn")
    var main = tmpl.instantiate()
    var gm = main.get_node("GridMap")
    var cells = gm.get_used_cells()
    var floors = 0
    var walls = 0
    for c in cells:
        if gm.get_cell_item(c) == 1:
            floors += 1
        elif gm.get_cell_item(c) == 0:
            walls += 1
    print("Floors: ", floors, " Walls: ", walls)
    quit()
