extends SceneTree

## 点击冰箱人 - the hide/show toggle plus the new red-notebook art and the props' spot.
## A plain click on the idle fridge man hides the notebook prop and the briefcase - the CAT STAYS
## PUT; a second click brings the two back. A press that DRAGGED him must not toggle, and while a
## performance owns him the same click still means 改变飞行方向. Everything goes through the real
## _input path.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := true
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var save_coins: int = int(scene.get("fridge_coin_count"))
	var save_active_item: String = str(scene.get("fridge_active_item_id"))
	var owned: Variant = scene.get("fridge_owned_items")
	var save_owned: Variant = (owned as Array).duplicate() if owned is Array else (owned as Dictionary).duplicate()

	var level_player: Node = scene.get("fridge_player")
	var cat: Node = scene.get("fridge_cat_pet")
	var stand: Node = scene.get("fridge_gallery_stand")
	var box: Node = scene.get("fridge_box")
	var viewport := scene.get_viewport()

	# ---- 1) the new notebook art is in place, and everything starts visible ----
	var stand_art: String = str(stand.get("art_texture_path")) if stand != null else ""
	var new_art: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/generated/paper_red_book_star.png"))
	print("stand art=", stand_art, " art=", new_art.get_size(), " used=", new_art.get_used_rect())
	ok = ok and stand != null and stand_art.ends_with("paper_red_book_star.png")
	ok = ok and new_art.get_used_rect().size.y > 300
	print("at start: hidden=", scene.get("fridge_props_hidden"),
		" cat=", cat.visible, " book=", stand.visible, " case=", box.visible)
	ok = ok and not bool(scene.get("fridge_props_hidden"))
	ok = ok and cat.visible and stand.visible and box.visible

	# ---- 1b) 猫的右边: both props stand to the picture-RIGHT of the cat, on its ground line ----
	var cat_right: float = cat.global_position.x + 148.0 * 0.5
	print("layout: cat_x=", cat.global_position.x, " cat_right=", cat_right,
		" book_x=", stand.global_position.x, " case_x=", box.global_position.x)
	ok = ok and stand.global_position.x > cat_right
	ok = ok and box.global_position.x > cat_right
	ok = ok and box.global_position.x > stand.global_position.x
	# ...and neither panel is pushed off the screen edge by the new spots
	var view: Vector2 = viewport.get_visible_rect().size
	var gallery_pos: Vector2 = scene.call("_fridge_gallery_popup_position")
	var box_pos: Vector2 = scene.call("_fridge_box_popup_position")
	print("panels: gallery=", gallery_pos, " box=", box_pos, " view=", view)
	ok = ok and gallery_pos.x >= 0.0 and gallery_pos.y >= 0.0
	ok = ok and box_pos.x >= 0.0 and box_pos.y >= 0.0
	ok = ok and gallery_pos.x < view.x and box_pos.x < view.x

	# The input path reads the REAL mouse position (a headless run leaves it in the screen
	# corner), so park him under the pointer before clicking him.
	level_player.global_position = viewport.get_canvas_transform().affine_inverse() \
		* viewport.get_mouse_position()

	# ---- 2) 点击冰箱人: a plain click hides the notebook and the briefcase (NOT the cat) ----
	_click(scene, viewport)
	print("after click 1: hidden=", scene.get("fridge_props_hidden"),
		" cat=", cat.visible, " book=", stand.visible, " case=", box.visible)
	ok = ok and bool(scene.get("fridge_props_hidden"))
	ok = ok and cat.visible and not stand.visible and not box.visible

	# ---- 3) a second click brings them all back ----
	_click(scene, viewport)
	print("after click 2: hidden=", scene.get("fridge_props_hidden"),
		" cat=", cat.visible, " book=", stand.visible, " case=", box.visible)
	ok = ok and not bool(scene.get("fridge_props_hidden"))
	ok = ok and cat.visible and stand.visible and box.visible

	# ---- 4) a press that MOVED him (dragging) is not a click: it must not toggle ----
	_press(scene, viewport)
	scene.set("fridge_player_drag_moved", true)
	_release(scene, viewport)
	var dragged_hidden: bool = bool(scene.get("fridge_props_hidden"))
	print("after a drag: hidden=", dragged_hidden, " cat=", cat.visible)
	ok = ok and not dragged_hidden and cat.visible

	# ---- 5) while a performance owns him the click never toggles the props (it stays a
	#         改变飞行方向 click, which only bites while he is actually flying) ----
	level_player.set("pager_reaction_active", true)
	var dir_before: float = float(scene.get("fridge_player_flight_dir"))
	_click(scene, viewport)
	var performing_hidden: bool = bool(scene.get("fridge_props_hidden"))
	var dir_after: float = float(scene.get("fridge_player_flight_dir"))
	print("click while performing: hidden=", performing_hidden,
		" dir=", dir_before, "->", dir_after, " flying=", level_player.call("is_pager_flying"))
	ok = ok and not performing_hidden and cat.visible and stand.visible and box.visible
	ok = ok and dir_after == dir_before
	level_player.set("pager_reaction_active", false)

	# ---- 6) 面板打开时不隐藏: the book / briefcase / cat-bag panels are opened FROM these very
	#         props, so a click that lands on him while one of them is on screen must leave the props
	#         (and the panel) alone instead of hiding them mid-look ----
	scene.call("_on_fridge_box_toggled", true)
	await process_frame
	await process_frame
	var box_panel: Node = scene.get("fridge_box_panel")
	_click(scene, viewport)
	var hidden_with_box: bool = bool(scene.get("fridge_props_hidden"))
	print("click with 公文包 open: hidden=", hidden_with_box, " panel=",
		box_panel.visible if box_panel != null else null, " book=", stand.visible, " case=", box.visible)
	ok = ok and not hidden_with_box and box_panel != null and box_panel.visible
	ok = ok and stand.visible and box.visible

	scene.call("_on_fridge_box_toggled", false)
	scene.call("_on_fridge_gallery_stand_toggled", true)
	await process_frame
	await process_frame
	var book_panel: Node = scene.get("fridge_gallery_panel")
	_click(scene, viewport)
	var hidden_with_book: bool = bool(scene.get("fridge_props_hidden"))
	print("click with 书本 open: hidden=", hidden_with_book, " panel=",
		book_panel.visible if book_panel != null else null, " book=", stand.visible, " case=", box.visible)
	ok = ok and not hidden_with_book and book_panel != null and book_panel.visible
	ok = ok and stand.visible and box.visible
	scene.call("_on_fridge_gallery_stand_toggled", false)
	await process_frame
	await process_frame

	# ...and with every panel closed the click toggles again, so the guard does not kill the feature.
	_click(scene, viewport)
	var hidden_after_close: bool = bool(scene.get("fridge_props_hidden"))
	print("click with every panel closed: hidden=", hidden_after_close)
	ok = ok and hidden_after_close
	_click(scene, viewport)
	ok = ok and not bool(scene.get("fridge_props_hidden"))
	ok = ok and cat.visible and stand.visible and box.visible

	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.set("fridge_owned_items", save_owned)
	scene.call("_save_fridge_progress")
	print("PROPS_HIDE_TEST=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0)


func _click(scene: Node, viewport: Viewport) -> void:
	_press(scene, viewport)
	_release(scene, viewport)


func _press(scene: Node, viewport: Viewport) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = viewport.get_mouse_position()
	scene.call("_input", event)


func _release(scene: Node, viewport: Viewport) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = viewport.get_mouse_position()
	scene.call("_input", event)