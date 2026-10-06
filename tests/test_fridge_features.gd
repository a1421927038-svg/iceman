extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := true

	# ---------- player: juggle atlas + hit frame + default projectile + ending ----------
	var player_script: GDScript = load("res://scripts/FridgePomodoroPlayer.gd")
	var player: Node = player_script.new()
	get_root().add_child(player)
	await process_frame
	await process_frame
	var anim: AnimatedSprite2D = player.get_node("Sprite") as AnimatedSprite2D
	var sf: SpriteFrames = anim.sprite_frames
	var juggle_frames: int = sf.get_frame_count("tomato_juggle")
	var has_hit: bool = sf.has_animation("face_hit")
	var default_proj: String = str(player.get("juggle_projectile_id"))
	print("juggle_frames=", juggle_frames, " has_hit=", has_hit, " default_projectile=", default_proj)
	ok = ok and juggle_frames == 4 and has_hit and default_proj == "tomato"

	var counter := {"n": 0}
	player.performance_finished.connect(func() -> void: counter["n"] += 1)
	player.call("play_ball_drop_ending")
	var active_start: bool = bool(player.get("ball_drop_active"))
	var guard := 0
	while bool(player.get("ball_drop_active")) and guard < 300:
		await process_frame
		guard += 1
	var drop_anim: String = anim.animation
	print("drop started=", active_start, " frames=", guard, " anim_after=", drop_anim, " finished_emits=", counter["n"])
	ok = ok and active_start and guard < 300 and not bool(player.get("ball_drop_active")) and drop_anim == "idle" and int(counter["n"]) == 1

	# Projectiles rotate through the toss patterns (轮番播放). Whatever the shape of the
	# flight, every pattern must still put the objects INTO both raised palms
	# (x ~ -111 / +103) and arc above the head.
	player.call("play_juggle_preview", 60.0)
	var min_x := 9999.0
	var max_x := -9999.0
	var min_y := 9999.0
	var objects: Array = player.get("juggle_objects")
	var hand_left: Vector2 = FridgePomodoroPlayer.JUGGLE_HAND_LEFT
	var hand_right: Vector2 = FridgePomodoroPlayer.JUGGLE_HAND_RIGHT
	var pattern_time: float = FridgePomodoroPlayer.JUGGLE_PATTERN_TIME
	var patterns: Array = FridgePomodoroPlayer.JUGGLE_PATTERNS
	var missed: Array = []
	for pattern_index in patterns.size():
		var touched_left := false
		var touched_right := false
		var pattern_name: String = str((patterns[pattern_index] as Dictionary).get("name", "?"))
		for step in int(pattern_time * 50.0):
			player.set("juggle_motion", float(pattern_index) * pattern_time + float(step) * 0.02)
			player.call("_update_juggle_motion")
			for object_sprite in objects:
				var p: Vector2 = (object_sprite as Sprite2D).position
				min_x = min(min_x, p.x)
				max_x = max(max_x, p.x)
				min_y = min(min_y, p.y)
				if p.distance_to(hand_left) < 4.0:
					touched_left = true
				if p.distance_to(hand_right) < 4.0:
					touched_right = true
		if not (touched_left and touched_right):
			missed.append(pattern_name)
	print("projectiles x=[", min_x, ",", max_x, "] peak_y=", min_y, " patterns=", patterns.size(),
		" missing_a_hand=", missed)
	ok = ok and min_x <= -100.0 and max_x >= 95.0 and min_y <= -340.0 and missed.is_empty()

	player.queue_free()
	await process_frame

	# ---------- level: take-out plays immediately + tooltip ----------
	var packed: PackedScene = load("res://scenes/FridgeLevel.tscn")
	var level: Node = packed.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	# This test drives the real take-out path, which writes the save; keep the
	# player's own state (coins + active item) intact.
	var save_coins: int = int(level.get("fridge_coin_count"))
	var save_active_item: String = str(level.get("fridge_active_item_id"))
	var widgets: Dictionary = level.get("fridge_item_widgets")
	var tomato_ball: Control = (widgets.get("tomato", {}) as Dictionary).get("ball") as Control
	var tip: String = tomato_ball.tooltip_text if tomato_ball != null else ""
	# 数字: the mouth balls carry NO hover tooltip any more - each one prints how many MINUTES one
	# focused run lasts right under its logo (1 = 1 分钟, 2 = 2 分钟).
	var tip_lines := tip.split("\n")
	print("tomato ball: tooltip=", "<empty>" if tip.is_empty() else tip.replace("\n", " | "),
		" lines=", tip_lines.size(), " minutes=", tomato_ball.get("minutes") if tomato_ball != null else -1)
	var tip_ok := tip.is_empty() and tip_lines.size() == 1
	tip_ok = tip_ok and tomato_ball != null and int(tomato_ball.get("minutes")) == 1
	tip_ok = tip_ok and int(level.call("_fridge_item_minutes", "tomato")) == 1
	level.call("_on_fridge_yarn_ball_pressed", tomato_ball, Vector2.ZERO)
	await process_frame
	var panel: Control = level.get("fridge_item_panel") as Control
	var phase: String = str(level.get("fridge_phase"))
	var juggling_flag: bool = bool(level.get("fridge_player_juggling"))
	print("after take-out: phase=", phase, " panel_visible=", panel.visible, " juggling=", juggling_flag)
	var takeout_ok := phase == "work" and not panel.visible and juggling_flag
	ok = ok and tip_ok and takeout_ok

	# ---------- level: each item is a pomodoro of its OWN length ----------
	# 番茄钟 30 s and BB机 60 s are baked into the item; anything without its own
	# "duration" follows 专注秒数 from the settings panel.
	var settings_duration := float(level.get("fridge_work_duration"))
	var duration_map: Dictionary = {}
	for entry: Dictionary in (level.get_script() as Script).get_script_constant_map().get("FRIDGE_ITEMS", []):
		duration_map[str(entry["id"])] = level.call("_get_fridge_item_duration", str(entry["id"]))
	var tomato_left := float(level.get("fridge_time_left"))
	print("item durations=", duration_map, " settings=", settings_duration)
	print("tomato session: time_left=", snappedf(tomato_left, 0.01),
		" | 30->", level.call("_format_fridge_duration", 30.0),
		" 60->", level.call("_format_fridge_duration", 60.0),
		" 90->", level.call("_format_fridge_duration", 90.0))
	ok = ok and absf(tomato_left - 60.0) <= 0.5
	# 嘴里的四个物品固定 1 / 2 / 3 / 4 分钟，各自有自己的 duration；随身听/录像带没有，跟随专注秒数
	ok = ok and float(duration_map.get("tomato", 0.0)) == 60.0
	ok = ok and float(duration_map.get("cassette", 0.0)) == 120.0
	ok = ok and float(duration_map.get("pager", 0.0)) == 180.0
	ok = ok and float(duration_map.get("crt", 0.0)) == 240.0
	ok = ok and float(duration_map.get("walkman", 0.0)) == settings_duration
	ok = ok and str(level.call("_format_fridge_duration", 60.0)) == "1 分钟"
	ok = ok and str(level.call("_format_fridge_duration", 240.0)) == "4 分钟"
	ok = ok and str(level.call("_format_fridge_duration", 90.0)) == "1 分 30 秒"

	var pager_ball: Control = (widgets.get("pager", {}) as Dictionary).get("ball") as Control
	var pager_tip: String = pager_ball.tooltip_text if pager_ball != null else ""
	print("pager ball: tooltip=", "<empty>" if pager_tip.is_empty() else pager_tip.replace("\n", " | "),
		" minutes=", pager_ball.get("minutes") if pager_ball != null else -1)
	ok = ok and pager_tip.is_empty()
	# BB机 is 180 秒 = 3 分钟
	ok = ok and pager_ball != null and int(pager_ball.get("minutes")) == 3

	# ...and a real session's countdown comes from the item, not the settings default.
	level.set("fridge_phase", "idle")
	level.set("fridge_active_item_id", "pager")
	level.call("_start_fridge_session")
	var pager_left := float(level.get("fridge_time_left"))
	print("pager session: time_left=", pager_left)
	ok = ok and absf(pager_left - 180.0) <= 0.5
	level.set("fridge_phase", "idle")
	level.call("_refresh_fridge_ui")

	# ---------- 道具箱: the action logos run across the TOP ROW and the tray below shows the
	# chosen action's own items in a 3x3 of compartments ----------
	var box_panel: Control = level.get("fridge_box_panel") as Control
	# 向下箭头 is the BOOK's pulsing scroll hint - the prop box must never build one.
	var box_arrow: Node = box_panel.find_child("ScrollArrow", true, false) if box_panel != null else null
	print("prop box scroll arrow node=", box_arrow != null, " (expect false)")
	ok = ok and box_arrow == null
	var level_consts: Dictionary = (level.get_script() as Script).get_script_constant_map()
	var box_entries: Array = level_consts.get("FRIDGE_BOX_ENTRIES", [])
	var payloads: Dictionary = level_consts.get("FRIDGE_SPRAY_PAYLOADS", {})
	var panel_consts: Dictionary = (load("res://addons/骨骼动画/action_gallery_panel.gd") as Script).get_script_constant_map()
	# 上面一排: the row shows ACTION_PAGE_SIZE logos at a time and the wheel turns the page.
	var page_size: int = int(panel_consts.get("ACTION_PAGE_SIZE", 3))
	var entries_ok := box_entries.size() == 6
	var group_count := 0
	var group_sizes: Array = []
	var action_names: Array = []
	var action_keys: Array = []
	var last_icon := ""
	for entry: Dictionary in box_entries:
		var icon := str(entry.get("action_icon", ""))
		entries_ok = entries_ok and not icon.is_empty() and not str(entry.get("action_name", "")).is_empty()
		entries_ok = entries_ok and FileAccess.file_exists(icon)
		if icon != last_icon:
			group_count += 1
			group_sizes.append(0)
			action_keys.append(icon)
			action_names.append(str(entry.get("action_name", "")))
			last_icon = icon
		group_sizes[group_sizes.size() - 1] = int(group_sizes[group_sizes.size() - 1]) + 1
	var found: Dictionary = {}
	if box_panel != null:
		box_panel.visible = true
		await process_frame
		await process_frame
		_collect_box_widgets(box_panel, found)
	print("prop box: entries=", box_entries.size(), " groups=", group_count, group_sizes,
		" selectors=", found.get("selectors", 0), " grid_columns=", found.get("grid_columns", 0),
		" action_buttons=", found.get("buttons", 0),
		" item_icons=", found.get("icons", 0),
		" tray_cells=", found.get("cells", 0), " empty=", found.get("empty_slots", 0),
		" labels=", found.get("labels", []))
	# 猫嘴里的动画: FOUR actions now - 抛球杂耍 and BB机来讯 (two cards each), plus the two items the
	# cat's bag gained later (磁带机 / 电视机), which show ONLY the one replacement each unlocks
	# (音乐符号 / 乌篷船): 不要显示自己的图标, because the lid's own logo already IS that item.
	ok = ok and entries_ok and group_count == 4 and group_sizes == [2, 2, 1, 1]
	# 上面一排: one BUTTON per action, but only ACTION_PAGE_SIZE of them fit on a page - the row shows
	# the first three and the wheel turns to the fourth. The row is furniture above ONE item grid (a
	# 3x2 tray), and only the chosen action's items are built into it.
	ok = ok and int(found.get("selectors", 0)) == 1 and int(found.get("grids", 0)) == 1
	ok = ok and int(found.get("grid_columns", 0)) == int(level_consts.get("FRIDGE_BOX_GRID_COLUMNS", 0))
	ok = ok and int(found.get("buttons", 0)) == mini(group_count, page_size)
	ok = ok and int(found.get("icons", 0)) == int(group_sizes[0])
	# 公文包格子: the tray is a FIXED grid (the level's FRIDGE_BOX_GRID_COLUMNS x FRIDGE_BOX_GRID_ROWS) whose
	# unused slots are drawn as EMPTY compartments, the way the reference briefcase shows them.
	var tray_cells: int = int(level_consts.get("FRIDGE_BOX_GRID_COLUMNS", 0)) \
		* int(level_consts.get("FRIDGE_BOX_GRID_ROWS", 0))
	ok = ok and tray_cells > 0 and int(found.get("cells", 0)) == tray_cells
	ok = ok and int(found.get("empty_slots", 0)) == tray_cells - int(group_sizes[0])
	ok = ok and int(found.get("action_icons", 0)) == mini(group_count, page_size)
	# 只留图标: neither the action buttons nor the cells print a name any more - the art alone, with
	# the name popping up in the hover tooltip. So the only Label left in the box is its title.
	ok = ok and int(found.get("names", 0)) == 0
	# 公文包: the board IS the opened case - and 去掉标题 means the lid carries no word at all now,
	# so there is no title Label and no drawn title text either.
	if box_panel != null:
		ok = ok and bool(box_panel.get("_board_case"))
		ok = ok and not bool(box_panel.get("_show_title"))
		ok = ok and str(box_panel.get("_title_text")) == ""
	# 不弹提示框: the box builds NO hover tooltip at all - hovering an item shows nothing.
	var box_tooltip := false
	if box_panel != null:
		box_tooltip = box_panel.find_child("HoverTooltip", true, false) != null
		ok = ok and not bool(box_panel.get("_hover_tooltip"))
	ok = ok and not box_tooltip
	print("prop box 不弹提示框: tooltip_node=", box_tooltip,
		" enabled=", box_panel.get("_hover_tooltip") if box_panel != null else null)
	ok = ok and not (found.get("labels", []) as Array).has("道具箱")
	for entry: Dictionary in box_entries:
		ok = ok and not (found.get("labels", []) as Array).has(str(entry.get("name", "")))
		ok = ok and not (found.get("labels", []) as Array).has(str(entry.get("action_name", "")))
	# 打开时左侧停在手上物品所属的那个动作: fridge_box_selected_id is 番茄, so the 抛球杂耍 items are
	# the ones on show - the other action's items are not built at all.
	var expected_cards: Array = []
	for entry: Dictionary in box_entries:
		if str(entry.get("action_name", "")) == str(action_names[0]):
			expected_cards.append(str(entry.get("id", "")))
	if box_panel != null:
		ok = ok and str(box_panel.call("get_active_action")) == str(action_keys[0])
		ok = ok and (box_panel.get("_cards") as Dictionary).keys() == expected_cards

	# 纸片格子: every card is a debossed paper pocket and the one in hand wears the
	# orange frame. The art is loaded raw on disk, so identify it by its pixels: a
	# plain pocket's centre is cream, the chosen pocket's is pale butter-yellow.
	var cell_cream := 0
	var cell_framed := 0
	var cell_cards: Array = []
	for entry_node: Node in box_panel.find_children("", "PanelContainer", true, false):
		# Only real cells: find_children() also reports the panel itself, the
		# scroll container's built-in "_focus" node and the hover tooltip, none of
		# which is a card.
		if entry_node == box_panel or entry_node.name == "_focus" or entry_node.name == "HoverTooltip":
			continue
		# 左侧按钮: the action buttons are PanelContainers wearing the paper-button art, NOT cells.
		if str(entry_node.name).begins_with("ActionButton"):
			continue
		cell_cards.append(entry_node)
	for cell_node: Node in cell_cards:
		var cell_style := (cell_node as Control).get_theme_stylebox("panel")
		if not (cell_style is StyleBoxTexture):
			continue
		var cell_texture := (cell_style as StyleBoxTexture).texture
		if cell_texture == null:
			continue
		var cell_image := cell_texture.get_image()
		if cell_image == null:
			continue
		var centre := cell_image.get_pixel(cell_image.get_width() / 2, cell_image.get_height() / 2)
		print("  cell art size=", cell_texture.get_size(), " centre=", centre)
		if centre.b < 0.70 and centre.r > 0.90:
			cell_framed += 1
		else:
			cell_cream += 1
	print("prop box cells: ", cell_cream + cell_framed, " pockets=", cell_cream,
		" background-highlights=", cell_framed, " (selected=", level.get("fridge_box_selected_id"), ")")
	ok = ok and cell_cream + cell_framed == int(found.get("cells", 0))
	# 去掉背景高亮: no cell wears a highlight any more - they are all the same paper,
	# and the item in hand shows through its larger icon instead.
	ok = ok and cell_framed == 0 and cell_cream == int(found.get("cells", 0))

	# 悬停: the cell's icon eases larger while the pointer is over the card and back
	# down when it leaves. The box panel is stubbed with the hover calls the engine
	# would make, because a headless run has no real pointer.
	var hover_card: Control = null
	for cell_node: Node in cell_cards:
		if str(cell_node.name).begins_with("Tomato"):
			hover_card = cell_node as Control
	var hover_icon: TextureRect = null
	if hover_card != null:
		for node: Node in hover_card.find_children("", "TextureRect", true, false):
			hover_icon = node as TextureRect
	var rest_scale: float = hover_icon.scale.x if hover_icon != null else 0.0
	if box_panel != null:
		box_panel.call("_on_card_hover", "tomato", true)
	for i in range(60):
		await process_frame
	var hover_scale: float = hover_icon.scale.x if hover_icon != null else 0.0
	if box_panel != null:
		box_panel.call("_on_card_hover", "tomato", false)
	for i in range(60):
		await process_frame
	var back_scale: float = hover_icon.scale.x if hover_icon != null else 0.0
	print("prop box hover: icon scale rest=", snappedf(rest_scale, 0.01),
		" hovered=", snappedf(hover_scale, 0.01), " back=", snappedf(back_scale, 0.01))
	ok = ok and hover_icon != null and hover_scale > rest_scale + 0.10 and back_scale < hover_scale - 0.10

	# 左侧按钮点击: pressing the OTHER action's button swaps the right-hand cells over to that
	# action's items, and drops the previous action's cells entirely. The press goes through the
	# button's own gui_input handler, which is what the engine would call on a real click.
	var other_button: Control = null
	if box_panel != null:
		other_button = box_panel.find_child("ActionButton1", true, false) as Control
	if other_button != null:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		other_button.gui_input.emit(press)
	for i in range(4):
		await process_frame
	var swapped: Dictionary = {}
	if box_panel != null:
		_collect_box_widgets(box_panel, swapped)
	print("prop box 切换动作: button=", other_button != null,
		" active=", box_panel.call("get_active_action") if box_panel != null else "",
		" item_icons=", swapped.get("icons", 0), " labels=", swapped.get("labels", []))
	ok = ok and other_button != null
	if box_panel != null:
		ok = ok and str(box_panel.call("get_active_action")) == str(action_keys[1])
		# The item in hand does not change: 番茄 is simply not on the page on show.
		ok = ok and str(box_panel.call("get_selected")) == "tomato"
	ok = ok and int(swapped.get("icons", 0)) == int(group_sizes[1])
	var expected_swapped: Array = []
	for entry: Dictionary in box_entries:
		if str(entry.get("action_name", "")) == str(action_names[1]):
			expected_swapped.append(str(entry.get("id", "")))
	if box_panel != null:
		ok = ok and (box_panel.get("_cards") as Dictionary).keys() == expected_swapped

	# 悬停放大: the action button's LOGO eases larger under the pointer and back down, exactly like a
	# cell's icon - it is the only hover feedback the left column has.
	var action_icons: Dictionary = (box_panel.get("_action_icons") as Dictionary) if box_panel != null else {}
	var action_icon: TextureRect = action_icons.get(str(action_keys[0]), null) as TextureRect
	var action_rest: float = action_icon.scale.x if action_icon != null else 0.0
	if box_panel != null:
		box_panel.call("_on_action_button_hover", str(action_keys[0]), true)
	for i in range(60):
		await process_frame
	var action_hovered: float = action_icon.scale.x if action_icon != null else 0.0
	if box_panel != null:
		box_panel.call("_on_action_button_hover", str(action_keys[0]), false)
	for i in range(60):
		await process_frame
	var action_back: float = action_icon.scale.x if action_icon != null else 0.0
	print("prop box 动作按钮悬停: logo scale rest=", snappedf(action_rest, 0.01),
		" hovered=", snappedf(action_hovered, 0.01), " back=", snappedf(action_back, 0.01))
	ok = ok and action_icon != null and action_hovered > action_rest + 0.10 \
		and action_back < action_hovered - 0.10

	# 只选不演: 音乐符号 and 乌篷船 are the two replacements the later cat-mouth items unlock. The box
	# lists them as cards, but picking one must NOT play anything - unlike 球 / 番茄 / 字体 / 泡泡,
	# which swap a projectile or a payload, these only mark the item in hand.
	var box_player: Node = level.get("fridge_player") as Node
	var box_played: Array = []
	for entry_id: String in ["cassette_note", "tv_boat"]:
		# Clear both preview clocks first, so the checks below can only fail if THIS press started one.
		box_player.set("cassette_preview_timer", 0.0)
		box_player.set("tv_preview_timer", 0.0)
		level.call("_on_fridge_box_entry_pressed", entry_id)
		await process_frame
		await process_frame
		box_played.append({
			"id": entry_id,
			"cassette_preview": float(box_player.get("cassette_preview_timer")),
			"tv_preview": float(box_player.get("tv_preview_timer")),
			"dancing": bool(box_player.call("is_cassette_dancing")),
			"fishing": bool(box_player.call("is_tv_fishing")),
			"selected": str(level.get("fridge_box_selected_id")),
		})
		for i in range(2):
			await process_frame
	print("prop box 猫嘴物品: ", box_played)
	for played: Dictionary in box_played:
		ok = ok and str(played.get("selected")) == str(played.get("id"))
		ok = ok and float(played.get("cassette_preview")) <= 0.0
		ok = ok and float(played.get("tv_preview")) <= 0.0
		ok = ok and not bool(played.get("dancing")) and not bool(played.get("fishing"))

	# 从左到右: the action row's own flashing hint - a RIGHT-pointing paper arrow at its end, on show
	# while the row really does hold another page of logos. A click on it turns the row to that page,
	# exactly like one wheel notch, so the actions that do not fit stay reachable by mouse alone.
	var row_arrow: Control = box_panel.find_child("ActionArrow", true, false) as Control if box_panel != null else null
	print("prop box 从左到右: node=", row_arrow != null,
		" dir=", row_arrow.get("dir") if row_arrow != null else Vector2.ZERO,
		" visible=", row_arrow.visible if row_arrow != null else false)
	ok = ok and row_arrow != null
	if row_arrow != null and box_panel != null:
		ok = ok and (row_arrow.get("dir") as Vector2) == Vector2.RIGHT
		# 白边: the case's arrow carries NO pale halo (it read as a white outline on the leather).
		ok = ok and not bool(row_arrow.get("halo"))
		ok = ok and row_arrow.visible
		ok = ok and row_arrow.mouse_filter == Control.MOUSE_FILTER_STOP
		# 上边: it hangs ABOVE the row, and its INK (not its padded box - see _ScrollArrow.ink_bottom) stays
		# clear of the row's logos, which are inset in their own buttons. That is what lets the row rise.
		var panel_origin: Vector2 = box_panel.global_position
		var row_rect: Rect2 = (box_panel.get("_action_row") as Control).get_global_rect()
		var arrow_rect: Rect2 = row_arrow.get_global_rect()
		var icon_size: Vector2 = panel_consts.get("ACTION_BUTTON_ICON_SIZE", Vector2(48, 48))
		var button_height: float = float(panel_consts.get("ACTION_BUTTON_HEIGHT", 62))
		var logo_inset: float = maxf((button_height - icon_size.y) * 0.5, 0.0)
		var ink_bottom: float = arrow_rect.position.y - panel_origin.y + float(row_arrow.call("ink_bottom"))
		var logo_top: float = row_rect.position.y - panel_origin.y + logo_inset
		print("prop box 从左到右 位置: arrow=", arrow_rect, " ink_bottom=", snappedf(ink_bottom, 0.01),
			" row=", row_rect, " logo_top=", snappedf(logo_top, 0.01))
		ok = ok and ink_bottom <= logo_top
		# 红框位置: it sits in the panel's TOP-RIGHT corner - beside the last logo, not centred over the row.
		var right_margin: float = float(panel_consts.get("ACTION_ARROW_RIGHT_MARGIN", 8.0))
		var top_margin: float = float(panel_consts.get("ACTION_ARROW_TOP_MARGIN", 8.0))
		ok = ok and arrow_rect.get_center().x > panel_origin.x + box_panel.size.x * 0.5
		ok = ok and absf(panel_origin.x + box_panel.size.x - arrow_rect.end.x - right_margin) <= 1.5
		ok = ok and absf(arrow_rect.position.y - panel_origin.y - top_margin) <= 1.5
		ok = ok and arrow_rect.position.y >= panel_origin.y
		# 不够亮 / 不够闪烁 / 透明度加大 / 白色: the case's arrow pulses over a WIDER swing than the book's slow
		# 若隐若现, quicker, and its ink is paper WHITE rather than the book's dark brown.
		var book_faint: float = float(panel_consts.get("SCROLL_ARROW_FAINT_ALPHA", 0.15))
		var book_strong: float = float(panel_consts.get("SCROLL_ARROW_STRONG_ALPHA", 0.95))
		var book_fade: float = float(panel_consts.get("SCROLL_ARROW_FADE_TIME", 1.1))
		var swing: float = float(row_arrow.get("strong_alpha")) - float(row_arrow.get("faint_alpha"))
		var book_swing: float = book_strong - book_faint
		var row_ink: Color = row_arrow.get("ink")
		print("prop box 从左到右 闪烁: faint=", row_arrow.get("faint_alpha"), " strong=",
			row_arrow.get("strong_alpha"), " fade=", row_arrow.get("fade_time"), " ink=", row_ink,
			" swing=", snappedf(swing, 0.001), " (book swing ", snappedf(book_swing, 0.001), ")")
		ok = ok and float(row_arrow.get("strong_alpha")) >= book_strong
		ok = ok and swing > book_swing
		ok = ok and minf(minf(row_ink.r, row_ink.g), row_ink.b) > 0.9
		ok = ok and float(row_arrow.get("fade_time")) < book_fade
		# 整体缩小: the box's arrow is SMALLER than the book's, while keeping its shape/style.
		var book_arrow_size: Vector2 = panel_consts.get("SCROLL_ARROW_SIZE", Vector2.ZERO)
		var row_arrow_size: Vector2 = panel_consts.get("ACTION_ARROW_SIZE", Vector2.ZERO)
		print("prop box 从左到右 尺寸: arrow=", row_arrow_size, " (book ", book_arrow_size, ")")
		ok = ok and row_arrow_size.x > 0.0 and row_arrow_size.x < book_arrow_size.x
		ok = ok and row_arrow.size == row_arrow_size
		# 图标太大: the action buttons and the logos inside them are smaller than they were (56 / 40).
		var row_icon: Vector2 = panel_consts.get("ACTION_BUTTON_ICON_SIZE", Vector2.ZERO)
		var row_button := Vector2(float(panel_consts.get("ACTION_BUTTON_WIDTH", 0.0)),
			float(panel_consts.get("ACTION_BUTTON_HEIGHT", 0.0)))
		print("prop box 动作图标尺寸: icon=", row_icon, " button=", row_button)
		ok = ok and row_icon == Vector2(40.0, 40.0) and row_button == Vector2(56.0, 56.0)
		# The row follows whichever card was picked last, so the page it starts on is not fixed - only
		# that a click TURNS it and a second click turns it back.
		var page_start: int = int(box_panel.get("_action_page"))
		var page_before: Array = (box_panel.get("_action_buttons") as Dictionary).keys()
		var row_click := InputEventMouseButton.new()
		row_click.button_index = MOUSE_BUTTON_LEFT
		row_click.pressed = true
		row_arrow.gui_input.emit(row_click)
		for click_step in 3:
			await process_frame
		var page_mid: int = int(box_panel.get("_action_page"))
		var page_after: Array = (box_panel.get("_action_buttons") as Dictionary).keys()
		print("prop box 从左到右 点击: page ", page_start, " -> ", page_mid,
			" logos ", page_before, " -> ", page_after)
		ok = ok and page_mid != page_start
		ok = ok and page_after != page_before
		ok = ok and row_arrow.visible
		row_arrow.gui_input.emit(row_click)
		for click_step in 3:
			await process_frame
		print("prop box 从左到右 再点: page=", box_panel.get("_action_page"),
			" logos=", (box_panel.get("_action_buttons") as Dictionary).keys())
		ok = ok and int(box_panel.get("_action_page")) == page_start
		ok = ok and (box_panel.get("_action_buttons") as Dictionary).keys() == page_before

	# 上面一排 + 鼠标滑动: once the action list outgrows the row, the WHEEL turns to the next
	# ACTION_PAGE_SIZE logos (the 下拉 is gone), so actions added later stay reachable. Probed on a
	# throwaway panel - the box's own four actions are checked above.
	var panel_script: GDScript = load("res://addons/骨骼动画/action_gallery_panel.gd")
	var probe_panel: PanelContainer = panel_script.new()
	get_root().add_child(probe_panel)
	var probe_entries: Array = []
	for i in range(5):
		probe_entries.append({
			"id": "probe_%d" % i,
			"name": "物品%d" % i,
			"icon": str(box_entries[0].get("icon", "")),
			"action_id": "act%d" % i,
			"action_icon": str(action_keys[0]),
			"action_name": "动作%d" % i,
		})
	probe_panel.call("setup", "动作", probe_entries, {
		"action_selector": true,
		"show_title": false,
	})
	probe_panel.visible = true
	await process_frame
	await process_frame
	var probe_found: Dictionary = {}
	_collect_box_widgets(probe_panel, probe_found)
	# One wheel notch: the row turns to the page holding the last two actions.
	probe_panel.call("_page_actions", 1)
	for i in range(4):
		await process_frame
	var probe_after: Dictionary = {}
	_collect_box_widgets(probe_panel, probe_after)
	print("prop box 翻页: page1_buttons=", probe_found.get("buttons", 0),
		" page2_buttons=", probe_after.get("buttons", 0))
	ok = ok and int(probe_found.get("buttons", 0)) == 3
	# 5 actions -> the second page holds the last two.
	ok = ok and int(probe_after.get("buttons", 0)) == 2
	# Picking one of them shows that action's own item, and only it.
	var fifth: Control = probe_panel.find_child("ActionButton4", true, false) as Control
	if fifth != null:
		var probe_press := InputEventMouseButton.new()
		probe_press.button_index = MOUSE_BUTTON_LEFT
		probe_press.pressed = true
		fifth.gui_input.emit(probe_press)
	for i in range(4):
		await process_frame
	var probe_picked: Dictionary = {}
	_collect_box_widgets(probe_panel, probe_picked)
	print("prop box 翻页选中: active=", probe_panel.call("get_active_action"),
		" icons=", probe_picked.get("icons", 0), " labels=", probe_picked.get("labels", []))
	ok = ok and fifth != null
	ok = ok and str(probe_panel.call("get_active_action")) == "act4"
	ok = ok and int(probe_picked.get("icons", 0)) == 1
	ok = ok and (probe_picked.get("labels", []) as Array).has("物品4")
	ok = ok and not (probe_picked.get("labels", []) as Array).has("物品0")
	probe_panel.queue_free()
	for i in range(2):
		await process_frame

	# 泡泡 / 字体 both belong to the BB机 row: picking one swaps what the device
	# squirts out, while 球 / 番茄 swap the juggled projectile. The card in hand lights up.
	var bubble_payload: Dictionary = payloads.get("bubble", {})
	var text_payload: Dictionary = payloads.get("text", {})
	print("spray payloads: text_h=", text_payload.get("height", 0.0),
		" bubble_h=", bubble_payload.get("height", 0.0),
		" bubble_atlas=", bubble_payload.get("atlas", ""),
		" bubble_regions=", (bubble_payload.get("regions", []) as Array).size())
	ok = ok and str(bubble_payload.get("atlas", "")).ends_with("paper_spray_bubbles.png")
	ok = ok and (bubble_payload.get("regions", []) as Array).size() >= 6
	ok = ok and float(bubble_payload.get("height", 0.0)) < float(text_payload.get("height", 0.0))

	var spray: Node = level.get("fridge_spray")
	level.call("set_fridge_spray_payload", "text")
	level.call("_on_fridge_box_entry_pressed", "spray_bubble")
	var selected: String = str(box_panel.call("get_selected")) if box_panel != null else ""
	print("prop box 泡泡: selected=", selected, " spray_payload=", level.get("fridge_spray_payload_id"),
		" textures=", spray.call("texture_count") if spray != null else -1)
	ok = ok and selected == "spray_bubble" and str(level.get("fridge_spray_payload_id")) == "bubble"
	ok = ok and spray != null and int(spray.call("texture_count")) == 8
	level.call("_on_fridge_box_entry_pressed", "spray_text")
	print("prop box 字体: selected=", level.get("fridge_box_selected_id"),
		" spray_payload=", level.get("fridge_spray_payload_id"),
		" textures=", spray.call("texture_count"))
	ok = ok and str(level.get("fridge_box_selected_id")) == "spray_text"
	ok = ok and str(level.get("fridge_spray_payload_id")) == "text" and int(spray.call("texture_count")) == 15
	level.call("_on_fridge_box_entry_pressed", "ball")
	print("prop box 球: selected=", level.get("fridge_box_selected_id"))
	ok = ok and str(level.get("fridge_box_selected_id")) == "ball"
	level.call("_on_fridge_box_entry_pressed", "spray_text")

	# 泡泡 then 字体 must leave NOTHING of the bubbles behind: the two items are
	# separate payloads, so a spray built after picking 字体 takes every piece off the
	# glyph sheet (1024x1024) and none off the bubble sheet (1024x512).
	var spray_script: GDScript = load("res://scripts/FridgeGlyphSpray.gd")
	var probe: Node2D = spray_script.new()
	get_root().add_child(probe)
	probe.set("origin", Vector2.ZERO)
	probe.set("emitting", true)
	var sheets: Array = []
	probe.call("set_payload", payloads["bubble"])
	for i in range(30):
		probe.call("step", 0.05)
	_collect_spray_sheets(probe, sheets)
	print("spray probe on 泡泡: pieces=", probe.get_child_count(), " sheet sizes=", sheets)
	ok = ok and sheets.size() == 1 and sheets[0] == Vector2(1024.0, 512.0)
	sheets.clear()
	probe.call("set_payload", payloads["text"])
	probe.set("emitting", false)
	# Swapping drops the old pieces with queue_free(), which only takes effect at the
	# end of the frame, so let a frame pass before measuring.
	await process_frame
	await process_frame
	for i in range(8):
		probe.call("step", 0.05)
	_collect_spray_sheets(probe, sheets)
	print("spray probe drained after picking 字体: pieces=", probe.get_child_count(), " sheet sizes=", sheets)
	ok = ok and sheets.is_empty()
	probe.set("emitting", true)
	for i in range(30):
		probe.call("step", 0.05)
	sheets.clear()
	_collect_spray_sheets(probe, sheets)
	print("spray probe re-emitting on 字体: pieces=", probe.get_child_count(), " sheet sizes=", sheets)
	ok = ok and sheets.size() == 1 and sheets[0] == Vector2(1024.0, 1024.0)
	probe.queue_free()
	await process_frame

	level.set("fridge_coin_count", save_coins)
	level.set("fridge_active_item_id", save_active_item)
	level.call("_save_fridge_progress")
	print("FRIDGE_FEATURES_TEST=", "PASS" if ok else "FAIL")
	level.queue_free()
	await process_frame
	quit(0)


## Collects the distinct sheet sizes the spray's live pieces are cut from.
func _collect_spray_sheets(spray: Node, sheets: Array) -> void:
	for child in spray.get_children():
		if child is Sprite2D and (child as Sprite2D).texture is AtlasTexture:
			var atlas_tex: AtlasTexture = (child as Sprite2D).texture
			if atlas_tex.atlas == null:
				continue
			var sheet_size: Vector2 = atlas_tex.atlas.get_size()
			if not sheets.has(sheet_size):
				sheets.append(sheet_size)


## Collects the prop box's widgets: how many action buttons (or the dropdown) its left column laid
## out, how many item grids it holds, how many item icons are in them and which labels are inside.
func _collect_box_widgets(node: Node, found: Dictionary) -> void:
	if node.name == "TooltipHolder":
		# The hover tooltip is not part of the box's own layout.
		return
	if node.name == "ActionHolder":
		# 上面一排: the selector's one container - the action row, drawn on the case's LID.
		found["selectors"] = int(found.get("selectors", 0)) + 1
	elif node.name == "ActionItemGrid":
		found["grids"] = int(found.get("grids", 0)) + 1
		found["grid_columns"] = (node as GridContainer).columns
	elif str(node.name).begins_with("ActionButton"):
		# 左侧按钮: one per action. Counted by NAME - the button is a PanelContainer wearing the
		# paper-button art (it has to be, so its LOGO child can be scaled on hover), not a Button.
		found["buttons"] = int(found.get("buttons", 0)) + 1
	elif node.name == "ActionIcon":
		found["action_icons"] = int(found.get("action_icons", 0)) + 1
	elif node.name == "CellIcon":
		found["icons"] = int(found.get("icons", 0)) + 1
	# 公文包格子: every child of the item grid is a CELL - the filled ones and the EMPTY compartments the
	# tray pads itself with. Identified by its PARENT rather than by name, because Godot renames duplicate
	# sibling names ("EmptySlot" -> "@EmptySlot@2") and a name scan would miss half of them.
	elif node.get_parent() != null and node.get_parent().name == "ActionItemGrid":
		found["cells"] = int(found.get("cells", 0)) + 1
		if node.find_child("CellIcon", true, false) == null:
			found["empty_slots"] = int(found.get("empty_slots", 0)) + 1
	# 只留图标: a cell's own caption. The box prints none any more - its names live in the tooltip.
	if node.name == "CellName" or node.name == "CellDescription":
		found["names"] = int(found.get("names", 0)) + 1
	if node is Label:
		var texts: Array = found.get("labels", [])
		texts.append((node as Label).text)
		found["labels"] = texts
	for child in node.get_children():
		_collect_box_widgets(child, found)