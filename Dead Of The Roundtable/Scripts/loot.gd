extends RigidBody3D
class_name LootDrop

@export var item_data: LootItem

const ITEM_CARD_SCENE: PackedScene = preload("res://Scenes/item_card.tscn")
var active_card: ItemCard = null

func _ready() -> void:
	if item_data:
		_refresh_card()
	
	item_data = LootDatabase.generate_loot("helmet", "rare")

func _refresh_card() -> void:
	if active_card:
		active_card.setup_card(item_data)

func focus() -> void:
	if not item_data or active_card: 
		return
		
	active_card = ITEM_CARD_SCENE.instantiate()
	
	get_tree().root.add_child(active_card) 
	active_card.setup_card(item_data)

func unfocus() -> void:
	if active_card:
		active_card.queue_free()
		active_card = null

func _process(_delta: float) -> void:
	if active_card and is_instance_valid(active_card):
		var camera := get_viewport().get_camera_3d()
		if not camera: return
		
		var target_pos = global_position + Vector3(0, 0.5, 0)
		
		if camera.is_position_behind(target_pos):
			active_card.hide()
		else:
			active_card.show()
			
			var screen_pos = camera.unproject_position(target_pos)
			
			# Get the boundaries
			var viewport_size = get_viewport().get_visible_rect().size
			var card_size = active_card.custom_minimum_size
			
			# Calculate the ideal default position
			var ideal_pos = screen_pos - Vector2(card_size.x * 0.5, card_size.y)
			
			# Define a safe margin
			var margin := 16.0 
			
			# Clamp the X and Y coordinates to stay inside the screen bounds
			var clamped_x = clamp(ideal_pos.x, margin, viewport_size.x - card_size.x - margin)
			var clamped_y = clamp(ideal_pos.y, margin, viewport_size.y - card_size.y - margin)
			
			active_card.global_position = Vector2(clamped_x, clamped_y)

func interact(player: CharacterBody3D) -> void:
	if not item_data: 
		return

	var old_item: LootItem = null
	match item_data.item_type:
		"helmet":
			old_item = player.equipped_helmet
		"chest":
			old_item = player.equipped_chest

	player.equip_item(item_data)

	if old_item:
		item_data = old_item
		_refresh_card()
	else:
		unfocus() 
		queue_free()
