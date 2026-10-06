extends SceneTree

## Harness: replay the two prop clicks through the viewport, using the CANVAS transform so the
## points are right in headless (which centres on a 1152x1152 viewport) and in the real game.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var viewport := scene.get_viewport()
	var canvas: Transform2D = viewport.get_canvas_transform()
	var stand: Node = scene.get("fridge_gallery_stand")
	var box: Node = scene.get("fridge_box")
	var gallery: Node = scene.get("fridge_gallery_panel")
	var box_panel: Node = scene.get("fridge_box_panel")

	var stand_point: Vector2 = canvas * (stand.global_position + Vector2(0.0, -40.0))
	var box_point: Vector2 = canvas * (box.global_position + Vector2(0.0, -40.0))
	print("click points: stand=", stand_point, " box=", box_point)

	print("== click the briefcase ==")
	_click(viewport, box_point)
	await process_frame
	print("   stand open=", stand.get("is_open"), " box open=", box.get("is_open"),
		" gallery=", gallery.visible, " box_panel=", box_panel.visible)

	print("== click the notebook ==")
	_click(viewport, stand_point)
	await process_frame
	print("   stand open=", stand.get("is_open"), " box open=", box.get("is_open"),
		" gallery=", gallery.visible, " box_panel=", box_panel.visible,
		" gallery_pos=", gallery.position, " gallery_size=", gallery.size)

	var tab_button: Node = gallery.find_child("ItemsTab", true, false)
	if tab_button == null:
		print("   ! ItemsTab not found")
		quit()
		return
	var rect: Rect2 = tab_button.get_global_rect()
	print("   ItemsTab rect=", rect, " in_tree=", tab_button.is_visible_in_tree())
	print("== click the 猫嘴物品 tab ==")
	_click(viewport, rect.get_center())
	await process_frame
	print("   active=", gallery.call("get_active_tab"), " gallery=", gallery.visible,
		" size=", gallery.size, " pos=", gallery.position)

	print("== click the notebook again (close) ==")
	_click(viewport, stand_point)
	await process_frame
	print("   stand open=", stand.get("is_open"), " gallery=", gallery.visible)
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