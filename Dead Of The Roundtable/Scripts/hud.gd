extends Control

@export var playerCamera: Camera3D

func _ready() -> void:
	pass

func set_player_camera(cam: Camera3D) -> void:
	if cam:
		playerCamera = cam
