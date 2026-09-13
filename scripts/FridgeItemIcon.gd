class_name FridgeItemIcon
extends Control

signal activated(item_id: String)

var item_id := "tomato"
var unlocked := true
var active := false
var icon_texture: Texture2D


func setup(new_item_id: String, is_unlocked: bool) -> void:
	item_id = new_item_id
	unlocked = is_unlocked
	custom_minimum_size = Vector2(52.0, 52.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_icon()
	queue_redraw()


func _load_icon() -> void:
	var path := "res://assets/generated/paper_icon_%s.png" % item_id
	if ResourceLoader.exists(path):
		icon_texture = load(path) as Texture2D
	else:
		var file_path := ProjectSettings.globalize_path(path)
		var img := Image.new()
		if img.load(file_path) == OK and not img.is_empty():
			icon_texture = ImageTexture.create_from_image(img)


func set_unlocked(is_unlocked: bool) -> void:
	unlocked = is_unlocked
	queue_redraw()


func set_state(is_unlocked: bool, is_active: bool) -> void:
	unlocked = is_unlocked
	active = is_active
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and unlocked:
			activated.emit(item_id)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var alpha: float = 1.0 if unlocked else 0.42
	# Paper craft card style for shop list item
	var bg_color := Color(0.96, 0.93, 0.86, 0.88 * alpha)
	var border_color := Color(0.82, 0.76, 0.64, 0.95 * alpha)
	if active:
		bg_color = Color(1.0, 0.96, 0.82, 0.98)
		border_color = Color(0.96, 0.74, 0.22, 0.98)
	
	# Drop shadow
	draw_rect(Rect2(Vector2(1.0, 2.0), size), Color(0.0, 0.0, 0.0, 0.18 * alpha), true)
	# Card base
	draw_rect(Rect2(Vector2.ZERO, size), bg_color, true)
	draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), border_color, false, 2.0 if active else 1.2)

	var center: Vector2 = size * 0.5
	if icon_texture != null:
		var icon_size := Vector2(38.0, 38.0)
		var icon_rect := Rect2(center - icon_size * 0.5, icon_size)
		draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		match item_id:
			"cassette":
				_draw_cassette(center, alpha)
			"pager":
				_draw_pager(center, alpha)
			"walkman":
				_draw_walkman(center, alpha)
			"crt":
				_draw_crt(center, alpha)
			"vhs":
				_draw_vhs(center, alpha)
			_:
				_draw_tomato(center, alpha)


func _draw_tomato(center: Vector2, alpha: float) -> void:
	draw_circle(center + Vector2(0.0, 4.0), 17.0, Color(0.92, 0.16, 0.12, alpha))
	draw_line(center + Vector2(0.0, 4.0), center + Vector2(0.0, -7.0), Color(1.0, 0.88, 0.62, alpha), 2.0, true)
	draw_line(center + Vector2(0.0, 4.0), center + Vector2(9.0, 8.0), Color(1.0, 0.88, 0.62, alpha), 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10.0, -11.0),
		center + Vector2(-2.0, -21.0),
		center + Vector2(3.0, -10.0),
	]), Color(0.18, 0.55, 0.26, alpha))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(3.0, -10.0),
		center + Vector2(14.0, -18.0),
		center + Vector2(12.0, -6.0),
	]), Color(0.18, 0.55, 0.26, alpha))


func _draw_cassette(center: Vector2, alpha: float) -> void:
	draw_rect(Rect2(center + Vector2(-20.0, -13.0), Vector2(40.0, 26.0)), Color(0.82, 0.68, 0.42, alpha), true)
	draw_rect(Rect2(center + Vector2(-15.0, -5.0), Vector2(30.0, 10.0)), Color(0.16, 0.18, 0.19, alpha), true)
	draw_circle(center + Vector2(-10.0, 0.0), 5.0, Color(0.90, 0.90, 0.84, alpha))
	draw_circle(center + Vector2(10.0, 0.0), 5.0, Color(0.90, 0.90, 0.84, alpha))


func _draw_pager(center: Vector2, alpha: float) -> void:
	draw_rect(Rect2(center + Vector2(-18.0, -12.0), Vector2(36.0, 24.0)), Color(0.12, 0.12, 0.14, alpha), true)
	draw_rect(Rect2(center + Vector2(-13.0, -7.0), Vector2(22.0, 9.0)), Color(0.48, 0.80, 0.58, alpha), true)
	draw_circle(center + Vector2(12.0, 7.0), 3.0, Color(0.95, 0.72, 0.25, alpha))


func _draw_walkman(center: Vector2, alpha: float) -> void:
	draw_arc(center + Vector2(0.0, -7.0), 24.0, PI * 1.08, PI * 1.92, 22, Color(0.08, 0.09, 0.10, alpha), 3.0, true)
	draw_circle(center + Vector2(-22.0, 5.0), 8.0, Color(0.18, 0.18, 0.20, alpha))
	draw_circle(center + Vector2(22.0, 5.0), 8.0, Color(0.18, 0.18, 0.20, alpha))
	draw_rect(Rect2(center + Vector2(-13.0, -4.0), Vector2(26.0, 21.0)), Color(0.58, 0.52, 0.78, alpha), true)


func _draw_crt(center: Vector2, alpha: float) -> void:
	draw_rect(Rect2(center + Vector2(-18.0, -15.0), Vector2(36.0, 28.0)), Color(0.24, 0.21, 0.18, alpha), true)
	draw_rect(Rect2(center + Vector2(-13.0, -10.0), Vector2(21.0, 16.0)), Color(0.42, 0.76, 0.78, alpha), true)
	draw_line(center + Vector2(-11.0, -1.0), center + Vector2(7.0, -1.0), Color(0.95, 1.0, 0.78, alpha), 2.0)
	draw_line(center + Vector2(-8.0, 16.0), center + Vector2(-15.0, 22.0), Color(0.20, 0.18, 0.16, alpha), 2.0)
	draw_line(center + Vector2(8.0, 16.0), center + Vector2(15.0, 22.0), Color(0.20, 0.18, 0.16, alpha), 2.0)


func _draw_vhs(center: Vector2, alpha: float) -> void:
	draw_rect(Rect2(center + Vector2(-22.0, -10.0), Vector2(44.0, 20.0)), Color(0.08, 0.08, 0.10, alpha), true)
	draw_rect(Rect2(center + Vector2(-12.0, -5.0), Vector2(24.0, 10.0)), Color(0.78, 0.78, 0.74, alpha), true)
	draw_circle(center + Vector2(-14.0, 0.0), 4.0, Color(0.20, 0.20, 0.22, alpha))
	draw_circle(center + Vector2(14.0, 0.0), 4.0, Color(0.20, 0.20, 0.22, alpha))
