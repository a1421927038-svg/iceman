class_name FridgeCatBell
extends Control

## Hotspot sitting exactly on the bell the cat wears on its collar.
##
## The bell is painted into the cat's own 256 px frame and stays GOLD. Nothing is drawn while idle, so the
## painted bell shows through untouched; on hover this shows the same bell re-cut as a RED paper token
## (res://assets/generated/paper_cat_bell_hover.png), built by tests/_bell_process.gd from the cat's art:
## the bell's own silhouette (gold + its rim, the clapper slot filled), recoloured on a 3-stop red gradient at
## the bell's own luminance so the slot stays a dark mark and the edge stays pale. No shadow, no lift - hovering
## only changes the bell's colour. Clicking emits `pressed`, and the level treats that as 退出游戏.
##
## ⚠ The token is drawn on a fractional rect, so its transparent pixels are COLOUR-BLED (see the process
## script): with (0,0,0,0) neighbours, bilinear filtering would give the red a black outline.

signal pressed

const BELL_TEXTURE_PATH := "res://assets/generated/paper_cat_bell_hover.png"
## The cat's frame is square and every pose stands on its bottom row (see tests/_cat_process.gd).
const FRAME_SIZE := 256.0
## Where the token sits INSIDE that frame - the drawn rect maps the token one-to-one onto the paint.
const BELL_CANVAS_RECT := Rect2(106.0, 139.0, 44.0, 46.0)

var hovered := false

var _bell_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bell_texture = _load_texture(BELL_TEXTURE_PATH)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _load_texture(path: String) -> Texture2D:
	# DISK FIRST: the token is rewritten in place whenever the bell is re-cut, and `load()` keeps serving the
	# OLD imported texture until the editor re-imports it (the trap FridgeCatNose / FridgeCatPet document).
	if FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			return resource as Texture2D
	return null


func _on_mouse_entered() -> void:
	hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()


## A bell, not a rectangular hotspot: the round body plus the loop above it.
func _has_point(point: Vector2) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var body_centre := Vector2(size.x * 0.5, size.y * 0.66)
	if point.distance_to(body_centre) <= size.x * 0.52:
		return true
	# the loop: a narrow band straight above the body
	return absf(point.x - size.x * 0.5) <= size.x * 0.16 and point.y >= size.y * 0.06 \
		and point.y < body_centre.y


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
		pressed.emit()
		accept_event()


func _draw() -> void:
	if not hovered or _bell_texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# No token/shadow treatment: hovering simply swaps the painted bell's colour, so the red bell sits exactly
	# where the gold one was.
	draw_texture_rect(_bell_texture, Rect2(Vector2.ZERO, size), false, Color.WHITE)