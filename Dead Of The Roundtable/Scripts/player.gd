extends Node3D

# Refs
@onready var body: CharacterBody3D = $PlayerController
@onready var camera: Camera3D = $PlayerController/PlayerCamera
@onready var mesh: MeshInstance3D = $PlayerController/PlayerMesh

# Params
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var sprint_acceleration: float = 20.0
@export var crouch_speed: float = 2.5
@export var slide_speed_initial: float = 18.0
@export var slide_friction: float = 18.0
@export var slide_end_threshold: float = 2.0
@export var mouse_sensitivity: float = 0.003

# Camera Tilt Params
@export var strafe_tilt_max: float = 1.5
@export var forward_tilt_max: float = 0.3
@export var tilt_lerp_speed: float = 8.0
@export var crouch_camera_offset: float = 0.5

# State Machine Vars
enum State { IDLE, WALK, SPRINT, CROUCH, SLIDE, AIR }
var state: State = State.IDLE

# Internal Vars
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_speed: float = 0.0
var current_slide_speed: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var original_camera_y: float = 0.0
var sprint_toggled: bool = false
var slide_just_ended: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera:
		original_camera_y = camera.position.y


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		body.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var on_floor := body.is_on_floor()

	# sprint toggle
	if Input.is_action_just_pressed("sprint"):
		sprint_toggled = not sprint_toggled
	if input_dir == Vector2.ZERO:
		sprint_toggled = false

	# gravity
	if not on_floor:
		body.velocity.y -= gravity * delta

	# post-slide crouch suppression
	if slide_just_ended and not Input.is_action_pressed("slide"):
		slide_just_ended = false

	# state transitions
	var next_state := _determine_state(input_dir, on_floor)

	if next_state != state:
		_exit_state(state)
		_enter_state(next_state, input_dir)
		state = next_state

	# movement
	_process_state(delta, input_dir)

	# camera tilt
	_apply_camera_tilt(delta, input_dir)

	# camera duck
	var ducking := state == State.SLIDE or state == State.CROUCH
	var target_y := original_camera_y - crouch_camera_offset if ducking else original_camera_y
	camera.position.y = lerp(camera.position.y, target_y, 10.0 * delta)

	body.move_and_slide()

func _determine_state(input_dir: Vector2, on_floor: bool) -> State:
	# slide cannot be canceled
	if state == State.SLIDE:
		if Vector2(body.velocity.x, body.velocity.z).length() < slide_end_threshold:
			return State.IDLE
		return State.SLIDE

	if not on_floor:
		return State.AIR

	# slide entry
	if Input.is_action_just_pressed("slide") and sprint_toggled and input_dir != Vector2.ZERO and current_speed >= sprint_speed:
		return State.SLIDE

	# crouch hold
	if Input.is_action_pressed("slide") and not slide_just_ended:
		return State.CROUCH

	if input_dir == Vector2.ZERO:
		return State.IDLE

	if sprint_toggled:
		return State.SPRINT

	return State.WALK

func _enter_state(s: State, input_dir: Vector2) -> void:
	match s:
		State.SLIDE:
			current_slide_speed = slide_speed_initial
			slide_direction = (body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		State.IDLE:
			current_speed = 0.0


func _exit_state(s: State) -> void:
	match s:
		State.SLIDE:
			sprint_toggled = false
			slide_just_ended = true
			current_speed = walk_speed
		State.SPRINT:
			pass

func _process_state(delta: float, input_dir: Vector2) -> void:
	match state:
		State.SLIDE:
			_move_slide(delta)
		State.AIR:
			_move_directed(delta, input_dir, current_speed)
		_:
			var target := _target_speed_for(state)
			current_speed = move_toward(current_speed, target, sprint_acceleration * delta)
			_move_directed(delta, input_dir, current_speed)


func _move_directed(delta: float, input_dir: Vector2, speed: float) -> void:
	var direction := (body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		body.velocity.x = direction.x * speed
		body.velocity.z = direction.z * speed
	else:
		body.velocity.x = move_toward(body.velocity.x, 0, sprint_speed)
		body.velocity.z = move_toward(body.velocity.z, 0, sprint_speed)


func _move_slide(delta: float) -> void:
	current_slide_speed = move_toward(current_slide_speed, 0.0, slide_friction * delta)
	body.velocity.x = slide_direction.x * current_slide_speed
	body.velocity.z = slide_direction.z * current_slide_speed


func _target_speed_for(s: State) -> float:
	match s:
		State.SPRINT: return sprint_speed
		State.CROUCH: return crouch_speed
		State.WALK:   return walk_speed
		_:            return 0.0

func _apply_camera_tilt(delta: float, input_dir: Vector2) -> void:
	# roll from strafing
	var target_roll := deg_to_rad(-input_dir.x * strafe_tilt_max)

	# nudge from forward/back movement
	var target_pitch_offset := deg_to_rad(input_dir.y * forward_tilt_max)

	# blend
	var current_roll := camera.rotation.z
	camera.rotation.z = lerp(current_roll, target_roll, tilt_lerp_speed * delta)

	# pitch tilt
	var pitch_tilt_current: float = camera.get_meta("pitch_tilt", 0.0) as float
	var pitch_tilt_new: float = lerp(pitch_tilt_current, target_pitch_offset, tilt_lerp_speed * delta)

	# remove old and apply new tilt
	camera.rotation.x -= pitch_tilt_current
	camera.rotation.x += pitch_tilt_new
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	camera.set_meta("pitch_tilt", pitch_tilt_new)
