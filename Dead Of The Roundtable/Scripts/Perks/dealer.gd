extends Perk

var cast_count: int = 0

func on_cast(player: Node3D) -> void:
	cast_count += 1

func modify_hit(context: HitContext) -> void:
	if cast_count % 4 == 0:
		context.final_damage *= 2.0
		context.is_critical = true
