class_name FridgeYarnBall
extends Control

signal pressed_for_drag(ball, pointer_offset: Vector2)
signal unlock_requested(item_id: String)

const DEFAULT_RADIUS := 20.0

var item_id := "tomato"
var item_name := "Pomodoro"
var reward_amount := 5
var radius := DEFAULT_RADIUS
var unlocked := true
var active := false
var interactable := true
var velocity := Vector2.ZERO
var is_dragging_visual := false


func setup(new_item_id: String, new_item_name: String, is_unlocked: bool, new_reward_amount: int) -> void:
	item_id = new_item_id
	item_name = new_item_name
	unlocked = is_unlocked
	reward_amount = new_reward_amount
	custom_minimum_size = Vector2(radius * 2.0 + 8.0, radius * 2.0 + 8.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = item_name
	queue_redraw()


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
	var alpha := 1.0 if unlocked else 0.40
	var palette := _get_palette()
	var base_color: Color = palette[0]
	var strand_color: Color = palette[1]
	var dark_color: Color = palette[2]

	draw_circle(center + Vector2(0.0, 3.0), radius + 2.0, Color(0.0, 0.0, 0.0, 0.20 * alpha))
	draw_circle(center, radius + (2.0 if is_dragging_visual else 0.0), _with_alpha(base_color, alpha))

	for i in range(7):
		var offset := float(i) * 0.54
		var arc_radius := radius * (0.36 + float(i % 4) * 0.13)
		var arc_center := center + Vector2(sin(offset * 1.7) * 2.4, cos(offset * 1.3) * 2.0)
		draw_arc(arc_center, arc_radius, offset, offset + PI * 1.45, 22, _with_alpha(strand_color, 0.86 * alpha), 2.2, true)

	draw_arc(center + Vector2(-1.0, 1.0), radius * 0.76, PI * 0.15, PI * 1.78, 28, _with_alpha(dark_color, 0.34 * alpha), 2.0, true)
	draw_line(center + Vector2(-radius * 0.74, -2.0), center + Vector2(radius * 0.72, 4.0), _with_alpha(strand_color.lightened(0.12), 0.65 * alpha), 1.6, true)

	if active:
		draw_arc(center, radius + 4.0, 0.0, TAU, 36, Color(1.0, 0.84, 0.28, 0.95), 3.0, true)

	if not unlocked:
		_draw_lock(center)


func _draw_lock(center: Vector2) -> void:
	var lock_color := Color(0.10, 0.10, 0.11, 0.66)
	draw_arc(center + Vector2(0.0, -2.0), 8.0, PI, TAU, 18, lock_color, 2.4, true)
	draw_rect(Rect2(center + Vector2(-8.0, -1.0), Vector2(16.0, 12.0)), lock_color, true)
	draw_circle(center + Vector2(0.0, 4.0), 2.0, Color(0.92, 0.86, 0.62, 0.82))


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _get_palette() -> Array[Color]:
	match item_id:
		"cassette":
			return [Color(0.74, 0.55, 0.34), Color(0.96, 0.80, 0.50), Color(0.36, 0.23, 0.14)]
		"pager":
			return [Color(0.42, 0.72, 0.50), Color(0.82, 0.96, 0.70), Color(0.18, 0.38, 0.25)]
		"walkman":
			return [Color(0.54, 0.48, 0.76), Color(0.86, 0.80, 1.0), Color(0.25, 0.20, 0.42)]
		"crt":
			return [Color(0.42, 0.72, 0.74), Color(0.84, 1.0, 0.96), Color(0.14, 0.36, 0.38)]
		"vhs":
			return [Color(0.52, 0.52, 0.56), Color(0.86, 0.86, 0.88), Color(0.22, 0.22, 0.25)]
		_:
			return [Color(0.92, 0.22, 0.18), Color(1.0, 0.62, 0.52), Color(0.45, 0.08, 0.06)]
