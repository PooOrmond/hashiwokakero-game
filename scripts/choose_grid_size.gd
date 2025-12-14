extends Control

@onready var click: AudioStreamPlayer2D = $click

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene_to_file("res://scenes/main_menu.tscn")

func _on_x_7_button_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	TimerManager.set_grid_size("7x7")
	SceneTransition.change_scene_to_file("res://scenes/timer_selection.tscn")

func _on_x_9_button_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	TimerManager.set_grid_size("9x9")
	SceneTransition.change_scene_to_file("res://scenes/timer_selection.tscn")

func _on_x_13_button_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	TimerManager.set_grid_size("13x13")
	SceneTransition.change_scene_to_file("res://scenes/timer_selection.tscn")
