extends Control
class_name ItemCard

@export var stat_labels: Array[RichTextLabel]
@export var perk_labels: Array[RichTextLabel]

@onready var title_label: Label = $Background/AlignmentContainer/Container/NameLabel
@onready var icon_rect: TextureRect = $Background/AlignmentContainer/Container/HBoxContainer/TextureRect

func setup_card(item: LootItem, player: CharacterBody3D = null) -> void:
	title_label.text = item.item_name
	
	if item.icon_path != "":
		icon_rect.texture = load("res://Assets/Sprites/" + item.icon_path)
		
	# 1. Figure out what the player is currently wearing
	var equipped_item: LootItem = null
	if player:
		match item.item_type:
			"helmet":
				equipped_item = player.equipped_helmet
			"chest":
				equipped_item = player.equipped_chest

	# 2. Distribute and Color Stats
	var stat_lines = item.get_stat_lines()
	var stat_keys = item.stats.keys() # Assuming stats is a Dictionary
	
	for i in range(stat_labels.size()):
		if i < stat_lines.size():
			var base_text = stat_lines[i]
			var color_tag = "[color=white]" # Default to white
			
			# If we successfully grabbed a matching key for this line
			if i < stat_keys.size():
				var stat_key = stat_keys[i]
				var new_val: float = item.stats[stat_key]
				var old_val: float = 0.0
				
				# Check if the equipped item has this same stat
				if equipped_item and equipped_item.stats.has(stat_key):
					old_val = equipped_item.stats[stat_key]
					
				# Compare values to determine color
				if equipped_item == null or new_val > old_val:
					color_tag = "[color=green]"
				elif new_val < old_val:
					color_tag = "[color=red]"
			
			# Wrap the existing line
			stat_labels[i].text = color_tag + base_text + "[/color]"
			stat_labels[i].show()
		else:
			stat_labels[i].hide()
			
	# Distribute Perks
	var perk_lines = item.get_perk_lines()
	var perk_descs = item.get_perk_descs()
	for i in range(perk_labels.size()):
		if i < perk_lines.size():
			perk_labels[i].text = perk_lines[i] + ": " + perk_descs[i]
			perk_labels[i].show()
		else:
			perk_labels[i].hide()
