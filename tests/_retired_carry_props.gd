extends SceneTree

## Covers 手持 vs 落地: the level's leftmost prop (the backpack's host stand) is drawn as a big
## RED notebook instead of the wardrobe, the fridge man starts the level carrying a notebook in
## his left hand and a briefcase in his right, clicking either carried thing puts full-size
## copies of both down into the room (the carried ones vanish), and clicking HIM picks them back
## up. Everything is driven through the real _input path.

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
	level_player.set_process(false)

	# ---- 1) the leftmost prop is the red notebook now ----
	var stand: Node = scene.get("fridge_gallery_stand")
	var stand_art: String = str(stand.get("art_texture_path")) if stand != null else ""
	print("stand art=", stand_art, " node=", stand != null)
	ok = ok and stand != null and stand_art.ends_with("paper_red_book.png")
	# ...and its picture really is loaded (the file exists and has content)
	var book_img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/generated/paper_red_book.png"))
	print("red book art = ", book_img.get_size(), " used=", book_img.get_used_rect())
	ok = ok and book_img.get_used_rect().size.y > 300

	# ---- 2) he starts holding the notebook (his left = picture-right) and the case ----
	var book: Sprite2D = level_player.get("carry_book_sprite") as Sprite2D
	var case: Sprite2D = level_player.get("carry_case_sprite") as Sprite2D
	var book_h: float = absf(book.texture.get_height() * book.scale.y) if book != null else 0.0
	var case_h: float = absf(case.texture.get_height() * case.scale.y) if case != null else 0.0
	print("carrying: held=", level_player.get("carry_held"),
		" book=", book != null and book.visible, " case=", case != null and case.visible,
		" book_pos=", book.position if book != null else Vector2.ZERO,
		" case_pos=", case.position if case != null else Vector2.ZERO,
		" drawn book_h=%.1f case_h=%.1f" % [book_h, case_h])
	ok = ok and bool(level_player.get("carry_held"))
	ok = ok and book != null and book.visible and case != null and case.visible
	# a believable size in his hand (~22% of his 320px drawn height), not a stamp
	ok = ok and book_h > 60.0 and case_h > 45.0
	# the notebook rides on his picture-right hand, the briefcase on his picture-left one
	ok = ok and book.position.x > 20.0 and case.position.x < -20.0
	ok = ok and absf(book.position.x) < 130.0 and absf(case.position.x) < 130.0
	# ...and the carried things are clickable, while empty space is not
	var book_center: Vector2 = level_player.global_position + book.position
	var case_center: Vector2 = level_player.global_position + case.position
	print("carry hit test: on_book=", level_player.call("is_carry_item_at", book_center),
		" on_case=", level_player.call("is_carry_item_at", case_center),
		" far_away=", level_player.call("is_carry_item_at", book_center + Vector2(400.0, 400.0)))
	ok = ok and bool(level_player.call("is_carry_item_at", book_center))
	ok = ok and bool(level_player.call("is_carry_item_at", case_center))
	ok = ok and not bool(level_player.call("is_carry_item_at", book_center + Vector2(400.0, 400.0)))

	# nothing extra is spawned: the room's book and briefcase ARE the leftmost notebook prop
	# and the 道具箱 briefcase, so the level must not build second copies of either.
	print("no placed copies: book=", scene.get("fridge_placed_book"),
		" case=", scene.get("fridge_placed_case"), " placed=", scene.get("fridge_carry_placed"))
	ok = ok and scene.get("fridge_placed_book") == null and scene.get("fridge_placed_case") == null
	ok = ok and not bool(scene.get("fridge_carry_placed"))

	# ---- 3) 点击公文包和本子: a real click on a carried thing puts both down ----
	var viewport := scene.get_viewport()
	# The input path reads the REAL mouse position, and a headless run leaves the mouse in the
	# screen corner - so slide HIM until the carried notebook sits under the pointer.
	level_player.global_position = (viewport.get_canvas_transform().affine_inverse()
		* viewport.get_mouse_position()) - book.position
	var to_screen: Vector2 = viewport.get_canvas_transform() * (level_player.global_position + book.position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = to_screen
	scene.call("_input", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to_screen
	scene.call("_input", release)
	print("after clicking the carried notebook: placed=", scene.get("fridge_carry_placed"),
		" held=", level_player.get("carry_held"),
		" book_visible=", book.visible, " case_visible=", case.visible)
	ok = ok and bool(scene.get("fridge_carry_placed"))
	ok = ok and not bool(level_player.get("carry_held"))
	ok = ok and not book.visible and not case.visible
	# ...and they cannot be re-triggered by another click on where they used to be carried
	print("carry hit test while put down: ", level_player.call("is_carry_item_at", book_center))
	ok = ok and not bool(level_player.call("is_carry_item_at", book_center))

	# ---- 4) 点击冰箱爷爷: a click on HIM picks them back up ----
	# The headless mouse sits in the screen corner, and the man's hit test needs the pointer on
	# him, so park him under the mouse first (exactly what the pager suite does).
	var mouse_world: Vector2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
	level_player.global_position = mouse_world
	var press2 := InputEventMouseButton.new()
	press2.button_index = MOUSE_BUTTON_LEFT
	press2.pressed = true
	press2.position = viewport.get_mouse_position()
	scene.call("_input", press2)
	var release2 := InputEventMouseButton.new()
	release2.button_index = MOUSE_BUTTON_LEFT
	release2.pressed = false
	release2.position = press2.position
	scene.call("_input", release2)
	print("after clicking him: placed=", scene.get("fridge_carry_placed"),
		" held=", level_player.get("carry_held"),
		" book_visible=", book.visible, " case_visible=", case.visible)
	ok = ok and not bool(scene.get("fridge_carry_placed"))
	ok = ok and bool(level_player.get("carry_held"))
	ok = ok and book.visible and case.visible

	# ---- 5) restore the save this suite borrowed ----
	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.set("fridge_owned_items", save_owned)
	scene.call("_save_fridge_progress")
	print("CARRY_PROPS_TEST=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0)