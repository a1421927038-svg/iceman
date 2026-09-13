class_name FridgeYarnBall
extends Control

signal pressed_for_drag(ball: Control, pointer_offset: Vector2)
signal unlock_requested(item_id: String)

const DEFAULT_RADIUS := 48.0

var item_id := "tomato"
var item_name := "Pomodoro"
var reward_amount := 5
var radius := DEFAULT_RADIUS
var unlocked := true
var active := false
var interactable := true
var velocity := Vector2.ZERO
var is_dragging_visual := false
var icon_texture: Texture2D


func setup(new_item_id: String, new_item_name: String, is_unlocked: bool, new_reward_amount: int) -> void:
	item_id = new_item_id
	item_name = new_item_name
	unlocked = is_unlocked
	reward_amount = new_reward_amount
	custom_minimum_size = Vector2(radius * 2.0 + 12.0, radius * 2.0 + 12.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = item_name
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


func set_state(is_unlocked: bool, is_active: bool, can_interact: bool, new_reward_amount: int) -> void:
	unlocked = is_unlocked
	active = is_active
	interactable = can_interact
	reward_amount = new_reward_amount
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked and interactable else Control.CURSOR_ARROW
	queue_redraw()


func set_dragging_visual(value: bool) -> void:
	is_dragging_visual = value
	queue_redraw()


func get_radius() -> float:
	return radius


func get_item_id() -> String:
	return item_id


func get_center_position() -> Vector2:
	return position + size * 0.5


func set_center_position(center: Vector2) -> void:
	position = center - size * 0.5


func get_velocity() -> Vector2:
	return velocity


func set_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius + 4.0


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return

	if not unlocked:
		unlock_requested.emit(item_id)
		get_viewport().set_input_as_handled()
		return

	if not interactable:
		return

	pressed_for_drag.emit(self, get_global_mouse_position() - global_position)
	get_viewport().set_input_as_handled()


func _draw() -> void:
	var center := size * 0.5
	var alpha: float = 1.0 if unlocked else 0.45
	var palette := _get_palette()
	var card_color: Color = palette[0]
	var border_color: Color = palette[1]
	var dark_accent: Color = palette[2]

	var draw_r: float = radius + (2.0 if is_dragging_visual else 0.0)

	# 1. Soft paper drop shadow
	draw_circle(center + Vector2(1.5, 3.5), draw_r + 1.5, Color(0.0, 0.0, 0.0, 0.26 * alpha))

	# 2. Main paper-cut circle token base
	draw_circle(center, draw_r, _with_alpha(card_color, alpha))

	# 3. Inner craft border ring (paper collage edge)
	draw_arc(center, draw_r - 2.0, 0.0, TAU, 36, _with_alpha(border_color, 0.95 * alpha), 1.8, true)
	draw_arc(center, draw_r - 4.5, 0.0, TAU, 36, _with_alpha(dark_accent, 0.35 * alpha), 1.0, true)

	# 4. Item icon logo inside the badge
	if icon_texture != null:
		var icon_r: float = draw_r * 0.72
		var icon_rect := Rect2(center - Vector2(icon_r, icon_r), Vector2(icon_r * 2.0, icon_r * 2.0))
		draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))

	# 5. Active state gold aura highlight
	if active:
		draw_arc(center, draw_r + 4.5, 0.0, TAU, 40, Color(1.0, 0.86, 0.32, 0.98), 3.0, true)
		draw_arc(center, draw_r + 2.0, 0.0, TAU, 36, Color(1.0, 1.0, 0.85, 0.90), 1.5, true)

	# 6. Locked overlay: subtle tint + small lock icon badge at bottom-right
	if not unlocked:
		draw_circle(center, draw_r, Color(0.04, 0.05, 0.06, 0.38))
		var lock_pos := center + Vector2(draw_r * 0.42, draw_r * 0.40)
		_draw_lock_badge(lock_pos)


func _draw_lock_badge(pos: Vector2) -> void:
	# Small circular backer for the lock
	draw_circle(pos + Vector2(0.5, 1.0), 9.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_circle(pos, 8.5, Color(0.18, 0.16, 0.15, 0.96))
	draw_arc(pos, 8.5, 0.0, TAU, 24, Color(0.96, 0.84, 0.32, 0.95), 1.2, true)

	var lock_metal := Color(1.0, 0.90, 0.42, 0.98)
	var lock_shackle := Color(0.92, 0.92, 0.88, 0.98)

	# Shackle
	draw_arc(pos + Vector2(0.0, -2.5), 3.5, PI, TAU, 14, lock_shackle, 1.6, true)
	# Body
	draw_rect(Rect2(pos + Vector2(-4.5, -1.5), Vector2(9.0, 7.0)), lock_metal, true)
	# Keyhole
	draw_circle(pos + Vector2(0.0, 1.5), 1.0, Color(0.18, 0.16, 0.15, 0.98))
	draw_line(pos + Vector2(0.0, 1.5), pos + Vector2(0.0, 4.0), Color(0.18, 0.16, 0.15, 0.98), 1.1)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _get_palette() -> Array[Color]:
	match item_id:
		"cassette":
			return [Color(0.93, 0.84, 0.65), Color(0.98, 0.93, 0.80), Color(0.48, 0.36, 0.22)]
		"pager":
			return [Color(0.50, 0.68, 0.56), Color(0.80, 0.92, 0.76), Color(0.22, 0.36, 0.26)]
		"walkman":
			return [Color(0.70, 0.62, 0.86), Color(0.88, 0.82, 0.98), Color(0.36, 0.28, 0.52)]
		"crt":
			return [Color(0.45, 0.74, 0.76), Color(0.78, 0.94, 0.96), Color(0.20, 0.42, 0.44)]
		"vhs":
			return [Color(0.46, 0.48, 0.54), Color(0.78, 0.80, 0.86), Color(0.24, 0.25, 0.30)]
		_: # tomato
			return [Color(0.88, 0.34, 0.28), Color(1.0, 0.72, 0.64), Color(0.52, 0.16, 0.14)]
