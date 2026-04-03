class_name AnalysisEntityProfile
extends Resource

# Shared analysis copy for any interactable entity.
# Supports {weakness_tool} placeholder in the weakness summary.
@export_multiline var summary_basic: String = "No reliable field notes yet."
@export_multiline var summary_partial: String = ""
@export_multiline var summary_weakness: String = ""
@export_multiline var summary_disposal: String = ""