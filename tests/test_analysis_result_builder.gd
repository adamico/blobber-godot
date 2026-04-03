extends GutTest

const AnalysisKnowledgeStateScript = preload("res://models/analysis_knowledge_state.gd")
const AnalysisResultBuilderScript = preload("res://models/analysis_result_builder.gd")
const ANALYSIS_TARGET_DATA_SCRIPT := "res://models/analysis_target_data.gd"


func test_summary_hides_details_before_basic_knowledge() -> void:
	var builder = AnalysisResultBuilderScript.new()
	var state = AnalysisKnowledgeStateScript.new()
	var target = load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(
		{
			"key": "hostile:burning_hazard",
			"display_name": "Burning Hazard",
			"summary_basic": "Unstable fire hazard.",
		},
	)

	var result: Dictionary = builder.build(
		target,
		state.snapshot(&"hostile:burning_hazard"),
	).to_dict()
	assert_true(String(result.summary).contains("No reliable field notes yet"))


func test_summary_reveals_basic_knowledge_when_unlocked() -> void:
	var builder = AnalysisResultBuilderScript.new()
	var state = AnalysisKnowledgeStateScript.new()
	var key := &"hostile:burning_hazard"
	var target = load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(
		{
			"key": String(key),
			"display_name": "Burning Hazard",
			"summary_basic": "Unstable fire hazard.",
		},
	)
	state.unlock(key, state.KNOWLEDGE_BASIC)

	var result: Dictionary = builder.build(target, state.snapshot(key)).to_dict()
	assert_true(String(result.summary).contains("Unstable fire hazard"))


func test_summary_appends_partial_weakness_and_disposal_details() -> void:
	var builder = AnalysisResultBuilderScript.new()
	var state = AnalysisKnowledgeStateScript.new()
	var key := &"hostile:burning_hazard"
	var target = load(ANALYSIS_TARGET_DATA_SCRIPT).from_dict(
		{
			"key": String(key),
			"display_name": "Burning Hazard",
			"summary_basic": "Unstable fire hazard.",
			"summary_partial": "Some tools underperform.",
			"summary_weakness": "Most effective counter: Soaked.",
			"summary_disposal": "Debris should be routed into the chute.",
		},
	)
	state.unlock(key, state.KNOWLEDGE_BASIC)
	state.unlock(key, state.KNOWLEDGE_PARTIAL)
	state.unlock(key, state.KNOWLEDGE_WEAKNESS)
	state.unlock(key, state.KNOWLEDGE_DISPOSAL)

	var result: Dictionary = builder.build(target, state.snapshot(key)).to_dict()
	assert_true(String(result.summary).contains("Some tools underperform"))
	assert_true(String(result.summary).contains("Most effective counter: Soaked"))
	assert_true(String(result.summary).contains("Debris should be routed into the chute"))
