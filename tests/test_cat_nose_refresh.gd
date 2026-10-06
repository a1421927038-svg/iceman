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

	# ---------- closing the mouth hides the nose again ----------
	level.call("_on_fridge_item_toolbar_close_pressed")
	level.call("_position_fridge_popups")
	print("visible_after_close=", nose.visible)
	ok = ok and not nose.visible

	print("CAT_NOSE_REFRESH_TEST=", "PASS" if ok else "FAIL")
	level.queue_free()
	await process_frame
	quit(0)