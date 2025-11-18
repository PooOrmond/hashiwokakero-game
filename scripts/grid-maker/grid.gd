extends Node2D

@export var grid_size: Vector2i = Vector2i(7, 7)
@export var cell_size: int = 48
@export var total_islands: int = 10

var grid_offset := Vector2.ZERO
var puzzle_data := []

func _ready():
	_calculate_grid_offset()
	queue_redraw()

func _calculate_grid_offset():
	var window_size = Vector2(800, 650)
	var grid_pixel_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	grid_offset = (window_size - grid_pixel_size) / 2

func _draw():
	_draw_grid()

func _draw_grid():
	for y in range(grid_size.y + 1):
		draw_line(grid_offset + Vector2(0, y * cell_size),
				  grid_offset + Vector2(grid_size.x * cell_size, y * cell_size),
				  Color(0,0,0), 1)
	for x in range(grid_size.x + 1):
		draw_line(grid_offset + Vector2(x * cell_size, 0),
				  grid_offset + Vector2(x * cell_size, grid_size.y * cell_size),
				  Color(0,0,0), 1)
