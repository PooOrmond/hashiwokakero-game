extends Node2D

@onready var click: AudioStreamPlayer2D = $click
@onready var grid = $grid

var placing_island := false

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/choose_grid_size.tscn")

func _on_islandbutton_pressed() -> void:
	click.play()
	grid.set_placing_island(!grid.placing_island)
