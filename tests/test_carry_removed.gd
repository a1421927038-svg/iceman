extends SceneTree

## Guards the 手持 / 落地 feature's REMOVAL: it was built (he carried a notebook and a briefcase),
## then the user asked to delete both from his hands. So now he must carry NOTHING - no carry
## sprites, no carry state on either the player or the level, and nothing spawned into the room.
## The leftmost prop stays the big red notebook and the room keeps exactly its two fixtures.

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

	# ---- 1) his hands are empty: no carried sprite, no carry state, no carry API ----
	var vars_left: Array = []
	for key in ["carry_book_sprite", "carry_case_sprite", "carry_held"]:
		if level_player.get(key) != null:
			vars_left.append(key)
	var sprite_children: Array = []
	for child in level_player.get_children():
		if child is Sprite2D and str(child.name).to_lower().contains("carry"):
			sprite_children.append(str(child.name))
	print("hands: vars_left=", vars_left, " carry_sprites=", sprite_children,
		" is_carry_item_at=", level_player.has_method("is_carry_item_at"),
		" set_carry_held=", level_player.has_method("set_carry_held"))
	ok = ok and vars_left.is_empty() and sprite_children.is_empty()
	ok = ok and not level_player.has_method("is_carry_item_at")
	ok = ok and not level_player.has_method("set_carry_held")

	# ---- 2) the level keeps no carry state and spawns no copies of the book or the briefcase ----
	print("level: placed=", scene.get("fridge_carry_placed"),
		" book=", scene.get("fridge_placed_book"), " case=", scene.get("fridge_placed_case"),
		" set_method=", scene.has_method("_set_fridge_carry_placed"))
	ok = ok and scene.get("fridge_carry_placed") == null
	ok = ok and scene.get("fridge_placed_book") == null and scene.get("fridge_placed_case") == null
	ok = ok and not scene.has_method("_set_fridge_carry_placed")

	# ---- 3) the leftmost prop is still the red notebook, and the 道具箱 briefcase is still there ----
	var stand: Node = scene.get("fridge_gallery_stand")
	var stand_art: String = str(stand.get("art_texture_path")) if stand != null else ""
	print("stand art=", stand_art, " box=", scene.get("fridge_box") != null,
		" cat=", scene.get("fridge_cat_pet") != null)
	ok = ok and stand != null and stand_art.ends_with("paper_red_book_star.png")
	ok = ok and scene.get("fridge_box") != null
	ok = ok and scene.get("fridge_cat_pet") != null

	# ---- 4) a click on him is still harmless while he is idle: he does not turn around (only a
	#         flight turns on a click), it does not leave him stuck mid-drag, and it no longer
	#         touches any carry state - there is none ----
	var mouse_world: Vector2 = scene.get_viewport().get_canvas_transform().affine_inverse() \
		* scene.get_viewport().get_mouse_position()
	level_player.global_position = mouse_world
	var before: float = float(scene.get("fridge_player_flight_dir"))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.get_viewport().get_mouse_position()
	scene.call("_input", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	scene.call("_input", release)
	var after: float = float(scene.get("fridge_player_flight_dir"))
	print("click while idle: before=", before, " after=", after,
		" dragging=", scene.get("fridge_player_is_dragging"))
	ok = ok and after == before
	ok = ok and not bool(scene.get("fridge_player_is_dragging"))

	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.set("fridge_owned_items", save_owned)
	scene.call("_save_fridge_progress")
	print("CARRY_REMOVED_TEST=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0)