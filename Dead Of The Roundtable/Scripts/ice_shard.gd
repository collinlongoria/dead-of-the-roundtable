extends Area3D

var damage: float = 0.0
var velocity: Vector3 = Vector3.ZERO
@export var speed: float = 20.0
var is_critical: bool = false
var attacker: Node3D

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	
	if velocity.length_squared() > 0.0001:
		look_at(global_position + velocity, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	if body is CharacterBody3D and body.has_method("_handle_shooting"): return
	
	if body.has_method("take_damage"):
		# create context
		var context = HitContext.new()
		context.attacker = attacker
		context.victim = body
		context.base_damage = damage
		context.final_damage = damage
		context.is_critical = is_critical
		context.hit_position = global_position
		
		# run thru perk manager
		if attacker and attacker.has_method("process_hit_perks"):
			attacker.process_hit_perks(context)
		
		body.take_damage(context.final_damage)
		
		# process kill perks
		if body.get("current_health") <= 0:
			if attacker and attacker.has_method("process_kill_perks"):
				attacker.process_kill_perks(context)
		
		# Tell all clients to show the damage number
		spawn_damage_number.rpc(global_position, context.final_damage, is_critical)
	
	queue_free()

@rpc("call_local", "reliable")
func spawn_damage_number(pos: Vector3, amt: float, is_crit: bool):
	DamageIndicator.spawn(pos, amt, is_crit)
