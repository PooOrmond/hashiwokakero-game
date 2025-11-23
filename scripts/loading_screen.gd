extends Control

@onready var bg: AnimatedSprite2D = $bg
@onready var percent_label: Label = $Label

var progress: float = 0.0
var loading_visible: bool = false
var current_resource_path: String = ""

func _ready():
	# Hide by default
	visible = false
	bg.stop()

func show_loading(resource_path: String = ""):
	"""Show the loading screen"""
	progress = 0.0
	loading_visible = true
	current_resource_path = resource_path
	visible = true
	bg.play()
	_update_percent_label()

func hide_loading():
	"""Hide the loading screen"""
	loading_visible = false
	visible = false
	bg.stop()
	current_resource_path = ""

func update_loading_progress():
	"""Update progress using threaded loading status"""
	if current_resource_path.is_empty():
		return
	
	var load_status = ResourceLoader.load_threaded_get_status(current_resource_path)
	
	match load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Get actual progress
			var _result = ResourceLoader.load_threaded_get(current_resource_path)
			# For progress, we simulate based on time since we can't get progress array directly
			progress = min(progress + 0.1, 0.9)  # Simulate progress
			_update_percent_label()
		
		ResourceLoader.THREAD_LOAD_LOADED:
			progress = 1.0
			_update_percent_label()
		
		ResourceLoader.THREAD_LOAD_FAILED:
			progress = 1.0
			_update_percent_label()
			print("❌ Resource loading failed: ", current_resource_path)

func set_progress_manual(value: float):
	"""Set loading progress manually (0.0 to 1.0)"""
	progress = clamp(value, 0.0, 1.0)
	_update_percent_label()

func _update_percent_label():
	"""Update the percentage label"""
	var percent = int(progress * 100)
	percent_label.text = "%d%%" % percent

func is_loading() -> bool:
	"""Check if loading screen is visible"""
	return loading_visible

func is_resource_loaded() -> bool:
	"""Check if the current resource is fully loaded"""
	if current_resource_path.is_empty():
		return false
	
	var status = ResourceLoader.load_threaded_get_status(current_resource_path)
	return status == ResourceLoader.THREAD_LOAD_LOADED
