class_name MessItem
extends Sprite3D

@export var item_data: ItemData
@export var grid_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group(&"interactable")
	
	if (item_data == null or item_data.texture == null) and texture == null:
		texture = load("res://assets/textures/mess_slime.png")
	elif item_data != null and item_data.texture != null:
		texture = item_data.texture

	billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	pixel_size = 0.0008 # Scale 1024px to ~0.8 units
	_sync_position()


func _process(_delta: float) -> void:
	# Simple floating animation
	var time := Time.get_ticks_msec() / 1000.0
	var bob := sin(time * 2.0) * 0.05
	global_position.y = GridMapper.cell_to_world(grid_cell, 1.0, 0.2).y + bob


func matches_cell(cell: Vector2i) -> bool:
	return cell == grid_cell


func interact(player: Player) -> void:
	if player.add_item(item_data):
		print("[MessItem] Picked up %s" % item_data.item_name)
		queue_free()


func _sync_position() -> void:
	# Initial position sync
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, 0.2)
