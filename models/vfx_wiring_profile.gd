class_name VFXWiringProfile
extends Resource

@export var entries: Array = []


func find_by_signal_key(signal_key: StringName):
	for entry in find_all_by_signal_key(signal_key):
		return entry
	return null


func find_all_by_signal_key(signal_key: StringName) -> Array[Resource]:
	var matches: Array[Resource] = []
	for entry in entries:
		if entry == null:
			continue
		if not ("signal_key" in entry):
			continue
		if entry.signal_key != signal_key:
			continue
		matches.append(entry)
	return matches


func all_signal_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for entry in entries:
		if entry == null:
			continue
		if entry.signal_key == StringName():
			continue
		if keys.has(entry.signal_key):
			continue
		keys.append(entry.signal_key)
	return keys
