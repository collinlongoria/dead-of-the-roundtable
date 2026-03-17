extends Control
@export var player: CharacterBody3D
@onready var label: Label = $SpeedLabel

func _process(_delta: float) -> void:
	if not player or not label:
		return

	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var vertical_speed := player.velocity.y

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
		player.is_on_floor()
	]
