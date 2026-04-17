extends Node

var current_round: int = 0
var total_zombies_this_round: int = 0
var zombies_remaining_to_spawn: int = 0
var active_zombies_on_map: int = 0

@export var enemy_scenes: Array[PackedScene]
@export var pool_size: int = 50
@export var base_zombies: int = 6
@export var round_multiplier: float = 1.15
@export var player_group: String = "targets"

var enemy_pool: Array[BaseEnemy] = []
var spawn_timer: Timer
var _started: bool = false

func start() -> void:
	if _started:
		return
	if not multiplayer.is_server():
		return
	_started = true
	
	_initialize_pool()
	
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	call_deferred("start_next_round")

func reset() -> void:
	if spawn_timer:
		spawn_timer.stop()
	for enemy in enemy_pool:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemy_pool.clear()
	current_round = 0
	total_zombies_this_round = 0
	zombies_remaining_to_spawn = 0
	active_zombies_on_map = 0
	_started = false

func _initialize_pool() -> void:
	for i in range(pool_size):
		var random_scene = enemy_scenes.pick_random()
		var enemy: BaseEnemy = random_scene.instantiate()
		
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		enemy_pool.append(enemy)

func start_next_round() -> void:
	current_round += 1
	print("--- ROUND ", current_round, " STARTING ---")
	
	total_zombies_this_round = int(base_zombies * pow(round_multiplier, current_round - 1))
	zombies_remaining_to_spawn = total_zombies_this_round
	active_zombies_on_map = 0
	
	spawn_timer.wait_time = max(0.5, 2.5 - (current_round * 0.1))
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if zombies_remaining_to_spawn <= 0:
		spawn_timer.stop()
		return
		
	if active_zombies_on_map >= pool_size:
		return
		
	_spawn_zombie()

func _spawn_zombie() -> void:
	var zombie = _get_inactive_zombie()
	if not zombie: return
	
	var spawn_pos = _get_best_spawn_position()
	zombie.activate(spawn_pos)
	
	zombies_remaining_to_spawn -= 1
	active_zombies_on_map += 1

func _get_inactive_zombie() -> BaseEnemy:
	for enemy in enemy_pool:
		if not enemy.is_active:
			return enemy
	return null

func _on_enemy_died(_enemy: BaseEnemy) -> void:
	active_zombies_on_map -= 1
	
	if active_zombies_on_map == 0 and zombies_remaining_to_spawn == 0:
		print("Round ", current_round, " completed!")
		get_tree().create_timer(5.0).timeout.connect(start_next_round)

func _get_best_spawn_position() -> Vector3:
	var spawners = get_tree().get_nodes_in_group("spawners")
	var players = get_tree().get_nodes_in_group(player_group)
	
	if spawners.is_empty():
		push_warning("No spawners found!")
		return Vector3.ZERO
		
	if players.is_empty():
		return spawners.pick_random().global_position
		
	var spawner_distances = []
	
	for spawner in spawners:
		var min_dist = INF
		for player in players:
			var dist = spawner.global_position.distance_to(player.global_position)
			if dist < min_dist:
				min_dist = dist
		
		if min_dist > 10.0:
			spawner_distances.append({"spawner": spawner, "distance": min_dist})
			
	spawner_distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	var top_spawners = spawner_distances.slice(0, 3)
	
	if top_spawners.size() > 0:
		var chosen = top_spawners.pick_random()
		return chosen.spawner.global_position
		
	return spawners.pick_random().global_position
