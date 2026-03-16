extends Node3D

# Node Refs
@onready var body: CharacterBody3D = $PlayerController
@onready var camera: Camera3D = $PlayerController/PlayerCamera
@onready var mesh: MeshInstance3D = $PlayerController/PlayerMesh

# Movement Params
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var sprint_acceleration: float = 20.0
@export var crouch_speed: float = 2.5
@export var slide_speed_initial: float = 18.0
@export var slide_friction: float = 18.0
@export var mouse_sensitivity: float = 0.003

# State Vars
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_sprinting: bool = false
var is_sliding: bool = false
var is_crouching: bool = false
var current_speed: float = 0.0
var current_slide_speed: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var original_camera_y: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera:
		original_camera_y = camera.position.y

func _unhandled_input(event: InputEvent) -> void:
	# free mouse when escape is called
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# cam look
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			# yaw
			body.rotate_y(-event.relative.x * mouse_sensitivity)
			
			# pitch
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	# apply gravity
	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	
	# get input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# sprint toggle
	if Input.is_action_just_pressed("sprint"):
		is_sprinting = not is_sprinting
	
	# stop sprinting if no input
	if input_dir == Vector2.ZERO:
		is_sprinting = false
	
	# slide is uncancellable — only ends naturally
	if not is_sliding:
		# crouch hold
		is_crouching = Input.is_action_pressed("slide")
		
		# start slide only at full sprint speed
		if Input.is_action_just_pressed("slide") and is_sprinting and body.is_on_floor() and input_dir != Vector2.ZERO and current_speed >= sprint_speed:
			start_slide(input_dir)
	else:
		# end slide only when speed runs out
		if Vector2(body.velocity.x, body.velocity.z).length() < 2.0:
			end_slide()
	
	# velocity
	var direction := (body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_sliding:
		current_slide_speed = move_toward(current_slide_speed, 0.0, slide_friction * delta)
		body.velocity.x = slide_direction.x * current_slide_speed
		body.velocity.z = slide_direction.z * current_slide_speed
	else:
		# determine target speed
		var target_speed: float
		if is_crouching:
			target_speed = crouch_speed
		elif is_sprinting:
			target_speed = sprint_speed
		else:
			target_speed = walk_speed
		
		# accelerate/decelerate current_speed toward target
		current_speed = move_toward(current_speed, target_speed, sprint_acceleration * delta)
		
		if direction:
			body.velocity.x = direction.x * current_speed
			body.velocity.z = direction.z * current_speed
		else:
			current_speed = 0.0
			body.velocity.x = move_toward(body.velocity.x, 0, sprint_speed)
			body.velocity.z = move_toward(body.velocity.z, 0, sprint_speed)
	
	# camera ducking
	var target_camera_y = original_camera_y - 0.5 if (is_sliding or is_crouching) else original_camera_y
	camera.position.y = lerp(camera.position.y, target_camera_y, 10.0 * delta)
	
	# apply
	body.move_and_slide()

func start_slide(input_dir: Vector2) -> void:
	is_sliding = true
	is_crouching = false
	current_slide_speed = slide_speed_initial
	slide_direction = (body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func end_slide() -> void:
	is_sliding = false
	is_crouching = false
	is_sprinting = false
	current_speed = walk_speed
