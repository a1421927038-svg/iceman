extends Control

## Throwaway preview: the mouth-panel art with the nose hotspot hovered, so the
## YELLOW hover token can be checked against the painted RED nose without needing
## the live game window to be tall enough to show the whole panel.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.85, 0.85, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Two 1:1 copies of the panel art: left idle (the nose has to look untouched),
	# right hovered (the same pixels, only recoloured).
	_add_panel(Vector2(30.0, 70.0), false)
	_add_panel(Vector2(610.0, 70.0), true)


func _add_panel(art_position: Vector2, hovered: bool) -> void:
	var art := TextureRect.new()
	# DISK FIRST, like FridgeCatNose/FridgeCatPet: load() keeps serving the stale
	# imported texture after the panel PNG is rewritten on disk, which would show
	# the old nose colour here.
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/generated/paper_cat_mouth_inventory_panel.png"))
	if img != null and not img.is_empty():
		art.texture = ImageTexture.create_from_image(img)
	else:
		art.texture = load("res://assets/generated/paper_cat_mouth_inventory_panel.png")
	art.position = art_position
	# the game draws the 512 art at FRIDGE_TOOLBAR_SIZE, so use the same size here: the
	# token then lands on a fractional rect and gets resampled, exactly as in game
	art.size = FridgeLevel.FRIDGE_TOOLBAR_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	# read the level's own numbers so this preview can never drift from the game
	var nose := FridgeCatNose.new()
	var nose_size: Vector2 = art.size * FridgeLevel.FRIDGE_NOSE_SIZE_FRAC
	nose.size = nose_size
	nose.position = art_position + art.size * FridgeLevel.FRIDGE_NOSE_CENTER_FRAC - nose_size * 0.5
	add_child(nose)
	if hovered:
		nose.call("_on_mouse_entered")
	var texture := nose.get("_nose_texture") as Texture2D
	var cut_size := Vector2i.ZERO
	if texture != null:
		cut_size = texture.get_size()
	print("hovered=", hovered, " nose_rect=", nose.get_global_rect(),
		" cut_texture=", texture != null, " cut_size=", cut_size)