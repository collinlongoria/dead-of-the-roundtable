extends Area3D

var damage: float = 0.0
var speed: float = 5.0

func _physics_process(delta: float) -> void:
	position -= transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	
	if body is CharacterBody3D and body.has_method("_handle_shooting"):
		return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
		# Determine if it was a crit TODO replace with real logic
		var is_crit = randf() < 0.2 
		
		# Tell all clients to show the damage number
		spawn_damage_number.rpc(global_position, damage, is_crit)
	
	queue_free()

@rpc("call_local", "reliable")
func spawn_damage_number(pos: Vector3, amt: float, is_crit: bool):
	DamageIndicator.spawn(pos, amt, is_crit)
