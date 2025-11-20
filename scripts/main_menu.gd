extends Control

@onready var click: AudioStreamPlayer2D = $click
	
func _on_exit_pressed() -> void:
	click.play()
	get_tree().quit()

func _on_gobutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene_to_file("res://scenes/choose_grid_size.tscn")
