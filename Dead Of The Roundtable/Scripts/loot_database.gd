extends Node

var helmet_perks: Dictionary = {}
var helmet_rarities: Dictionary = {}

func _ready() -> void:
	_load_database()

func _load_database() -> void:
	var file_path := "res://Data/Perks/helmet_data.json"
	
	if not FileAccess.file_exists(file_path):
		push_error("Loot Database cannot find file: " + file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(content)
	
	if error != OK:
		push_error("Loot Database JSON parse error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	
	var data = json.get_data()
	
	if typeof(data) == TYPE_DICTIONARY:
		helmet_perks = data.get("helmet_perks", {})
		helmet_rarities = data.get("helmet_rarities", {})
		print("Loot Database successfully loaded loot data.")
	else:
		push_error("Loot Database received bad JSON file.")

# Helmet
const POSSIBLE_HELMET_STATS: Array[PlayerStats.Stat] = [
	PlayerStats.Stat.DAMAGE_MULTIPLIER,
	PlayerStats.Stat.ATTACK_SPEED_MULTIPLIER,
	PlayerStats.Stat.KNOCKBACK_MULTIPLIER
]

func generate_helmet(rarity_key: String) -> LootItem:
	var new_helmet = LootItem.new()
	
	if helmet_rarities.has(rarity_key):
		var r_data = helmet_rarities[rarity_key]
		new_helmet.item_name = r_data.get("name", "Unknown Helmet")
		new_helmet.icon_path = r_data.get("icon", "")
		new_helmet.rarity = rarity_key
	
	var stat_count: int = 0
	var perk_count: int = 0
	
	match rarity_key:
		"common":
			stat_count = 1
			perk_count = 0
		"rare":
			stat_count = 2
			perk_count = 1
		"epic":
			stat_count = 3
			perk_count = 1
		"legendary":
			stat_count = 3
			perk_count = 2
	
	var available_stats = POSSIBLE_HELMET_STATS.duplicate()
	available_stats.shuffle()
	
	for i in range(stat_count):
		var stat_enum = available_stats[i]
		var roll = randi_range(1, 3)
		var increase = 0.0
		
		if roll == 1: increase = 0.05
		if roll == 2: increase = 0.10
		if roll == 3: increase = 0.20
		
		new_helmet.stats[stat_enum] = increase
	
	if perk_count > 0 and not helmet_perks.is_empty():
		var available_perks = helmet_perks.keys()
		available_perks.shuffle()
		var perks_to_add = min(perk_count, available_perks.size())
		
		for i in range(perks_to_add):
			var perk_key = available_perks[i]
			new_helmet.perks.append(helmet_perks[perk_key])
	
	return new_helmet
