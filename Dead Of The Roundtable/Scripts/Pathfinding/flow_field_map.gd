extends Resource
class_name FlowFieldMap

@export var width: int = 100
@export var depth: int = 100
@export var cell_size: float = 2.0
@export var max_step_height: float = 1.0

# world-space origin of cell (0,0), corresponds to grid corner
@export var origin: Vector3 = Vector3.ZERO

var height_map: PackedFloat32Array
var cost_field: PackedByteArray
var integration_field: PackedInt32Array
var flow_field: PackedVector2Array

func initialize() -> void:
	var total_cells := width * depth
	
	height_map.resize(total_cells)
	height_map.fill(0.0)
	
	cost_field.resize(total_cells)
	cost_field.fill(1)
	
	integration_field.resize(total_cells)
	integration_field.fill(65535)
	
	flow_field.resize(total_cells)
	flow_field.fill(Vector2.ZERO)

func get_index(x: int, z: int) -> int:
	return z * width + x

func in_bounds(x: int, z: int) -> bool:
	return x >= 0 and x < width and z >= 0 and z < depth

func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := world_pos - origin
	var cx := int(floor(local.x / cell_size))
	var cz := int(floor(local.z / cell_size))
	return Vector2i(cx, cz)

func get_world_pos(index: int) -> Vector3:
	var x := index % width
	var z := index / width
	var wx := origin.x + (x + 0.5) * cell_size
	var wz := origin.z + (z + 0.5) * cell_size
	var wy := 0.0
	if index >= 0 and index < height_map.size():
		wy = height_map[index]
	return Vector3(wx, wy, wz)
