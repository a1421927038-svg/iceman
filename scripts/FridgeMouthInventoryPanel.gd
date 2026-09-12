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
