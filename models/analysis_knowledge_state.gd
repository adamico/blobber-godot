class_name AnalysisKnowledgeState
extends RefCounted

signal knowledge_updated(key: StringName, snapshot: Dictionary, unlock_flag: StringName)

const KNOWLEDGE_BASIC := &"basic_known"
const KNOWLEDGE_PARTIAL := &"partial_clue_known"
const KNOWLEDGE_WEAKNESS := &"weakness_known"
const KNOWLEDGE_DISPOSAL := &"disposal_known"

var _knowledge_by_key: Dictionary = { }


func unlock(key: StringName, unlock_flag: StringName) -> bool:
	if key == StringName() or unlock_flag == StringName():
		return false

	var entry := _ensure_entry(key)
	if entry.is_empty():
		return false
	if bool(entry.get(unlock_flag, false)):
		return false

	entry[unlock_flag] = true
	_knowledge_by_key[key] = entry
	knowledge_updated.emit(key, entry.duplicate(true), unlock_flag)
	return true


func snapshot(key: StringName) -> Dictionary:
	if key == StringName():
		return _default_snapshot()

	var entry := _ensure_entry(key)
	if entry.is_empty():
		return _default_snapshot()
	return entry.duplicate(true)


func _ensure_entry(key: StringName) -> Dictionary:
	if key == StringName():
		return { }
	if _knowledge_by_key.has(key):
		return _knowledge_by_key[key]

	var entry := _default_snapshot()
	_knowledge_by_key[key] = entry
	return entry


func _default_snapshot() -> Dictionary:
	return {
		KNOWLEDGE_BASIC: false,
		KNOWLEDGE_PARTIAL: false,
		KNOWLEDGE_WEAKNESS: false,
		KNOWLEDGE_DISPOSAL: false,
	}