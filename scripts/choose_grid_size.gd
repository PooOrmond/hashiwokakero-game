extends Control

@onready var click: AudioStreamPlayer2D = $click

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene_to_file("res://scenes/main_menu.tscn")

func _on_x_7_button_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene_to_file("res://scenes/grids/7x_7.tscn")

func _on_x_9_button_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene_to_file("res://scenes/grids/9x_9.tscn")

func _on_x_13_button_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene_to_file("res://scenes/grids/13x_13.tscn")
