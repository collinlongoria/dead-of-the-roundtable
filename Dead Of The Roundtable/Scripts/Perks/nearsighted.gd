extends Perk

func modify_hit(context: HitContext) -> void:
	var dist = context.get_distance()
	if dist <= 5.0:
		context.final_damage *= 1.2
