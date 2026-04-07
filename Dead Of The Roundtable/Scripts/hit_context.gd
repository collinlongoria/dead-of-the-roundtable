extends RefCounted
class_name HitContext

var attacker: Node3D
var victim: Node3D
var base_damage: float
var final_damage: float
var is_critical: bool
var hit_position: Vector3

func get_distance() -> float:
	if attacker and victim:
		return attacker.global_position.distance_to(victim.global_position)
	return 0.0
