extends SceneTree

## Harness: measure the notebook prop's and the briefcase's real hit rects, then replay the two
## clicks through the viewport to see which one actually toggles.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var viewport := scene.get_viewport()
	var canvas: Transform2D = viewport.get_canvas_transform()
	for key in ["fridge_gallery_stand", "fridge_box"]:
		var node: Node = scene.get(key)
		print("--- ", key, " pos=", node.global_position, " open=", node.get("is_open"),
			" visible=", node.visible)
		for child in node.get_children():
			if child is CollisionShape2D and child.shape != null:
				var size: Vector2 = child.shape.get("size")
				var centre: Vector2 = node.global_position + child.position
				var world := Rect2(centre - size * 0.5, size)
				var screen := Rect2(canvas * world.position, size)
				print("    shape centre=", centre, " world=", world, " screen=", screen)
	print("gallery panel: pos=", scene.get("fridge_gallery_panel").position,
		" size=", scene.get("fridge_gallery_panel").size,
		" visible=", scene.get("fridge_gallery_panel").visible)
	print("box panel: pos=", scene.get("fridge_box_panel").position,
		" size=", scene.get("fridge_box_panel").size,
		" visible=", scene.get("fridge_box_panel").visible)

	print("== click 1 (1084,454) ==")
	_click(viewport, Vector2(1084.0, 454.0))
	await process_frame
	print("   stand open=", scene.get("fridge_gallery_stand").get("is_open"),
		" box open=", scene.get("fridge_box").get("is_open"),
		" gallery_panel=", scene.get("fridge_gallery_panel").visible,
		" box_panel=", scene.get("fridge_box_panel").visible)
	print("== click 2 (996,463) ==")
	_click(viewport, Vector2(996.0, 463.0))
	await process_frame
	print("   stand open=", scene.get("fridge_gallery_stand").get("is_open"),
		" box open=", scene.get("fridge_box").get("is_open"),
		" gallery_panel=", scene.get("fridge_gallery_panel").visible,
		" box_panel=", scene.get("fridge_box_panel").visible,
		" gallery_pos=", scene.get("fridge_gallery_panel").position)
	var tabs: Array = scene.get("fridge_gallery_panel").call("get_tab_ids")
	print("   tabs=", tabs)
	var tab_button: Node = scene.get("fridge_gallery_panel").find_child("ItemsTab", true, false)
	if tab_button != null:
		var rect: Rect2 = tab_button.get_global_rect()
		print("   ItemsTab rect=", rect, " visible=", tab_button.is_visible_in_tree())
		print("== click the 猫嘴物品 tab ==")
		_click(viewport, rect.get_center())
		await process_frame
		print("   active=", scene.get("fridge_gallery_panel").call("get_active_tab"),
			" gallery_panel=", scene.get("fridge_gallery_panel").visible)
	quit()


func _click(viewport: Viewport, at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	viewport.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	viewport.push_input(release)