class_name RpsSystem
extends RefCounted

enum HazardClass {
	FLAMMABLE,
	VOLATILE,
	UNDEAD,
	CURSED,
	CORROSIVE,
	ACID,
}

enum ToolClass {
	AQUEOUS,
	SPECTRAL,
	INERT,
	UTILITY,
}

const WEAKNESS_TABLE: Dictionary = {
	ToolClass.AQUEOUS: [HazardClass.FLAMMABLE, HazardClass.VOLATILE],
	ToolClass.SPECTRAL: [HazardClass.UNDEAD, HazardClass.CURSED],
	ToolClass.INERT: [HazardClass.CORROSIVE, HazardClass.ACID],
}

const EFFECTIVE_DAMAGE := 999
const BASE_DAMAGE := 1


static func is_effective(tool_class: ToolClass, hazard_class: HazardClass) -> bool:
	var weaknesses: Array = WEAKNESS_TABLE.get(tool_class, [])
	return weaknesses.has(hazard_class)


static func compute_damage(tool_class: ToolClass, hazard_class: HazardClass) -> int:
	if is_effective(tool_class, hazard_class):
		return EFFECTIVE_DAMAGE
	return BASE_DAMAGE
