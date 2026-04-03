class_name AnalysisResultBuilder
extends RefCounted

const AnalysisKnowledgeStateModel = preload("res://models/analysis_knowledge_state.gd")
const ANALYSIS_RESULT_DATA_SCRIPT := "res://models/analysis_result_data.gd"


func build(target, knowledge: Dictionary):
	var summary := "No reliable field notes yet."

	if bool(knowledge.get(AnalysisKnowledgeStateModel.KNOWLEDGE_BASIC, false)):
		summary = target.summary_basic if target.summary_basic != "" else "No details available."

	var details: Array[String] = []
	if bool(knowledge.get(AnalysisKnowledgeStateModel.KNOWLEDGE_PARTIAL, false)):
		details.append(target.summary_partial)
	if bool(knowledge.get(AnalysisKnowledgeStateModel.KNOWLEDGE_WEAKNESS, false)):
		details.append(target.summary_weakness)
	if bool(knowledge.get(AnalysisKnowledgeStateModel.KNOWLEDGE_DISPOSAL, false)):
		details.append(target.summary_disposal)
	details = details.filter(func(line: String) -> bool: return line.strip_edges() != "")

	var full_summary := "%s: %s" % [
		target.display_name if target.display_name != "" else "Target",
		summary,
	]
	if not details.is_empty():
		full_summary += "\n" + "\n".join(details)

	var result = load(ANALYSIS_RESULT_DATA_SCRIPT).new(target)
	result.summary = full_summary
	result.knowledge = knowledge.duplicate(true)
	return result