class_name AudioWiringEntry
extends Resource

@export var signal_key: StringName = StringName()
@export var sound_name: StringName = StringName()
@export_file("*.ogg", "*.wav", "*.mp3") var stream_path: String = ""
@export var bus: StringName = &"SFX"
@export var volume_db: float = 0.0
@export_range(0, 2000, 10) var cooldown_ms: int = 0
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.0
