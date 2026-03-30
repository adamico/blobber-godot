extends SceneTree
func _init():
    var tmpl = load("res://scenes/world/main.tscn")
    var main = tmpl.instantiate()
    var gm = main.get_node("GridMap")
    var cells = gm.get_used_cells()
    var min_x = 999
    var max_x = -999
    var min_z = 999
    var max_z = -999
    for c in cells:
        min_x = min(min_x, c.x)
        max_x = max(max_x, c.x)
        min_z = min(min_z, c.z)
        max_z = max(max_z, c.z)
    print("X: ", min_x, " to ", max_x, ", Z: ", min_z, " to ", max_z)
    quit()
