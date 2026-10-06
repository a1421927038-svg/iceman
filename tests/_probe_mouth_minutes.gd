extends SceneTree

## 数字 probe: checks the cat's mouth and the notebook's 猫嘴物品 page.
##  * the mouth has 4 balls (no 随身听 / 录像带), each with an EMPTY tooltip and a minutes digit that
##    reads 1 / 2 / 3 / 4 for 番茄钟 / 磁带机 / 寻呼机 / 显像管电视 (1 = 1 分钟 ... 4 = 4 分钟);
##  * each ball merges its minutes digit into the token as 融在一起: a scalloped paper plate riding the
##    ball's top edge, a dark medallion punched into it and a gold digit inside (no floating numeral);
##  * the 猫嘴物品 page carries NO 数字 badge under its icons any more;
##  * the page's hover box prints the item's 名称 on top and its 描述 below, with the 持续时间
##    appended inside the description ("基础待机动画 · 30 秒").

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var panel: Node = scene.get("fridge_gallery_panel")
	scene.call("_on_fridge_gallery_stand_toggled", true)
	await process_frame
	await process_frame
	panel.call("select_tab", "items")
	await process_frame
	await process_frame

	# ---- the mouth bag: no ball for the two excluded items, no hover tooltip, one minutes digit each ----
	var ok := true
	var balls: Array = scene.get("fridge_yarn_balls")
	var names: Array = []
	for ball in balls:
		names.append(str(ball.name))
	print("mouth balls=", names.size(), " ", names)
	print("has walkman ball=", "WalkmanYarnBall" in names, " vhs ball=", "VhsYarnBall" in names)
	if "WalkmanYarnBall" in names or "VhsYarnBall" in names or names.size() != 4:
		ok = false
	for ball in balls:
		var b := ball as Control
		var ball_minutes := int(b.get("minutes"))
		var expected_minutes: int = {"tomato": 1, "cassette": 2, "pager": 3, "crt": 4}.get(str(b.get("item_id")), 0)
		var want := int(scene.call("_fridge_item_minutes", str(b.get("item_id"))))
		print("%s: tooltip=", b.name, "\"", b.tooltip_text, "\" minutes=", ball_minutes,
			" (expect ", want, " / spec ", expected_minutes, ") tooltip_empty=", b.tooltip_text.is_empty())
		if not b.tooltip_text.is_empty() or ball_minutes != want or ball_minutes < 1:
			ok = false
		if ball_minutes != expected_minutes:
			ok = false
		# 融在一起: the number is now a scalloped paper plate riding the ball's TOP edge, with a dark
		# medallion punched into it and a gold digit inside. Check the whole stack is coherent: the
		# plate smaller than the ball and centred ON its top edge, the medallion inside the plate, and
		# the digit's ink (cap height, not the line ascent) inside the medallion with its outline.
		var ball_consts: Dictionary = (b.get_script() as Script).get_script_constant_map()
		var radius := float(b.get("radius"))
		var plate_r: float = radius * float(ball_consts.get("MINUTES_PLATE_FRAC", 0.38))
		var stand := float(ball_consts.get("MINUTES_PLATE_STAND_FRAC", 1.0))
		var medal_r: float = plate_r * float(ball_consts.get("MINUTES_MEDALLION_FRAC", 0.66))
		var edge := float(ball_consts.get("MINUTES_PLATE_EDGE_FRAC", 1.10))
		var lobes := int(ball_consts.get("MINUTES_PLATE_LOBES", 9))
		var outline := int(ball_consts.get("MINUTES_OUTLINE_SIZE", 0))
		var font := b.get_theme_default_font()
		var font_size := int(ball_consts.get("MINUTES_FONT_SIZE", 17))
		var cap: float = float(font_size) * 0.72
		var text_width: float = font.get_string_size(str(ball_minutes), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 0.0
		print("   融在一起: plate_r=", plate_r, " medal_r=", medal_r, " ball_r=", radius,
			" plate_on_top_edge=", stand == 1.0, " medal_inside=", medal_r < plate_r,
			" digit_cap=", cap, " digit_width=", text_width,
			" digit_fits=", cap + float(outline) < medal_r * 2.0 and text_width < medal_r * 2.0,
			" rim=", edge, " lobes=", lobes, " outline=", outline)
		if font == null or plate_r >= radius or medal_r >= plate_r:
			ok = false
		if stand <= 0.5 or edge <= 1.0 or lobes < 6 or outline < 1:
			ok = false
		if cap + float(outline) >= medal_r * 2.0 or text_width >= medal_r * 2.0:
			ok = false

	# ---- the book's 猫嘴物品 page: NO badge under the icons, and the hover box carries the
	#      名称 + the 描述 (the 持续时间 lives inside the description) ----
	var cards: Dictionary = panel.get("_cards")
	var icons: Dictionary = panel.get("_icons")
	var page_entries: Array = panel.call("get_tab_entries", "items")
	for entry: Dictionary in page_entries:
		var entry_id := str(entry.get("id", ""))
		if not str(entry.get("badge", "")).is_empty():
			ok = false
			print("  ! the page still carries a badge field: ", entry_id)
		var card: Control = cards.get(entry_id, null)
		var entry_icon: Control = icons.get(entry_id, null)
		var badge_nodes := 0
		if entry_icon != null:
			for sibling in entry_icon.get_parent().get_children():
				if sibling is Label and str(sibling.name).begins_with("CellBadge"):
					badge_nodes += 1
		print("%s: card=%s icon=%s badge_nodes=%d" % [entry_id,
			card.get_global_rect() if card != null else Rect2(),
			entry_icon.get_global_rect() if entry_icon != null else Rect2(), badge_nodes])
		if badge_nodes != 0:
			ok = false

	# ---- the hover box on an ITEM card: 名称 on top, 描述 (with the 持续时间) below ----
	panel.call("_on_card_hover", "item_tomato", true)
	await process_frame
	var tooltip: Control = panel.get("_tooltip")
	var tooltip_name: Label = panel.get("_tooltip_name")
	var tooltip_desc: Label = panel.get("_tooltip_desc")
	var item_tip: bool = tooltip != null and tooltip.visible
	var box_name := tooltip_name.text if tooltip_name != null else "<none>"
	var box_desc := tooltip_desc.text if tooltip_desc != null else "<none>"
	print("hover box: visible=", item_tip, " name=\"", box_name, "\" desc=\"", box_desc, "\"")
	ok = ok and item_tip and box_name == "番茄钟" and box_desc == "基础待机动画 · 1 分钟"
	panel.call("_on_card_hover", "item_tomato", false)
	scene.call("_on_fridge_gallery_stand_toggled", false)
	await process_frame
	await process_frame
	scene.call("_on_fridge_gallery_stand_toggled", true)
	await process_frame
	await process_frame
	panel.call("select_tab", "skeleton")
	await process_frame
	await process_frame
	var skeleton_entries: Array = panel.call("get_tab_entries", "skeleton")
	var skeleton_id := str((skeleton_entries[0] as Dictionary).get("id", ""))
	panel.call("_on_card_hover", skeleton_id, true)
	await process_frame
	var skeleton_tip: bool = tooltip != null and tooltip.visible
	# The mouth BALLS have no tooltip at all (checked above); the book's 猫嘴物品 page keeps its own
	# 悬停说明框 (the user asked for it) and a skeleton card still pops it too.
	print("item card box=", item_tip, " (checked above)  skeleton card ", skeleton_id, "=",
		skeleton_tip, " (expect true)")
	ok = ok and skeleton_tip
	print("MOUTH_MINUTES_PROBE=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit()