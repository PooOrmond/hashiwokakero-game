extends Node2D

@export var grid_size: Vector2i = Vector2i(7, 7)
@export var cell_size: int = 48
@export var total_islands: int = 10

var grid_offset := Vector2.ZERO
var puzzle_data := []

func _ready():
	_calculate_grid_offset()
	generate_puzzle(total_islands)
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

# ---------------- Create islands ------------------

func generate_puzzle(total_islands: int):
	# Clear previous islands
	for isl in puzzle_data:
		if "node" in isl and isl.node:
			isl.node.queue_free()
	puzzle_data.clear()
	
	var occupied_positions := []

	while puzzle_data.size() < total_islands:
		# Pick random position inside grid (avoid borders)
		var pos = Vector2(randi() % (grid_size.x - 2) + 1,
						  randi() % (grid_size.y - 2) + 1)
		if pos in occupied_positions:
			continue
		occupied_positions.append(pos)

		# Create Sprite2D for this island
		var sprite = Sprite2D.new()
		sprite.position = grid_offset + pos * cell_size
		sprite.centered = true
		sprite.scale = Vector2(0.6, 0.6)

		# ✅ Give it a visible appearance (simple colored square)
		var img = Image.new()
		img.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.6, 0.8))  # light blue
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		sprite.texture = tex

		add_child(sprite)

		# Store island data
		var island = {
			"pos": pos,
			"node": sprite,
			"bridges_target": randi_range(1, 4),
			"connected_bridges": 0
		}
		puzzle_data.append(island)

	print("✅ Puzzle generated with ", puzzle_data.size(), " islands")
	queue_redraw()
