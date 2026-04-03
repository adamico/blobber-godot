class_name AnalysisSummaryResolver
extends Resource


func resolve(
		_collector,
		_def: AnalysisCandidateKindDefinition,
		_node,
		_item: ItemData,
) -> Dictionary:
	return {
		"basic": "",
		"partial": "",
		"weakness": "",
	}
