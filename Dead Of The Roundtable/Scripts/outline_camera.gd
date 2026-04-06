extends Camera3D

var camera: Camera3D

func _process(delta: float) -> void:
	if camera:
		global_transform = camera.global_transform
		fov = camera.fov
