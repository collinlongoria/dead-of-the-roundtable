extends Node

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_CONNECTIONS = 4

var peer: ENetMultiplayerPeer

@onready var host_button: Button = $UI/VBoxContainer/HostButton
@onready var join_button: Button = $UI/VBoxContainer/JoinButton
@onready var address_entry: LineEdit = $UI/VBoxContainer/AddressEntry

# level to load
@export var world_scene: PackedScene
var current_world: Node

@export var player_scene: PackedScene

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	
	if error != OK:
		print("Failed to host: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	
	# Since we are hosting, we need to listen for new clients connecting
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	_start_game()
	
	# The host is always peer ID 1
	_spawn_player(1)

func _on_join_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var ip = address_entry.text
	if ip.is_empty():
		ip = DEFAULT_SERVER_IP
		
	var error = peer.create_client(ip, PORT)
	if error != OK:
		print("Failed to join: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	_start_game()

func _start_game() -> void:
	$UI.hide()
	
	if world_scene:
		current_world = world_scene.instantiate()
		add_child(current_world)

# Only the host runs this when a new client connects
func _on_peer_connected(id: int) -> void:
	print("Player connected with ID: ", id)
	_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	print("Player disconnected with ID: ", id)
	
	if not multiplayer.is_server() or not current_world:
		return
	
	var player_to_remove = current_world.get_node_or_null(str(id))
	if player_to_remove:
		player_to_remove.queue_free()

func _spawn_player(id: int) -> void:
	print("Spawning player for ID: ", id)
	
	if not current_world or not player_scene:
		push_error("Missing world or player scene.")
		return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	current_world.add_child(player)
