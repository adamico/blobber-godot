class_name AnalysisSummaryResolverProfile
extends AnalysisSummaryResolver


func resolve(
		collector,
		def: AnalysisCandidateKindDefinition,
		node,
		_item: ItemData,
) -> Dictionary:
	var attached_profile: Resource = null
	var resolved_profile: Variant = collector.resolve_path(node, def.attached_profile_path)
	if resolved_profile is Resource:
		attached_profile = resolved_profile
	var fallback_profile: AnalysisEntityProfile = collector.load_entity_profile(
		def.fallback_profile_path
	)

	var basic: String = collector.profile_field(
		attached_profile,
		fallback_profile,
		&"summary_basic",
		def.summary_basic_default,
	)
	if (
		def.summary_basic_override_bool_path != ""
		and attached_profile == null
		and bool(collector.resolve_path(node, def.summary_basic_override_bool_path))
	):
		basic = collector.non_empty_or(def.summary_basic_override_when_true, basic)

	return {
		"basic": basic,
		"partial": collector.profile_field(
			attached_profile,
			fallback_profile,
			&"summary_partial",
			def.summary_partial_default,
		),
		"weakness": collector.profile_field(
			attached_profile,
			fallback_profile,
			&"summary_weakness",
			def.summary_weakness_default,
		),
	}
