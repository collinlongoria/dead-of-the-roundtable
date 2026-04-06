extends Control

@export var playerCamera: Camera3D

func _ready() -> void:
	if playerCamera:
		$OutlineContainer/OutlineViewport/OutlineCamera.camera = playerCamera
	else:
		push_error("Player Camera not set in HUD... expect visual errors.")
