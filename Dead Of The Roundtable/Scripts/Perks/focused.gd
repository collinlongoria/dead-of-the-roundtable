extends Perk

func on_equip(player: Node3D) -> void:
	player.spread_multiplier = 0.5

func on_unequip(player: Node3D) -> void:
	player.spread_multiplier = 1.0
