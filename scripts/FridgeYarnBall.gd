class_name FridgeYarnBall
extends Control

signal pressed_for_drag(ball: Control, pointer_offset: Vector2)
signal unlock_requested(item_id: String)

const DEFAULT_RADIUS := 48.0
## 融在一起: the item's length in MINUTES is a paper BADGE notched onto the ball's top edge - a
## scalloped pale plate with a dark medallion punched into it and a gold digit inside - so the number
## and the ball's own logo read as ONE piece of art (1 = 1 分钟, 2 = 2 分钟).
## This replaced the hover tooltip (the mouth balls no longer show one at all).
const MINUTES_FONT_SIZE := 17
## The digit's outline, drawn in the ball's own dark accent, with the gold face on top of it.
const MINUTES_OUTLINE_SIZE := 3
## The plate's radius, as a fraction of the ball's radius (the reference badge is about a third).
const MINUTES_PLATE_FRAC := 0.38
## It is a paper FLOWER: a circle whose radius ripples this deep around this many lobes.
const MINUTES_PLATE_LOBES := 9
const MINUTES_PLATE_LOBE_DEPTH := 0.085
## The plate's gold rim, drawn as a slightly larger copy behind it, and its pale paper face.
const MINUTES_PLATE_EDGE_FRAC := 1.10
const MINUTES_PLATE_EDGE_COLOR := Color(0.87, 0.69, 0.28, 1.0)
const MINUTES_PLATE_COLOR := Color(1.0, 0.95, 0.81, 1.0)
## The dark medallion punched into the plate (a fraction of the plate's radius) and the digit's gold face.
const MINUTES_MEDALLION_FRAC := 0.66
const MINUTES_DIGIT_COLOR := Color(0.98, 0.85, 0.40, 1.0)
## 1.0 = the plate is centred ON the ball's top edge: half rides above the ball, half rests on it.
const MINUTES_PLATE_STAND_FRAC := 1.0
## The logo's half-width, as a fraction of the ball's radius, and how far it drops so the plate sits
## over its top margin - exactly like the reference art.
const ICON_RADIUS_FRAC := 0.72
const ICON_DROP_FRAC := 0.06

var item_id := "tomato"
var item_name := "Pomodoro"
var reward_amount := 5
var radius := DEFAULT_RADIUS
var minutes := 0
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
	# 数字: no hover tooltip - the ball prints its length in minutes under the logo instead (the
	# level calls set_minutes). tooltip_text is left EMPTY on purpose (FridgeLevel clears it too).
	tooltip_text = ""
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


## 数字: how many whole minutes one focused run of this item lasts (1 = 1 分钟, 2 = 2 分钟).
## 0 hides the digit.
func set_minutes(value: int) -> void:
	if value == minutes:
		return
	minutes = value
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


## Custom tooltip: the engine's black TooltipPanel background is removed and
## replaced by a cream paper card via the project theme
## (res://ui/paper_tooltip_theme.tres), so this only lays out the two text lines
## — the item's name and how long one focused run takes ("name\nduration", see
## FridgeLevel). Returning a bare container guarantees nothing paints over the
## themed card.
func _make_custom_tooltip(for_text: String) -> Object:
	var lines := for_text.split("\n", false)
	if lines.is_empty():
		return null

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 1)

	var title := Label.new()
	title.text = str(lines[0])
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.29, 0.20, 0.15))
	title.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(title)

	if lines.size() > 1:
		var duration := Label.new()
		duration.text = str(lines[1])
		duration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		duration.add_theme_font_size_override("font_size", 14)
		duration.add_theme_color_override("font_color", Color(0.74, 0.42, 0.15))
		duration.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.4))
		duration.add_theme_constant_override("shadow_offset_y", 1)
		column.add_child(duration)

	return column


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

	# 4. Item icon logo, dropped a touch so the 数字 plate can sit over its top margin.
	if icon_texture != null:
		var icon_r: float = draw_r * ICON_RADIUS_FRAC
		var icon_centre := center + Vector2(0.0, radius * ICON_DROP_FRAC)
		var icon_rect := Rect2(icon_centre - Vector2(icon_r, icon_r), Vector2(icon_r * 2.0, icon_r * 2.0))
		draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))

	# 5. Active state gold aura highlight
	if active:
		draw_arc(center, draw_r + 4.5, 0.0, TAU, 40, Color(1.0, 0.86, 0.32, 0.98), 3.0, true)
		draw_arc(center, draw_r + 2.0, 0.0, TAU, 36, Color(1.0, 1.0, 0.85, 0.90), 1.5, true)

	# 6. 融在一起: the minutes badge rides the ball's top edge and is drawn LAST, so neither the logo
	#    nor the aura can cross it - the number and the token read as one piece.
	if minutes > 0:
		_draw_minutes_badge(center, dark_accent, alpha)

	# 6. Locked overlay: subtle tint + small lock icon badge at bottom-right
	if not unlocked:
		draw_circle(center, draw_r, Color(0.04, 0.05, 0.06, 0.38))
		var lock_pos := center + Vector2(draw_r * 0.42, draw_r * 0.40)
		_draw_lock_badge(lock_pos)


## 融在一起: the item's length in minutes as a paper BADGE notched onto the ball's top edge - a
## scalloped pale plate with a gold rim, a dark medallion punched into it and a gold digit (outlined
## in the ball's own dark accent) inside. This is what merges the number with the token's logo.
func _draw_minutes_badge(center: Vector2, ink: Color, alpha: float) -> void:
	var plate_r: float = radius * MINUTES_PLATE_FRAC
	var plate_center := Vector2(center.x, center.y - radius * MINUTES_PLATE_STAND_FRAC)
	var plate := _minutes_plate_points(plate_center, plate_r)
	var rim := _minutes_plate_points(plate_center, plate_r * MINUTES_PLATE_EDGE_FRAC)

	# paper depth first, then the gold rim, then the pale plate face - the same cut-paper stack as the
	# ball itself, so the badge looks glued onto the token rather than pasted over it.
	draw_colored_polygon(_offset_points(plate, Vector2(1.4, 2.6)), Color(0.20, 0.13, 0.09, 0.34 * alpha))
	draw_colored_polygon(rim, _with_alpha(MINUTES_PLATE_EDGE_COLOR, alpha))
	draw_colored_polygon(plate, _with_alpha(MINUTES_PLATE_COLOR, alpha))

	# the dark medallion punched into the plate, with a hairline of the rim colour around it
	var medal_r: float = plate_r * MINUTES_MEDALLION_FRAC
	draw_circle(plate_center + Vector2(0.0, 0.7), medal_r + 1.2, _with_alpha(MINUTES_PLATE_EDGE_COLOR, 0.92 * alpha))
	draw_circle(plate_center, medal_r, _with_alpha(ink, alpha))

	# the digit: a gold face with the ball's own dark accent as its outline
	var font := get_theme_default_font()
	if font == null:
		return
	var text := str(minutes)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MINUTES_FONT_SIZE).x
	var baseline := Vector2(plate_center.x - width * 0.5, plate_center.y + float(MINUTES_FONT_SIZE) * 0.36)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MINUTES_FONT_SIZE,
		MINUTES_OUTLINE_SIZE, _with_alpha(ink, alpha))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MINUTES_FONT_SIZE,
		_with_alpha(MINUTES_DIGIT_COLOR, alpha))


## The plate's outline: a circle whose radius ripples MINUTES_PLATE_LOBE_DEPTH around
## MINUTES_PLATE_LOBES rounded bumps - the scalloped paper flower of the reference badge.
func _minutes_plate_points(plate_center: Vector2, plate_r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := MINUTES_PLATE_LOBES * 6
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var r: float = plate_r * (1.0 + MINUTES_PLATE_LOBE_DEPTH * cos(float(MINUTES_PLATE_LOBES) * t))
		points.append(plate_center + Vector2(cos(t), sin(t)) * r)
	return points


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + offset)
	return moved


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
