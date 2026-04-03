class_name AnalysisSummaryResolverPickupItem
extends AnalysisSummaryResolver


func resolve(
		collector,
		def: AnalysisCandidateKindDefinition,
		_node,
		item: ItemData,
) -> Dictionary:
	var attached_profile: Resource = item.analysis_profile if item != null else null
	var fallback_profile: AnalysisEntityProfile = collector.load_entity_profile(
		def.fallback_profile_path
	)

	var basic := ""
	if item != null:
		basic = collector.first_non_empty_line(item.description)
	if basic.is_empty():
		basic = collector.non_empty_or(
			def.summary_basic_default,
			collector.profile_field(attached_profile, fallback_profile, &"summary_basic", ""),
		)

	var partial := ""
	if item != null:
		var full_desc := item.description.strip_edges()
		if item.tool_property != RpsSystem.ToolProperty.OTHER:
			var prop := RpsSystem.humanize_tool_property(item.tool_property)
			partial = "Property: %s" % prop
			if not full_desc.is_empty():
				partial += "\n" + full_desc
		else:
			partial = full_desc
	partial = collector.profile_field(
		attached_profile,
		fallback_profile,
		&"summary_partial",
		partial,
	)

	return {
		"basic": basic,
		"partial": partial,
		"weakness": collector.profile_field(
			attached_profile,
			fallback_profile,
			&"summary_weakness",
			def.summary_weakness_default,
		),
	}
