extends Resource
class_name LootItem

@export var item_name: String = ""
@export var rarity: String = ""
@export var icon_path: String = ""
@export var item_type: String = ""

@export var stats: Dictionary = {}

@export var perks: Array[Dictionary] = []

func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	
	for stat_enum in stats:
		var amount: float = stats[stat_enum]
		var percentage: int = roundi(amount * 100)
		
		var stat_string: String = PlayerStats.Stat.keys()[stat_enum].capitalize().replace("_", " ")
		
		lines.append("[color=green]+%d%% %s[/color]" % [percentage, stat_string])
	
	return lines
	
func get_perk_lines() -> Array[String]:
	var lines: Array[String] = []
	
	for perk in perks:
		lines.append("[b]%s[/b]" % perk.name)
	
	return lines
