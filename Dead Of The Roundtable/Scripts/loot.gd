extends RigidBody3D
class_name LootDrop

@export var outline_color: Color = Color(0.2, 0.8, 0.2, 1.0)
@export var outline_color2: Color = Color(0.757, 0.253, 0.09, 1.0)
@export var hover_multiplier: float = 13.0
@export var depth_proxy_shader: Shader
@export var color_proxy_shader: Shader

@export var item_data: LootItem

@onready var depth_proxy_mesh: MeshInstance3D = $OutlineDepthProxy
@onready var color_proxy_mesh: MeshInstance3D = $OutlineColorProxy
var depth_proxy_material: ShaderMaterial
var color_proxy_material: ShaderMaterial

const ITEM_CARD_SCENE: PackedScene = preload("res://Scenes/item_card.tscn")
var active_card: ItemCard = null
var viewing_player: CharacterBody3D = null

func _ready() -> void:
	depth_proxy_material = ShaderMaterial.new()
	depth_proxy_material.shader = depth_proxy_shader
	depth_proxy_mesh.material_override = depth_proxy_material

	color_proxy_material = ShaderMaterial.new()
	color_proxy_material.shader = color_proxy_shader
	color_proxy_material.set_shader_parameter("outline_color", Vector3(outline_color.r, outline_color.g, outline_color.b))
	color_proxy_mesh.material_override = color_proxy_material
	
	if item_data:
		_refresh_card()
	
	# can put this somewhere else later
	_roll_loot()

func _roll_loot() -> void:
	var rarity_roll: int = round(randf_range(1,100))
	var type_roll: int = round(randf_range(1,1)) # change this later
	
	var rarity: String = ""
	var type: String = ""
	
	if rarity_roll <= 30:
		rarity = "common"
	elif rarity_roll <= 60:
		rarity = "rare"
	elif rarity_roll <= 90:
		rarity = "epic"
	else:
		rarity = "legendary"
	
	match type_roll:
		1:
			type = "helmet"
		2:
			type = "chest"
		3:
			type = "gauntlets"
		4:
			type = "boots"
		5:
			type = "amulet"
		6:
			type = "ring"
	
	item_data = LootDatabase.generate_loot(type, rarity)

func _refresh_card() -> void:
	if active_card:
		active_card.setup_card(item_data, viewing_player)

func focus(player: CharacterBody3D = null) -> void:
	if not item_data or active_card: 
		return
	
	viewing_player = player # Store them for refresh calls
	active_card = ITEM_CARD_SCENE.instantiate()
	
	get_tree().root.add_child(active_card) 
	active_card.scale = Vector2(1.4,1.4)
	
	active_card.setup_card(item_data, viewing_player)
	
	var hovered: Color = outline_color2
	color_proxy_material.set_shader_parameter("outline_color", Vector3(hovered.r, hovered.g, hovered.b))

func unfocus() -> void:
	if active_card:
		active_card.queue_free()
		active_card = null
		
	color_proxy_material.set_shader_parameter("outline_color", Vector3(outline_color.r, outline_color.g, outline_color.b))

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
