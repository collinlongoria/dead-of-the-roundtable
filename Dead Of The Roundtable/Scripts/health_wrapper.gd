extends MarginContainer

@onready var main_bar: ProgressBar = $HealthBar
@onready var catchup_bar: ProgressBar = $CatchupBar
@onready var overshield_bar: ProgressBar = $OvershieldBar
@onready var health_text: RichTextLabel = $HBoxContainer/HealthLabel

var catchup_tween: Tween
var health_flash_tween: Tween
var overshield_flash_tween: Tween

var _previous_overshield: float = 0.0

@onready var _main_bar_base_color: Color = main_bar.modulate
@onready var _overshield_base_color: Color = overshield_bar.modulate if overshield_bar else Color.WHITE

const FLASH_HOLD_TIME: float = 0.05
const FLASH_FADE_TIME: float = 0.25
const HEALTH_FLASH_COLOR: Color = Color(2.0, 2.0, 2.0)
const OVERSHIELD_FLASH_COLOR: Color = Color(1.6, 2.2, 2.2)

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
			
			# Flash the overshield if it dropped
			if new_overshield < _previous_overshield:
				_flash_overshield()
			
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
		_flash_health()
		
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
	
	_previous_overshield = new_overshield


func _flash_health() -> void:
	if health_flash_tween:
		health_flash_tween.kill()
	
	main_bar.modulate = HEALTH_FLASH_COLOR
	
	health_flash_tween = create_tween()
	health_flash_tween.tween_interval(FLASH_HOLD_TIME)
	health_flash_tween.tween_property(
		main_bar, "modulate", _main_bar_base_color, FLASH_FADE_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _flash_overshield() -> void:
	if not overshield_bar:
		return
	if overshield_flash_tween:
		overshield_flash_tween.kill()
	
	overshield_bar.modulate = OVERSHIELD_FLASH_COLOR
	
	overshield_flash_tween = create_tween()
	overshield_flash_tween.tween_interval(FLASH_HOLD_TIME)
	overshield_flash_tween.tween_property(
		overshield_bar, "modulate", _overshield_base_color, FLASH_FADE_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
