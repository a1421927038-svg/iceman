class_name FridgeMouthInventoryPanel
extends PanelContainer

const MOUTH_PANEL_TEXTURE_PATH := "res://assets/generated/paper_cat_mouth_inventory_panel.png"

var mouth_texture: Texture2D


func _ready() -> void:
	mouth_texture = _load_texture(MOUTH_PANEL_TEXTURE_PATH)
	queue_redraw()


func _draw() -> void:
	if mouth_texture != null:
		draw_texture_rect(mouth_texture, Rect2(Vector2.ZERO, size), false)
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.05, 0.92), true)


func _load_texture(texture_path: String) -> Texture2D:
	# DISK FIRST: the mouth panel is rewritten in place whenever the cat is
	# re-skinned, and `load()` keeps serving the OLD imported texture until the
	# editor re-imports it (the same trap FridgeCatNose/FridgeCatPet document).
	if FileAccess.file_exists(texture_path):
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(texture_path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)

	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D

	return null
