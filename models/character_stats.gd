class_name CharacterStats
extends Resource

signal stamina_drained(amount: int, old_stamina: int, new_stamina: int)
signal stamina_restored(amount: int, old_stamina: int, new_stamina: int)
signal stamina_changed(old_stamina: int, new_stamina: int)

const MAX_INT := 2147483647

@export var max_stamina: int = 6
var stamina: int = 0

func _init(p_max_stamina: int = 6) -> void:
	max_stamina = p_max_stamina
	stamina = max_stamina

func drain_stamina(amount: int) -> void:
	var applied := clampi(amount, 1, MAX_INT)
	var old_stamina := stamina
	stamina = clampi(stamina - applied, 0, max_stamina)
	if stamina != old_stamina:
		stamina_drained.emit(applied, old_stamina, stamina)
		stamina_changed.emit(old_stamina, stamina)

func restore_stamina(amount: int) -> void:
	var applied := clampi(amount, 0, MAX_INT)
	var old_stamina := stamina
	stamina = clampi(stamina + applied, 0, max_stamina)
	if stamina != old_stamina:
		stamina_restored.emit(stamina - old_stamina, old_stamina, stamina)
		stamina_changed.emit(old_stamina, stamina)

func is_exhausted() -> bool:
	return stamina <= 0

func fill() -> void:
	var old_stamina := stamina
	stamina = max_stamina
	if stamina != old_stamina:
		stamina_restored.emit(stamina - old_stamina, old_stamina, stamina)
		stamina_changed.emit(old_stamina, stamina)
