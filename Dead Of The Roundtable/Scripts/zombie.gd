extends CharacterBody3D

# These vars will change based on round
@export var speed: float = 3.0

@export var max_health: float = 100.0
var current_health: float

@export var target_group: String = "targets"

@onready var nav_agent: NavigationAgent3D = $ZombieNavigationAgent

var target: Node3D

func _ready():
	current_health = max_health
	
	$TargetTimer.wait_time = randf_range(0.4, 0.6)

func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	# Can do more here later
	queue_free()

func _physics_process(delta: float) -> void:
	if not target or nav_agent.is_navigation_finished():
		return
	
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	var desired_velocity = direction * speed
	
	nav_agent.set_velocity(desired_velocity)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	
	if not is_on_floor():
		velocity.y -= 9.8 * get_physics_process_delta_time()
	
	move_and_slide()

func _find_closest_target() -> Node3D:
	var potential_targets = get_tree().get_nodes_in_group(target_group)
	
	if potential_targets.is_empty():
		return null
	
	var closest: Node3D = null
	var shortest_distance: float = INF
	
	for potential_target in potential_targets:
		if potential_target is Node3D:
			var distance = global_position.distance_squared_to(potential_target.global_position)
			
			if distance < shortest_distance:
				shortest_distance = distance
				closest = potential_target
	
	return closest

func _on_target_timer_timeout() -> void:
	target = _find_closest_target()
	
	if target:
		nav_agent.target_position = target.global_position
