class_name FridgeChest
extends Area2D

## Treasure chest prop on the left side of the level. Clicking it toggles it
## open (art swap + bouncy pop) and emits `toggled` so the level can show or
## hide the collection panel with the fridge man's skins and animations.

signal toggled(is_open: bool)

const CLOSED_TEXTURE_PATH := "res://assets/generated/paper_fridge_chest_closed.png"
const OPEN_TEXTURE_PATH := "res://assets/generated/paper_fridge_chest_open_v2.png"
const DRAG_CLICK_THRESHOLD := 10.0

## Display height of the chest art, in pixels.
@export var display_height := 176.0

var is_open := false
var is_dragging := false
var drag_start_position := Vector2.ZERO
var sprite: Sprite2D
var closed_texture: Texture2D
var open_texture: Texture2D
var base_sprite_scale := Vector2.ONE


func _ready() -> void:
	z_index = 13
	input_pickable = true
	set_process_input(true)
	_load_textures()
	_create_sprite()
	_create_hit_area()
	input_event.connect(_on_input_event)


func set_open(open: bool, animate: bool = true) -> void:
	is_open = open
	if sprite != null:
		if is_open and open_texture != null:
			sprite.texture = open_texture
		elif closed_texture != null:
			sprite.texture = closed_texture
	if animate:
		_play_bounce()


func _play_bounce() -> void:
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "scale", base_sprite_scale * Vector2(0.86, 0.9), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_sprite_scale, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			# Start a potential drag; click (toggle) is decided on release.
			is_dragging = true
			drag_start_position = global_position
			get_viewport().set_input_as_handled()


## While a press is held, the chest follows the pointer (via `relative`,
## which stays accurate for real and synthetic pointer events alike). On
## release, a chest that barely moved counts as a click and toggles.
func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventMouseMotion:
		global_position += (event as InputEventMouseMotion).relative
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			is_dragging = false
			get_viewport().set_input_as_handled()
			# Click-vs-drag is judged by the chest's own displacement, so it
			# never misfires even when pointer position data lags.
			if drag_start_position.distance_to(global_position) <= DRAG_CLICK_THRESHOLD:
				set_open(not is_open)
				toggled.emit(is_open)


func _create_hit_area() -> void:
	var shape := CollisionShape2D.new()
	var shape_rect := RectangleShape2D.new()
	shape_rect.size = Vector2(150.0, 150.0)
	shape.shape = shape_rect
	shape.position = Vector2(0.0, -40.0)
	add_child(shape)


func _create_sprite() -> void:
	var texture: Texture2D = closed_texture if closed_texture != null else open_texture
	if texture == null:
		push_warning("Fridge chest textures not found")
		return

	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = Vector2(0.0, -42.0)
	var texture_height := float(texture.get_height())
	if texture_height > 0.0:
		var scale_factor := display_height / texture_height
		base_sprite_scale = Vector2(scale_factor, scale_factor)
		sprite.scale = base_sprite_scale
	add_child(sprite)


func _load_textures() -> void:
	closed_texture = _load_texture(CLOSED_TEXTURE_PATH)
	open_texture = _load_texture(OPEN_TEXTURE_PATH)


## Robust texture loader: freshly generated PNGs may not have been imported by
## the editor yet, so fall back to reading the raw file from disk.
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
