class_name Inventory
extends Resource

signal item_added(item)
signal item_removed(item)
signal item_used(item)

const MAX_SLOTS := 3

var _items: Array = []


func add_item(item) -> bool:
	if not (item is ItemData):
		return false
	if item == null:
		return false
	if _items.size() >= MAX_SLOTS:
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


func remove_at(index: int) -> bool:
	if index < 0 or index >= _items.size():
		return false
	var removed = _items[index]
	_items.remove_at(index)
	item_removed.emit(removed)
	return true


func get_items() -> Array:
	return _items.duplicate()


func get_item_at(index: int) -> ItemData:
	if index < 0 or index >= _items.size():
		return null
	return _items[index]


func size() -> int:
	return _items.size()


func is_full() -> bool:
	return _items.size() >= MAX_SLOTS


func use_item(index: int, target_stats: CharacterStats) -> bool:
	if target_stats == null:
		return false
	if index < 0 or index >= _items.size():
		return false

	var item = _items[index]
	if item == null:
		return false

	_apply_stat_effects(item.stat_effect, target_stats)
	item_used.emit(item)

	if not item.is_reusable:
		_items.remove_at(index)
		item_removed.emit(item)

	return true


func _apply_stat_effects(stat_effect: Dictionary, target_stats: CharacterStats) -> void:
	if stat_effect.has("heal"):
		target_stats.heal(int(stat_effect["heal"]))
