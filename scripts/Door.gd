extends Area2D

signal clicked(level_id: String)

var level_id := ""
var display_name := ""
var style_name := ""
var door_color := Color.WHITE
var is_return := false
var sprite: Sprite2D
var animation_textures: Array[Texture2D] = []
var animation_frame_index := 0
var animation_elapsed := 0.0
var animation_frame_time := 0.12
var is_opening := false
var is_open := false
var enter_after_animation := false
var name_label: Label

const PIXEL_OPEN_FRAME_PATHS := [
	"res://assets/doors/gemini_pixel_door_cutout.png",
	"res://assets/doors/art0001_open_frames/art0001_open_01_transparent.png",
	"res://assets/doors/art0001_open_frames/art0001_open_02_transparent.png",
	"res://assets/doors/art0001_open_frames/art0001_open_03_transparent.png",
	"res://assets/doors/art0001_open_frames/art0001_open_04_transparent.png",
]
const RETURN_ICON_PATH := "res://assets/generated/paper_escape_door_icon.png"


func setup(new_level_id: String, new_display_name: String, new_style_name: String, new_color: Color, return_door := false) -> void:
	level_id = new_level_id
	display_name = new_display_name
	style_name = new_style_name
	door_color = new_color
	is_return = return_door
	is_opening = false
	is_open = false
	enter_after_animation = false
	animation_elapsed = 0.0
	animation_frame_index = 0
	queue_redraw()


func _ready() -> void:
	set_process(true)
	var shape := CollisionShape2D.new()
	var shape_rect := RectangleShape2D.new()
	if is_return:
		shape_rect.size = Vector2(96.0, 96.0)
		shape.position = Vector2.ZERO
	elif level_id == "desktop_fish_tank":
		shape_rect.size = Vector2(116.0, 154.0)
		shape.position = Vector2(0.0, -6.0)
	else:
		shape_rect.size = Vector2(92.0, 116.0)
		shape.position = Vector2(0.0, 8.0)
	shape.shape = shape_rect
	add_child(shape)
	_create_sprite()
	_create_name_label()
	input_pickable = true
	input_event.connect(_on_input_event)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_opening:
		return

	animation_elapsed += delta
	if animation_elapsed < animation_frame_time:
		return

	animation_elapsed = 0.0
	animation_frame_index += 1
	if animation_frame_index >= animation_textures.size():
		_finish_open_animation()
		return

	sprite.texture = animation_textures[animation_frame_index]


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(level_id)



func _draw() -> void:
	if is_return:
		if sprite == null:
			_draw_return_door()
		return
	if sprite != null:
		return

	match level_id:
		"pixel":
			_draw_pixel_door()
		"clay":
			_draw_clay_door()
		"cartoon":
			_draw_cartoon_door()
		"desktop_fish_tank":
			_draw_bathtub_door()
		_:
			_draw_cartoon_door()


func _create_sprite() -> void:
	var texture_path: String = _get_texture_path()
	if texture_path == "":
		return

	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return

	sprite = Sprite2D.new()
	sprite.name = "GeminiDoorSprite"
	sprite.texture = texture
	if is_return:
		sprite.flip_h = true
	sprite.position = Vector2.ZERO if is_return else Vector2(0.0, -8.0)
	var texture_width: int = texture.get_width()
	var texture_height: int = texture.get_height()
	var longest_side: float = float(texture_width if texture_width > texture_height else texture_height)
	if longest_side > 0.0:
		var target_size: float = 96.0 if is_return else 145.0
		var scale_factor: float = target_size / longest_side
		sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)
	_load_open_animation()


func _load_texture(texture_path: String) -> Texture2D:
	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D

	var file_path: String = texture_path
	if texture_path.begins_with("res://") or texture_path.begins_with("user://"):
		file_path = ProjectSettings.globalize_path(texture_path)

	var image := Image.new()
	var error: int = image.load(file_path)
	if error == OK and not image.is_empty():
		return ImageTexture.create_from_image(image)

	return null


func _load_open_animation() -> void:
	animation_textures.clear()
	if level_id != "pixel":
		return

	for path in PIXEL_OPEN_FRAME_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			animation_textures.append(texture)


func _can_play_open_animation() -> bool:
	return sprite != null and animation_textures.size() > 1 and level_id == "pixel"


func _play_open_animation() -> void:
	is_opening = true
	animation_elapsed = 0.0
	animation_frame_index = 0
	sprite.texture = animation_textures[animation_frame_index]


func _finish_open_animation() -> void:
	is_opening = false
	is_open = true
	animation_frame_index = animation_textures.size() - 1
	sprite.texture = animation_textures[animation_frame_index]
	if enter_after_animation:
		enter_after_animation = false
		clicked.emit(level_id)


func _get_texture_path() -> String:
	if is_return:
		return RETURN_ICON_PATH

	match level_id:
		"fridge_people":
			return "res://assets/doors/gemini_fridge_door_clay_v2_cutout.png"
		"mouse_genesis":
			return "res://assets/doors/gemini_mouse_genesis_door_cutout.png"
		"nana_shrine":
			return "res://assets/doors/gemini_nana_shrine_door_cutout.png"
		"archaeology_team":
			if ResourceLoader.exists("res://assets/archaeology_team/archaeology_door.png"):
				return "res://assets/archaeology_team/archaeology_door.png"
			return "res://assets/doors/gemini_clay_door_cutout.png"
		"fairy_academy":
			if ResourceLoader.exists("res://assets/xianxia_academy/xianxia_door.png"):
				return "res://assets/xianxia_academy/xianxia_door.png"
			return "res://assets/doors/gemini_cartoon_door_cutout.png"
		"corpse_farm":
			if ResourceLoader.exists("res://assets/corpse_farm/corpse_farm_door.png"):
				return "res://assets/corpse_farm/corpse_farm_door.png"
			return "res://assets/doors/gemini_clay_door_cutout.png"
		"tiny_prison":
			if ResourceLoader.exists("res://assets/tiny_prison/prison_door.png"):
				return "res://assets/tiny_prison/prison_door.png"
			return "res://assets/doors/gemini_clay_door_cutout.png"
		"desktop_fish_tank":
			return "res://assets/doors/gemini_desktop_fish_tank_bathtub_door_cutout.png"
		"meow_energy":
			if ResourceLoader.exists("res://assets/meow_energy/meow_energy_door.png"):
				return "res://assets/meow_energy/meow_energy_door.png"
			return "res://assets/doors/gemini_cartoon_door_cutout.png"
		"scary_barbie":
			return "res://assets/doors/gemini_scary_barbie_door_cutout.png"
		_:
			return ""


func _create_name_label() -> void:
	if display_name.strip_edges() == "":
		return

	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-68.0, 70.0)
	name_label.size = Vector2(136.0, 30.0)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86))
	name_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.05, 0.07, 0.90))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(name_label)


func _draw_pixel_door() -> void:
	var block := 12.0
	draw_rect(Rect2(-48.0, -54.0, 96.0, 120.0), Color(0.08, 0.08, 0.09))
	for y in range(8):
		for x in range(6):
			var shade := 0.9 if (x + y) % 2 == 0 else 0.72
			draw_rect(Rect2(-36.0 + x * block, -42.0 + y * block, block, block), door_color * shade)
	draw_rect(Rect2(18.0, 6.0, 10.0, 10.0), Color(1.0, 0.92, 0.25))


func _draw_clay_door() -> void:
	draw_circle(Vector2(0.0, -18.0), 54.0, Color(0.50, 0.30, 0.22))
	draw_rect(Rect2(-54.0, -18.0, 108.0, 86.0), Color(0.50, 0.30, 0.22))
	draw_circle(Vector2(0.0, -12.0), 43.0, door_color)
	draw_rect(Rect2(-43.0, -12.0, 86.0, 76.0), door_color)
	draw_circle(Vector2(24.0, 18.0), 6.0, Color(0.95, 0.82, 0.31))
	for i in range(4):
		draw_arc(Vector2(-16.0 + i * 12.0, 12.0), 20.0, 0.5, 2.2, 18, Color(0.64, 0.34, 0.26), 2.0)


func _draw_cartoon_door() -> void:
	draw_rect(Rect2(-50.0, -56.0, 100.0, 124.0), Color(0.05, 0.05, 0.06), false, 8.0)
	draw_rect(Rect2(-42.0, -48.0, 84.0, 108.0), door_color)
	draw_line(Vector2(-32.0, -30.0), Vector2(28.0, -44.0), Color.WHITE, 4.0)
	draw_line(Vector2(-30.0, -12.0), Vector2(24.0, -24.0), Color.WHITE, 4.0)
	draw_circle(Vector2(22.0, 10.0), 7.0, Color(1.0, 0.86, 0.18))


func _draw_return_door() -> void:
	var bg := Rect2(-48.0, -48.0, 96.0, 96.0)
	var green := Color(0.10, 0.58, 0.33)
	var white := Color(0.96, 0.97, 0.94)
	draw_rect(bg, Color(0.03, 0.04, 0.04, 0.45))
	draw_rect(bg.grow(-4.0), green)
	draw_rect(Rect2(-30.0, -32.0, 48.0, 60.0), white)
	draw_rect(Rect2(-42.0, 22.0, 64.0, 18.0), white)

	draw_circle(Vector2(-4.0, -22.0), 10.0, green)
	draw_line(Vector2(-10.0, -8.0), Vector2(-23.0, 12.0), green, 12.0)
	draw_line(Vector2(-8.0, -7.0), Vector2(18.0, -2.0), green, 12.0)
	draw_line(Vector2(-18.0, 8.0), Vector2(-36.0, 31.0), green, 12.0)
	draw_line(Vector2(-15.0, 8.0), Vector2(7.0, 31.0), green, 12.0)
	draw_line(Vector2(7.0, 31.0), Vector2(34.0, 31.0), green, 12.0)

	draw_colored_polygon(PackedVector2Array([
		Vector2(18.0, -1.0),
		Vector2(38.0, -1.0),
		Vector2(38.0, 8.0),
		Vector2(48.0, -7.0),
		Vector2(38.0, -22.0),
		Vector2(38.0, -13.0),
		Vector2(18.0, -13.0),
	]), white)


func _draw_bathtub_door() -> void:
	var tub := Color(0.74, 0.86, 0.92)
	var tub_light := Color(0.86, 0.94, 0.98)
	var rim := Color(0.83, 0.91, 0.95)
	var brass := Color(0.71, 0.58, 0.30)
	var brass_dark := Color(0.45, 0.35, 0.18)
	var shower := Color(0.44, 0.74, 0.76)
	var claw := Color(0.17, 0.18, 0.21)

	draw_line(Vector2(-38.0, -26.0), Vector2(-38.0, -110.0), brass, 8.0)
	draw_line(Vector2(-38.0, -110.0), Vector2(6.0, -124.0), brass, 8.0)
	draw_line(Vector2(6.0, -124.0), Vector2(32.0, -84.0), brass, 8.0)
	draw_circle(Vector2(38.0, -66.0), 15.0, brass_dark)
	draw_circle(Vector2(38.0, -66.0), 10.0, shower)
	draw_circle(Vector2(38.0, -66.0), 4.0, Color(0.94, 0.96, 0.96))

	draw_rect(Rect2(-78.0, -28.0, 156.0, 82.0), tub)
	draw_rect(Rect2(-84.0, -38.0, 168.0, 24.0), rim)
	draw_rect(Rect2(-70.0, -20.0, 140.0, 62.0), tub_light)
	draw_rect(Rect2(-64.0, -18.0, 128.0, 56.0), tub)
	draw_line(Vector2(-48.0, -12.0), Vector2(48.0, -12.0), Color(0.93, 0.97, 0.99, 0.25), 3.0)
	draw_line(Vector2(-50.0, -3.0), Vector2(42.0, -3.0), Color(0.97, 0.99, 1.0, 0.12), 2.0)

	draw_line(Vector2(-48.0, -28.0), Vector2(-26.0, -48.0), brass, 8.0)
	draw_line(Vector2(-26.0, -48.0), Vector2(-2.0, -48.0), brass, 8.0)
	draw_circle(Vector2(-2.0, -48.0), 12.0, brass_dark)
	draw_circle(Vector2(-2.0, -48.0), 8.0, brass)

	draw_circle(Vector2(-46.0, -20.0), 8.0, brass_dark)
	draw_circle(Vector2(-46.0, -20.0), 5.0, brass)
	draw_circle(Vector2(-20.0, -20.0), 8.0, brass_dark)
	draw_circle(Vector2(-20.0, -20.0), 5.0, brass)

	draw_line(Vector2(-52.0, 34.0), Vector2(-60.0, 58.0), claw, 7.0)
	draw_line(Vector2(-44.0, 34.0), Vector2(-32.0, 58.0), claw, 7.0)
	draw_line(Vector2(32.0, 34.0), Vector2(24.0, 58.0), claw, 7.0)
	draw_line(Vector2(42.0, 34.0), Vector2(56.0, 58.0), claw, 7.0)
	draw_circle(Vector2(-52.0, 58.0), 9.0, claw)
	draw_circle(Vector2(42.0, 58.0), 9.0, claw)
