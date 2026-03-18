extends Resource
class_name SpellData

@export var spell_name: String = "New Spell" # name of spell 
@export var damage: float = 10.0 # this is per 'projectile'
@export var fire_rate: float = 0.5 # time in seconds between shots
@export var automatic: bool = false # whether holding down the fire button triggers spell

@export var projectile_scene: PackedScene # linked scene
