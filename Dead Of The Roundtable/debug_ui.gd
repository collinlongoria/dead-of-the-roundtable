extends Control

@export var player: Node3D
@onready var label: Label = $SpeedLabel

func _process(_delta: float) -> void:
	if not player or not label:
		return
	
	var body: CharacterBody3D = player.body if player.has_node("PlayerController") else null
	if not body:
		return
	
	var horizontal_speed := Vector2(body.velocity.x, body.velocity.z).length()
	var vertical_speed := body.velocity.y
	
	var state_names := {
		player.State.IDLE: "Idle",
		player.State.WALK: "Walking",
		player.State.SPRINT: "Sprinting",
		player.State.CROUCH: "Crouching",
		player.State.SLIDE: "Sliding",
		player.State.AIR: "Air",
	}
	
	var state: String = state_names.get(player.state, "Unknown")
	
	label.text = "State: %s\nSpeed: %.1f\nVertical: %.1f\nSlide Speed: %.1f\nOn Floor: %s" % [
		state,
		horizontal_speed,
		vertical_speed,
		player.current_slide_speed,
		body.is_on_floor()
	]
