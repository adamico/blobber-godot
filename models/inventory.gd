class_name Inventory
extends Resource

signal item_added(item)
signal item_removed(item)
signal item_used(item)
signal capacity_changed(new_capacity)

var _items: Array = []
var max_capacity: int = 3 :
	set(value):
		if max_capacity != value:
			max_capacity = value
			capacity_changed.emit(max_capacity)

func add_item(item) -> bool:
	if not (item is ItemData):
		return false
	if item == null:
		return false
	if _items.size() >= max_capacity:
		return false
	_items.append(item)
	item_added.emit(item)
	return true

func remove_item(item) -> bool:
	var index := _items.find(item)
	if index == -1:
		return false
	var removed = _items[index]
	_items.remove_at(index)
	item_removed.emit(removed)
	return true

func get_items() -> Array:
	return _items.duplicate()

func size() -> int:
	return _items.size()

func use_item(index: int, target_stats: CharacterStats) -> bool:
	if target_stats == null:
		return false
	if index < 0 or index >= _items.size():
		return false

	var item = _items[index] as ItemData
	if item == null:
		return false
		
	if item.is_potion and item.has_property(&"wet"):
		target_stats.restore_stamina(1)
		item_used.emit(item)
		_items.remove_at(index)
		item_removed.emit(item)
		return true

	return false
