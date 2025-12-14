# timer_selection.gd
extends Control

@onready var click: AudioStreamPlayer2D = $click
# Remove or comment out these lines if the nodes don't exist:
# @onready var timer_label: Label = $TimerLabel
# @onready var back_button: Button = $BackButton

func _ready() -> void:
	# Update the label to show which grid size was selected
	var grid_size = TimerManager.get_grid_size()
	# If you have a label node, uncomment this line and make sure the path is correct:
	# if timer_label:
	#     timer_label.text = "Select Timer for %s Grid" % grid_size
	
	# If you have a back button, position it correctly
	# if back_button:
	#     back_button.position = Vector2(50, 50)
	
	# Print for debugging
	print("Selected grid size: ", grid_size)

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene_to_file("res://scenes/choose_grid_size.tscn")

func _on_2min_pressed() -> void:
	click.play()
	TimerManager.start_timer(2 * 60)  # 2 minutes = 120 seconds
	await get_tree().create_timer(0.1).timeout
	_load_game_scene()

func _on_5min_pressed() -> void:
	click.play()
	TimerManager.start_timer(5 * 60)  # 5 minutes = 300 seconds
	await get_tree().create_timer(0.1).timeout
	_load_game_scene()

func _on_10min_pressed() -> void:
	click.play()
	TimerManager.start_timer(10 * 60)  # 10 minutes = 600 seconds
	await get_tree().create_timer(0.1).timeout
	_load_game_scene()

func _on_no_timer_pressed() -> void:
	click.play()
	TimerManager.selected_time = 0  # No timer mode
	TimerManager.start_timer(0)  # Start with 0 time (inactive)
	await get_tree().create_timer(0.1).timeout
	_load_game_scene()

func _load_game_scene() -> void:
	var grid_size = TimerManager.get_grid_size()
	match grid_size:
		"7x7":
			SceneTransition.change_scene_to_file("res://scenes/grids/7x_7.tscn")
		"9x9":
			SceneTransition.change_scene_to_file("res://scenes/grids/9x_9.tscn")
		"13x13":
			SceneTransition.change_scene_to_file("res://scenes/grids/13x_13.tscn")
		_:
			SceneTransition.change_scene_to_file("res://scenes/grids/7x_7.tscn")
