extends Node2D

@onready var itemCard: ItemCard = $ItemCard

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
	
	var helmet = LootDatabase.generate_helmet(rarity)
	itemCard.setup_card(helmet)
