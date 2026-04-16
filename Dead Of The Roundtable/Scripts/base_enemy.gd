extends CharacterBody3D
class_name BaseEnemy

signal died(enemy_node)

@export var speed: float = 3.0
@export var max_health: float = 100.0
@export var target_group: String = "targets"
@export var damage: float = 10.0 

var current_health: float
var is_active: bool = false
var target: Node3D

@onready var nav_agent: NavigationAgent3D = $ZombieNavigationAgent

func _ready() -> void:
	deactivate()
	if not multiplayer.is_server():
		nav_agent.avoidance_enabled = false

func activate(spawn_position: Vector3) -> void:
	global_position = spawn_position
	current_health = max_health
	is_active = true
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	
	if multiplayer.is_server() and has_node("TargetTimer"):
		$TargetTimer.start()

func deactivate() -> void:
	is_active = false
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	global_position = Vector3(0, -1000, 0)
	
	if has_node("TargetTimer"):
		$TargetTimer.stop()

func take_damage(amount: float) -> void:
	if not multiplayer.is_server() or not is_active:
		return

	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	died.emit(self)
	deactivate()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not is_active:
		return
	
	if not target or nav_agent.is_navigation_finished():
		return
	
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	var desired_velocity = direction * speed
	
	nav_agent.set_velocity(desired_velocity)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not multiplayer.is_server() or not is_active:
		return

	velocity = safe_velocity
	if not is_on_floor():
		velocity.y -= 9.8 * get_physics_process_delta_time()
	
	move_and_slide()
