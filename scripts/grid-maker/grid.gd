extends Node2D

@export var cell_size: int = 64
@export var grid_size: Vector2i = Vector2i(7, 7)
@export var island_texture: Texture2D
var puzzle_data = []
var hints_used = 0

func _ready():
	_generate_puzzle()
	queue_redraw()

# ----------------------------
# Draws grid lines
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
# Generate puzzle islands
# ----------------------------
func _generate_puzzle():
	puzzle_data.clear()

	# Simple fixed layout for now
	var pattern = [
		{ "pos": Vector2(1, 1), "bridges": 2 },
		{ "pos": Vector2(1, 5), "bridges": 1 },
		{ "pos": Vector2(3, 3), "bridges": 3 },
		{ "pos": Vector2(5, 1), "bridges": 2 },
		{ "pos": Vector2(5, 5), "bridges": 3 }
	]

	for island in pattern:
		var sprite := Sprite2D.new()

		if island_texture:
			sprite.texture = island_texture
			sprite.scale = Vector2(0.5, 0.5)  # shrink a bit if too large
		else:
			print("⚠️ No texture assigned to island_texture export!")

		# Convert grid coords to pixel coords (center in cell)
		var pos = island.pos * cell_size + Vector2(cell_size / 2, cell_size / 2)
		sprite.position = pos

		add_child(sprite)
		puzzle_data.append(island)

	print("✅ Puzzle generated with", puzzle_data.size(), "islands")

# ----------------------------
# Hint Button
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

	# Position aligned to grid cell
	hint_circle.position = island_data.pos * cell_size
	add_child(hint_circle)

	await get_tree().create_timer(1.0).timeout
	hint_circle.queue_free()
