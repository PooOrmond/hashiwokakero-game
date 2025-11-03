extends Node2D

@export var cell_size: int = 64
@export var grid_size: Vector2i = Vector2i(7, 7)
var island_textures: Array[Texture2D] = []
var islands: Array[Sprite2D] = []
var placing_island: bool = false  # NEW flag

func _on_islandbutton_pressed():
	placing_island = !placing_island
	print("Island placement mode:", placing_island)

func _ready():
	randomize()
	for i in range(8):
		var path = "res://assets/islands/7x7/%d.png" % i
		var tex = load(path)
		if tex:
			island_textures.append(tex)
	queue_redraw()

func set_placing_island(value: bool):
	placing_island = value
	print("Placing island mode:", placing_island)

func _draw():
	var w = grid_size.x
	var h = grid_size.y
	var s = cell_size
	var line_color = Color(0, 0, 0)
	
	# Draw horizontal lines
	for y in range(h + 1):
		draw_line(Vector2(0, y * s), Vector2(w * s, y * s), line_color, 1)
	
	# Draw vertical lines
	for x in range(w + 1):
		draw_line(Vector2(x * s, 0), Vector2(x * s, h * s), line_color, 1)


func _input(event):
	# 🧠 Ignore clicks unless "placing island" mode is ON
	if not placing_island:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = to_local(event.position)
		var s = cell_size
		if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > grid_size.x * s or local_pos.y > grid_size.y * s:
			return
		var gx = round(local_pos.x / s) * s
		var gy = round(local_pos.y / s) * s
		var grid_pos = Vector2(gx, gy)
		var tolerance = max(6, s * 0.12)
		if local_pos.distance_to(grid_pos) > tolerance:
			return
		for island in islands:
			if island.position.distance_to(grid_pos) < 1:
				return
		if island_textures.is_empty():
			print("⚠️ No island textures loaded!")
			return
		var sprite := Sprite2D.new()
		sprite.texture = island_textures[randi() % island_textures.size()]
		sprite.centered = true
		sprite.z_index = 10
		sprite.position = grid_pos
		add_child(sprite)
		islands.append(sprite)
		print("✅ Placed island at", grid_pos)
