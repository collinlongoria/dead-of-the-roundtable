extends Resource
class_name Perk

@export var perk_name: String = "Base Perk"
@export var perk_desc: String = ""

# virtual methods
func modify_hit(context: HitContext) -> void:
	pass

func on_kill(context: HitContext) -> void:
	pass

func on_firing_tick(player: Node3D, delta: float) -> void:
	pass
