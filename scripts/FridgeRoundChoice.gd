class_name FridgeRoundChoice
extends Area2D

signal selected(choice_id: String)

const DISPLAY_HEIGHT := 92.0

var choice_id := ""
var texture_path := ""
var sprite: Sprite2D
var hovered := false


func setup(new_choice_id: String, new_texture_path: String) -> void:
	choice_id = new_choice_id
	texture_path = new_texture_path
	if is_inside_tree():
		_create_sprite()


func _ready() -> void:
	z_index = 80
	input_pickable = true
	_create_hit_area()
	_create_sprite()
	mouse_entered.connect(func() -> void:
		hovered = true
		_update_hover_scale()
	)
	mouse_exited.connect(func() -> void:
		hovered = false
		_update_hover_scale()
	)
	input_event.connect(_on_input_event)


func _create_hit_area() -> void:
	var shape := CollisionShape2D.new()
	var shape_rect := RectangleShape2D.new()
	shape_rect.size = Vector2(96.0, 104.0)
	shape.shape = shape_rect
	shape.position = Vector2(0.0, -4.0)
	add_child(shape)


func _create_sprite() -> void:
	if sprite != null or texture_path == "":
		return

	var texture := _load_texture(texture_path)
	if texture == null:
		return

	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	var texture_height := float(texture.get_height())
	if texture_height > 0.0:
		var scale_factor := DISPLAY_HEIGHT / texture_height
		sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	var file_path := path
	if path.begins_with("res://") or path.begins_with("user://"):
		file_path = ProjectSettings.globalize_path(path)

	var image := Image.new()
	var error := image.load(file_path)
	if error == OK and not image.is_empty():
		return ImageTexture.create_from_image(image)

	return null


func _update_hover_scale() -> void:
	scale = Vector2(1.08, 1.08) if hovered else Vector2.ONE


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			selected.emit(choice_id)
			get_viewport().set_input_as_handled()
