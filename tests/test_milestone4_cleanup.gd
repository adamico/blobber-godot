## Milestone 4 regression suite — Disposal & Progression.
##
## Covers:
##   - DisposalChute.accepts_item filters correctly
##   - JobRating grade thresholds (boundary values)
##   - JobRating grade_label / flavor_text return correct strings
##   - ItemData.cleanup_value defaults to 1 and can be overridden
extends GutTest

const JobRatingModel = preload("res://models/job_rating.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_debris(cleanup_val: int = 1) -> ItemData:
	var item := ItemData.new()
	item.item_name = "Test Debris"
	item.item_type = ItemData.ItemType.DEBRIS
	item.cleanup_value = cleanup_val
	return item


func _make_tool() -> ItemData:
	var item := ItemData.new()
	item.item_name = "Test Tool"
	item.item_type = ItemData.ItemType.TOOL
	return item


func _make_consumable() -> ItemData:
	var item := ItemData.new()
	item.item_name = "Test Consumable"
	item.item_type = ItemData.ItemType.CONSUMABLE
	return item


func _make_chute(cell: Vector2i) -> DisposalChute:
	var chute := DisposalChute.new()
	chute.grid_cell = cell
	add_child_autofree(chute)
	return chute


# ---------------------------------------------------------------------------
# DisposalChute — cell matching
# ---------------------------------------------------------------------------

func test_chute_matches_its_own_cell() -> void:
	var chute := _make_chute(Vector2i(3, 4))
	assert_true(chute.matches_cell(Vector2i(3, 4)))


func test_chute_does_not_match_different_cell() -> void:
	var chute := _make_chute(Vector2i(3, 4))
	assert_false(chute.matches_cell(Vector2i(2, 4)))


# ---------------------------------------------------------------------------
# DisposalChute — item acceptance
# ---------------------------------------------------------------------------

func test_chute_accepts_debris() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	var debris := _make_debris()
	assert_true(chute.accepts_item(debris))


func test_chute_rejects_tool() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	var tool := _make_tool()
	assert_false(chute.accepts_item(tool))


func test_chute_rejects_consumable() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	var consumable := _make_consumable()
	assert_false(chute.accepts_item(consumable))


func test_chute_rejects_null_item() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	assert_false(chute.accepts_item(null))


# ---------------------------------------------------------------------------
# DisposalChute — group membership
# ---------------------------------------------------------------------------

func test_chute_is_in_disposal_chutes_group() -> void:
	var chute := _make_chute(Vector2i(0, 0))
	assert_true(chute.is_in_group(&"disposal_chutes"))


# ---------------------------------------------------------------------------
# ItemData — cleanup_value
# ---------------------------------------------------------------------------

func test_item_data_cleanup_value_defaults_to_one() -> void:
	var item := ItemData.new()
	assert_eq(item.cleanup_value, 1)


func test_item_data_cleanup_value_can_be_set() -> void:
	var item := _make_debris(3)
	assert_eq(item.cleanup_value, 3)


# ---------------------------------------------------------------------------
# JobRating — grade thresholds (boundary values)
# ---------------------------------------------------------------------------

func test_grade_90_is_a() -> void:
	assert_eq(JobRatingModel.grade_for_percent(90), JobRatingModel.Grade.A)


func test_grade_100_is_a() -> void:
	assert_eq(JobRatingModel.grade_for_percent(100), JobRatingModel.Grade.A)


func test_grade_89_is_b() -> void:
	assert_eq(JobRatingModel.grade_for_percent(89), JobRatingModel.Grade.B)


func test_grade_70_is_b() -> void:
	assert_eq(JobRatingModel.grade_for_percent(70), JobRatingModel.Grade.B)


func test_grade_69_is_c() -> void:
	assert_eq(JobRatingModel.grade_for_percent(69), JobRatingModel.Grade.C)


func test_grade_50_is_c() -> void:
	assert_eq(JobRatingModel.grade_for_percent(50), JobRatingModel.Grade.C)


func test_grade_49_is_d() -> void:
	assert_eq(JobRatingModel.grade_for_percent(49), JobRatingModel.Grade.D)


func test_grade_0_is_d() -> void:
	assert_eq(JobRatingModel.grade_for_percent(0), JobRatingModel.Grade.D)


# ---------------------------------------------------------------------------
# JobRating — grade_label
# ---------------------------------------------------------------------------

func test_grade_label_a() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.A), "A")


func test_grade_label_b() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.B), "B")


func test_grade_label_c() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.C), "C")


func test_grade_label_d() -> void:
	assert_eq(JobRatingModel.grade_label(JobRatingModel.Grade.D), "D")


# ---------------------------------------------------------------------------
# JobRating — flavor_text returns non-empty strings per grade
# ---------------------------------------------------------------------------

func test_flavor_text_a_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.A), "")


func test_flavor_text_b_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.B), "")


func test_flavor_text_c_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.C), "")


func test_flavor_text_d_is_non_empty() -> void:
	assert_ne(JobRatingModel.flavor_text(JobRatingModel.Grade.D), "")


func test_flavor_text_grades_are_distinct() -> void:
	var texts := [
		JobRatingModel.flavor_text(JobRatingModel.Grade.A),
		JobRatingModel.flavor_text(JobRatingModel.Grade.B),
		JobRatingModel.flavor_text(JobRatingModel.Grade.C),
		JobRatingModel.flavor_text(JobRatingModel.Grade.D),
	]
	# All four strings should be unique.
	for i in range(texts.size()):
		for j in range(i + 1, texts.size()):
			assert_ne(texts[i], texts[j],
				"Grades at indices %d and %d share the same flavor text" % [i, j])
