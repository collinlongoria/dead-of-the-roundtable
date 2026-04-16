extends BaseEnemy
class_name WalkerZombie

func _ready() -> void:
	super()
	
	# Override
	speed = 2.0
	max_health = 100.0
	damage = 40.0

func attack_target() -> void:
	if not multiplayer.is_server():
		return
		
	# Placeholder for future attack logic
	print("Walker zombie is doing a slow swipe attack!")
