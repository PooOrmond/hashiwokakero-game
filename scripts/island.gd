extends Node2D

@export var texture: Array[Texture2D]
@export var index: int = 0 : set = set_index 

@onready var sprite: Sprite2D = $Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_texture()

func set_index(value):
	index = clamp(value, 0, texture.size() - 1)
	_update_texture()

func _update_texture():
	if texture.size() > 0:
		sprite.texture = texture[index]
