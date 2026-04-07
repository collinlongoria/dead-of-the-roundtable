extends Perk

func modify_hit(context: HitContext) -> void:
	if context.is_critical and context.victim.get("current_health") == context.victim.get("max_health"):
		context.final_damage *= 2.0
