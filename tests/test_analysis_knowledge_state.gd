extends GutTest

const AnalysisKnowledgeStateScript = preload("res://models/analysis_knowledge_state.gd")


func test_snapshot_defaults_all_flags_false() -> void:
	var state = AnalysisKnowledgeStateScript.new()
	var snapshot := state.snapshot(&"hostile:burning_hazard")

	assert_eq(
		snapshot,
		{
			state.KNOWLEDGE_BASIC: false,
			state.KNOWLEDGE_PARTIAL: false,
			state.KNOWLEDGE_WEAKNESS: false,
			state.KNOWLEDGE_DISPOSAL: false,
		},
	)


func test_unlock_sets_requested_flag() -> void:
	var state = AnalysisKnowledgeStateScript.new()

	assert_true(state.unlock(&"hostile:burning_hazard", state.KNOWLEDGE_BASIC))
	assert_true(bool(state.snapshot(&"hostile:burning_hazard").get(state.KNOWLEDGE_BASIC, false)))


func test_unlock_emits_once_per_flag() -> void:
	var state = AnalysisKnowledgeStateScript.new()
	var emitted: Array = []
	state.knowledge_updated.connect(
		func(key: StringName, snapshot: Dictionary, unlock_flag: StringName) -> void:
			emitted.append([key, snapshot, unlock_flag])
	)

	assert_true(state.unlock(&"hostile:burning_hazard", state.KNOWLEDGE_BASIC))
	assert_false(state.unlock(&"hostile:burning_hazard", state.KNOWLEDGE_BASIC))

	assert_eq(emitted.size(), 1)
	assert_eq(
		emitted[0],
		[
			&"hostile:burning_hazard",
			{
				state.KNOWLEDGE_BASIC: true,
				state.KNOWLEDGE_PARTIAL: false,
				state.KNOWLEDGE_WEAKNESS: false,
				state.KNOWLEDGE_DISPOSAL: false,
			},
			state.KNOWLEDGE_BASIC,
		],
	)