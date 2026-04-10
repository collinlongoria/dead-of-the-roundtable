extends Control
class_name HUDManager

@onready var main_profile = $Margin/Control/VBoxContainer/ProfileHud
@onready var main_wrapper = main_profile.find_child("HealthWrapper")

@onready var coop_profiles = [
	$Margin/Control/VBoxContainer/CoopProfileHud,
	$Margin/Control/VBoxContainer/CoopProfileHud2,
	$Margin/Control/VBoxContainer/CoopProfileHud3
]

var assigned_players: Dictionary = {}

func _ready() -> void:
	for coop in coop_profiles:
		coop.hide()

func register_player(player: CharacterBody3D) -> void:
	var target_profile: Control = null
	var target_wrapper: MarginContainer = null
	
	if player.is_multiplayer_authority():
		target_profile = main_profile
		target_wrapper = main_wrapper
	else:
		for coop in coop_profiles:
			if not assigned_players.values().has(coop):
				target_profile = coop
				target_wrapper = coop.find_child("HealthWrapper")
				target_profile.show()
				break
	
	if target_profile and target_wrapper:
		assigned_players[player] = target_profile
		player.health_changed.connect(target_wrapper._on_player_health_changed)
		
		player.health_changed.emit(player.current_health, player.stats.health, player.current_overshield, player.stats.overshield)

func unregister_player(player: CharacterBody3D) -> void:
	if assigned_players.has(player):
		var profile = assigned_players[player]
		var wrapper = profile.find_child("HealthWrapper")
		
		player.health_changed.disconnect(wrapper._on_player_health_changed)
		
		if profile in coop_profiles:
			profile.hide()
		
		assigned_players.erase(player)
