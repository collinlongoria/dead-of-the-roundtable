extends StaticBody3D

@export var DPS: int = 6
@export var cooldown: float = 1.0

var damage_timer: Timer
var victims: Array[Node3D] = []

func _ready() -> void:
	damage_timer = Timer.new()
	damage_timer.wait_time = cooldown
	add_child(damage_timer)
	
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	damage_timer.start()

func _on_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"): 
		if body not in victims:
			victims.append(body)

func _on_detector_body_exited(body: Node3D) -> void:
	if body in victims:
		victims.erase(body)

func _on_damage_timer_timeout() -> void:
	for victim in victims:
		if is_instance_valid(victim) and victim.has_method("take_damage"):
			victim.take_damage(DPS)
