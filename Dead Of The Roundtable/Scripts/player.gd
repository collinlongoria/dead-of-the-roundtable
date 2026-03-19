extends CharacterBody3D

# Refs
@onready var camera: Camera3D = $PlayerCamera
@onready var mesh: MeshInstance3D = $PlayerMesh
@onready var spell_spawn_point: Marker3D = $PlayerCamera/SpellSpawnPoint

# Params
@export var walk_speed: float = 5.0 # base walk speed
@export var sprint_speed: float = 10.0 # max sprint speed
@export var sprint_acceleration: float = 20.0 # sprint accel to max
@export var crouch_speed: float = 2.5 # base crouch speed
@export var slide_speed_initial: float = 18.0 # when the player slides, this is how fast it starts
@export var slide_friction: float = 18.0 # friction for slowing slide
@export var slide_end_threshold: float = 2.0 # how slow the player must be sliding for it to end
@export var mouse_sensitivity: float = 0.003 # mouse sensitiivity multiplier

# Spell Params
@export var equipped_spell: SpellData

# Camera Tilt Params
@export var strafe_tilt_max: float = 1.5 # maximum amount camera will tilt (side to side)
@export var forward_tilt_max: float = 0.3 # maximum amount camera will tilt (forward and back)
@export var tilt_lerp_speed: float = 8.0 # speed to reach max tilt distance
@export var crouch_camera_offset: float = 0.5 # amount the camera lowers when you crouch

# Camera Bob Params
@export var bob_frequency: float = 2.0 # how fast the head bobs
@export var bob_amplitude: float = 0.08 # how far up and down the head bobs

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
var bob_time: float = 0.0
var can_fire: bool = true

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if is_multiplayer_authority():
		position = Vector3(randf_range(-2, 2), 2.0, randf_range(-2, 2))
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	if camera:
		camera.current = is_multiplayer_authority()
		original_camera_y = camera.position.y


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
		
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var on_floor := is_on_floor()

	if Input.is_action_just_pressed("sprint"):
		sprint_toggled = not sprint_toggled
	if input_dir == Vector2.ZERO:
		sprint_toggled = false

	if not on_floor:
		velocity.y -= gravity * delta

	if slide_just_ended and not Input.is_action_pressed("slide"):
		slide_just_ended = false

	var next_state := _determine_state(input_dir, on_floor)

	if next_state != state:
		_exit_state(state)
		_enter_state(next_state, input_dir)
		state = next_state

	_process_state(delta, input_dir)
	_apply_camera_tilt(delta, input_dir)

	# base Y target (handles crouching/sliding)
	var ducking := state == State.SLIDE or state == State.CROUCH
	var base_target_y := original_camera_y - crouch_camera_offset if ducking else original_camera_y
	
	# camera bob logic
	var bob_offset := 0.0
	if on_floor and input_dir != Vector2.ZERO and state != State.SLIDE:
		bob_time += delta * velocity.length() * bob_frequency
		bob_offset = sin(bob_time) * bob_amplitude
	else:
		bob_time = 0.0
	
	# combine!
	var target_y := base_target_y + bob_offset
	camera.position.y = lerp(camera.position.y, target_y, 10.0 * delta)

	move_and_slide()
	
	_handle_shooting()

func _determine_state(input_dir: Vector2, on_floor: bool) -> State:
	if state == State.SLIDE:
		if Vector2(velocity.x, velocity.z).length() < slide_end_threshold:
			return State.IDLE
		return State.SLIDE

	if not on_floor:
		return State.AIR

	if Input.is_action_just_pressed("slide") and sprint_toggled and input_dir != Vector2.ZERO and current_speed >= sprint_speed:
		return State.SLIDE

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
			slide_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
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
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, sprint_speed)
		velocity.z = move_toward(velocity.z, 0, sprint_speed)


func _move_slide(delta: float) -> void:
	current_slide_speed = move_toward(current_slide_speed, 0.0, slide_friction * delta)
	velocity.x = slide_direction.x * current_slide_speed
	velocity.z = slide_direction.z * current_slide_speed


func _target_speed_for(s: State) -> float:
	match s:
		State.SPRINT: return sprint_speed
		State.CROUCH: return crouch_speed
		State.WALK:   return walk_speed
		_:            return 0.0

func _apply_camera_tilt(delta: float, input_dir: Vector2) -> void:
	var target_roll := deg_to_rad(-input_dir.x * strafe_tilt_max)
	var target_pitch_offset := deg_to_rad(input_dir.y * forward_tilt_max)

	var current_roll := camera.rotation.z
	camera.rotation.z = lerp(current_roll, target_roll, tilt_lerp_speed * delta)

	var pitch_tilt_current: float = camera.get_meta("pitch_tilt", 0.0) as float
	var pitch_tilt_new: float = lerp(pitch_tilt_current, target_pitch_offset, tilt_lerp_speed * delta)

	camera.rotation.x -= pitch_tilt_current
	camera.rotation.x += pitch_tilt_new
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	camera.set_meta("pitch_tilt", pitch_tilt_new)

func _handle_shooting() -> void:
	if not equipped_spell:
		return
	if not can_fire:
		return

	var is_shooting = false
	if equipped_spell.automatic:
		is_shooting = Input.is_action_pressed("shoot")
	else:
		is_shooting = Input.is_action_just_pressed("shoot")

	if is_shooting:
		_cast_spell()

func _cast_spell() -> void:
	can_fire = false
	
	# find exact center of the screen
	var viewport := get_viewport()
	var screen_center := viewport.get_visible_rect().size / 2.0
	
	# shoot ray from camera
	var from := camera.project_ray_origin(screen_center)
	var to := from + camera.project_ray_normal(screen_center) * 1000.0
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self.get_rid()] # dont include self
	
	var result := space_state.intersect_ray(query)
	var target_point: Vector3
	
	if result:
		target_point = result.position
	else:
		target_point = to
	
	# request host to spawn spell
	_server_spawn_spell.rpc_id(1, spell_spawn_point.global_position, target_point)
	
	# start cooldown timer
	var timer := get_tree().create_timer(equipped_spell.fire_rate)
	timer.timeout.connect(func(): can_fire = true)

@rpc("any_peer", "call_local", "reliable")
func _server_spawn_spell(spawn_pos: Vector3, target_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	
	var projectile = equipped_spell.projectile_scene.instantiate()
	get_parent().add_child(projectile, true)
	projectile.global_position = spawn_pos
	projectile.look_at(target_pos, Vector3.UP)
	
	if "damage" in projectile:
		projectile.damage = equipped_spell.damage
