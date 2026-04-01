extends RigidBody3D

var damage: float = 0.0
var velocity: Vector3 = Vector3.ZERO
@export var speed: float = 5.0
var is_critical: bool = false

func _physics_process(delta: float) -> void:
	linear_velocity = velocity
	
	if velocity.length_squared() > 0.0001:
		look_at(global_position + velocity, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	
	if body is CharacterBody3D and body.has_method("_handle_shooting"):
		return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
		# Tell all clients to show the damage number
		spawn_damage_number.rpc(global_position, damage, is_critical)
	
	queue_free()

@rpc("call_local", "reliable")
func spawn_damage_number(pos: Vector3, amt: float, is_crit: bool):
	DamageIndicator.spawn(pos, amt, is_crit)
