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
		Grade.A:
			return (
				"Floor certified clean. Impressive. The dungeon hasn't seen this level "
				+ "of professional conduct since... well. Ever, actually."
			)
		Grade.B: return "Acceptable. Some biohazard residue remains."
		Grade.C:
			return "Floor cleared. Technically. The word 'thorough' does not apply here. Moving on."
		_:
			return (
				"This is not what was agreed upon. The remaining hazards will be someone "
				+ "else's problem. You know this. You did it anyway."
			)
