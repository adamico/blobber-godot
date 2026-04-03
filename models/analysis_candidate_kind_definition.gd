class_name AnalysisCandidateKindDefinition
extends Resource

@export var kind: String = ""
@export var group_name: StringName
@export var required_class_name: String = ""
@export var required_methods: PackedStringArray = PackedStringArray()
@export var required_non_null_paths: PackedStringArray = PackedStringArray()
@export var skip_if_method_true: StringName = StringName()
@export var cell_path: String = "grid_cell"

@export var key_mode: String = "instance_id"
@export var key_prefix: String = ""
@export var key_literal: String = ""
@export var key_path: String = ""
@export var definition_id_path: String = ""

@export var display_name_mode: String = "path_or_default"
@export var display_name_default: String = ""
@export var display_name_path: String = ""

@export var fallback_profile_path: String = ""
@export var attached_profile_path: String = "analysis_profile"
@export var targeting_profile_path: String = ""
@export var summary_resolver_path: String = ""

@export_multiline var summary_basic_default: String = ""
@export_multiline var summary_partial_default: String = ""
@export_multiline var summary_weakness_default: String = ""
@export var summary_basic_override_bool_path: String = ""
@export_multiline var summary_basic_override_when_true: String = ""

@export var item_path: String = ""
