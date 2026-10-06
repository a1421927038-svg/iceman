class_name FridgeCatNose
extends Control

## Hotspot sitting exactly on the cat's nose in the mouth-inventory art.
##
## The nose is painted into the panel texture and stays RED. Nothing is drawn
## while idle, so the painted nose shows through untouched; on hover this shows
## the same nose re-cut as a YELLOW paper token
## (res://assets/generated/paper_cat_nose_hover.png). The token is built from the
## panel's own nose pixels - the silhouette grown 3 px and softened so it covers
## the painted nose exactly - recoloured yellow at the nose's own luminance, so it
## keeps the collage's paper material (fibre grain, soft shading, cut edge) rather
## than being a flat vector fill. It is drawn with NO shadow and NO lift: hovering
## just changes the nose's colour in place. Clicking emits `pressed` so the level
## can re-roll the balls in the mouth.

signal pressed

const NOSE_TEXTURE_PATH := "res://assets/generated/paper_cat_nose_hover.png"
# The cut-out inside this control's rect: a rounded triangle, wide across the
# top and tapering to a tip, as fractions of size (measured from the mask).
const NOSE_TOP_FRAC := 0.06
const NOSE_BOTTOM_FRAC := 0.94
const NOSE_HALF_WIDTH_FRAC := 0.47

var hovered := false

var _nose_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_nose_texture = _load_texture(NOSE_TEXTURE_PATH)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _load_texture(path: String) -> Texture2D:
	# DISK FIRST: the nose token is rewritten in place whenever the cat's mouth panel
	# is re-skinned, and `load()` keeps serving the OLD imported texture until the
	# editor re-imports it (the same trap FridgeCatPet._load_texture documents).
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


## Only the nose triangle reacts, not the whole rectangular hotspot.
func _has_point(point: Vector2) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var top := size.y * NOSE_TOP_FRAC
	var bottom := size.y * NOSE_BOTTOM_FRAC
	if point.y < top or point.y > bottom:
		return false
	var tip_ratio: float = (point.y - top) / maxf(bottom - top, 0.001)
	var half_width := size.x * NOSE_HALF_WIDTH_FRAC * (1.0 - tip_ratio)
	return absf(point.x - size.x * 0.5) <= half_width + size.x * 0.06


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
		pressed.emit()
		accept_event()


func _draw() -> void:
	if not hovered or _nose_texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# No token/shadow treatment ("高亮去掉，只需要鼻子变色"): hovering simply swaps the
	# painted nose's colour, so the yellow nose sits exactly where the red one was.
	draw_texture_rect(_nose_texture, Rect2(Vector2.ZERO, size), false, Color.WHITE)