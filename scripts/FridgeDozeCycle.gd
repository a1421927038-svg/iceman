class_name FridgeDozeCycle
extends Node2D

## The default standing idle ("站立待机") for both characters. Left alone the
## character simply stands there for a while, then drowsiness wins: he nods off,
## sleep bubbles rise out of him, the bubble swells and pops, and he snaps awake
## with a start before settling back down and starting over.
##
## The cycle owns only the TIMING and the bubble/pop effects. The character owns
## its own poses and reads `phase` every frame (see tick), so one cycle drives
## both the fridge man and the cat.
##
##   stand  ->  nod  ->  doze  ->  pop  ->  startle  ->  stand ...

const PHASE_STAND := "stand"
const PHASE_NOD := "nod"
const PHASE_DOZE := "doze"
const PHASE_POP := "pop"
const PHASE_STARTLE := "startle"

## How long the character just stands there before drowsiness wins.
const STAND_TIME := 3.2
## The drowsy sag into sleep, with the first bubble surfacing.
const NOD_TIME := 0.9
## Deep sleep while the bubbles drift up.
const DOZE_TIME := 2.9
## The bubble swells up and bursts.
const POP_TIME := 0.45
## Jolted awake, then trembling back down to a calm stance.
const STARTLE_TIME := 1.3
## One full loop, stand to stand.
const TOTAL_TIME := STAND_TIME + NOD_TIME + DOZE_TIME + POP_TIME + STARTLE_TIME

const BUBBLE_TEXTURE_PATH := "res://assets/generated/paper_sleep_bubble.png"
const POP_TEXTURE_PATH := "res://assets/generated/paper_sleep_pop.png"

# Bubble travel relative to the offset handed to configure().
const BUBBLE_RISE := Vector2(12.0, -34.0)
const BUBBLE_SMALL_OFFSET := Vector2(24.0, 14.0)
const BUBBLE_SMALL_SCALE := 0.52
const BUBBLE_SMALL_DELAY := 0.5
const BUBBLE_PULSE_SPEED := 2.1
const BUBBLE_PULSE_AMOUNT := 0.07
## The bubble puffs up by this fraction right before it bursts.
const BUBBLE_SWELL := 0.45
const POP_SPRITE_SCALE := 1.45

var phase := PHASE_STAND
# Time inside the whole cycle, used for the slow sleepy wobble.
var clock := 0.0
var phase_clock := 0.0

var enabled := true

## How long this character stands there each cycle before drowsiness wins. The
## cat is given a longer stand so the two of them never nod off in lockstep.
## Set before adding the cycle to the tree.
var stand_time := STAND_TIME

var _bubble_offset := Vector2.ZERO
var _bubble_scale := 0.5
var _body_sink := 7.0
var _phase_duration := STAND_TIME
var _bubble: Sprite2D
var _bubble_small: Sprite2D
var _pop: Sprite2D


func _ready() -> void:
	z_index = 3
	_bubble = _make_effect("SleepBubble", BUBBLE_TEXTURE_PATH, 1)
	_bubble_small = _make_effect("SleepBubbleSmall", BUBBLE_TEXTURE_PATH, 1)
	_pop = _make_effect("SleepPop", POP_TEXTURE_PATH, 2)
	reset()


## Places the effects for this character: `bubble_offset` is where the sleep
## bubble sits above its head (in the character's local space), `bubble_scale`
## sizes the bubble art and `body_sink` is how far the body sags while it sleeps.
## Call before adding the cycle to the tree.
func configure(bubble_offset: Vector2, bubble_scale: float, body_sink: float) -> void:
	_bubble_offset = bubble_offset
	_bubble_scale = bubble_scale
	_body_sink = body_sink


## Advances the cycle by `delta` and returns the phase the character should hold.
func tick(delta: float) -> String:
	if not enabled:
		return PHASE_STAND
	clock += delta
	phase_clock += delta
	if phase_clock >= _phase_duration:
		phase_clock -= _phase_duration
		_advance()
	_update_effects()
	return phase


## Parks the cycle back at the start (standing, no bubbles).
func reset() -> void:
	phase = PHASE_STAND
	clock = 0.0
	phase_clock = 0.0
	_phase_duration = stand_time
	_update_effects()


## Anything that owns the character (a running session, a preview, an open mouth,
## being dragged) turns this off. That parks the cycle, so the next idle always
## starts from a calm stand instead of resuming mid-sneeze.
func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		reset()


func is_enabled() -> bool:
	return enabled


## Where the body should sit this frame, as an offset on top of the idle position:
## a drowsy sag while nodding off, a slow sleeping breath, a jolt upwards as the
## bubble pops and a decaying tremble while he comes to.
func get_body_offset() -> Vector2:
	match phase:
		PHASE_NOD:
			var t: float = clampf(phase_clock / NOD_TIME, 0.0, 1.0)
			return Vector2(0.0, _body_sink * (1.0 - pow(1.0 - t, 2.0)))
		PHASE_DOZE:
			return Vector2(sin(clock * 1.6) * 1.2, _body_sink + sin(clock * 2.3) * 1.8)
		PHASE_POP:
			return Vector2(0.0, -_body_sink * 0.35)
		PHASE_STARTLE:
			var damp: float = 1.0 - clampf(phase_clock / STARTLE_TIME, 0.0, 1.0)
			var amp: float = _body_sink * 0.7 * damp * damp
			return Vector2(sin(phase_clock * 46.0) * amp, cos(phase_clock * 39.0) * amp * 0.6)
		_:
			return Vector2.ZERO


func _advance() -> void:
	match phase:
		PHASE_STAND:
			phase = PHASE_NOD
			_phase_duration = NOD_TIME
		PHASE_NOD:
			phase = PHASE_DOZE
			_phase_duration = DOZE_TIME
		PHASE_DOZE:
			phase = PHASE_POP
			_phase_duration = POP_TIME
		PHASE_POP:
			phase = PHASE_STARTLE
			_phase_duration = STARTLE_TIME
		_:
			phase = PHASE_STAND
			_phase_duration = stand_time


func _update_effects() -> void:
	if _bubble == null:
		return
	var sleeping := phase == PHASE_NOD or phase == PHASE_DOZE or phase == PHASE_POP
	_bubble.visible = sleeping
	_bubble_small.visible = sleeping and phase != PHASE_POP and phase_clock > BUBBLE_SMALL_DELAY

	var rise := 0.0
	var appear := 1.0
	var swell := 1.0
	if phase == PHASE_NOD:
		var t: float = clampf(phase_clock / NOD_TIME, 0.0, 1.0)
		appear = t
		rise = t * 0.25
	elif phase == PHASE_DOZE:
		var t: float = clampf(phase_clock / DOZE_TIME, 0.0, 1.0)
		rise = 0.25 + t * 0.75
	elif phase == PHASE_POP:
		var t: float = clampf(phase_clock / POP_TIME, 0.0, 1.0)
		rise = 1.15
		swell = 1.0 + BUBBLE_SWELL * sin(t * PI)

	if sleeping:
		var pulse: float = 1.0 + sin(clock * BUBBLE_PULSE_SPEED) * BUBBLE_PULSE_AMOUNT
		var main_position: Vector2 = _bubble_offset + BUBBLE_RISE * rise
		_bubble.position = main_position
		_bubble.scale = Vector2.ONE * _bubble_scale * pulse * swell * lerpf(0.35, 1.0, appear)
		_bubble.modulate = Color(1.0, 1.0, 1.0, clampf(appear * 1.8, 0.0, 1.0))
		var small_appear: float = clampf((phase_clock - BUBBLE_SMALL_DELAY) / 0.5, 0.0, 1.0)
		if phase == PHASE_POP:
			small_appear = 0.0
		_bubble_small.position = main_position + BUBBLE_SMALL_OFFSET
		_bubble_small.scale = Vector2.ONE * _bubble_scale * BUBBLE_SMALL_SCALE * pulse
		_bubble_small.modulate = Color(1.0, 1.0, 1.0, small_appear)

	if _pop == null:
		return
	if phase == PHASE_POP:
		var t: float = clampf(phase_clock / POP_TIME, 0.0, 1.0)
		_pop.visible = true
		_pop.position = _bubble_offset + BUBBLE_RISE * 1.15 + Vector2(0.0, -6.0)
		_pop.scale = Vector2.ONE * _bubble_scale * POP_SPRITE_SCALE * lerpf(0.45, 1.15, t)
		_pop.modulate = Color(1.0, 1.0, 1.0, 1.0 - t)
	else:
		_pop.visible = false


func _make_effect(sprite_name: String, texture_path: String, layer: int) -> Sprite2D:
	var effect := Sprite2D.new()
	effect.name = sprite_name
	effect.texture = _load_texture(texture_path)
	effect.z_index = layer
	effect.visible = false
	add_child(effect)
	return effect


## The PNG on disk wins over the editor's import cache, so freshly generated art
## shows up immediately.
func _load_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	var file_path := texture_path
	if texture_path.begins_with("res://") or texture_path.begins_with("user://"):
		file_path = ProjectSettings.globalize_path(texture_path)
	if FileAccess.file_exists(file_path):
		var image := Image.new()
		if image.load(file_path) == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D
	return null