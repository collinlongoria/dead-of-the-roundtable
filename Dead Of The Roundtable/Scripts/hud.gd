extends Control

@export var player_stats: PlayerStats

func _ready():
	$BarContainer/HealthBar.player_stats = player_stats
