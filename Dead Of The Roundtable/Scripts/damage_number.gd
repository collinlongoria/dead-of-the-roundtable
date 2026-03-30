extends Label3D
class_name DamageNumber

var float_speed: float = 1.5
var float_distance: float = 1.5
var lifetime: float = 0.8

func setup(amount: float, is_critical: bool = false) -> void:
	text = str(round(amount))
	
	if is_critical:
		text += "!"
		modulate = Color(1.0, 0.2, 0.2)
		outline_modulate = Color.DARK_RED
		scale = Vector3(1.5, 1.5, 1.5)
		position.x += randf_range(-0.5, 0.5)
	else:
		modulate = Color.WHITE
	
	_animate()

func _animate() -> void:
	var tween = create_tween().set_parallel(true)
	
	# float up
	var target_y = position.y + float_distance
	tween.tween_property(self, "position:y", target_y, lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	
	# Fade out alpha
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "outline_modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Once the parallel animations finish, queue it for deletion
	tween.chain().tween_callback(queue_free)
