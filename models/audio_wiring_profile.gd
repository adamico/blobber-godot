class_name AudioWiringProfile
extends Resource

@export var entries: Array[Resource] = []


func find_by_signal_key(signal_key: StringName) -> Resource:
	for entry_resource in entries:
		if entry_resource == null:
			continue
		if not ("signal_key" in entry_resource):
			continue
		if entry_resource.signal_key == signal_key:
			return entry_resource
	return null


func all_signal_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for entry_resource in entries:
		if entry_resource == null:
			continue
		if not ("signal_key" in entry_resource):
			continue
		if entry_resource.signal_key == StringName():
			continue
		keys.append(entry_resource.signal_key)
	return keys
