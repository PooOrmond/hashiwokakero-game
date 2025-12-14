extends Control

@onready var click: AudioStreamPlayer2D = $click

func _ready() -> void:
	# Pause the timer when menu opens (only if timer is active)
	if TimerManager.get_selected_time() > 0 and TimerManager.is_timer_active:
		TimerManager.pause_timer()

func _on_quitbutton_pressed() -> void:
	click.play()
	TimerManager.stop_timer()  # Stop timer when quitting
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/choose_grid_size.tscn")
	queue_free()

func _on_cancelbutton_pressed() -> void:
	click.play()
	# Resume timer when closing menu (only if timer was active)
	if TimerManager.get_selected_time() > 0:
		TimerManager.resume_timer()
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _on_new_gamebutton_pressed() -> void:
	click.play()
	# Reset timer state
	if TimerManager.get_selected_time() > 0:
		TimerManager.stop_timer()
		TimerManager.start_timer(TimerManager.get_selected_time())
	await get_tree().create_timer(0.1).timeout
	# Signal to the main scene to load a new puzzle
	get_tree().call_group("puzzle_scene", "load_new_puzzle")
	queue_free()

func _on_restartbutton_pressed() -> void:
	click.play()
	# Reset timer state
	if TimerManager.get_selected_time() > 0:
		TimerManager.stop_timer()
		TimerManager.start_timer(TimerManager.get_selected_time())
	await get_tree().create_timer(0.1).timeout
	# Signal to the main scene to restart the current puzzle
	get_tree().call_group("puzzle_scene", "restart_current_puzzle")
	queue_free()
