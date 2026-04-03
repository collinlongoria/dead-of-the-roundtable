extends Control
class_name ItemCard

@export var stat_labels: Array[RichTextLabel]
@export var perk_labels: Array[RichTextLabel]

@onready var title_label: Label = $Background/AlignmentContainer/Container/NameLabel
@onready var icon_rect: TextureRect = $Background/AlignmentContainer/Container/TextureRect

func setup_card(item: LootItem) -> void:
	title_label.text = item.item_name
	
	if item.icon_path != "":
		icon_rect.texture = load("res://Assets/Sprites/" + item.icon_path)
		
	# Distribute Stats
	var stat_lines = item.get_stat_lines()
	for i in range(stat_labels.size()):
		if i < stat_lines.size():
			stat_labels[i].text = stat_lines[i]
			stat_labels[i].show()
		else:
			stat_labels[i].hide()
			
	# Distribute Perks
	var perk_lines = item.get_perk_lines()
	for i in range(perk_labels.size()):
		if i < perk_lines.size():
			perk_labels[i].text = perk_lines[i]
			perk_labels[i].show()
		else:
			perk_labels[i].hide()
