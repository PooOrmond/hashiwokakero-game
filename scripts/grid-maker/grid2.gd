extends Node2D

@export var cell_size: int = 64
@export var grid_size: Vector2i = Vector2i(11, 11)

func _draw():
	var w = grid_size.x
	var h = grid_size.y
	var s = cell_size
	var line_color = Color(0, 0, 0)
	# Draw horizontal lines
	for y in range(h):
		draw_line(Vector2(0, y * s), Vector2((w - 1) * s, y * s), line_color, 1)
	
	# Draw vertical lines
	for x in range(w):
		draw_line(Vector2(x * s, 0), Vector2(x * s, (h - 1) * s), line_color, 1)
