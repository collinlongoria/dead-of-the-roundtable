extends Control
class_name LootCardScroller

const ITEM_CARD_SCENE: PackedScene = preload("res://Scenes/item_card.tscn")
const ITEM_TYPES: Array[String] = ["helmet", "chest", "gauntlets", "boots", "amulet", "ring"]
const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]

@export var num_rows: int = 8
@export var card_size: Vector2 = Vector2(200, 240)  # adjust to match your actual card
@export var horizontal_spacing: float = 40.0
@export var vertical_spacing: float = 60.0
@export var scroll_speed: float = 120.0  # pixels per second, upward
@export var row_offset: float = 140.0    # vertical stagger between rows for the patterned look
@export var spawn_interval: float = 1.5  # seconds between new cards per row

# rarity weights — tweak for the trailer vibe (more legendaries = more flashy)
@export var rarity_weights: Dictionary = {
	"common": 10,
	"rare": 40,
	"epic": 30,
	"legendary": 20,
}

var _row_timers: Array[float] = []
var _active_cards: Array[ItemCard] = []

func _ready() -> void:
	# Each row gets its own little spawn timer, started at a staggered offset
	# so the rows don't all pop a card at the same instant.
	for i in range(num_rows):
		_row_timers.append(spawn_interval * (float(i) / num_rows))

func _process(delta: float) -> void:
	# Tick each row's spawn timer
	for i in range(num_rows):
		_row_timers[i] -= delta
		if _row_timers[i] <= 0.0:
			_spawn_card_in_row(i)
			_row_timers[i] = spawn_interval
	
	# Scroll every active card upward, cull when off-screen
	var viewport_height: float = get_viewport_rect().size.y
	for card in _active_cards.duplicate():
		if not is_instance_valid(card):
			_active_cards.erase(card)
			continue
		card.position.y -= scroll_speed * delta
		if card.position.y + card_size.y < -50.0:
			_active_cards.erase(card)
			card.queue_free()

func _spawn_card_in_row(row_index: int) -> void:
	var item: LootItem = LootDatabase.generate_loot(_random_type(), _random_rarity())
	if not item:
		return
	
	var card: ItemCard = ITEM_CARD_SCENE.instantiate()
	add_child(card)
	card.setup_card(item)
	
	var viewport_size: Vector2 = get_viewport_rect().size
	
	# X: each row sits in its own column, with a stagger so it looks patterned
	var total_row_width: float = num_rows * card_size.x + (num_rows - 1) * horizontal_spacing
	var start_x: float = (viewport_size.x - total_row_width) * 0.5
	var x_pos: float = start_x + row_index * (card_size.x + horizontal_spacing)
	
	# Y: spawn just below the screen, with a per-row vertical offset so adjacent
	# rows don't line up — that's where the patterned/woven look comes from
	var stagger: float = (row_index % 2) * row_offset
	var y_pos: float = viewport_size.y + 20.0 + stagger
	
	card.position = Vector2(x_pos, y_pos)
	_active_cards.append(card)

func _random_type() -> String:
	return ITEM_TYPES[randi() % ITEM_TYPES.size()]

func _random_rarity() -> String:
	var total: int = 0
	for w in rarity_weights.values():
		total += w
	var roll: int = randi() % total
	var running: int = 0
	for rarity in rarity_weights.keys():
		running += rarity_weights[rarity]
		if roll < running:
			return rarity
	return "common"
