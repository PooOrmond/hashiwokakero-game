extends Control

@onready var bg: AnimatedSprite2D = $bg
@onready var percent_label: Label = $Label

var progress: float = 0.0
var loading_visible: bool = false  # Changed from is_visible to avoid shadowing

func _ready():
	# Hide by default
	visible = false
	bg.stop()

func show_loading():
	"""Show the loading screen"""
	progress = 0.0
	loading_visible = true
	visible = true
	bg.play()
	_update_percent_label()
	print("Loading screen shown - computation starting")

func hide_loading():
	"""Hide the loading screen"""
	loading_visible = false
	visible = false
	bg.stop()
	print("Loading screen hidden - computation complete")

func set_progress(value: float):
	"""Set loading progress (0.0 to 1.0)"""
	progress = clamp(value, 0.0, 1.0)
	_update_percent_label()

func _update_percent_label():
	"""Update the percentage label"""
	var percent = int(progress * 100)
	percent_label.text = "%d%%" % percent

func is_loading() -> bool:
	"""Check if loading screen is visible"""
	return loading_visible

func update_progress_from_solver(solver):
	"""Update progress based on solver computation progress"""
	if solver.is_computing():
		var progress_value = solver.get_computation_progress()
		set_progress(progress_value)
		# Force redraw to update the percentage
		queue_redraw()
