extends Node

@export var damage_number_scene: PackedScene = preload("res://Scenes/damage_number.tscn")

func spawn(spawn_position: Vector3, amount: float, is_critical: bool = false) -> void:
	if not damage_number_scene:
		push_error("Damage number scene not assigned!")
		return
		
	var dmg_num = damage_number_scene.instantiate() as DamageNumber
	
	# Add it to the current active scene tree
	get_tree().current_scene.add_child(dmg_num)
	
	# Set its starting position to where the hit happened
	dmg_num.global_position = spawn_position
	
	# Pass in our data!
	dmg_num.setup(amount, is_critical)
