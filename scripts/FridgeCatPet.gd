class_name FridgeCatPet
extends Area2D

signal clicked

const IDLE_TEXTURE_PATH := "res://assets/generated/paper_fridge_cat_idle.png"
const OPEN_TEXTURE_PATHS := [
	"res://assets/generated/paper_cat_open_01.png",
	"res://assets/generated/paper_cat_open_02.png",
	"res://assets/generated/paper_cat_open_03.png",
	"res://assets/generated/paper_cat_open_04.png",
]
const OPEN_FRAME_TIME := 0.08
const DISPLAY_HEIGHT := 148.0
const DRAG_CLICK_THRESHOLD := 10.0

var hover_amount := 0.0
var time := 0.0
var is_bag_open := false
var is_opening := false
var is_dragging := false
var drag_offset := Vector2.ZERO
var drag_start_mouse := Vector2.ZERO
var drag_distance := 0.0
var opening_elapsed := 0.0
var opening_frame_index := 0
var sprite: Sprite2D
var idle_texture: Texture2D
var open_textures: Array[Texture2D] = []


func _ready() -> void:
	z_index = 14
	input_pickable = true
	set_process(true)
	set_process_input(true)
	_create_sprite()
	_create_hit_area()
	mouse_entered.connect(func() -> void:
		hover_amount = 1.0
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hover_amount = 0.0
		queue_redraw()
	)
	input_event.connect(_on_input_event)
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	if is_opening:
		_update_opening_animation(delta)
	if sprite != null:
		sprite.position = Vector2(0.0, -20.0 + sin(time * 2.2) * 2.0)
	else:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		global_position = get_global_mouse_position() + drag_offset
		drag_distance += mouse_motion.relative.length()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			is_dragging = false
			input_pickable = not is_bag_open
			get_viewport().set_input_as_handled()
			if drag_start_mouse.distance_to(get_viewport().get_mouse_position()) <= DRAG_CLICK_THRESHOLD and drag_distance <= DRAG_CLICK_THRESHOLD:
				_begin_opening_animation()


func _create_hit_area() -> void:
	var shape := CollisionShape2D.new()
	var shape_rect := RectangleShape2D.new()
	shape_rect.size = Vector2(116.0, 128.0)
	shape.shape = shape_rect
	shape.position = Vector2(0.0, -18.0)
	add_child(shape)


func _create_sprite() -> void:
	idle_texture = _load_texture(IDLE_TEXTURE_PATH)
	open_textures.clear()
	for path: String in OPEN_TEXTURE_PATHS:
		var texture := _load_texture(path)
		if texture != null:
			open_textures.append(texture)
	if idle_texture == null:
		return

	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = idle_texture
	sprite.position = Vector2(0.0, -20.0)
	var texture_height := float(idle_texture.get_height())
	if texture_height > 0.0:
		var scale_factor := DISPLAY_HEIGHT / texture_height
		sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)


func _load_texture(texture_path: String) -> Texture2D:
	var file_path := texture_path
	if texture_path.begins_with("res://") or texture_path.begins_with("user://"):
		file_path = ProjectSettings.globalize_path(texture_path)

	var image := Image.new()
	var error := image.load(file_path)
	if error == OK and not image.is_empty():
		return ImageTexture.create_from_image(image)

	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D

	return null


func set_bag_open(open: bool) -> void:
	is_bag_open = open
	is_opening = false
	opening_elapsed = 0.0
	opening_frame_index = 0
	visible = true
	input_pickable = not is_bag_open
	if sprite != null:
		if is_bag_open and not open_textures.is_empty():
			sprite.texture = open_textures[open_textures.size() - 1]
		else:
			sprite.texture = idle_texture
	queue_redraw()


func _begin_opening_animation() -> void:
	if is_opening or is_bag_open:
		return
	if open_textures.is_empty():
		set_bag_open(true)
		clicked.emit()
		return
	is_opening = true
	input_pickable = false
	opening_elapsed = 0.0
	opening_frame_index = 0
	if sprite != null:
		sprite.texture = open_textures[0]


func _update_opening_animation(delta: float) -> void:
	opening_elapsed += delta
	if opening_elapsed < OPEN_FRAME_TIME:
		return

	opening_elapsed = 0.0
	opening_frame_index += 1
	if opening_frame_index < open_textures.size():
		if sprite != null:
			sprite.texture = open_textures[opening_frame_index]
		return

	set_bag_open(true)
	clicked.emit()


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			is_dragging = true
			drag_offset = global_position - get_global_mouse_position()
			drag_start_mouse = get_viewport().get_mouse_position()
			drag_distance = 0.0
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if sprite != null:
		return

	var bob := sin(time * 2.2) * 2.0
	var body_color := Color(0.56, 0.78, 0.68)
	var edge_color := Color(0.32, 0.44, 0.40)
	var dark_color := Color(0.10, 0.12, 0.13)
	var cream := Color(0.96, 0.95, 0.90)
	var blush := Color(0.94, 0.45, 0.42)
	var highlight := Color(0.84, 0.96, 0.88, 0.58)

	draw_ellipse(Vector2(0.0, 50.0), 46.0, 9.0, Color(0.0, 0.0, 0.0, 0.24))

	var tail_base := Vector2(46.0, -22.0 + bob)
	var tail_tip := Vector2(80.0 + sin(time * 2.8) * 4.0, -54.0 + bob)
	draw_line(tail_base, tail_tip, edge_color, 19.0, true)
	draw_line(tail_base, tail_tip, body_color.lightened(0.06), 13.0, true)
	draw_circle(tail_tip, 8.0, body_color.lightened(0.06))

	draw_colored_polygon(PackedVector2Array([
		Vector2(-36.0, -66.0 + bob),
		Vector2(-15.0, -99.0 + bob),
		Vector2(4.0, -66.0 + bob),
	]), edge_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4.0, -66.0 + bob),
		Vector2(25.0, -99.0 + bob),
		Vector2(46.0, -66.0 + bob),
	]), edge_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29.0, -68.0 + bob),
		Vector2(-15.0, -88.0 + bob),
		Vector2(-2.0, -68.0 + bob),
	]), body_color.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2(10.0, -68.0 + bob),
		Vector2(25.0, -88.0 + bob),
		Vector2(39.0, -68.0 + bob),
	]), body_color.lightened(0.08))

	draw_rect(Rect2(-42.0, -66.0 + bob, 84.0, 96.0), edge_color, true)
	draw_rect(Rect2(-35.0, -59.0 + bob, 70.0, 82.0), body_color, true)
	draw_rect(Rect2(-29.0, -21.0 + bob, 58.0, 4.0), edge_color.darkened(0.12), true)
	draw_rect(Rect2(22.0, -46.0 + bob, 5.0, 30.0), edge_color.darkened(0.10), true)
	draw_rect(Rect2(-26.0, -54.0 + bob, 30.0, 18.0), highlight, true)

	draw_circle(Vector2(-16.0, -31.0 + bob), 7.0, cream)
	draw_circle(Vector2(16.0, -31.0 + bob), 7.0, cream)
	draw_circle(Vector2(-14.0, -30.0 + bob), 3.0, dark_color)
	draw_circle(Vector2(18.0, -30.0 + bob), 3.0, dark_color)
	draw_circle(Vector2(0.0, -20.0 + bob), 4.0, Color(0.95, 0.48, 0.22))

	draw_line(Vector2(-3.0, -15.0 + bob), Vector2(-12.0, -11.0 + bob), dark_color, 2.0, true)
	draw_line(Vector2(3.0, -15.0 + bob), Vector2(12.0, -11.0 + bob), dark_color, 2.0, true)
	for side in [-1, 1]:
		draw_line(Vector2(7.0 * side, -18.0 + bob), Vector2(30.0 * side, -24.0 + bob), cream, 2.0, true)
		draw_line(Vector2(7.0 * side, -14.0 + bob), Vector2(29.0 * side, -13.0 + bob), cream, 2.0, true)
		draw_line(Vector2(7.0 * side, -10.0 + bob), Vector2(27.0 * side, -3.0 + bob), cream, 2.0, true)

	draw_circle(Vector2(-26.0, -18.0 + bob), 4.0, blush)
	draw_circle(Vector2(26.0, -18.0 + bob), 4.0, blush)

	draw_line(Vector2(-24.0, 28.0 + bob), Vector2(-24.0, 47.0), Color(0.83, 0.52, 0.44), 10.0, true)
	draw_line(Vector2(24.0, 28.0 + bob), Vector2(24.0, 47.0), Color(0.83, 0.52, 0.44), 10.0, true)
	draw_ellipse(Vector2(-22.0, 48.5), 12.0, 5.5, Color(0.94, 0.66, 0.57))
	draw_ellipse(Vector2(22.0, 48.5), 12.0, 5.5, Color(0.94, 0.66, 0.57))
