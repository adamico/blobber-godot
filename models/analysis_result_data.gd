class_name AnalysisResultData
extends RefCounted

const ANALYSIS_TARGET_DATA_SCRIPT := "res://models/analysis_target_data.gd"

var target: Variant
var summary: String = ""
var knowledge: Dictionary = { }


func _init(target_data = null) -> void:
	if target_data != null:
		target = target_data
	else:
		target = load(ANALYSIS_TARGET_DATA_SCRIPT).new()


func to_dict() -> Dictionary:
	var result: Dictionary = target.to_dict()
	result["summary"] = summary
	result["knowledge"] = knowledge.duplicate(true)
	return result