class_name FridgePomodoroPlayer
extends CharacterBody2D

@export var sprite_sheet_path := "res://assets/generated/paper_fridge_player_sheet.png"
@export var frame_count := 3
@export var frame_size := Vector2i(512, 512)
@export var animation_fps := 3.0
@export var display_height := 320.0

var phase := "idle"
var progress := 0.0
var time_text := "00:00"
var active_item_id := "tomato"
var item_elapsed := 0.0
var animated_sprite: AnimatedSprite2D


func _ready() -> void:
	z_index = 12
	set_process(true)
	_create_shadow()
	_create_animation()
	queue_redraw()


func _process(delta: float) -> void:
	item_elapsed += delta
	queue_redraw()


func set_pomodoro_state(new_phase: String, new_progress: float, new_time_text: String) -> void:
	phase = new_phase
	progress = clamp(new_progress, 0.0, 1.0)
	time_text = new_time_text
	queue_redraw()


func set_active_item(item_id: String) -> void:
	if active_item_id == item_id:
		return
	active_item_id = item_id
	item_elapsed = 0.0
	queue_redraw()


func _draw() -> void:
	if phase == "idle":
		return

	var ring_center: Vector2 = Vector2(0.0, -145.0)
	var ring_radius := 160.0
	var base_color: Color = Color(0.35, 0.38, 0.32, 0.35)
	var accent: Color = Color(0.92, 0.40, 0.22, 0.95)
	if phase == "work":
		accent = Color(0.94, 0.42, 0.22, 0.95)
	elif phase == "break":
		accent = Color(0.32, 0.72, 0.48, 0.95)

	draw_arc(ring_center, ring_radius, -PI * 0.5, PI * 1.5, 80, base_color, 5.0, true)
	if phase != "idle":
		draw_arc(ring_center, ring_radius, -PI * 0.5, -PI * 0.5 + progress * TAU, 80, accent, 8.0, true)


func _draw_item_idle_effect() -> void:
	var bob: float = sin(item_elapsed * 4.0) * 4.0
	match active_item_id:
		"cassette":
			_draw_cassette(Vector2(94.0, -120.0 + bob))
		"pager":
			_draw_pager(Vector2(94.0, -142.0 + bob))
		"walkman":
			_draw_walkman(Vector2(0.0, -196.0 + bob * 0.4))
		"crt":
			_draw_crt(Vector2(104.0, -132.0 + bob))
		"vhs":
			_draw_vhs(Vector2(98.0, -118.0 + bob))
		_:
			pass


func _draw_cassette(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-34.0, -22.0), Vector2(68.0, 44.0))
	draw_rect(body, Color(0.15, 0.17, 0.20, 0.92), true)
	draw_rect(body, Color(0.88, 0.76, 0.52, 0.96), false, 3.0)
	draw_circle(center + Vector2(-18.0, 0.0), 10.0, Color(0.78, 0.80, 0.78, 0.95))
	draw_circle(center + Vector2(18.0, 0.0), 10.0, Color(0.78, 0.80, 0.78, 0.95))
	draw_line(center + Vector2(-18.0, -10.0).rotated(item_elapsed), center + Vector2(-18.0, 10.0).rotated(item_elapsed), Color(0.09, 0.10, 0.11), 2.0)
	draw_line(center + Vector2(18.0, -10.0).rotated(-item_elapsed), center + Vector2(18.0, 10.0).rotated(-item_elapsed), Color(0.09, 0.10, 0.11), 2.0)


func _draw_pager(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-28.0, -18.0), Vector2(56.0, 36.0))
	var blink: float = 0.45 + 0.35 * abs(sin(item_elapsed * 5.5))
	draw_rect(body, Color(0.12, 0.12, 0.14, 0.94), true)
	draw_rect(Rect2(center + Vector2(-20.0, -10.0), Vector2(28.0, 12.0)), Color(0.46, 0.78, 0.60, blink), true)
	draw_circle(center + Vector2(18.0, 8.0), 4.0, Color(0.95, 0.72, 0.25, 0.95))


func _draw_walkman(center: Vector2) -> void:
	draw_arc(center + Vector2(0.0, -18.0), 62.0, PI * 1.06, PI * 1.94, 36, Color(0.08, 0.09, 0.10, 0.86), 5.0, true)
	draw_circle(center + Vector2(-62.0, 0.0), 18.0, Color(0.18, 0.18, 0.20, 0.92))
	draw_circle(center + Vector2(62.0, 0.0), 18.0, Color(0.18, 0.18, 0.20, 0.92))


func _draw_crt(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-34.0, -28.0), Vector2(68.0, 52.0))
	var scan_y: float = fposmod(item_elapsed * 34.0, 34.0) - 17.0
	draw_rect(body, Color(0.22, 0.20, 0.18, 0.95), true)
	draw_rect(Rect2(center + Vector2(-25.0, -19.0), Vector2(42.0, 31.0)), Color(0.42, 0.74, 0.78, 0.88), true)
	draw_line(center + Vector2(-23.0, scan_y), center + Vector2(15.0, scan_y), Color(0.96, 1.0, 0.82, 0.72), 2.0)
	draw_circle(center + Vector2(25.0, 13.0), 4.0, Color(0.95, 0.72, 0.25, 0.95))


func _draw_vhs(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-38.0, -18.0), Vector2(76.0, 36.0))
	draw_rect(body, Color(0.08, 0.08, 0.10, 0.94), true)
	draw_rect(Rect2(center + Vector2(-22.0, -9.0), Vector2(44.0, 18.0)), Color(0.78, 0.78, 0.74, 0.95), true)
	draw_circle(center + Vector2(-24.0, 0.0), 7.0, Color(0.18, 0.18, 0.19, 0.95))
	draw_circle(center + Vector2(24.0, 0.0), 7.0, Color(0.18, 0.18, 0.19, 0.95))


func _create_shadow() -> void:
	# Subtle paper-drop shadow or none matching the flat paper craft style
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.28, 0.30, 0.18, 0.18)
	shadow.polygon = PackedVector2Array([
		Vector2(-60.0, -8.0),
		Vector2(60.0, -8.0),
		Vector2(75.0, 4.0),
		Vector2(60.0, 16.0),
		Vector2(-60.0, 16.0),
		Vector2(-75.0, 4.0),
	])
	add_child(shadow)


func _create_animation() -> void:
	var texture: Texture2D = load(sprite_sheet_path) as Texture2D
	if texture == null:
		push_warning("Fridge player sprite sheet not found: %s" % sprite_sheet_path)
		return

	var frames := SpriteFrames.new()
	const ANIMATION_NAME := "idle"
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_speed(ANIMATION_NAME, animation_fps)
	frames.set_animation_loop(ANIMATION_NAME, true)

	for frame_index in range(frame_count):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(
			frame_index * frame_size.x,
			0,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame(ANIMATION_NAME, atlas_texture)

	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "Sprite"
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = ANIMATION_NAME
	animated_sprite.position = Vector2(0.0, -145.0)
	var scale_factor: float = display_height / float(frame_size.y)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)
	animated_sprite.play()
	add_child(animated_sprite)
