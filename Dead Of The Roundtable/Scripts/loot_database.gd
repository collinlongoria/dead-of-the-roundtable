extends Node

var loot_data: Dictionary = {}

const POSSIBLE_STATS: Dictionary = {
	"helmet": [
		PlayerStats.Stat.DAMAGE_MULTIPLIER,
		PlayerStats.Stat.ATTACK_SPEED_MULTIPLIER,
		PlayerStats.Stat.KNOCKBACK_MULTIPLIER
	],
	"chest": [
		PlayerStats.Stat.HEALTH,
		PlayerStats.Stat.HEALTH_REGEN,
		PlayerStats.Stat.THORNS
	]
}

func _ready() -> void:
	_load_json("helmet", "res://Data/Items/helmet_data.json")
	_load_json("chest", "res://Data/Items/chest_data.json")

func _load_json(type_key: String, file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		push_error("Loot Database cannot find file: " + file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(content)
	
	if error != OK:
		push_error("Loot Database JSON parse error in " + type_key + ": ", json.get_error_message(), " at line ", json.get_error_line())
		return
	
	var data = json.get_data()
	
	if typeof(data) == TYPE_DICTIONARY:
		loot_data[type_key] = {
			"perks": data.get(type_key + "_perks", {}),
			"rarities": data.get(type_key + "_rarities", {})
		}
		print("Loot Database successfully loaded " + type_key + " data.")
	else:
		push_error("Loot Database received bad JSON file for " + type_key)

func generate_loot(type_key: String, rarity_key: String) -> LootItem:
	if not loot_data.has(type_key):
		push_error("Loot generator requested unknown type: " + type_key)
		return null
		
	var type_data: Dictionary = loot_data[type_key]
	var rarities: Dictionary = type_data["rarities"]
	var perks_db: Dictionary = type_data["perks"]
	
	if not rarities.has(rarity_key):
		push_error("Loot generator requested unknown rarity: " + rarity_key + " for type: " + type_key)
		return null
		
	var r_data: Dictionary = rarities[rarity_key]
	
	var new_item := LootItem.new()
	new_item.item_type = type_key
	new_item.item_name = r_data.get("name", "Unknown Item")
	new_item.icon_path = r_data.get("icon", "")
	new_item.rarity = rarity_key
	
	var stat_count: int = r_data.get("stat_count", 0)
	var perk_count: int = r_data.get("perk_count", 0)
	
	if POSSIBLE_STATS.has(type_key):
		var available_stats: Array = POSSIBLE_STATS[type_key].duplicate()
		available_stats.shuffle()
		
		var stats_to_add: int = min(stat_count, available_stats.size())
		
		for i in range(stats_to_add):
			var stat_enum: int = available_stats[i]
			var roll := randi_range(1, 3)
			var increase := 0.0
			
			if roll == 1: increase = 0.05
			if roll == 2: increase = 0.10
			if roll == 3: increase = 0.20
			
			new_item.stats[stat_enum] = increase
	
	if perk_count > 0 and not perks_db.is_empty():
		var available_perks: Array = perks_db.keys()
		available_perks.shuffle()
		
		var perks_to_add: int = min(perk_count, available_perks.size())
		
		for i in range(perks_to_add):
			var perk_key: String = available_perks[i]
			new_item.perks.append(perks_db[perk_key])
	
	return new_item
