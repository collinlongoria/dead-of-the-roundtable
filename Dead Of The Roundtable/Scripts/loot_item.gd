extends Resource
class_name LootItem

@export var item_name: String = ""
@export var rarity: String = ""
@export var icon_path: String = ""
@export var item_type: String = ""

@export var stats: Dictionary = {}

@export var perks: Array[Perk] = []

func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	
	for stat_enum in stats:
		var amount: float = stats[stat_enum]
		var stat_string: String = PlayerStats.Stat.keys()[stat_enum].capitalize().replace("_", " ")
		
		if PlayerStats.is_flat_stat(stat_enum):
			lines.append("+%d %s" % [roundi(amount), stat_string])
		else:
			var percentage: int = roundi(amount * 100)
			lines.append("+%d%% %s" % [percentage, stat_string])
	
	return lines
	
func get_perk_lines() -> Array[String]:
	var lines: Array[String] = []
	
	for perk in perks:
		lines.append("[b]%s[/b]" % perk.perk_name)
	
	return lines

func to_dict() -> Dictionary:
	var perk_data: Array = []
	for perk in perks:
		var safe_path = perk.get_meta("original_path", perk.resource_path)
		
		perk_data.append({
			"path": safe_path,
			"name": perk.perk_name,
			"desc": perk.perk_desc
		})
		
	return {
		"item_name": item_name,
		"rarity": rarity,
		"icon_path": icon_path,
		"item_type": item_type,
		"stats": stats,
		"perks": perk_data
	}

func load_from_dict(data: Dictionary) -> void:
	item_name = data.get("item_name", "")
	rarity = data.get("rarity", "")
	icon_path = data.get("icon_path", "")
	item_type = data.get("item_type", "")
	stats = data.get("stats", {})
	
	perks.clear()
	for p_data in data.get("perks", []):
		var p_path = p_data.get("path", "")
		
		# Safety check to prevent load("") crashes
		if p_path == "":
			continue
			
		var perk_res = load(p_path)
		if perk_res:
			var inst = perk_res.duplicate()
			inst.perk_name = p_data.get("name", "Unknown")
			inst.perk_desc = p_data.get("desc", "Unknown")
			
			# Re-stamp the metadata so it survives future network syncs
			inst.set_meta("original_path", p_path) 
			
			perks.append(inst)
