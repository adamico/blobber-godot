class_name JobRating
extends RefCounted

enum Grade { A, B, C, D }

## Thresholds from design.md: A >= 90%, B >= 70%, C >= 50%, D < 50%.
const THRESHOLD_A := 90
const THRESHOLD_B := 70
const THRESHOLD_C := 50


static func grade_for_percent(clean_percent: int) -> Grade:
	if clean_percent >= THRESHOLD_A:
		return Grade.A
	if clean_percent >= THRESHOLD_B:
		return Grade.B
	if clean_percent >= THRESHOLD_C:
		return Grade.C
	return Grade.D


static func grade_label(grade: Grade) -> String:
	match grade:
		Grade.A: return "A"
		Grade.B: return "B"
		Grade.C: return "C"
		_: return "D"


static func flavor_text(grade: Grade) -> String:
	match grade:
		Grade.A: return "Outstanding sanitation. Veridian is pleased."
		Grade.B: return "Acceptable. Some biohazard residue remains."
		Grade.C: return "Marginal. The union will be hearing about this."
		_: return "Unsatisfactory. Please update your safety waiver."
