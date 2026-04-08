extends CharacterBody3D

signal health_changed(new_health: float, max_health: float)

# Refs
@onready var camera: Camera3D = $PlayerCamera
@onready var mesh: MeshInstance3D = $PlayerMesh
@onready var spell_spawn_point: Marker3D = $PlayerCamera/SpellSpawnPoint
@onready var interact_ray: RayCast3D = $PlayerCamera/InteractRay
@onready var post_process_quad: MeshInstance3D = $PlayerCamera/DepthMesh

@onready var sub_viewport_depth: SubViewport = $OutlineDepthViewport
@onready var sub_viewport_color: SubViewport = $OutlineColorViewport
@onready var outline_camera_depth: Camera3D = $OutlineDepthViewport/OutlineDepthCamera
@onready var outline_camera_color: Camera3D = $OutlineColorViewport/OutlineColorCamera

# Loot
@export_group("Equipment")
@export var equipped_helmet: LootItem
@export var equipped_chest: LootItem
@export var equipped_gauntlets: LootItem
@export var equipped_boots: LootItem
@export var equipped_amulet: LootItem
@export var equipped_ring: LootItem

var active_perks: Array[Perk] = []

# Params
@export_group("Base Speeds")
@export var base_walk_speed: float = 5.0 # base walk speed
@export var base_sprint_speed: float = 10.0 # max sprint speed
@export var base_crouch_speed: float = 2.5 # base crouch speed
@export var base_slide_speed_initial: float = 18.0 # when the player slides, this is how fast it starts

@export_group("Movement Settings")
@export var slide_friction: float = 18.0 # friction for slowing slide
@export var slide_end_threshold: float = 2.0 # how slow the player must be sliding for it to end
@export var mouse_sensitivity: float = 0.003 # mouse sensitiivity multiplier
@export var sprint_acceleration: float = 20.0 # sprint accel to max

# Spell Params
@export_group("Stats")
@export var equipped_spell: SpellData
@export var stats: PlayerStats

# Camera Tilt Params
@export_group("Camera Settings")
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
var current_health: float
var current_target: Node3D = null # what is currently being looked at

# movement vars
var walk_speed: float:
	get: return base_walk_speed * (stats.movement_speed if stats else 1.0)

var sprint_speed: float:
	get: return base_sprint_speed * (stats.movement_speed if stats else 1.0)

var crouch_speed: float:
	get: return base_crouch_speed * (stats.movement_speed if stats else 1.0)

var slide_speed_initial: float:
	get: return base_slide_speed_initial * (stats.movement_speed if stats else 1.0)

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	var quad_material: ShaderMaterial = post_process_quad.get_active_material(0)
	if quad_material:
		quad_material = quad_material.duplicate()
		post_process_quad.set_surface_override_material(0, quad_material)
		
		quad_material.set_shader_parameter("proxy_depth_tex", sub_viewport_depth.get_texture())
		quad_material.set_shader_parameter("proxy_color_tex", sub_viewport_color.get_texture())
	
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		current_health = stats.health
		
		# HUD connection
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			health_changed.connect(hud._on_player_health_changed)
			health_changed.emit(current_health, stats.health)
		else:
			push_warning("Player spawned, but no HUD found in scene!")
	else:
		sub_viewport_depth.render_target_update_mode = SubViewport.UPDATE_DISABLED
		sub_viewport_color.render_target_update_mode = SubViewport.UPDATE_DISABLED
		
	if camera:
		camera.current = is_multiplayer_authority()
		original_camera_y = camera.position.y
	
	# Black environments on both outline cameras so they don't render the sky
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	outline_camera_depth.environment = env
	outline_camera_color.environment = env.duplicate()

	# Initial viewport size + connect to size changes
	_resize_outline_viewports()
	get_viewport().size_changed.connect(_resize_outline_viewports)
	
	_sync_outline_cameras()


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
	
	_handle_interaction()
	
	# fire tick perks
	for perk in active_perks:
		if perk.has_method("on_tick"):
			perk.on_tick(self, delta)
	

func _process(delta: float) -> void:
	_sync_outline_cameras()

func _resize_outline_viewports() -> void:
	var s: Vector2i = get_viewport().size
	sub_viewport_depth.size = s
	sub_viewport_color.size = s

func _sync_outline_cameras() -> void:
	outline_camera_depth.global_transform = camera.global_transform
	outline_camera_depth.fov = camera.fov
	outline_camera_depth.near = camera.near
	outline_camera_depth.far = camera.far
	outline_camera_depth.projection = camera.projection
	outline_camera_depth.keep_aspect = camera.keep_aspect

	outline_camera_color.global_transform = camera.global_transform
	outline_camera_color.fov = camera.fov
	outline_camera_color.near = camera.near
	outline_camera_color.far = camera.far
	outline_camera_color.projection = camera.projection
	outline_camera_color.keep_aspect = camera.keep_aspect

func _handle_interaction() -> void:
	var collider = interact_ray.get_collider()
	
	# If we are looking at a LootDrop
	if collider is LootDrop:
		if current_target != collider:
			if current_target and current_target.has_method("unfocus"):
				current_target.unfocus()
			
			current_target = collider
			current_target.focus(self)
			
		if Input.is_action_just_pressed("interact"):
			_server_interact_with_loot.rpc_id(1, current_target.get_path())
			
	elif current_target:
		if current_target.has_method("unfocus"):
			current_target.unfocus()
		current_target = null

@rpc("any_peer", "call_local", "reliable")
func _server_interact_with_loot(loot_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	
	var target_loot = get_node_or_null(loot_path)
	if target_loot and target_loot is LootDrop:
		target_loot.interact(self)

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
	
	# get absolute camera orientation
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	
	# get bloom
	var spread_amount: float = equipped_spell.accuracy
	
	# random point with inside a circle for bloom
	var random_angle := randf() * TAU
	var random_radius := randf() * spread_amount
	var rand_x := cos(random_angle) * random_radius
	var rand_y := sin(random_angle) * random_radius
	
	var cast_direction := (forward + (right * rand_x) + (up * rand_y)).normalized()
	
	# shoot ray from camera
	var from := camera.global_position
	var to := from + (cast_direction * 1000.0)
	
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
	var spell_scene_path := equipped_spell.projectile_scene.resource_path
	
	# combine with player stats
	var final_damage := equipped_spell.damage * stats.damage_multiplier
	var is_crit := randf() <= (stats.critical_chance_multiplier - 1.0)
	
	if is_crit:
		final_damage *= stats.critical_damage_multiplier
	
	_server_spawn_spell.rpc_id(1, spell_spawn_point.global_position, target_point, velocity, spell_scene_path, final_damage, is_crit, self.get_path())
	
	# start cooldown timer
	var final_fire_rate = equipped_spell.fire_rate / stats.attack_speed_multiplier
	var timer := get_tree().create_timer(final_fire_rate)
	timer.timeout.connect(func(): can_fire = true)
	
	# perks
	if not multiplayer.is_server():
		for perk in active_perks:
			if perk.has_method("on_cast"):
				perk.on_cast(self)

func take_damage(amount: float, attacker: Node3D = null) -> void:
	var context := HitContext.new()
	context.victim = self
	context.attacker = attacker
	context.base_damage = amount
	context.final_damage = amount
	
	for perk in active_perks:
		if perk.has_method("modify_incoming_hit"):
			perk.modify_incoming_hit(context)
			
	current_health -= context.final_damage
	current_health = clamp(current_health, 0.0, stats.health)
	health_changed.emit(current_health, stats.health)

@rpc("any_peer", "call_local", "reliable")
func _server_spawn_spell(spawn_pos: Vector3, target_pos: Vector3, player_velocity: Vector3, scene_path: String, damage: float, is_crit: bool, attacker_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	
	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("Failed to load spell scene: ", scene_path)
		return

	var projectile = scene.instantiate()
	get_parent().add_child(projectile, true)
	projectile.global_position = spawn_pos
	
	var dir := (target_pos - spawn_pos).normalized()
	
	if dir.length_squared() > 0.0001:
		projectile.look_at(target_pos, Vector3.UP)
	
	if "damage" in projectile:
		projectile.damage = damage
	if "is_critical" in projectile:
		projectile.is_critical = is_crit
	
	if "velocity" in projectile and "speed" in projectile:
		var forward_speed: float = max(0.0, player_velocity.dot(dir))
		var inherited_speed := forward_speed * 0.5
		projectile.velocity = dir * (projectile.speed + inherited_speed)
	
	if "attacker" in projectile:
		projectile.attacker = get_node(attacker_path)
	
	for perk in active_perks:
		if perk.has_method("on_cast"):
			perk.on_cast(self)

func equip_item(new_item: LootItem) -> void:
	if not new_item:
		return
		
	match new_item.item_type:
		"helmet":
			_swap_gear(equipped_helmet, new_item)
			equipped_helmet = new_item
		"chest":
			_swap_gear(equipped_chest, new_item)
			equipped_chest = new_item
		"amulet":
			_swap_gear(equipped_amulet, new_item)
			equipped_amulet = new_item
		_:
			push_error("Player tried to equip unknown item type: ", new_item.item_type)

func _swap_gear(old_item: LootItem, new_item: LootItem) -> void:
	if old_item:
		_apply_item_modifiers(old_item, -1.0)
		_toggle_item_perks(old_item, false)
		
	if new_item:
		_apply_item_modifiers(new_item, 1.0)
		_toggle_item_perks(new_item, true)

func _apply_item_modifiers(item: LootItem, multiplier: float) -> void:
	if not stats: return
	
	for stat_enum in item.stats:
		var amount: float = item.stats[stat_enum] * multiplier
		stats.apply_modifier(stat_enum, amount)

func _toggle_item_perks(item: LootItem, is_equipped: bool) -> void:
	for perk in item.perks: # 'perk' is now a Perk Resource
		if is_equipped:
			if not active_perks.has(perk):
				active_perks.append(perk)
				print("Perk Activated: ", perk.perk_name, " -> ", perk.perk_desc)
				
				# Fire an initialization method if the perk needs it
				if perk.has_method("on_equip"):
					perk.on_equip(self)
		else:
			if active_perks.has(perk):
				# Fire a cleanup method if the perk needs it
				if perk.has_method("on_unequip"):
					perk.on_unequip(self)
					
				active_perks.erase(perk)
				print("Perk Deactivated: ", perk.perk_name)

func has_perk(perk_name: String) -> bool:
	for p in active_perks:
		if p.perk_name == perk_name:
			return true
	return false

func process_hit_perks(context: HitContext) -> void:
	for perk in active_perks:
		if perk.has_method("modify_hit"):
			perk.modify_hit(context)

@rpc("any_peer", "call_local", "reliable")
func _client_equip_item(item_dict: Dictionary) -> void:
	# Security check
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 1 and sender_id != 0:
		push_warning("Client tried to force an equip!") # should handle this later
		return
		
	var new_item := LootItem.new()
	new_item.load_from_dict(item_dict)
	
	equip_item(new_item)
