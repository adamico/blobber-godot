class_name AnalysisSummaryResolverHostileWeakness
extends AnalysisSummaryResolverProfile


func resolve(
		collector,
		def: AnalysisCandidateKindDefinition,
		node,
		item: ItemData,
) -> Dictionary:
	var summary := super.resolve(collector, def, node, item)
	var weakness_tool: RpsSystem.ToolProperty = collector.weakness_tool_for_hostile_node(node)
	var weakness_text := RpsSystem.humanize_tool_property(weakness_tool)
	summary["weakness"] = String(summary.get("weakness", "")).replace(
		"{weakness_tool}",
		weakness_text,
	)
	return summary
