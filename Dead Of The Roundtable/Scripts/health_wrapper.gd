extends MarginContainer

@onready var main_bar: ProgressBar = $HealthBar
@onready var catchup_bar: ProgressBar = $CatchupBar
@onready var overshield_bar: ProgressBar = $OvershieldBar
@onready var health_text: Label = $HBoxContainer/HealthLabel

var catchup_tween: Tween

func _on_player_health_changed(new_health: float, max_health: float, new_overshield: float, max_overshield: float) -> void:
	# Ensure max values are synced
	main_bar.max_value = max_health
	catchup_bar.max_value = max_health
	
	if overshield_bar:
		if max_overshield <= 0.0:
			overshield_bar.hide()
		else:
			overshield_bar.show()
			overshield_bar.max_value = 100.0
			overshield_bar.value = new_overshield

	# Instantly update the main red bar
	main_bar.value = new_health
	
	# Update the text - only show the " / Y S" if there's overshield remaining
	if new_overshield > 0:
		health_text.text = str(ceil(new_health)) + " HP / " + str(ceil(new_overshield)) + " S"
	else:
		health_text.text = str(ceil(new_health)) + " HP"

	# Handle the Catch-Up Bar Tween
	if catchup_tween:
		catchup_tween.kill() # Stop the old animation if we take damage again

	catchup_tween = create_tween()

	# Tiny delay on white bar
	catchup_tween.tween_interval(0.15) 

	# Smoothly shrink the white bar to match the new health
	catchup_tween.tween_property(catchup_bar, "value", new_health, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
