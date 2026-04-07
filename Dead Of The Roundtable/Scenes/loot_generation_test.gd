extends Node2D

@onready var itemCard: ItemCard = $ItemCard

var type: String = "helmet"

func _on_button_pressed() -> void:
	var dice: int = round(randf_range(0, 3))
	
	var rarity: String = ""
	match dice:
		0:
			rarity = "common"
		1:
			rarity = "rare"
		2:
			rarity = "epic"
		3:
			rarity = "legendary"
	
	var helmet = LootDatabase.generate_loot(type, rarity)
	itemCard.setup_card(helmet)


func _on_item_list_item_selected(index: int) -> void:
	match index:
		0:
			type = "helmet"
		1:
			type = "chest"
		2:
			type = "gauntlets"
		3:
			type = "boots"
		4:
			type = "amulet"
		5:
			type = "ring"
		_:
			type = "helmet"
