class_name VFXWiringEntry
extends Resource

enum EffectType {
	SCREEN_SHAKE,
	SCREEN_FLASH,
	ENTITY_FLASH,
	PARTICLES,
}

@export var signal_key: StringName = StringName()
@export var effect_type: EffectType = EffectType.PARTICLES
@export_range(0, 2000, 10) var cooldown_ms: int = 0
@export_range(0.01, 2.0, 0.01) var duration: float = 0.2
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.15
@export var color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(1, 64, 1) var particle_amount: int = 10
@export var particle_scene: PackedScene
@export var position_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0, 0.01) var flash_peak_alpha: float = 0.3
