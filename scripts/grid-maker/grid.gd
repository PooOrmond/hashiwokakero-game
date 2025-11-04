extends Node2D

@export var cell_size: int = 64
@export var grid_size: Vector2i = Vector2i(7, 7)

var island_textures: Array[Texture2D] = []
var puzzle_data = []
var hints_used = 0

func _ready():
	_load_island_textures()
	_generate_puzzle()
	queue_redraw()

# ----------------------------
# Load island textures (1.png–8.png)
# ----------------------------
func _load_island_textures():
	island_textures.clear()
	for i in range(1, 9):  # loads 1.png through 8.png
		var path = "res://assets/islands/7x7/%d.png" % i
		if ResourceLoader.exists(path):
			island_textures.append(load(path))
		else:
			print("⚠️ Missing texture:", path)
	print("✅ Loaded", island_textures.size(), "island textures")

# ----------------------------
# Draw grid lines
# ----------------------------
func _draw():
	var w = grid_size.x
	var h = grid_size.y
	var s = cell_size
	var line_color = Color(0, 0, 0)
	for y in range(h + 1):
		draw_line(Vector2(0, y * s), Vector2(w * s, y * s), line_color, 1)
	for x in range(w + 1):
		draw_line(Vector2(x * s, 0), Vector2(x * s, h * s), line_color, 1)

# ----------------------------
# Generate puzzle islands (on intersections)
# ----------------------------
func _generate_puzzle():
	puzzle_data.clear()

	# Example: fixed small pattern
	var pattern = [
		{ "pos": Vector2(1, 1), "bridges": 2 },
		{ "pos": Vector2(3, 1), "bridges": 3 },
		{ "pos": Vector2(5, 2), "bridges": 1 },
		{ "pos": Vector2(2, 4), "bridges": 4 },
		{ "pos": Vector2(4, 5), "bridges": 2 },
		{ "pos": Vector2(6, 6), "bridges": 3 }
	]

	for island in pattern:
		var sprite := Sprite2D.new()

		var bridge_num = clamp(island.bridges, 1, island_textures.size())
		var texture = island_textures[bridge_num - 1]
		sprite.texture = texture

		# Position on intersection:
		# Intersections occur at multiples of cell_size
		sprite.position = island.pos * cell_size

		# Optional: scale down slightly
		sprite.scale = Vector2(0.8, 0.8)
		sprite.centered = true

		add_child(sprite)
		puzzle_data.append(island)

	print("✅ Puzzle generated with", puzzle_data.size(), "islands")

# ----------------------------
# Hint button
# ----------------------------
func _on_hintbutton_pressed():
	if hints_used >= puzzle_data.size():
		print("No more hints!")
		return

	var island = puzzle_data[hints_used]
	_highlight_island(island)
	hints_used += 1

func _highlight_island(island_data):
	var hint_circle := ColorRect.new()
	hint_circle.color = Color(1, 1, 0, 0.3)
	hint_circle.size = Vector2(cell_size, cell_size)
	hint_circle.position = island_data.pos * cell_size - hint_circle.size / 2
	add_child(hint_circle)
	await get_tree().create_timer(1.0).timeout
	hint_circle.queue_free()
