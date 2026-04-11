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
	],
	"gauntlets": [
		PlayerStats.Stat.RELOAD_SPEED_MULTIPLIER,
		PlayerStats.Stat.MAXIMUM_MANA,
		PlayerStats.Stat.MAXIMUM_STORED_MANA
	],
	"boots": [
		PlayerStats.Stat.MOVEMENT_SPEED,
		PlayerStats.Stat.CRITICAL_CHANCE_MULTIPLIER,
		PlayerStats.Stat.CRITICAL_DAMAGE_MULTIPLIER
	],
	"amulet": [
		PlayerStats.Stat.OVERSHIELD,
		PlayerStats.Stat.ELEMENTAL_CHANCE_MULTIPLIER,
		PlayerStats.Stat.ELEMENTAL_DAMAGE_MULTIPLIER
	],
	"ring": [
		PlayerStats.Stat.DAMAGE_MULTIPLIER,
		PlayerStats.Stat.ATTACK_SPEED_MULTIPLIER,
		PlayerStats.Stat.KNOCKBACK_MULTIPLIER,
		PlayerStats.Stat.HEALTH,
		PlayerStats.Stat.HEALTH_REGEN,
		PlayerStats.Stat.THORNS,
		PlayerStats.Stat.RELOAD_SPEED_MULTIPLIER,
		PlayerStats.Stat.MAXIMUM_MANA,
		PlayerStats.Stat.MAXIMUM_STORED_MANA,
		PlayerStats.Stat.MOVEMENT_SPEED,
		PlayerStats.Stat.CRITICAL_CHANCE_MULTIPLIER,
		PlayerStats.Stat.CRITICAL_DAMAGE_MULTIPLIER,
		PlayerStats.Stat.OVERSHIELD,
		PlayerStats.Stat.ELEMENTAL_CHANCE_MULTIPLIER,
		PlayerStats.Stat.ELEMENTAL_DAMAGE_MULTIPLIER
	]
}

func _ready() -> void:
	_load_json("helmet", "res://Data/Items/helmet_data.json")
	_load_json("chest", "res://Data/Items/chest_data.json")
	_load_json("gauntlets", "res://Data/Items/gauntlets_data.json")
	_load_json("boots", "res://Data/Items/boots_data.json")
	_load_json("amulet", "res://Data/Items/amulet_data.json")
	_load_json("ring", "res://Data/Items/ring_data.json")

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
			
			if PlayerStats.is_flat_stat(stat_enum):
				if roll == 1: increase = 15.0
				if roll == 2: increase = 30.0
				if roll == 3: increase = 50.0
			else:
				if roll == 1: increase = 0.05
				if roll == 2: increase = 0.10
				if roll == 3: increase = 0.20
			
			new_item.stats[stat_enum] = increase
	
	if perk_count > 0 and not perks_db.is_empty():
		# ring logic
		if new_item.item_type == "ring":
			var target_perk_key: String = ""

			match rarity_key:
				"rare": target_perk_key = "1spellslot"
				"epic": target_perk_key = "2spellslot"
				"legendary": target_perk_key = "3spellslot"

			if target_perk_key != "" and perks_db.has(target_perk_key):
				var perk_json_data: Dictionary = perks_db[target_perk_key]
				var resource_path: String = "res://Resources/Perks/" + target_perk_key + ".tres"

				if ResourceLoader.exists(resource_path):
					var executable_perk = load(resource_path)
						
					# Duplicate first, then modify the duplicate!
					var duplicated = executable_perk.duplicate(true)
					duplicated.perk_name = perk_json_data.get("name", "Unknown")
					duplicated.perk_desc = perk_json_data.get("description", "Unknown")
					
					# Stamp the path into the resource's metadata
					duplicated.set_meta("original_path", resource_path)
					
					new_item.perks.append(duplicated)
				else:
					push_error("Loot Database generated a ring perk but missing logic resource at: " + resource_path)
		else:
			var available_perks: Array = perks_db.keys()
			available_perks.shuffle()

			var perks_to_add: int = min(perk_count, available_perks.size())

			for i in range(perks_to_add):
				var perk_key: String = available_perks[i]

				# Grab the JSON data for UI text/names
				var perk_json_data: Dictionary = perks_db[perk_key]

				# Dynamically build the path to the executable logic
				var resource_path: String = "res://Resources/Perks/" + perk_key + ".tres"

				if ResourceLoader.exists(resource_path):
					var executable_perk = load(resource_path)
						
					# Duplicate first, then modify the duplicate!
					var duplicated = executable_perk.duplicate(true)
					duplicated.perk_name = perk_json_data.get("name", "Unknown")
					duplicated.perk_desc = perk_json_data.get("description", "Unknown")
					
					# Stamp the path into the resource's metadata
					duplicated.set_meta("original_path", resource_path)
					
					new_item.perks.append(duplicated)
				else:
					push_error("Loot Database generated a perk but missing logic resource at: " + resource_path)
	
	return new_item
