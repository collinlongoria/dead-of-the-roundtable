extends Node3D
class_name FlowFieldDebug

@export var enabled: bool = true
@export var toggle_action: String = "debug_flowfield"
@export var show_grid: bool = true
@export var show_arrows: bool = true
@export var show_costs: bool = true
@export var show_integration: bool = false
@export var show_bounds_box: bool = true
@export var show_active_chunk: bool = true
@export var show_target_markers: bool = true
@export var only_draw_active_chunk: bool = true

@export_group("View Range")
@export var draw_around_camera: bool = true
@export var view_radius_cells: int = 40

@export_group("Appearance")
@export var floor_lift: float = 0.05
@export var arrow_length_ratio: float = 0.6
@export var update_interval: float = 0.15

var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _material: StandardMaterial3D
var _timer: Timer

func _ready() -> void:
	_immediate_mesh = ImmediateMesh.new()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.disable_receive_shadows = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.top_level = true
	add_child(_mesh_instance)
	
	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.autostart = true
	_timer.timeout.connect(_redraw)
	add_child(_timer)

func _unhandled_input(event: InputEvent) -> void:
	if toggle_action != "" and InputMap.has_action(toggle_action):
		if event.is_action_pressed(toggle_action):
			enabled = not enabled
			if not enabled:
				_immediate_mesh.clear_surfaces()

func _redraw() -> void:
	if not enabled:
		return
	
	var mgr := _get_manager()
	if mgr == null or mgr.map_data == null:
		return
	
	var map: FlowFieldMap = mgr.map_data
	if map.flow_field.size() == 0:
		return
	
	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var x0 := 0
	var x1: int = map.width - 1
	var z0 := 0
	var z1: int = map.depth - 1
	
	if only_draw_active_chunk and mgr._has_chunk:
		x0 = mgr._chunk_min.x
		x1 = mgr._chunk_max.x
		z0 = mgr._chunk_min.y
		z1 = mgr._chunk_max.y
	
	if draw_around_camera:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var cam_cell: Vector2i = map.world_to_cell(cam.global_position)
			x0 = maxi(x0, cam_cell.x - view_radius_cells)
			x1 = mini(x1, cam_cell.x + view_radius_cells)
			z0 = maxi(z0, cam_cell.y - view_radius_cells)
			z1 = mini(z1, cam_cell.y + view_radius_cells)
	
	if show_bounds_box:
		_draw_grid_bounds(map, mgr)
	
	if show_active_chunk and mgr._has_chunk:
		_draw_chunk_outline(map, mgr)
	
	if show_target_markers:
		_draw_target_markers(mgr, map)
	
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or x >= map.width or z < 0 or z >= map.depth:
				continue
			var idx: int = map.get_index(x, z)
			
			var world_x := map.origin.x + (x + 0.5) * map.cell_size
			var world_z := map.origin.z + (z + 0.5) * map.cell_size
			var baked_y: float = map.height_map[idx]
			var cost: int = map.cost_field[idx]
			var integ: int = map.integration_field[idx]
			
			var draw_y := baked_y + floor_lift
			if baked_y <= -99998.0:
				# abyss cell - try to use a nearby non-abyss neighbor's Y for visibility
				draw_y = _nearest_valid_y(map, x, z, 3) + floor_lift
			
			var center := Vector3(world_x, draw_y, world_z)
			
			var cell_color := Color(0.2, 0.8, 0.2, 0.6)
			if cost == 255:
				cell_color = Color(1.0, 0.15, 0.15, 0.9)
			elif integ == 65535:
				cell_color = Color(0.5, 0.5, 0.5, 0.4)
			elif show_integration:
				var t: float = clampf(float(integ) / 60.0, 0.0, 1.0)
				cell_color = Color(t, 1.0 - t, 0.2, 0.7)
			
			if show_grid:
				_draw_cell_outline(center, map.cell_size, cell_color)
			
			if show_costs and cost == 255:
				_draw_cell_x(center, map.cell_size, Color(1.0, 0.3, 0.3, 1.0))
			
			if show_arrows and cost != 255:
				var flow: Vector2 = map.flow_field[idx]
				if flow.length_squared() > 0.001:
					_draw_arrow(center, flow, map.cell_size * arrow_length_ratio, Color(0.2, 0.9, 1.0, 1.0))
	
	_immediate_mesh.surface_end()

func _nearest_valid_y(map: FlowFieldMap, x: int, z: int, radius: int) -> float:
	for r in range(1, radius + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var nx := x + dx
				var nz := z + dz
				if nx < 0 or nx >= map.width or nz < 0 or nz >= map.depth:
					continue
				var n_idx := map.get_index(nx, nz)
				var ny: float = map.height_map[n_idx]
				if ny > -99998.0:
					return ny
	return 0.0

func _draw_grid_bounds(map: FlowFieldMap, mgr: Node) -> void:
	var y := _nearest_valid_y(map, map.width / 2, map.depth / 2, 50) + floor_lift + 0.01
	var x0: float = map.origin.x
	var z0: float = map.origin.z
	var x1: float = map.origin.x + map.width * map.cell_size
	var z1: float = map.origin.z + map.depth * map.cell_size
	
	var c := Color(1.0, 1.0, 0.0, 1.0)
	var corners := [
		Vector3(x0, y, z0),
		Vector3(x1, y, z0),
		Vector3(x1, y, z1),
		Vector3(x0, y, z1),
	]
	for i in range(4):
		_immediate_mesh.surface_set_color(c)
		_immediate_mesh.surface_add_vertex(corners[i])
		_immediate_mesh.surface_set_color(c)
		_immediate_mesh.surface_add_vertex(corners[(i + 1) % 4])

func _draw_chunk_outline(map: FlowFieldMap, mgr: Node) -> void:
	var y := _nearest_valid_y(map, (mgr._chunk_min.x + mgr._chunk_max.x) / 2, (mgr._chunk_min.y + mgr._chunk_max.y) / 2, 20) + floor_lift + 0.02
	var x0: float = map.origin.x + mgr._chunk_min.x * map.cell_size
	var z0: float = map.origin.z + mgr._chunk_min.y * map.cell_size
	var x1: float = map.origin.x + (mgr._chunk_max.x + 1) * map.cell_size
	var z1: float = map.origin.z + (mgr._chunk_max.y + 1) * map.cell_size
	
	var c := Color(1.0, 0.5, 0.0, 1.0)
	var corners := [
		Vector3(x0, y, z0),
		Vector3(x1, y, z0),
		Vector3(x1, y, z1),
		Vector3(x0, y, z1),
	]
	for i in range(4):
		_immediate_mesh.surface_set_color(c)
		_immediate_mesh.surface_add_vertex(corners[i])
		_immediate_mesh.surface_set_color(c)
		_immediate_mesh.surface_add_vertex(corners[(i + 1) % 4])

func _draw_target_markers(mgr: Node, map: FlowFieldMap) -> void:
	var targets := get_tree().get_nodes_in_group(mgr.target_group)
	for t in targets:
		if not (t is Node3D):
			continue
		var pos: Vector3 = (t as Node3D).global_position
		var c := Color(1.0, 0.5, 1.0, 1.0)
		var h := 1.2
		_immediate_mesh.surface_set_color(c)
		_immediate_mesh.surface_add_vertex(pos)
		_immediate_mesh.surface_set_color(c)
		_immediate_mesh.surface_add_vertex(pos + Vector3(0, h, 0))
		
		var r := 0.4
		var segments := 8
		for i in range(segments):
			var a0: float = TAU * i / segments
			var a1: float = TAU * (i + 1) / segments
			_immediate_mesh.surface_set_color(c)
			_immediate_mesh.surface_add_vertex(pos + Vector3(cos(a0) * r, h, sin(a0) * r))
			_immediate_mesh.surface_set_color(c)
			_immediate_mesh.surface_add_vertex(pos + Vector3(cos(a1) * r, h, sin(a1) * r))

func _draw_cell_outline(center: Vector3, size: float, color: Color) -> void:
	var h := size * 0.5
	var corners := [
		center + Vector3(-h, 0, -h),
		center + Vector3( h, 0, -h),
		center + Vector3( h, 0,  h),
		center + Vector3(-h, 0,  h),
	]
	for i in range(4):
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(corners[i])
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(corners[(i + 1) % 4])

func _draw_cell_x(center: Vector3, size: float, color: Color) -> void:
	var h := size * 0.4
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(center + Vector3(-h, 0, -h))
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(center + Vector3( h, 0,  h))
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(center + Vector3(-h, 0,  h))
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(center + Vector3( h, 0, -h))

func _draw_arrow(center: Vector3, dir2d: Vector2, length: float, color: Color) -> void:
	var dir3d := Vector3(dir2d.x, 0, dir2d.y).normalized()
	var tail: Vector3 = center - dir3d * (length * 0.5)
	var head: Vector3 = center + dir3d * (length * 0.5)
	
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(tail)
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(head)
	
	var side := Vector3(-dir3d.z, 0, dir3d.x)
	var barb := length * 0.25
	var barb_left: Vector3 = head - dir3d * barb + side * barb * 0.6
	var barb_right: Vector3 = head - dir3d * barb - side * barb * 0.6
	
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(head)
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(barb_left)
	
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(head)
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(barb_right)

func _get_manager() -> Node:
	if get_tree().root.has_node("FlowFieldManager"):
		return get_tree().root.get_node("FlowFieldManager")
	return null
