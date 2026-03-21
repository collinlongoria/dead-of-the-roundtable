extends ProgressBar

@export var player_stats: PlayerStats

func _ready() -> void:
	pass
#	player_stats.stat_changed.connect(_on_stat_changed)

func _on_stat_changed(stat: PlayerStats.Stat, new_value: float) -> void:
	match stat:
		PlayerStats.Stat.HEALTH:
			value = new_value
