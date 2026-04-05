extends RigidBody3D
class_name LootDrop

@export var item_data: LootItem

@onready var card_sprite: Sprite3D = $UIAnchor/Sprite
@onready var item_card: ItemCard = $SubViewport/ItemCard
@onready var viewport: SubViewport = $SubViewport

func _ready() -> void:
	card_sprite.hide()
	
	# Ensure the viewport renders correctly to the sprite
	viewport.transparent_bg = true
	card_sprite.texture = viewport.get_texture()
	
	if item_data:
		_refresh_card()

func _refresh_card() -> void:
	# Calls the setup_card function from your item_card.gd
	item_card.setup_card(item_data) 

func focus() -> void:
	card_sprite.show()

func unfocus() -> void:
	card_sprite.hide()

func interact(player: CharacterBody3D) -> void:
	if not item_data: 
		return

	# 1. Grab the player's old item before equipping the new one
	var old_item: LootItem = null
	match item_data.item_type:
		"helmet":
			old_item = player.equipped_helmet
		"chest":
			old_item = player.equipped_chest
		# Add more slots here later

	# 2. Equip the new item to the player
	player.equip_item(item_data)

	# 3. Swap logic
	if old_item:
		# If they had an item, this drop becomes the old item
		item_data = old_item
		_refresh_card()
	else:
		# If they had nothing equipped in that slot, consume the drop completely
		queue_free()
