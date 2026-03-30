extends StaticBody3D

# Huge amount of health for testing purposes
@export var max_health: float = 999999.0
var current_health: float

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float) -> void:
	# Keep consistent with your multiplayer authority checks
	if not multiplayer.is_server():
		return

	current_health -= amount
	print("Dummy took ", amount, " damage! Health remaining: ", current_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	# For a test dummy, it's usually better to reset health rather than queue_free()
	print("Dummy destroyed! Resetting health.")
	current_health = max_health
	
	# If you prefer it to actually disappear like the zombie, uncomment the line below:
	# queue_free()
