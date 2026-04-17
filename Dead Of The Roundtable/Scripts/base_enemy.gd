extends CharacterBody3D
class_name BaseEnemy

signal died(enemy_node)

@export var speed: float = 3.0
@export var max_health: float = 100.0
@export var target_group: String = "targets"
@export var damage: float = 10.0

@export_group("Flow Field")
@export var separation_radius: float = 1.5
@export var separation_strength: float = 2.0
@export var flow_weight: float = 1.0
@export var face_movement: bool = true
@export var turn_speed: float = 8.0

@export_group("Debug")
@export var debug_draw: bool = false
@export var debug_logs: bool = false

var current_health: float
var is_active: bool = false
var target: Node3D

var _debug_mesh_instance: MeshInstance3D
var _debug_mesh: ImmediateMesh
var _debug_material: StandardMaterial3D
var _debug_logged_once: bool = false

func _ready() -> void:
	deactivate()
	if debug_draw:
		_setup_debug_mesh()

func _setup_debug_mesh() -> void:
	_debug_mesh = ImmediateMesh.new()
	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_material.vertex_color_use_as_albedo = true
	_debug_material.no_depth_test = true
	_debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.mesh = _debug_mesh
	_debug_mesh_instance.material_override = _debug_material
	_debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_mesh_instance.top_level = true
	add_child(_debug_mesh_instance)

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
	
	FlowFieldManager.ensure_fresh_hash_for_this_frame()
	FlowFieldManager.register_agent(self)
	
	var flow_dir_2d: Vector2 = FlowFieldManager.get_flow_at_world(global_position)
	var desired := Vector3(flow_dir_2d.x * flow_weight, 0.0, flow_dir_2d.y * flow_weight)
	
	var nearby: Array = FlowFieldManager.query_nearby_agents(global_position, separation_radius)
	var push := Vector3.ZERO
	var count := 0
	for other in nearby:
		if other == self:
			continue
		var diff: Vector3 = global_position - (other as Node3D).global_position
		diff.y = 0.0
		var dist_sq: float = diff.x * diff.x + diff.z * diff.z
		if dist_sq > 0.0001 and dist_sq < separation_radius * separation_radius:
			push += diff.normalized() / sqrt(dist_sq)
			count += 1
	if count > 0:
		desired += push * separation_strength
	
	if desired.length() > 1.0:
		desired = desired.normalized()
	
	velocity.x = desired.x * speed
	velocity.z = desired.z * speed
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif velocity.y <= 0.0:
		velocity.y = -0.1
	
	if face_movement:
		var horiz := Vector3(velocity.x, 0.0, velocity.z)
		if horiz.length_squared() > 0.01:
			var target_basis := Basis.looking_at(horiz.normalized(), Vector3.UP)
			transform.basis = transform.basis.slerp(target_basis, clampf(turn_speed * delta, 0.0, 1.0))
	
	move_and_slide()
	
	if debug_logs and not _debug_logged_once:
		_debug_logged_once = true
		print("[Enemy ", name, "] pos: ", global_position,
			" | flow read: ", flow_dir_2d,
			" | on_floor: ", is_on_floor(),
			" | velocity: ", velocity,
			" | is_server: ", multiplayer.is_server())
	
	if debug_draw and _debug_mesh_instance != null:
		_draw_debug(flow_dir_2d)

func _draw_debug(flow: Vector2) -> void:
	_debug_mesh.clear_surfaces()
	var origin := global_position + Vector3(0, 1.2, 0)
	
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	_debug_mesh.surface_set_color(Color(1, 1, 0, 1))
	_debug_mesh.surface_add_vertex(origin + Vector3(-0.1, 0, 0))
	_debug_mesh.surface_set_color(Color(1, 1, 0, 1))
	_debug_mesh.surface_add_vertex(origin + Vector3(0.1, 0, 0))
	_debug_mesh.surface_set_color(Color(1, 1, 0, 1))
	_debug_mesh.surface_add_vertex(origin + Vector3(0, 0, -0.1))
	_debug_mesh.surface_set_color(Color(1, 1, 0, 1))
	_debug_mesh.surface_add_vertex(origin + Vector3(0, 0, 0.1))
	
	if flow.length_squared() > 0.001:
		var tip := origin + Vector3(flow.x, 0, flow.y) * 1.5
		_debug_mesh.surface_set_color(Color(0, 1, 1, 1))
		_debug_mesh.surface_add_vertex(origin)
		_debug_mesh.surface_set_color(Color(0, 1, 1, 1))
		_debug_mesh.surface_add_vertex(tip)
	else:
		_debug_mesh.surface_set_color(Color(1, 0, 0, 1))
		_debug_mesh.surface_add_vertex(origin + Vector3(-0.3, 0.3, 0))
		_debug_mesh.surface_set_color(Color(1, 0, 0, 1))
		_debug_mesh.surface_add_vertex(origin + Vector3(0.3, -0.3, 0))
		_debug_mesh.surface_set_color(Color(1, 0, 0, 1))
		_debug_mesh.surface_add_vertex(origin + Vector3(0.3, 0.3, 0))
		_debug_mesh.surface_set_color(Color(1, 0, 0, 1))
		_debug_mesh.surface_add_vertex(origin + Vector3(-0.3, -0.3, 0))
	
	_debug_mesh.surface_end()

func _on_target_timer_timeout() -> void:
	if not multiplayer.is_server() or not is_active:
		return
	
	var potential_targets := get_tree().get_nodes_in_group(target_group)
	if potential_targets.is_empty():
		target = null
		return
	
	var best: Node3D = null
	var best_dist_sq := INF
	for t in potential_targets:
		if not (t is Node3D):
			continue
		var d: float = global_position.distance_squared_to((t as Node3D).global_position)
		if d < best_dist_sq:
			best_dist_sq = d
			best = t
	target = best
