extends Control

@onready var click: AudioStreamPlayer2D = $click

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/choose_grid_size.tscn")


func _on_custommade_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/grids/7x_7.tscn")


func _on_aimade_pressed() -> void:
	click.play()
