extends MarginContainer

@onready var main_bar: ProgressBar = $HealthBar
@onready var catchup_bar: ProgressBar = $CatchupBar
@onready var health_text: Label = $HBoxContainer/HealthLabel

var catchup_tween: Tween

func _on_player_health_changed(new_health: float, max_health: float) -> void:
	# Ensure max values are synced
	main_bar.max_value = max_health
	catchup_bar.max_value = max_health

	# 1. Instantly update the main red bar and the text
	main_bar.value = new_health
	health_text.text = str(new_health) + " HP"

	# 2. Handle the Catch-Up Bar Tween
	if catchup_tween:
		catchup_tween.kill() # Stop the old animation if we take damage again

	catchup_tween = create_tween()

	# Add a tiny delay (0.1 to 0.2 seconds) before the white bar drops. 
	# This creates a "hang time" effect that gives the hit more impact.
	catchup_tween.tween_interval(0.15) 

	# Smoothly shrink the white bar to match the new health
	catchup_tween.tween_property(catchup_bar, "value", new_health, 0.4) \
	.set_trans(Tween.TRANS_SINE) \
	.set_ease(Tween.EASE_OUT)
