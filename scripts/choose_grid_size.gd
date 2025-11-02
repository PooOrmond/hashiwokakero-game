extends Control

@onready var click: AudioStreamPlayer2D = $click

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
