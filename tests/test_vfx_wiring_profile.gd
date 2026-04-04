extends GutTest

const VFX_WIRING_ENTRY_SCRIPT := preload("res://models/vfx_wiring_entry.gd")
const VFX_WIRING_PROFILE_SCRIPT := preload("res://models/vfx_wiring_profile.gd")


func _make_entry(signal_key: StringName, effect_type: int):
	var entry = VFX_WIRING_ENTRY_SCRIPT.new()
	entry.signal_key = signal_key
	entry.effect_type = effect_type
	return entry


func _set_entries(profile, items: Array) -> void:
	profile.entries.clear()
	for item in items:
		profile.entries.append(item)


func test_find_by_signal_key_returns_first_match() -> void:
	var profile = VFX_WIRING_PROFILE_SCRIPT.new()
	var shake = _make_entry(&"player.hit", 0)
	var flash = _make_entry(&"player.hit", 1)
	_set_entries(profile, [shake, flash])

	assert_same(profile.find_by_signal_key(&"player.hit"), shake)


func test_find_all_by_signal_key_returns_all_matches() -> void:
	var profile = VFX_WIRING_PROFILE_SCRIPT.new()
	var shake = _make_entry(&"player.hit", 0)
	var flash = _make_entry(&"player.hit", 1)
	var particles = _make_entry(&"item.used", 3)
	_set_entries(profile, [shake, flash, particles])

	var matches := profile.find_all_by_signal_key(&"player.hit")
	assert_eq(matches.size(), 2)
	assert_true(matches.has(shake))
	assert_true(matches.has(flash))


func test_all_signal_keys_deduplicates_keys() -> void:
	var profile = VFX_WIRING_PROFILE_SCRIPT.new()
	_set_entries(profile, [
		_make_entry(&"player.hit", 0),
		_make_entry(&"player.hit", 1),
		_make_entry(&"hostile.hit", 2),
	])

	var keys := profile.all_signal_keys()
	assert_eq(keys.size(), 2)
	assert_true(keys.has(&"player.hit"))
	assert_true(keys.has(&"hostile.hit"))
