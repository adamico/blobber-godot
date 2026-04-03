class_name AnalysisTargetData
extends RefCounted

var key: String = ""
var kind: String = ""
var display_name: String = ""
var summary_basic: String = ""
var summary_partial: String = ""
var summary_weakness: String = ""
var summary_disposal: String = ""
var cell: Vector2i = Vector2i.ZERO
var distance: int = 0
var source: String = ""


static func from_dict(payload: Dictionary) -> AnalysisTargetData:
	var data := AnalysisTargetData.new()
	data.key = String(payload.get("key", ""))
	data.kind = String(payload.get("kind", ""))
	data.display_name = String(payload.get("display_name", ""))
	data.summary_basic = String(payload.get("summary_basic", ""))
	data.summary_partial = String(payload.get("summary_partial", ""))
	data.summary_weakness = String(payload.get("summary_weakness", ""))
	data.summary_disposal = String(payload.get("summary_disposal", ""))
	data.cell = payload.get("cell", Vector2i.ZERO)
	data.distance = int(payload.get("distance", 0))
	data.source = String(payload.get("source", ""))
	return data


func to_dict() -> Dictionary:
	var payload := {
		"key": key,
		"kind": kind,
		"display_name": display_name,
		"summary_basic": summary_basic,
		"summary_partial": summary_partial,
		"summary_weakness": summary_weakness,
		"summary_disposal": summary_disposal,
		"cell": cell,
		"distance": distance,
	}
	if source != "":
		payload["source"] = source
	return payload