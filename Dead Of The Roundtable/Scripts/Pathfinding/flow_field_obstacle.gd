extends Node
class_name FlowFieldObstacle

@export var auto_register_on_ready: bool = true
@export var dynamic: bool = false
@export var update_interval: float = 0.5
@export var padding: float = 0.0
@export var register_delay_frames: int = 2

var _registered_aabb: AABB
var _is_registered: bool = false
var _timer: Timer

func _ready() -> void:
	if not multiplayer.is_server():
		return
	
	if auto_register_on_ready:
		_deferred_register()
	
	if dynamic:
		_timer = Timer.new()
		_timer.wait_time = update_interval
		_timer.autostart = true
		_timer.timeout.connect(_refresh_registration)
		add_child(_timer)

func _deferred_register() -> void:
	for i in range(register_delay_frames):
		await get_tree().physics_frame
	register_now()

func register_now() -> void:
	if _is_registered:
		return
	var aabb := _compute_world_aabb()
	if aabb.size == Vector3.ZERO:
		push_warning("[FlowFieldObstacle] Could not compute AABB for ", get_parent().name if get_parent() else "<no parent>")
		return
	_registered_aabb = _pad_aabb(aabb, padding)
	FlowFieldManager.add_obstacle_aabb(_registered_aabb)
	_is_registered = true

func unregister() -> void:
	if not _is_registered:
		return
	FlowFieldManager.remove_obstacle_aabb(_registered_aabb)
	_is_registered = false

func _refresh_registration() -> void:
	if not _is_registered:
		register_now()
		return
	var new_aabb := _pad_aabb(_compute_world_aabb(), padding)
	if _aabb_significantly_different(_registered_aabb, new_aabb):
		FlowFieldManager.remove_obstacle_aabb(_registered_aabb)
		FlowFieldManager.add_obstacle_aabb(new_aabb)
		_registered_aabb = new_aabb

func _exit_tree() -> void:
	if _is_registered and multiplayer.is_server():
		# Use the stored AABB since the parent is being removed and its transform may be invalid
		FlowFieldManager.remove_obstacle_aabb(_registered_aabb)
		_is_registered = false

func _compute_world_aabb() -> AABB:
	var parent := get_parent()
	if parent == null or not (parent is Node3D):
		return AABB()
	
	var parent_3d := parent as Node3D
	var combined := AABB()
	var found_any := false
	
	for child in parent.get_children():
		if child is CollisionShape3D:
			var cs := child as CollisionShape3D
			if cs.shape == null or cs.disabled:
				continue
			var local_aabb := _approx_shape_aabb(cs.shape)
			var world_aabb := cs.global_transform * local_aabb
			if not found_any:
				combined = world_aabb
				found_any = true
			else:
				combined = combined.merge(world_aabb)
	
	if not found_any:
		var p := parent_3d.global_position
		combined = AABB(p - Vector3(0.5, 0.5, 0.5), Vector3(1.0, 1.0, 1.0))
	
	return combined

func _approx_shape_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var b := shape as BoxShape3D
		return AABB(-b.size * 0.5, b.size)
	if shape is SphereShape3D:
		var s := shape as SphereShape3D
		var d := s.radius * 2.0
		return AABB(Vector3(-s.radius, -s.radius, -s.radius), Vector3(d, d, d))
	if shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		var h := c.height * 0.5
		return AABB(Vector3(-c.radius, -h, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if shape is CylinderShape3D:
		var cy := shape as CylinderShape3D
		var h2 := cy.height * 0.5
		return AABB(Vector3(-cy.radius, -h2, -cy.radius), Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0))
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

func _pad_aabb(aabb: AABB, pad: float) -> AABB:
	if pad <= 0.0:
		return aabb
	return AABB(aabb.position - Vector3(pad, 0, pad), aabb.size + Vector3(pad * 2, 0, pad * 2))

func _aabb_significantly_different(a: AABB, b: AABB) -> bool:
	var threshold := 0.5
	if a.position.distance_to(b.position) > threshold:
		return true
	if a.size.distance_to(b.size) > threshold:
		return true
	return false
