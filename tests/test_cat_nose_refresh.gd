extends SceneTree

## Covers the cat-nose refresh feature:
##  1. the nose hotspot tracks the mouth panel and is hidden while it is shut,
##  2. hovering blushes it (the hit test is the nose triangle, not the rect),
##  3. clicking re-deals the balls, which pour out of the throat one by one,
##  4. the cursor parts the pile as it moves through the mouth.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := true

	var packed: PackedScene = load("res://scenes/FridgeLevel.tscn")
	var level: Node = packed.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame

	var panel: Control = level.get("fridge_item_panel") as Control
	var nose: Control = level.get("fridge_nose_button") as Control
	print("nose_exists=", nose != null, " visible_while_shut=", nose.visible if nose != null else "n/a")
	ok = ok and nose != null and not nose.visible

	# ---------- 1. hotspot tracks the painted nose on the open panel ----------
	level.call("_show_fridge_item_toolbar")
	panel.scale = Vector2.ONE  # skip the pop-in tween; positioning is what matters
	level.call("_position_fridge_popups")
	var panel_rect: Rect2 = panel.get_global_rect()
	var nose_rect: Rect2 = nose.get_global_rect()
	var expected_center: Vector2 = panel_rect.position + panel_rect.size * Vector2(0.49902, 0.18945)
	var center_error: float = nose_rect.get_center().distance_to(expected_center)
	# The hotspot must keep the cut-out's 62x43 aspect so the recoloured nose is
	# never stretched out of shape.
	var cut := nose.get("_nose_texture") as Texture2D
	var cut_aspect: float = float(cut.get_width()) / float(cut.get_height()) if cut != null else 0.0
	var rect_aspect: float = nose.size.x / nose.size.y
	print("panel=", panel_rect, " nose_rect=", nose_rect, " center_error=", center_error)
	print("cut_texture=", cut != null, " cut_aspect=", cut_aspect, " rect_aspect=", rect_aspect)
	ok = ok and nose.visible and center_error < 1.0
	ok = ok and cut != null and absf(cut_aspect - rect_aspect) < 0.02

	# ---------- 2. triangle hit test + hover blush ----------
	print("nose_tooltip=", nose.tooltip_text)
	ok = ok and nose.tooltip_text.is_empty()  # no hover tooltip on the nose
	var inside := bool(nose.call("_has_point", nose.size * 0.5))
	var top_left := bool(nose.call("_has_point", Vector2(1.0, 1.0)))
	var bottom_left := bool(nose.call("_has_point", Vector2(1.0, nose.size.y - 1.0)))
	nose.call("_on_mouse_entered")
	var hovered: bool = bool(nose.get("hovered"))
	nose.call("_on_mouse_exited")
	print("has_point center=", inside, " top_left=", top_left, " bottom_left=", bottom_left,
		" hovered=", hovered, " after_exit=", bool(nose.get("hovered")))
	ok = ok and inside and not top_left and not bottom_left and hovered and not bool(nose.get("hovered"))

	# ---------- 3. click re-deals the balls out of the throat ----------
	var balls: Array = level.get("fridge_yarn_balls")
	var pile: Control = level.get("fridge_yarn_pile") as Control
	level.call("_refresh_fridge_yarn_balls")
	var spawn: Dictionary = level.get("fridge_yarn_spawn")
	var hidden := 0
	for ball in balls:
		# Godot clamps a zero node scale to CMP_EPSILON, so "hidden" means
		# effectively invisible rather than exactly (0, 0).
		if (ball as Control).scale.length() < 0.01:
			hidden += 1
	print("after nose click: spawning=", spawn.size(), "/", balls.size(), " hidden=", hidden)
	ok = ok and spawn.size() == balls.size() and hidden == balls.size()

	var steps := 0
	while not (level.get("fridge_yarn_spawn") as Dictionary).is_empty() and steps < 600:
		level.call("_update_fridge_yarn_spawn", 1.0 / 60.0)
		steps += 1
	print("pour-out finished in ", steps, " steps (staggered, ", float(steps) / 60.0, " s)")

	var spots := {}
	var all_inside := true
	var all_full_scale := true
	for ball in balls:
		var b := ball as Control
		var center: Vector2 = b.call("get_center_position")
		var radius := float(b.call("get_radius"))
		if not b.scale.is_equal_approx(Vector2.ONE):
			all_full_scale = false
		if center.x < radius + 4.0 or center.y < radius + 4.0 \
				or center.x > pile.size.x - radius - 4.0 or center.y > pile.size.y - radius - 4.0:
			all_inside = false
		spots[Vector2i(roundi(center.x), roundi(center.y))] = true
	print("steps<600=", steps < 600, " distinct_spots=", spots.size(), "/", balls.size(),
		" all_inside=", all_inside, " all_full_scale=", all_full_scale)
	ok = ok and steps < 600 and spots.size() == balls.size() and all_inside and all_full_scale

	# ---------- 4. cursor parts the pile ----------
	var origin := Vector2(pile.size.x * 0.5, pile.size.y * 0.5)
	var near_push: Vector2 = level.call("_get_fridge_yarn_pointer_push", origin + Vector2(10.0, 0.0), origin, 1.0 / 60.0)
	var closest_push: Vector2 = level.call("_get_fridge_yarn_pointer_push", origin + Vector2(2.0, 0.0), origin, 1.0 / 60.0)
	var far_push: Vector2 = level.call("_get_fridge_yarn_pointer_push", origin + Vector2(400.0, 0.0), origin, 1.0 / 60.0)
	var none_push: Vector2 = level.call("_get_fridge_yarn_pointer_push", origin + Vector2(10.0, 0.0), Vector2(-100000.0, -100000.0), 1.0 / 60.0)
	print("push_near=", near_push, " push_closest=", closest_push, " push_far=", far_push, " push_none=", none_push)
	ok = ok and near_push.x > 0.0 and absf(near_push.y) < 0.0001 \
		and closest_push.x > near_push.x and far_push == Vector2.ZERO and none_push == Vector2.ZERO

	# The whole pile keeps settling safely inside the mouth.
	for step in 60:
		level.call("_update_fridge_yarn_pile", 1.0 / 60.0)
	var settled_inside := true
	for ball in balls:
		var center: Vector2 = (ball as Control).call("get_center_position")
		if center.x < 2.0 or center.y < 2.0 or center.x > pile.size.x - 2.0 or center.y > pile.size.y - 2.0:
			settled_inside = false
	print("pile settled inside=", settled_inside)
	ok = ok and settled_inside

	# ---------- 4. 铃铛: hover turns the cat's bell red, clicking QUITS ----------
	# The bell hotspot rides the cat's PAINTED bell (the collar's gold bell in its 256 px frame), so it must land
	# where the paint is, stay inside the cat's art (the click-through region only wraps what is measured there)
	# and its token must be RED. ⚠ The handler is never CALLED - it quits the game.
	var bell: Control = level.get("fridge_bell_button") as Control
	var cat: Node = level.get("fridge_cat_pet")
	level.call("_position_fridge_popups")
	var bell_rect: Rect2 = bell.get_global_rect() if bell != null else Rect2()
	var cat_art: Rect2 = level.call("_fridge_node_art_rect", cat)
	# the paint's own bell centre: frame (127.5, 162) of 256, mapped through the sprite's transform
	var sprite: Sprite2D = cat.get("sprite") as Sprite2D
	var to_screen: Transform2D = get_root().get_canvas_transform() * sprite.global_transform
	var paint_centre: Vector2 = to_screen * (Vector2(127.5, 162.0) - Vector2(128.0, 128.0))
	var centre_error: float = bell_rect.get_center().distance_to(paint_centre)
	var token := bell.get("_bell_texture") as Texture2D if bell != null else null
	print("bell: exists=", bell != null, " visible=", bell.visible if bell != null else "n/a",
		" rect=", bell_rect, " paint_centre=", paint_centre, " centre_error=", snappedf(centre_error, 0.01),
		" inside_cat_art=", cat_art.encloses(bell_rect), " token=", token != null,
		" available=", cat.call("is_bell_available"))
	ok = ok and bell != null
	ok = ok and token != null and cat_art.encloses(bell_rect)
	ok = ok and centre_error < 2.0
	# the hotspot is the BELL (round body + loop), not its rectangle
	ok = ok and bool(bell.call("_has_point", bell.size * Vector2(0.5, 0.66)))
	print("bell has_point: centre=", bell.call("_has_point", bell.size * Vector2(0.5, 0.66)),
		" top_left=", bell.call("_has_point", Vector2(1.0, 1.0)),
		" bottom_left=", bell.call("_has_point", Vector2(1.0, bell.size.y - 1.0)))
	ok = ok and not bool(bell.call("_has_point", Vector2(1.0, 1.0)))
	ok = ok and not bool(bell.call("_has_point", Vector2(1.0, bell.size.y - 1.0)))
	# hover state (the token itself is drawn red - see the check on its pixels below)
	bell.call("_on_mouse_entered")
	ok = ok and bool(bell.get("hovered"))
	bell.call("_on_mouse_exited")
	ok = ok and not bool(bell.get("hovered"))
	# the click path exists but is NOT invoked (it calls get_tree().quit())
	print("bell click wired=", bell.pressed.is_connected(Callable(level, "_on_fridge_cat_bell_pressed")),
		" handler=", level.has_method("_on_fridge_cat_bell_pressed"))
	ok = ok and bell.pressed.is_connected(Callable(level, "_on_fridge_cat_bell_pressed"))
	ok = ok and level.has_method("_on_fridge_cat_bell_pressed")

	# ---------- 4a. the bell ASKS: a 是否退出 card, not an instant quit ----------
	# ⚠ `_on_fridge_cat_bell_pressed` is safe to call now (it only opens the card); the 退出 button's own
	# handler is NEVER invoked here - it quits the test.
	level.call("_on_fridge_cat_bell_pressed")
	await process_frame
	level.call("_position_fridge_popups")
	var quit_panel: PanelContainer = level.get("fridge_quit_panel") as PanelContainer
	var buttons: Array = []
	var labels: Array = []
	if quit_panel != null:
		for child: Node in quit_panel.find_children("*", "Button", true, false):
			buttons.append(child)
			labels.append((child as Button).text)
		# the card is UI the player has to reach, so it must be inside the click-through region
		var rects3: Array = level.call("desktop_pet_hit_rects")
		var region4: PackedVector2Array = get_root().mouse_passthrough_polygon
		var panel_rect3: Rect2 = quit_panel.get_global_rect()
		var centre_covered: bool = _point_in_polygon(region4, panel_rect3.get_center())
		var view_size := get_root().get_visible_rect().size
		var centred_error: float = panel_rect3.get_center().distance_to(view_size * 0.5)
		print("quit card: visible=", quit_panel.visible, " rect=", panel_rect3,
			" buttons=", labels, " in_hit_rects=", rects3.has(panel_rect3),
			" centre_in_region=", centre_covered, " centred_error=", snappedf(centred_error, 0.1))
		ok = ok and quit_panel.visible
		ok = ok and labels.has("退出") and labels.has("取消")
		ok = ok and centre_covered and centred_error < 2.0
		var confirm: Button = null
		for button: Button in buttons:
			if button.text == "退出":
				confirm = button
		ok = ok and confirm != null and confirm.pressed.is_connected(Callable(level, "_on_fridge_quit_confirmed"))
		ok = ok and level.has_method("_on_fridge_quit_confirmed")
	# 取消 just closes the card
	level.call("_on_fridge_quit_cancelled")
	await process_frame
	print("quit card after 取消: visible=", quit_panel.visible)
	ok = ok and not quit_panel.visible
	# ... and a second bell click closes it again (toggle)
	level.call("_on_fridge_cat_bell_pressed")
	await process_frame
	ok = ok and quit_panel.visible
	level.call("_on_fridge_cat_bell_pressed")
	await process_frame
	ok = ok and not quit_panel.visible
	# the token is RED: the mean of its opaque pixels must be red-dominant (it is the colour swap's whole point)
	var token_image: Image = Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/generated/paper_cat_bell_hover.png"))
	var red_sum := Vector3.ZERO
	var opaque := 0
	for y in token_image.get_height():
		for x in token_image.get_width():
			var c: Color = token_image.get_pixel(x, y)
			if c.a > 0.5:
				red_sum += Vector3(c.r, c.g, c.b)
				opaque += 1
	var mean := red_sum / maxf(float(opaque), 1.0)
	print("bell token: opaque=", opaque, " mean_rgb=(", snappedf(mean.x, 0.01), ",", snappedf(mean.y, 0.01),
		",", snappedf(mean.z, 0.01), ")")
	ok = ok and opaque > 500 and mean.x > 0.6 and mean.x - mean.y > 0.3 and mean.x - mean.z > 0.35
	# ⚠ and it is hidden the moment the cat stops standing in its plain idle (another pose paints the bell
	# somewhere else), so it can never be clicked in the wrong place. The bag is still OPEN here, so the bell is
	# legitimately hidden - the positive case is checked after the bag closes.
	cat.set("is_dragging", true)
	ok = ok and not bool(cat.call("is_bell_available"))
	level.call("_position_fridge_popups")
	print("bell while dragging: available=", cat.call("is_bell_available"), " visible=", bell.visible)
	ok = ok and not bell.visible
	cat.set("is_dragging", false)

	# ---------- closing the mouth hides the nose again ----------
	level.call("_on_fridge_item_toolbar_close_pressed")
	level.call("_position_fridge_popups")
	print("visible_after_close=", nose.visible)
	ok = ok and not nose.visible

	# ---------- 4b. 铃铛 visible again once the cat is back to its plain idle ----------
	for i in 3:
		await process_frame
	level.call("_position_fridge_popups")
	print("bell with the bag shut: available=", cat.call("is_bell_available"), " visible=", bell.visible)
	ok = ok and bool(cat.call("is_bell_available")) and bell.visible

	print("CAT_NOSE_REFRESH_TEST=", "PASS" if ok else "FAIL")
	level.queue_free()
	await process_frame
	quit(0)


## Point-in-polygon for the click-through region (⚠ Rect2.has_point EXCLUDES the far edge).
func _point_in_polygon(polygon: PackedVector2Array, point: Vector2) -> bool:
	var inside := false
	var count := polygon.size()
	var j := count - 1
	for i in count:
		var a := polygon[i]
		var b := polygon[j]
		if ((a.y > point.y) != (b.y > point.y)) \
				and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside