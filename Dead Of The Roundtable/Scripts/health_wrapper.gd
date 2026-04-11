extends MarginContainer

@onready var main_bar: ProgressBar = $HealthBar
@onready var catchup_bar: ProgressBar = $CatchupBar
@onready var overshield_bar: ProgressBar = $OvershieldBar
@onready var health_text: RichTextLabel = $HBoxContainer/HealthLabel

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
			overshield_bar.max_value = max_overshield
			overshield_bar.value = new_overshield

	# Update the text
	if new_overshield > 0:
		health_text.text = str(ceil(new_health)) + " HP / " + "[color=teal]" + str(ceil(new_overshield)) + " S [/color]"
	else:
		health_text.text = str(ceil(new_health)) + " HP"

	# DAMAGE VS HEALING LOGIC
	if new_health < main_bar.value:
		# TAKING DAMAGE
		main_bar.value = new_health
		
		if catchup_tween:
			catchup_tween.kill() # Stop the old animation if we take damage again
			
		catchup_tween = create_tween()
		catchup_tween.tween_interval(0.15) 
		catchup_tween.tween_property(catchup_bar, "value", new_health, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	else:
		# HEALING
		main_bar.value = new_health
		catchup_bar.value = new_health
		
		# If we heal while a previous damage tween is still falling, kill it
		if catchup_tween and catchup_tween.is_running():
			catchup_tween.kill()
