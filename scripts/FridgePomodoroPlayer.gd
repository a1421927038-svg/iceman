class_name FridgePomodoroPlayer
extends CharacterBody2D

@export var sprite_sheet_path := "res://assets/generated/paper_fridge_player_sheet.png"
@export var frame_count := 3
@export var frame_size := Vector2i(512, 512)
@export var animation_fps := 3.0
@export var display_height := 320.0

## Emitted when a performance preview (juggle replay or rest) ends naturally
## after its timer runs out. The host level uses this to bring the post-round
## choice buttons back, so the player can pick again. Not emitted when a
## performance is replaced or stopped (new session, reset, mutual swap).
signal performance_finished

# Pomodoro juggle sequence, triggered by placing the tomato item from the
# cat mouth onto the player: open own fridge door -> reveal the tomatoes
# inside the belly -> take them out -> start juggling them in a loop.
const INTRO_ANIMATION_NAME := "tomato_intro"
const JUGGLE_ANIMATION_NAME := "tomato_juggle"
const INTRO_FRAME_PATHS := [
	"res://assets/generated/paper_fridge_kf_open_door.png",
	"res://assets/generated/paper_fridge_kf_reveal_tomatoes.png",
	"res://assets/generated/paper_fridge_kf_take_out.png",
]
const INTRO_ANIMATION_FPS := 2.0
const INTRO_FRAME_SIZE := Vector2i(512, 512)

# The juggle phase uses ONE static pose; the flying tomatoes are separate
# sprites animated in code. Frame-by-frame AI animation visibly deformed the
# character between frames, so the motion is composited instead of baked into
# a frame strip. The tomatoes follow a classic up-toss juggle (like the
# reference): they rise from a hand, hover above the head and fall back —
# no orbiting around the body.
const JUGGLE_BASE_PATH := "res://assets/generated/paper_fridge_kf_juggle_base_v3.png"

# Rest performance: after a work round finishes, the right button plays this
# Gemini-generated exhausted-panting loop (bent over, hands on knees, sweat
# drops flying). The atlas holds three 512px frames; they are ping-ponged
# (1-2-3-2) at load time so the breathing heave eases instead of snapping.
const REST_ANIMATION_NAME := "pomodoro_rest"
const REST_ATLAS_PATH := "res://assets/generated/paper_fridge_rest_pant.png"
const REST_FRAME_SIZE := Vector2i(512, 512)
const REST_ANIMATION_FPS := 5.5

const JUGGLE_FRAME_SIZE := Vector2i(512, 512)
const JUGGLE_OBJECT_SCALE := 0.62
# Measured from the base art: where the raised open palms are.
const JUGGLE_HAND_LEFT := Vector2(-109.0, -218.0)
const JUGGLE_HAND_RIGHT := Vector2(108.0, -218.0)
const JUGGLE_CYCLE_TIME := 0.9
const JUGGLE_PEAK_DRIFT := 26.0
const JUGGLE_LAUNCH_TIME := 0.45
# Per-object flight: landing hand, toss height (px) and cycle offset.
const JUGGLE_FLIGHTS := [
	{"hand": JUGGLE_HAND_LEFT, "amp": 130.0, "phase": 0.0},
	{"hand": JUGGLE_HAND_RIGHT, "amp": 110.0, "phase": 0.33},
	{"hand": JUGGLE_HAND_LEFT, "amp": 88.0, "phase": 0.66},
]
# Tossable objects: the base animation is pure motion with EMPTY hands, so the
# flying object is a separate, swappable layer (ball by default; the prop box
# in the level swaps it live; more objects can be registered here later).
const JUGGLE_PROJECTILES := [
	{"id": "ball", "path": "res://assets/generated/paper_juggle_ball.png"},
	{"id": "tomato", "path": "res://assets/generated/paper_tomato_projectile.png"},
]
const SPRITE_BASE_POSITION := Vector2(0.0, -145.0)

const IDLE_ANIMATION_NAME := "idle"

var phase := "idle"
var progress := 0.0
var time_text := "00:00"
var active_item_id := "tomato"
var item_elapsed := 0.0
# Juggle performance state: driven by the work session (dragging the tomato
# onto the fridge person) and by short chest-panel previews.
var session_juggling := false
var juggle_preview_timer := 0.0
var juggling := false
var juggle_motion := 0.0
var juggle_projectile_id := "ball"
var juggle_objects: Array[Sprite2D] = []
var animated_sprite: AnimatedSprite2D
# Rest performance state: a timed preview of the panting animation.
var resting := false
var rest_preview_timer := 0.0


func _ready() -> void:
	z_index = 12
	set_process(true)
	_create_shadow()
	_create_animation()
	queue_redraw()


func _process(delta: float) -> void:
	item_elapsed += delta
	if juggle_preview_timer > 0.0:
		juggle_preview_timer -= delta
		if juggle_preview_timer <= 0.0:
			juggle_preview_timer = 0.0
			_update_juggle_state()
			performance_finished.emit()
	if rest_preview_timer > 0.0:
		rest_preview_timer -= delta
		if rest_preview_timer <= 0.0:
			rest_preview_timer = 0.0
			_update_rest_state()
			performance_finished.emit()
	if juggling:
		juggle_motion += delta
		_update_juggle_motion()
	# Gentle body bob while juggling; slower breathing sway while resting.
	if animated_sprite != null and is_instance_valid(animated_sprite):
		var bob := 0.0
		if juggling:
			bob = sin(item_elapsed * 5.0) * 3.0
		elif resting:
			bob = sin(item_elapsed * 3.0) * 2.0
		animated_sprite.position = SPRITE_BASE_POSITION + Vector2(0.0, bob)
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


## Toggle the pomodoro juggle performance tied to a running work session:
## plays the intro keyframes once (open door -> reveal tomatoes -> take them
## out) and then loops the juggle. While performing, the countdown ring is
## replaced by the animation.
func set_pomodoro_juggle(enabled: bool) -> void:
	if session_juggling == enabled:
		return
	session_juggling = enabled
	_update_juggle_state()


## Short preview performance (e.g. from the chest collection panel): juggle
## for `duration` seconds even outside a session, then return to idle.
func play_juggle_preview(duration: float) -> void:
	if duration <= 0.0:
		return
	# The juggle replaces a running rest performance.
	if rest_preview_timer > 0.0:
		rest_preview_timer = 0.0
		_update_rest_state()
	if juggle_preview_timer <= 0.0:
		juggle_preview_timer = duration
		_update_juggle_state()
	else:
		juggle_preview_timer = maxf(juggle_preview_timer, duration)


## Timed preview of the Gemini-generated exhausted rest animation (bent over,
## hands on knees, heavy panting). Replaces a running juggle performance.
func play_rest_preview(duration: float) -> void:
	if duration <= 0.0:
		return
	if juggle_preview_timer > 0.0:
		juggle_preview_timer = 0.0
		_update_juggle_state()
	if rest_preview_timer <= 0.0:
		rest_preview_timer = duration
		_update_rest_state()
	else:
		rest_preview_timer = maxf(rest_preview_timer, duration)


## Stop any timed performance preview (rest or juggle); used when a new
## pomodoro session starts so the character snaps back to idle.
func stop_performances() -> void:
	juggle_preview_timer = 0.0
	rest_preview_timer = 0.0
	_update_juggle_state()
	_update_rest_state()


## Swap the object being juggled (ball <-> tomato <-> future objects).
## Applies live: flying sprites switch texture immediately, so it can be
## called mid-performance.
func set_juggle_projectile(id: String) -> void:
	var texture: Texture2D = _load_projectile_texture(id)
	if texture == null:
		return
	juggle_projectile_id = id
	for object_sprite: Sprite2D in juggle_objects:
		if object_sprite != null and is_instance_valid(object_sprite):
			object_sprite.texture = texture


## Single source of truth for the visual juggling state.
func _update_juggle_state() -> void:
	var should_juggle := session_juggling or juggle_preview_timer > 0.0
	if juggling == should_juggle:
		return
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if should_juggle and not animated_sprite.sprite_frames.has_animation(INTRO_ANIMATION_NAME):
		return
	if should_juggle and resting:
		resting = false

	juggling = should_juggle
	if juggling:
		juggle_motion = 0.0
	for object_sprite: Sprite2D in juggle_objects:
		if object_sprite != null and is_instance_valid(object_sprite):
			object_sprite.visible = juggling
	_play_current_animation()


## Single source of truth for the visual rest (panting) state.
func _update_rest_state() -> void:
	var should_rest := rest_preview_timer > 0.0
	if resting == should_rest:
		return
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if should_rest and not animated_sprite.sprite_frames.has_animation(REST_ANIMATION_NAME):
		return
	if should_rest and juggling:
		juggling = false
		for object_sprite: Sprite2D in juggle_objects:
			if object_sprite != null and is_instance_valid(object_sprite):
				object_sprite.visible = false

	resting = should_rest
	_play_current_animation()


## Drives the flying objects: classic up-toss juggling — each object rises
## from its landing hand, hovers above the head at its own height, then falls
## back into the same hand. Phases are staggered so objects are always
## distributed between the palms and the air (matching the reference still).
func _update_juggle_motion() -> void:
	var launch_t: float = clamp(juggle_motion / JUGGLE_LAUNCH_TIME, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - launch_t, 3.0)
	var start_point := Vector2(0.0, -160.0)
	for i in juggle_objects.size():
		var object_sprite := juggle_objects[i]
		if object_sprite == null or not is_instance_valid(object_sprite):
			continue
		var flight: Dictionary = JUGGLE_FLIGHTS[i % JUGGLE_FLIGHTS.size()]
		var anchor: Vector2 = flight["hand"]
		var cycle := fposmod(juggle_motion / JUGGLE_CYCLE_TIME + float(flight["phase"]), 1.0)
		var lift := sin(PI * cycle)
		var target: Vector2 = Vector2(
			anchor.x + signf(-anchor.x) * JUGGLE_PEAK_DRIFT * lift,
			anchor.y - float(flight["amp"]) * lift
		)
		object_sprite.position = start_point.lerp(target, eased)
		var object_scale: float = JUGGLE_OBJECT_SCALE * (0.45 + 0.55 * eased)
		object_sprite.scale = Vector2(object_scale, object_scale)
		# Gentle airborne tilt, like the tilted objects in the reference.
		object_sprite.rotation = sin(juggle_motion * 2.2 + float(i) * 1.7) * 0.3
		# The toss happens in a vertical plane in front of the fridge man —
		# no weaving around the body.
		object_sprite.z_index = 2


func _play_current_animation() -> void:
	if resting:
		_set_sprite_scale_for(REST_FRAME_SIZE)
		animated_sprite.animation = REST_ANIMATION_NAME
	elif juggling:
		_set_sprite_scale_for(INTRO_FRAME_SIZE)
		animated_sprite.animation = INTRO_ANIMATION_NAME
	else:
		_set_sprite_scale_for(frame_size)
		animated_sprite.animation = IDLE_ANIMATION_NAME
	animated_sprite.play()


## After the intro finishes, keep looping the juggle until the session ends.
func _on_animated_sprite_finished() -> void:
	if juggling and animated_sprite.animation == INTRO_ANIMATION_NAME \
			and animated_sprite.sprite_frames.has_animation(JUGGLE_ANIMATION_NAME):
		_set_sprite_scale_for(JUGGLE_FRAME_SIZE)
		animated_sprite.animation = JUGGLE_ANIMATION_NAME
		animated_sprite.play()


func _set_sprite_scale_for(source_frame_size: Vector2i) -> void:
	var scale_factor: float = display_height / float(source_frame_size.y)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)


func _draw() -> void:
	# While juggling or resting, the animation replaces the plain countdown ring.
	if phase == "idle" or juggling or resting:
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
	var texture: Texture2D = _load_texture(sprite_sheet_path)
	if texture == null:
		push_warning("Fridge player sprite sheet not found: %s" % sprite_sheet_path)
		return

	var frames := SpriteFrames.new()
	_add_sheet_animation(frames, IDLE_ANIMATION_NAME, texture, frame_count, frame_size, animation_fps, true)
	_add_intro_animation(frames)
	_add_juggle_animation(frames)
	_add_rest_animation(frames)

	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "Sprite"
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = IDLE_ANIMATION_NAME
	animated_sprite.position = SPRITE_BASE_POSITION
	var scale_factor: float = display_height / float(frame_size.y)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)
	animated_sprite.animation_finished.connect(_on_animated_sprite_finished)
	animated_sprite.play()
	add_child(animated_sprite)


## Intro: three full keyframes (open door, reveal tomatoes, take them out),
## played once; the juggle loop takes over via `animation_finished`.
func _add_intro_animation(frames: SpriteFrames) -> void:
	var intro_textures: Array[Texture2D] = []
	for path: String in INTRO_FRAME_PATHS:
		var keyframe: Texture2D = _load_texture(path)
		if keyframe == null:
			push_warning("Pomodoro intro keyframe not found: %s" % path)
			return
		intro_textures.append(keyframe)

	frames.add_animation(INTRO_ANIMATION_NAME)
	frames.set_animation_speed(INTRO_ANIMATION_NAME, INTRO_ANIMATION_FPS)
	frames.set_animation_loop(INTRO_ANIMATION_NAME, false)
	for keyframe: Texture2D in intro_textures:
		frames.add_frame(INTRO_ANIMATION_NAME, keyframe)


## Juggle: a single static pose (arms raised, one tomato in each hand); the
## flying objects are separate code-animated, swappable sprites (see _create_juggle_objects),
## so the character itself can never deform between frames.
func _add_juggle_animation(frames: SpriteFrames) -> void:
	var juggle_texture: Texture2D = _load_texture(JUGGLE_BASE_PATH)
	if juggle_texture == null:
		push_warning("Pomodoro juggle base not found: %s" % JUGGLE_BASE_PATH)
		return
	frames.add_animation(JUGGLE_ANIMATION_NAME)
	frames.set_animation_speed(JUGGLE_ANIMATION_NAME, 1.0)
	frames.set_animation_loop(JUGGLE_ANIMATION_NAME, true)
	frames.add_frame(JUGGLE_ANIMATION_NAME, juggle_texture)
	_create_juggle_objects()


## Rest: the Gemini-generated exhausted-panting atlas (three 512px frames in
## one row). Frames are ping-ponged 1-2-3-2 so the breathing cycle eases back
## down instead of snapping to the first frame.
func _add_rest_animation(frames: SpriteFrames) -> void:
	var rest_texture: Texture2D = _load_texture(REST_ATLAS_PATH)
	if rest_texture == null:
		push_warning("Pomodoro rest atlas not found: %s" % REST_ATLAS_PATH)
		return
	frames.add_animation(REST_ANIMATION_NAME)
	frames.set_animation_speed(REST_ANIMATION_NAME, REST_ANIMATION_FPS)
	frames.set_animation_loop(REST_ANIMATION_NAME, true)
	for frame_index in [0, 1, 2, 1]:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = rest_texture
		atlas_texture.region = Rect2(
			int(frame_index) * REST_FRAME_SIZE.x,
			0,
			REST_FRAME_SIZE.x,
			REST_FRAME_SIZE.y
		)
		frames.add_frame(REST_ANIMATION_NAME, atlas_texture)


## Creates the swappable flying objects using the currently selected
## projectile texture (see set_juggle_projectile).
func _create_juggle_objects() -> void:
	var object_texture: Texture2D = _load_projectile_texture(juggle_projectile_id)
	if object_texture == null:
		push_warning("Juggle projectile texture not found for id: %s" % juggle_projectile_id)
		return
	for i in JUGGLE_FLIGHTS.size():
		var object_sprite := Sprite2D.new()
		object_sprite.name = "JuggleObject%d" % i
		object_sprite.texture = object_texture
		object_sprite.scale = Vector2(JUGGLE_OBJECT_SCALE, JUGGLE_OBJECT_SCALE)
		object_sprite.visible = false
		object_sprite.z_index = 2
		add_child(object_sprite)
		juggle_objects.append(object_sprite)


func _load_projectile_texture(id: String) -> Texture2D:
	for entry: Dictionary in JUGGLE_PROJECTILES:
		if str(entry.get("id", "")) == id:
			return _load_texture(str(entry.get("path", "")))
	return null


## Robust texture loader: freshly generated PNGs may not have been imported
## by the editor yet, so fall back to reading the raw file from disk.
func _load_texture(texture_path: String) -> Texture2D:
	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D

	var file_path := texture_path
	if texture_path.begins_with("res://") or texture_path.begins_with("user://"):
		file_path = ProjectSettings.globalize_path(texture_path)

	var image := Image.new()
	var error := image.load(file_path)
	if error == OK and not image.is_empty():
		return ImageTexture.create_from_image(image)

	return null


func _add_sheet_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, count: int, sheet_frame_size: Vector2i, fps: float, loops: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in range(count):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(
			frame_index * sheet_frame_size.x,
			0,
			sheet_frame_size.x,
			sheet_frame_size.y
		)
		frames.add_frame(animation_name, atlas_texture)
