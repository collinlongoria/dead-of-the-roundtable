extends Perk

func on_equip(player: Node3D) -> void:
	player.max_spells += 1

func on_unequip(player: Node3D) -> void:
	player.max_spells -= 1
