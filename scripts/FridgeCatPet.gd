class_name FridgeCatPet
extends Area2D

signal clicked
signal close_requested

## 奶牛猫: the cat is a black-and-white cow cat now - a white coat with large irregular solid
## black patches, a black tail tip and white paws - and its old fridge-box body is long gone.
## Every art is generated from ONE cow-cat base and normalised onto one frame geometry (the feet
## on the same ground row, nothing touching a frame's edges), so no frame can show a neighbour's
## tail.
##
## The plain standing idle: six 256px frames of a relaxed breathing loop - the cat
## breathes, blinks and glances about, staying on the same ground row.
const IDLE_ATLAS_PATH := "res://assets/generated/cat_idle_cow.png"
const IDLE_FRAME_SIZE := 256
const IDLE_ANIMATION_FPS := 2.0
## 张嘴: the cat's "bag" is its own mouth - these four frames drop the jaw wide open and
## the last one is the pose it holds while the 道具栏 (mouth inventory) is open.
const OPEN_TEXTURE_PATHS := [
	"res://assets/generated/paper_cat_open_cow_01.png",
	"res://assets/generated/paper_cat_open_cow_02.png",
	"res://assets/generated/paper_cat_open_cow_03.png",
	"res://assets/generated/paper_cat_open_cow_04.png",
]
const OPEN_FRAME_TIME := 0.08
const DISPLAY_HEIGHT := 148.0
const DRAG_CLICK_THRESHOLD := 10.0

## Idle ("待机") animations the cat plays by itself while nothing else is going
## on. Each atlas is a row of 256px frames generated from the cat's idle art.
## "run" is the travelling cycle (the trot back home). 小猫绕圈跑 has the LEVEL move the
## cat around the fridge man while it plays 玩球's animation, without the toy mouse - see
## FridgeLevel._start_fridge_cat_orbit.
const IDLE_ACTION_FRAME_SIZE := 256
const IDLE_ACTIONS := {
	# 站立歇息 IS the plain standing idle (no separate atlas): the cat stands
	# there breathing, exactly as it does when nothing is going on.
	"rest_stand": {"path": "", "fps": 4.0},
	# 打瞌睡 is its own action, NOT the default stance: the cat has to be asked to
	# nod off (the skeleton stand's gallery). Both poses come from _update_doze.
	"doze": {"path": "", "fps": 1.0},
	# 冰箱身体: the cat is a walking box, so it plays these slowly - a quick cycle
	# reads as a nimble animal, which is exactly what it is not.
	"play_ball": {"path": "res://assets/generated/cat_play_ball_cow.png", "fps": 7.0},
	# 四条腿: the running art is a SIDE-view fridge cat on all four legs (it used to be the
	# front-facing sitting pose bobbing up and down, which read as a standing cat).
	# A side-view cat fills its frame less than a sitting one, so `scale` makes it
	# stand exactly as tall as the idle - without it the cat visibly shrinks while
	# it runs. A heavy 8fps waddle, not a sprint.
	"run": {"path": "res://assets/generated/cat_run_cow.png", "fps": 8.0, "scale": 1.18},
}

## 玩球: the toy the cat bats around. It is NOT baked into the play atlas any more -
## it is its own sprite, so swapping the toy (a mouse today, a ball or anything else
## later) is one PNG or one call to set_play_toy_texture(). The art must stand on the
## BOTTOM row of its canvas, like every other pose in this game; any empty margin
## around the subject is fine and is what lets the toy tilt without its corners being
## clipped.
const PLAY_TOY_ACTION_ID := "play_ball"
const PLAY_TOY_PATH := "res://assets/generated/cat_play_toy.png"
## How tall the toy is drawn on screen, in the same units as DISPLAY_HEIGHT.
const PLAY_TOY_DISPLAY_HEIGHT := 32.0
## 玩球's own bounce: one sweep out and back, and two hops along the floor per sweep.
const PLAY_TOY_TRAVEL_TIME := 1.3
const PLAY_TOY_TRAVEL := 30.0
const PLAY_TOY_OFFSET_X := 14.0
const PLAY_TOY_HOP := 20.0
const PLAY_TOY_TILT := 15.0
## The cat's own ground line in this node's space. A Sprite2D is positioned by its
## CENTRE, and the art's ground row is its last row (255 of 256), so the feet sit
## (255 - 128) art rows below the sprite's position, scaled by DISPLAY_HEIGHT / 256.
const PLAY_TOY_GROUND_Y := -20.0 + (255.0 - 128.0) * (DISPLAY_HEIGHT / 256.0)

# 打瞌睡 (doze): an idle ACTION, not the default stance. The cat stands there for
# a while, nods off with sleep bubbles rising above its head, the bubble pops and
# it wakes with a start before settling back down and starting over. Both poses are
# single 256px frames laid out like the idle art (the subject filling the frame, paws
# on the same ground line) and their outlines match it, so the doze neither changes
# the cat's size nor looks like a different art style.
const DOZE_ACTION_ID := "doze"
# 打瞌睡 follows the drowsiness progression in three poses: the plain idle (eyes
# open) while standing, this half-lidded pose while nodding off, and the
# fully-asleep pose (both eyes shut) once the cat is out.
const DOZE_TEXTURE_PATH := "res://assets/generated/cat_doze_cow.png"
const DOZE_SLEEP_TEXTURE_PATH := "res://assets/generated/cat_doze_closed_cow.png"
const STARTLE_TEXTURE_PATH := "res://assets/generated/cat_startle_cow.png"
# The sleep bubble floats above its head (local offset); the body sags this far
# while it is asleep (see FridgeDozeCycle.get_body_offset).
const DOZE_BUBBLE_OFFSET := Vector2(44.0, -118.0)
const DOZE_BUBBLE_SCALE := 0.34
const DOZE_BODY_SINK := 5.0
## How long the cat stands before nodding off when 打瞌睡 is REQUESTED by name (the
## skeleton gallery, or the idle rotation picking it); a requested doze must start
## at once, or the click looks like it did nothing.
const DOZE_REQUESTED_STAND_TIME := 0.25
# FridgeDozeCycle's own ambient stand time, used while the doze is the plain stance.
const DOZE_STAND_TIME := 6.6

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
# Idle action state (see play_idle_action): "" while the cat is doing nothing
# but standing there.
var idle_action_id := ""
var idle_action_timer := 0.0
var idle_action_clock := 0.0
var idle_action_frames: Dictionary = {}
# Extra y offset applied while an idle action is drawn at a different size than
# the idle itself, so the cat's feet stay on the ground line.
var idle_action_drop := 0.0
# 打瞌睡 requested BY NAME (see DOZE_REQUESTED_STAND_TIME).
var doze: FridgeDozeCycle
var doze_texture: Texture2D
var doze_sleep_texture: Texture2D
var startle_texture: Texture2D
# How far the body sags / jolts this frame while dozing (see _update_doze).
var doze_body_offset := Vector2.ZERO
# 玩球's toy mouse (see PLAY_TOY_PATH): its own sprite, so it can be swapped for a
# different object without re-cutting the play atlas.
var play_toy: Sprite2D
# 小猫绕圈跑 (the orbit) plays 玩球's animation while the LEVEL moves the cat around the
# fridge man, but without the mouse - the cat is travelling, not batting anything.
var play_toy_hidden := false
# 小猫绕圈跑 also asks for a busier clip than the plain 玩球 ("动作频率要高，像是一蹦一跳的"):
# the LEVEL raises this while it drives the cat, and any fresh idle action resets it.
var idle_action_fps_scale := 1.0
var play_toy_texture_path := PLAY_TOY_PATH
# Scale that draws the toy's SUBJECT at PLAY_TOY_DISPLAY_HEIGHT, and how far the
# subject's bottom row sits below the sprite's centre once that scale is applied -
# measured from the art so a canvas with an empty margin still stands on the ground.
var play_toy_art_scale := 1.0
var play_toy_bottom_offset := 0.0


func _ready() -> void:
	z_index = 14
	input_pickable = true
	set_process(true)
	set_process_input(true)
	_create_sprite()
	_create_hit_area()
	_create_doze_cycle()
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
	if idle_action_id != "" and not is_opening:
		_update_idle_action(delta)
	# 打瞌睡: the plain idle's own bit of business, always evaluated last so the
	# default stance wins whenever nothing else owns the cat.
	_update_doze(delta)
	if sprite != null:
		# The breathing now lives in the idle art itself, frame by frame, so the
		# sprite position stays put and the paws never leave the ground line.
		_update_idle_animation()
		sprite.position = Vector2(doze_body_offset.x, -20.0 + idle_action_drop + doze_body_offset.y)
		_update_play_toy()
	else:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() + drag_offset
		# Track how far the cursor strayed from the press point (position based).
		# Accumulating `relative` lengths misfires on warped/synthetic motion
		# events that carry large deltas while the cursor stays put.
		drag_distance = maxf(drag_distance, drag_start_mouse.distance_to(get_viewport().get_mouse_position()))
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			is_dragging = false
			input_pickable = true
			get_viewport().set_input_as_handled()
			if drag_start_mouse.distance_to(get_viewport().get_mouse_position()) <= DRAG_CLICK_THRESHOLD and drag_distance <= DRAG_CLICK_THRESHOLD:
				_toggle_bag_from_click()


func _create_hit_area() -> void:
	var shape := CollisionShape2D.new()
	var shape_rect := RectangleShape2D.new()
	shape_rect.size = Vector2(116.0, 128.0)
	shape.shape = shape_rect
	shape.position = Vector2(0.0, -18.0)
	add_child(shape)


## Steps the plain standing idle through its frames while nothing else owns the
## cat. Driven here rather than by an AnimatedSprite2D because the cat's sprite is
## swapped as a whole for every action it performs.
func _update_idle_animation() -> void:
	if idle_action_id != "" or is_opening or is_bag_open or is_dragging:
		return
	if doze_body_offset != Vector2.ZERO:
		return
	var frames: Array = _get_idle_action_frames("rest_stand")
	if frames.size() <= 1 or sprite == null:
		return
	var frame_index: int = int(floor(time * IDLE_ANIMATION_FPS)) % frames.size()
	if sprite.texture != frames[frame_index]:
		sprite.texture = frames[frame_index]
		_apply_sprite_scale(frames[frame_index])


func _create_sprite() -> void:
	var idle_frames: Array = _get_idle_action_frames("rest_stand")
	if not idle_frames.is_empty():
		idle_texture = idle_frames[0] as Texture2D
	doze_texture = _load_texture(DOZE_TEXTURE_PATH)
	doze_sleep_texture = _load_texture(DOZE_SLEEP_TEXTURE_PATH)
	startle_texture = _load_texture(STARTLE_TEXTURE_PATH)
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
	_create_play_toy()


## 玩球: builds the toy sprite (see PLAY_TOY_PATH). Kept separate from the atlas so
## the toy can be replaced by any other object later.
func _create_play_toy() -> void:
	var texture := _load_texture(play_toy_texture_path)
	if texture == null:
		return
	var canvas_height := float(texture.get_height())
	var art_height := canvas_height
	var bottom_row := canvas_height - 1.0
	# Measure the subject inside its canvas: the art may carry an empty margin (which
	# is what lets it tilt), and the toy must stand on the ground by its SUBJECT.
	var image := _load_image(play_toy_texture_path)
	if image != null:
		var used := image.get_used_rect()
		if used.size.y > 0:
			art_height = float(used.size.y)
			bottom_row = float(used.position.y + used.size.y - 1)
	play_toy_art_scale = PLAY_TOY_DISPLAY_HEIGHT / maxf(art_height, 1.0)
	play_toy_bottom_offset = (bottom_row - canvas_height * 0.5) * play_toy_art_scale
	play_toy = Sprite2D.new()
	play_toy.name = "PlayToy"
	play_toy.texture = texture
	play_toy.scale = Vector2(play_toy_art_scale, play_toy_art_scale)
	play_toy.visible = false
	add_child(play_toy)


## Lets a later re-skin point 玩球's toy at different art - e.g. a ball instead of the
## toy mouse. Safe to call before or after the cat is in the tree.
func set_play_toy_texture(path: String) -> void:
	if path.is_empty():
		return
	play_toy_texture_path = path
	if not is_inside_tree():
		return
	if play_toy != null and is_instance_valid(play_toy):
		play_toy.queue_free()
	play_toy = null
	_create_play_toy()


## Hides 玩球's toy while the LEVEL is driving the cat: 小猫绕圈跑 plays the play-ball
## animation as it circles the fridge man, but the mouse stays out of it. Any fresh idle
## action clears it again (see play_idle_action), so it can never go stale.
## (The parameter is not called `hidden`: that shadows CanvasItem's own `hidden` signal.)
func set_play_toy_hidden(toy_hidden: bool) -> void:
	play_toy_hidden = toy_hidden


## Plays the idle action's own cycle faster (小猫绕圈跑 raises it so the cat bats busily as
## it bounds along). Any fresh idle action resets it to 1.0.
## (The parameter is not called `scale`: that shadows Node2D's own `scale` property.)
func set_idle_action_fps_scale(fps_multiplier: float) -> void:
	idle_action_fps_scale = maxf(fps_multiplier, 0.1)


## (吐毛球's item sprite was removed with the 吐毛球 action.)

## 吐毛球's two helpers were removed with the 吐毛球 action.


## Drives the toy while 玩球 runs: it is batted out and back along the floor with two
## hops per sweep, tilting into each hop, so the action reads as play and not as the
## cat sitting still with a mouse parked beside it.
func _update_play_toy() -> void:
	if play_toy == null or not is_instance_valid(play_toy):
		return
	var active := idle_action_id == PLAY_TOY_ACTION_ID and not play_toy_hidden \
			and not is_opening and not is_bag_open and not is_dragging
	play_toy.visible = active
	if not active:
		return
	var phase: float = idle_action_clock / PLAY_TOY_TRAVEL_TIME * TAU
	var x: float = PLAY_TOY_OFFSET_X + sin(phase) * PLAY_TOY_TRAVEL
	var hop: float = absf(sin(phase * 2.0)) * PLAY_TOY_HOP
	play_toy.position = Vector2(x, PLAY_TOY_GROUND_Y - hop - play_toy_bottom_offset)
	play_toy.rotation_degrees = sin(phase) * PLAY_TOY_TILT


## Builds the shared doze cycle (see FridgeDozeCycle). It owns the timing and the
## sleep bubble / pop effect; this script owns the poses.
func _create_doze_cycle() -> void:
	doze = FridgeDozeCycle.new()
	doze.name = "DozeCycle"
	doze.configure(DOZE_BUBBLE_OFFSET, DOZE_BUBBLE_SCALE, DOZE_BODY_SINK)
	doze.stand_time = DOZE_STAND_TIME
	add_child(doze)


## True only while 打瞌睡 owns the cat. The doze is an idle action now, not the
## default stance, so the plain relaxed idle never nods off on its own - the cat
## has to be asked (the skeleton stand's gallery). An open/opening mouth, being
## dragged or any other action also pauses it, so two animations never fight over
## the sprite.
func _is_doze_action() -> bool:
	if is_opening or is_bag_open or is_dragging:
		return false
	return idle_action_id == DOZE_ACTION_ID


## 打瞌睡: drives the cat's default standing idle. It stands there for a while,
## nods off with sleep bubbles rising above its head, the bubble swells and pops
## and it wakes with a start before settling back down and starting over.
func _update_doze(delta: float) -> void:
	if doze == null or not is_instance_valid(doze):
		return
	doze.set_enabled(_is_doze_action())
	var doze_phase: String = doze.tick(delta)
	if not doze.is_enabled():
		doze_body_offset = Vector2.ZERO
		return
	# 打盹三段: 站着 = eyes open (the idle), 点头 = half-lidded, 熟睡 = both eyes shut.
	var desired: Texture2D = idle_texture
	if doze_phase == FridgeDozeCycle.PHASE_NOD:
		desired = doze_texture
	elif doze_phase == FridgeDozeCycle.PHASE_DOZE:
		desired = doze_sleep_texture if doze_sleep_texture != null else doze_texture
	elif doze_phase == FridgeDozeCycle.PHASE_POP or doze_phase == FridgeDozeCycle.PHASE_STARTLE:
		desired = startle_texture
	if desired != null and sprite != null and sprite.texture != desired:
		sprite.texture = desired
		_apply_sprite_scale(desired)
	doze_body_offset = doze.get_body_offset()


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
	stop_idle_action()
	is_bag_open = open
	is_opening = false
	opening_elapsed = 0.0
	opening_frame_index = 0
	visible = true
	# The cat stays pickable while its mouth is open so the player can drag it
	# around, with the mouth inventory panel following along.
	input_pickable = true
	if sprite != null:
		if is_bag_open and not open_textures.is_empty():
			sprite.texture = open_textures[open_textures.size() - 1]
		else:
			sprite.texture = idle_texture
	queue_redraw()


## A click on the cat toggles the bag: the first one opens it, the next closes it.
func _toggle_bag_from_click() -> void:
	if is_opening:
		return
	stop_idle_action()
	if is_bag_open:
		close_requested.emit()
		return
	if open_textures.is_empty():
		set_bag_open(true)
		clicked.emit()
		return
	is_opening = true
	input_pickable = true
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


## Plays one of the cat's idle ("待机") animations for `duration` seconds, then
## returns to the plain idle pose. Used by the level's idle rotation and by the
## skeleton stand's action gallery. Refused while the mouth bag is open (the bag
## frames own the sprite then).
func play_idle_action(action_id: String, duration: float) -> void:
	if not IDLE_ACTIONS.has(action_id) or duration <= 0.0:
		return
	if is_opening or is_bag_open:
		return
	if action_id != "run":
		_face_right()
	_start_doze_if_requested(action_id)
	# A fresh action owns the toy and the normal playback speed again (see
	# set_play_toy_hidden / set_idle_action_fps_scale).
	play_toy_hidden = false
	idle_action_fps_scale = 1.0
	idle_action_id = action_id
	idle_action_timer = duration
	idle_action_clock = 0.0
	_show_idle_action_frame(0)


## 打瞌睡 asked for BY NAME has to nod off promptly: the long stand-up only made
## sense while the doze was the ambient stance, and as an explicitly requested
## action it reads as "the click did nothing" (6.6 s of it, here).
func _start_doze_if_requested(action_id: String) -> void:
	if action_id != DOZE_ACTION_ID:
		return
	if doze == null or not is_instance_valid(doze):
		return
	doze.stand_time = DOZE_REQUESTED_STAND_TIME
	doze.reset()


func stop_idle_action() -> void:
	# Every other pose faces the camera, so drop the running mirror on the way out.
	_face_right()
	if idle_action_id == "":
		return
	idle_action_id = ""
	idle_action_timer = 0.0
	idle_action_clock = 0.0
	if sprite != null and idle_texture != null:
		sprite.texture = idle_texture
		_apply_sprite_scale(idle_texture)


## 面朝方向: ONLY the side-view arts are mirrored while the cat travels left. The
## four-legged run is drawn facing RIGHT - it is the one side view; every other atlas
## (the idle and 玩球) are drawn facing the CAMERA, so
## mirroring it does not show the cat turning: it just swaps its two ears over (the left
## one is black, the right one cream, so it reads as an ear changing colour). Those stay
## exactly as drawn. The level calls this every frame while it drives the cat around the
## fridge man - see FridgeLevel._update_fridge_cat_motion.
const SIDE_VIEW_ACTIONS := ["run"]


func set_facing(direction: float) -> void:
	if sprite == null or is_zero_approx(direction):
		return
	if not SIDE_VIEW_ACTIONS.has(idle_action_id):
		_face_right()
		return
	sprite.flip_h = direction < 0.0


func _face_right() -> void:
	if sprite != null:
		sprite.flip_h = false


func is_idle_action_active() -> bool:
	return idle_action_id != ""


func _update_idle_action(delta: float) -> void:
	idle_action_timer -= delta
	if idle_action_timer <= 0.0:
		stop_idle_action()
		return
	var frames: Array = _get_idle_action_frames(idle_action_id)
	if frames.is_empty():
		return
	idle_action_clock += delta
	var fps: float = float(IDLE_ACTIONS[idle_action_id]["fps"]) * idle_action_fps_scale
	_show_idle_action_frame(int(idle_action_clock * fps))


func _show_idle_action_frame(index: int) -> void:
	var frames: Array = _get_idle_action_frames(idle_action_id)
	if frames.is_empty() or sprite == null:
		return
	var frame: Texture2D = frames[index % frames.size()]
	sprite.texture = frame
	_apply_sprite_scale(frame)


func _apply_sprite_scale(texture: Texture2D) -> void:
	var texture_height := float(texture.get_height())
	if texture_height <= 0.0:
		return
	var size_multiplier := 1.0
	if idle_action_id != "" and IDLE_ACTIONS.has(idle_action_id):
		size_multiplier = float(IDLE_ACTIONS[idle_action_id].get("scale", 1.0))
	var scale_factor := DISPLAY_HEIGHT / texture_height * size_multiplier
	sprite.scale = Vector2(scale_factor, scale_factor)
	# Scaling happens about the sprite's centre, so slide it back down by half of
	# what it just lost to keep the cat's feet on the same ground line.
	idle_action_drop = DISPLAY_HEIGHT * (1.0 - size_multiplier) * 0.5


## The idle and idle-action atlases are rows of 256px frames; slice them into separate
## textures once and cache them. Loaded through Image so freshly generated art works
## even before the editor imports it.
func _get_idle_action_frames(action_id: String) -> Array:
	if idle_action_frames.has(action_id):
		return idle_action_frames[action_id]
	# 站立歇息 IS the plain standing idle: slice its own loop (IDLE_FRAME_SIZE frames).
	if action_id == "rest_stand":
		var idle_frames: Array = []
		var idle_atlas: Image = _load_image(IDLE_ATLAS_PATH)
		if idle_atlas != null:
			var idle_count: int = maxi(int(float(idle_atlas.get_width()) / float(IDLE_FRAME_SIZE)), 1)
			for i in range(idle_count):
				var slice: Image = idle_atlas.get_region(Rect2i(i * IDLE_FRAME_SIZE, 0, IDLE_FRAME_SIZE, IDLE_FRAME_SIZE))
				if slice.get_format() != Image.FORMAT_RGBA8:
					slice.convert(Image.FORMAT_RGBA8)
				idle_frames.append(ImageTexture.create_from_image(slice))
		idle_action_frames[action_id] = idle_frames
		return idle_frames
	var frames: Array = []
	# An entry with no atlas of its own (打瞌睡 is driven by FridgeDozeCycle) has
	# nothing to slice, and loading an empty path is only noise in the log.
	if IDLE_ACTIONS.has(action_id) and not str(IDLE_ACTIONS[action_id]["path"]).is_empty():
		var image: Image = _load_image(str(IDLE_ACTIONS[action_id]["path"]))
		if image != null:
			var count: int = maxi(int(float(image.get_width()) / float(IDLE_ACTION_FRAME_SIZE)), 1)
			for i in range(count):
				var slice: Image = image.get_region(Rect2i(i * IDLE_ACTION_FRAME_SIZE, 0, IDLE_ACTION_FRAME_SIZE, IDLE_ACTION_FRAME_SIZE))
				frames.append(ImageTexture.create_from_image(slice))
	idle_action_frames[action_id] = frames
	return frames


func _load_image(texture_path: String) -> Image:
	var file_path := texture_path
	if texture_path.begins_with("res://") or texture_path.begins_with("user://"):
		file_path = ProjectSettings.globalize_path(texture_path)
	var image := Image.new()
	if image.load(file_path) == OK and not image.is_empty():
		return image
	return null


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
