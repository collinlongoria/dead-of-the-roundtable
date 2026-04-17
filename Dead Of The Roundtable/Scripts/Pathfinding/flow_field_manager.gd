extends Node

signal field_updated

@export var map_data: FlowFieldMap

@export_group("Grid")
@export var width: int = 200
@export var depth: int = 200
@export var cell_size: float = 2.0
@export var origin: Vector3 = Vector3.ZERO
@export var max_step_height: float = 1.0

@export_group("Baking")
@export var bake_on_ready: bool = true
@export var bake_delay_frames: int = 2
@export var bake_height: float = 200.0
@export var bake_depth: float = 400.0
@export var bake_collision_mask: int = 1

@export_group("Runtime")
@export var target_group: String = "targets"
@export var update_interval: float = 0.15
@export var chunk_padding: int = 30

@export_group("Separation")
@export var separation_cell_size: float = 2.0

@export_group("Debug")
@export var debug_logs: bool = false

const UINT16_MAX := 65535
const ABYSS_SENTINEL := -99999.0

const NEIGHBORS_8 := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
]

const NEIGHBORS_4 := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var _update_timer: Timer
var _chunk_min: Vector2i = Vector2i.ZERO
var _chunk_max: Vector2i = Vector2i.ZERO
var _has_chunk: bool = false
var _bfs_queue: PackedInt32Array = PackedInt32Array()
var _spatial_hash: Dictionary = {}
var _last_hash_frame: int = -1

func _ready() -> void:
	if map_data == null:
		map_data = FlowFieldMap.new()
	
	map_data.width = width
	map_data.depth = depth
	map_data.cell_size = cell_size
	map_data.origin = origin
	map_data.max_step_height = max_step_height
	map_data.initialize()
	
	_update_timer = Timer.new()
	_update_timer.wait_time = update_interval
	_update_timer.one_shot = false
	_update_timer.autostart = false
	_update_timer.timeout.connect(_on_update_tick)
	add_child(_update_timer)
	
	if bake_on_ready:
		_deferred_bake()

func _deferred_bake() -> void:
	# Wait N frames so the level scene and its colliders are fully instantiated.
	# Autoloads ready before user scenes, and physics bodies need at least one
	# physics tick to register with the space state.
	for i in range(bake_delay_frames):
		await get_tree().physics_frame
	bake_heights()

func start_updates() -> void:
	_update_timer.start()

func stop_updates() -> void:
	_update_timer.stop()

func bake_heights() -> void:
	if map_data == null:
		return
	
	var space_state := get_tree().root.world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = bake_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var hit_count := 0
	var miss_count := 0
	var first_hit_y := 0.0
	var got_first_hit := false
	
	for z in range(map_data.depth):
		for x in range(map_data.width):
			var idx := map_data.get_index(x, z)
			var world_x := map_data.origin.x + (x + 0.5) * map_data.cell_size
			var world_z := map_data.origin.z + (z + 0.5) * map_data.cell_size
			
			query.from = Vector3(world_x, bake_height, world_z)
			query.to = Vector3(world_x, bake_height - bake_depth, world_z)
			
			var result := space_state.intersect_ray(query)
			if result.is_empty():
				map_data.cost_field[idx] = 255
				map_data.height_map[idx] = ABYSS_SENTINEL
				miss_count += 1
			else:
				map_data.height_map[idx] = result.position.y
				map_data.cost_field[idx] = 1
				hit_count += 1
				if not got_first_hit:
					first_hit_y = result.position.y
					got_first_hit = true
	
	if debug_logs:
		print("[FlowField] Bake complete. Grid: ", map_data.width, "x", map_data.depth,
			" origin: ", map_data.origin,
			" cell_size: ", map_data.cell_size,
			" | traversable cells: ", hit_count,
			" | abyss cells: ", miss_count)
		if got_first_hit:
			print("[FlowField] First hit Y: ", first_hit_y)
		if hit_count == 0:
			push_warning("[FlowField] Every bake ray missed. Running a diagnostic raycast now...")
			_diagnostic_sample_raycast(space_state)
	
	start_updates()

func _diagnostic_sample_raycast(space_state: PhysicsDirectSpaceState3D) -> void:
	print("[FlowField] ----- Diagnostic start -----")
	print("[FlowField] bake_collision_mask = ", bake_collision_mask)
	print("[FlowField] Grid origin: ", map_data.origin,
		"  size: ", map_data.width * map_data.cell_size, " x ", map_data.depth * map_data.cell_size,
		"  spans X[", map_data.origin.x, " .. ", map_data.origin.x + map_data.width * map_data.cell_size,
		"] Z[", map_data.origin.z, " .. ", map_data.origin.z + map_data.depth * map_data.cell_size, "]")
	
	# sample 1: grid center with all masks + areas
	var world_x: float = map_data.origin.x + (map_data.width * map_data.cell_size) * 0.5
	var world_z: float = map_data.origin.z + (map_data.depth * map_data.cell_size) * 0.5
	_do_diagnostic_ray(space_state, "grid center", world_x, world_z)
	
	# sample 2: at each target's position
	var targets := get_tree().get_nodes_in_group(target_group)
	for t in targets:
		if not (t is Node3D):
			continue
		var pos: Vector3 = (t as Node3D).global_position
		_do_diagnostic_ray(space_state, "target '" + t.name + "'", pos.x, pos.z)
	
	print("[FlowField] ----- Diagnostic end -----")

func _do_diagnostic_ray(space_state: PhysicsDirectSpaceState3D, label: String, world_x: float, world_z: float) -> void:
	var q := PhysicsRayQueryParameters3D.new()
	q.from = Vector3(world_x, bake_height, world_z)
	q.to = Vector3(world_x, bake_height - bake_depth, world_z)
	q.collision_mask = 0xFFFFFFFF
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var r := space_state.intersect_ray(q)
	if r.is_empty():
		print("[FlowField]   [", label, " @ (", world_x, ",", world_z, ")] NO HIT with all masks + areas")
	else:
		var c = r.get("collider")
		var layer: int = 0
		var name_str: String = "<null>"
		var is_area: bool = false
		if c is CollisionObject3D:
			layer = (c as CollisionObject3D).collision_layer
			name_str = str(c.name)
			is_area = c is Area3D
		print("[FlowField]   [", label, " @ (", world_x, ",", world_z, ")] hit '", name_str,
			"' Y=", r.position.y, " layer=", layer, " area=", is_area,
			" -> set bake_collision_mask to include ", layer)

var _debug_first_tick_logged: bool = false
var _debug_no_targets_warned: bool = false

func _on_update_tick() -> void:
	var targets := get_tree().get_nodes_in_group(target_group)
	if targets.is_empty():
		_has_chunk = false
		if debug_logs and not _debug_no_targets_warned:
			push_warning("[FlowField] No nodes found in group '" + target_group + "'. Add your player(s) to this group (or change target_group).")
			_debug_no_targets_warned = true
		return
	
	if not _compute_active_chunk(targets):
		_has_chunk = false
		if debug_logs:
			print("[FlowField] Targets exist but none are inside the grid bounds. Check origin/width/depth vs player position.")
		return
	
	_reset_integration_in_chunk()
	_integration_pass(targets)
	_vector_pass()
	
	if debug_logs and not _debug_first_tick_logged:
		_debug_first_tick_logged = true
		var flow_cells := 0
		var w := map_data.width
		for z in range(_chunk_min.y, _chunk_max.y + 1):
			for x in range(_chunk_min.x, _chunk_max.x + 1):
				if map_data.flow_field[z * w + x].length_squared() > 0.0001:
					flow_cells += 1
		print("[FlowField] First tick. Targets: ", targets.size(),
			" | chunk: ", _chunk_min, " -> ", _chunk_max,
			" | cells with flow: ", flow_cells)
		if flow_cells == 0:
			push_warning("[FlowField] Integration ran but no cells received a flow direction. Likely causes: max_step_height too small, or all target cells are marked impassable.")
	
	field_updated.emit()

func _compute_active_chunk(targets: Array) -> bool:
	var any_valid := false
	var min_x := map_data.width
	var max_x := -1
	var min_z := map_data.depth
	var max_z := -1
	
	for t in targets:
		if not (t is Node3D):
			continue
		var cell: Vector2i = map_data.world_to_cell((t as Node3D).global_position)
		if not map_data.in_bounds(cell.x, cell.y):
			continue
		any_valid = true
		if cell.x < min_x: min_x = cell.x
		if cell.x > max_x: max_x = cell.x
		if cell.y < min_z: min_z = cell.y
		if cell.y > max_z: max_z = cell.y
	
	if not any_valid:
		return false
	
	min_x = maxi(0, min_x - chunk_padding)
	max_x = mini(map_data.width - 1, max_x + chunk_padding)
	min_z = maxi(0, min_z - chunk_padding)
	max_z = mini(map_data.depth - 1, max_z + chunk_padding)
	
	_chunk_min = Vector2i(min_x, min_z)
	_chunk_max = Vector2i(max_x, max_z)
	_has_chunk = true
	return true

func _reset_integration_in_chunk() -> void:
	for z in range(_chunk_min.y, _chunk_max.y + 1):
		var row_start := z * map_data.width
		for x in range(_chunk_min.x, _chunk_max.x + 1):
			map_data.integration_field[row_start + x] = UINT16_MAX
			map_data.flow_field[row_start + x] = Vector2.ZERO

func _integration_pass(targets: Array) -> void:
	_bfs_queue.clear()
	
	for t in targets:
		if not (t is Node3D):
			continue
		var cell: Vector2i = map_data.world_to_cell((t as Node3D).global_position)
		if not map_data.in_bounds(cell.x, cell.y):
			continue
		var idx := map_data.get_index(cell.x, cell.y)
		if map_data.cost_field[idx] == 255:
			continue
		map_data.integration_field[idx] = 0
		_bfs_queue.push_back(idx)
	
	var head := 0
	var w := map_data.width
	while head < _bfs_queue.size():
		var current_idx := _bfs_queue[head]
		head += 1
		
		var cx := current_idx % w
		var cz := current_idx / w
		
		if cx < _chunk_min.x or cx > _chunk_max.x or cz < _chunk_min.y or cz > _chunk_max.y:
			continue
		
		var current_cost: int = map_data.integration_field[current_idx]
		var current_h: float = map_data.height_map[current_idx]
		var next_cost := current_cost + 1
		
		for offset in NEIGHBORS_4:
			var nx: int = cx + offset.x
			var nz: int = cz + offset.y
			if nx < _chunk_min.x or nx > _chunk_max.x or nz < _chunk_min.y or nz > _chunk_max.y:
				continue
			var n_idx: int = nz * w + nx
			
			if map_data.cost_field[n_idx] == 255:
				continue
			
			if absf(map_data.height_map[n_idx] - current_h) > map_data.max_step_height:
				continue
			
			if next_cost < map_data.integration_field[n_idx]:
				map_data.integration_field[n_idx] = next_cost
				_bfs_queue.push_back(n_idx)

func _vector_pass() -> void:
	var w := map_data.width
	for z in range(_chunk_min.y, _chunk_max.y + 1):
		for x in range(_chunk_min.x, _chunk_max.x + 1):
			var idx := z * w + x
			
			if map_data.cost_field[idx] == 255:
				map_data.flow_field[idx] = Vector2.ZERO
				continue
			
			var my_cost: int = map_data.integration_field[idx]
			if my_cost == 0 or my_cost == UINT16_MAX:
				map_data.flow_field[idx] = Vector2.ZERO
				continue
			
			var best_cost := my_cost
			var best_dx := 0
			var best_dz := 0
			var my_h: float = map_data.height_map[idx]
			
			for offset in NEIGHBORS_8:
				var nx: int = x + offset.x
				var nz: int = z + offset.y
				if nx < 0 or nx >= w or nz < 0 or nz >= map_data.depth:
					continue
				var n_idx: int = nz * w + nx
				
				if map_data.cost_field[n_idx] == 255:
					continue
				if absf(map_data.height_map[n_idx] - my_h) > map_data.max_step_height:
					continue
				
				var n_cost: int = map_data.integration_field[n_idx]
				if n_cost < best_cost:
					best_cost = n_cost
					best_dx = offset.x
					best_dz = offset.y
			
			if best_dx == 0 and best_dz == 0:
				map_data.flow_field[idx] = Vector2.ZERO
			else:
				map_data.flow_field[idx] = Vector2(best_dx, best_dz).normalized()

func get_flow_at_world(world_pos: Vector3) -> Vector2:
	var cell := map_data.world_to_cell(world_pos)
	if not map_data.in_bounds(cell.x, cell.y):
		return Vector2.ZERO
	var idx := map_data.get_index(cell.x, cell.y)
	var flow: Vector2 = map_data.flow_field[idx]
	if flow.length_squared() > 0.0001:
		return flow
	
	# Fallback: cell is zero (obstacle, unreached, or target cell itself).
	# Find the neighbor with the lowest integration cost and point toward it.
	var best_cost := map_data.integration_field[idx]
	if best_cost == UINT16_MAX:
		best_cost = UINT16_MAX
	var best_dx := 0
	var best_dz := 0
	var w := map_data.width
	for offset in NEIGHBORS_8:
		var nx: int = cell.x + offset.x
		var nz: int = cell.y + offset.y
		if not map_data.in_bounds(nx, nz):
			continue
		var n_idx: int = nz * w + nx
		if map_data.cost_field[n_idx] == 255:
			continue
		var n_cost: int = map_data.integration_field[n_idx]
		if n_cost < best_cost:
			best_cost = n_cost
			best_dx = offset.x
			best_dz = offset.y
	if best_dx == 0 and best_dz == 0:
		return Vector2.ZERO
	return Vector2(best_dx, best_dz).normalized()

func get_floor_height_at_world(world_pos: Vector3) -> float:
	var cell := map_data.world_to_cell(world_pos)
	if not map_data.in_bounds(cell.x, cell.y):
		return world_pos.y
	return map_data.height_map[map_data.get_index(cell.x, cell.y)]

func add_obstacle_aabb(aabb: AABB, force_recalc: bool = false) -> void:
	_apply_aabb_cost(aabb, 255)
	if force_recalc:
		_force_immediate_update()

func remove_obstacle_aabb(aabb: AABB, force_recalc: bool = false) -> void:
	_apply_aabb_cost(aabb, 1)
	if force_recalc:
		_force_immediate_update()

func _apply_aabb_cost(aabb: AABB, cost: int) -> void:
	var min_cell := map_data.world_to_cell(aabb.position)
	var max_cell := map_data.world_to_cell(aabb.position + aabb.size)
	var x0: int = clampi(mini(min_cell.x, max_cell.x), 0, map_data.width - 1)
	var x1: int = clampi(maxi(min_cell.x, max_cell.x), 0, map_data.width - 1)
	var z0: int = clampi(mini(min_cell.y, max_cell.y), 0, map_data.depth - 1)
	var z1: int = clampi(maxi(min_cell.y, max_cell.y), 0, map_data.depth - 1)
	
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var idx := map_data.get_index(x, z)
			if cost == 1 and map_data.height_map[idx] <= ABYSS_SENTINEL + 1.0:
				continue
			map_data.cost_field[idx] = cost

func _force_immediate_update() -> void:
	_on_update_tick()

func _spatial_hash_cell(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / separation_cell_size)), int(floor(pos.z / separation_cell_size)))

func ensure_fresh_hash_for_this_frame() -> void:
	var f := Engine.get_physics_frames()
	if f != _last_hash_frame:
		_spatial_hash.clear()
		_last_hash_frame = f

func register_agent(agent: Node3D) -> void:
	if agent == null:
		return
	var cell := _spatial_hash_cell(agent.global_position)
	if not _spatial_hash.has(cell):
		_spatial_hash[cell] = []
	(_spatial_hash[cell] as Array).append(agent)

func query_nearby_agents(pos: Vector3, radius: float) -> Array:
	var results: Array = []
	var cell_radius := int(ceil(radius / separation_cell_size))
	var center := _spatial_hash_cell(pos)
	var r_sq := radius * radius
	for dz in range(-cell_radius, cell_radius + 1):
		for dx in range(-cell_radius, cell_radius + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			if not _spatial_hash.has(key):
				continue
			for a in _spatial_hash[key]:
				if a == null or not is_instance_valid(a):
					continue
				var d: Vector3 = (a as Node3D).global_position - pos
				if d.x * d.x + d.z * d.z <= r_sq:
					results.append(a)
	return results
