class_name HostileActorDefinition
extends Resource

@export var definition_id: StringName
@export var display_name: String = ""
@export var actor_scene: PackedScene
@export var sprite_texture: Texture2D

# Shared hostile behavior contract. Hazards and enemies are configured through data.
@export var hostile_property: RpsSystem.HostileProperty = RpsSystem.HostileProperty.BURNING
@export_range(1, 6, 1) var speed: int = 1
@export_range(0, 3, 1) var ai_behavior: int = 0
@export_range(1, 8, 1) var patrol_length: int = 3

@export_range(0, 10, 1) var contact_damage: int = 1
@export_range(1, 20, 1) var hostile_hp: int = 3
@export_range(1, 30, 1) var revert_turns_base: int = 5
@export_range(1, 20, 1) var cleanup_value: int = 1

# Behavioral capabilities (data-driven instead of class-checks).
@export var instant_clear_on_debris: bool = false

# Separate analysis metadata from hostile behavior stats.
@export var analysis_profile: Resource
