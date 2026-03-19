extends Area3D

var damage: float = 0.0
var speed: float = 10.0

func _physics_process(delta: float) -> void:
	position -= transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	queue_free()
