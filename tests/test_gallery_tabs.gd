extends SceneTree

## 分页: the notebook's panel has two pages - 骨架 (the animation gallery) and 猫嘴物品 (every
## unlocked item). Covers that the tabs exist in order, that switching rebuilds the page in
## place, that the item page lists exactly the unlocked items with their icons, and that a
## click on an item card is inert. Also guards the 公文包 open art: the new handle-less art must
## put its case body on the same canvas geometry as the old one, or the box would jump/resize
## when it is opened.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := true
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	# 中英文切换: pin 中文 (without writing the player's save) - this suite compares the game's Chinese
	# descriptions, which must not depend on whichever language the player last picked.
	scene.call("_set_fridge_language", "zh", false)

	# 解锁进度: pin the FULLY UNLOCKED progress (without writing the player's save) - this suite reads
	# the gallery / the collection / the cat's mouth, which must not depend on how far the player has played.
	scene.call("_unlock_all_fridge_progress_for_tests")
	var save_coins: int = int(scene.get("fridge_coin_count"))
	var save_active_item: String = str(scene.get("fridge_active_item_id"))
	var save_work_duration: float = float(scene.get("fridge_work_duration"))
	var owned: Variant = scene.get("fridge_owned_items")
	var save_owned: Variant = (owned as Array).duplicate() if owned is Array else (owned as Dictionary).duplicate()

	var panel: Node = scene.get("fridge_gallery_panel")
	var level_consts: Dictionary = (scene.get_script() as Script).get_script_constant_map()

	# ---- 1) the panel has the tabs, 骨架 first, and 存档 (progress) at the bottom ----
	var tab_ids: Array = panel.call("get_tab_ids")
	print("tabs=", tab_ids, " active=", panel.call("get_active_tab"),
		" has_signal=", panel.has_signal("tab_changed"))
	ok = ok and tab_ids == ["skeleton", "items", "box", "progress"]
	ok = ok and str(panel.call("get_active_tab")) == "skeleton"
	ok = ok and panel.has_signal("tab_changed")
	# 公文包物品: the third tab lists every unlocked briefcase item with its own description
	var box_entries: Array = panel.call("get_tab_entries", "box")
	print("box page: ", box_entries.size(), " entries")
	ok = ok and box_entries.size() == 8
	for box_entry: Dictionary in box_entries:
		ok = ok and str(box_entry.get("id", "")).begins_with("box_")
		ok = ok and not str(box_entry.get("description", "")).is_empty()
		ok = ok and not str(box_entry.get("icon", "")).is_empty()

	# ---- 2) the 骨架 page is the animation gallery ----
	var skeleton: Array = panel.call("get_tab_entries", "skeleton")
	var gallery: Array = level_consts.get("FRIDGE_GALLERY_ENTRIES", [])
	print("skeleton page: ", skeleton.size(), " entries (gallery has ", gallery.size(), ")")
	ok = ok and skeleton.size() == gallery.size() and skeleton.size() > 0

	# ---- 3) the 猫嘴物品 page lists exactly the unlocked MOUTH items, each with its own icon.
	#         猫嘴里去掉: the 随身听 and the 录像带 are excluded from the cat's mouth, so they must
	#         not appear here even though they are owned. ----
	var items: Array = panel.call("get_tab_entries", "items")
	var owned_now: Array = scene.get("fridge_owned_items")
	var excluded: Array = level_consts.get("FRIDGE_MOUTH_EXCLUDED_ITEMS", [])
	var expected := 0
	var fridge_items: Array = level_consts.get("FRIDGE_ITEMS", [])
	for item: Dictionary in fridge_items:
		var wanted_id := str(item.get("id", ""))
		if owned_now.has(wanted_id) and not excluded.has(wanted_id):
			expected += 1
	print("items page: ", items.size(), " entries, expected ", expected, " owned=", owned_now,
		" mouth-excluded=", excluded)
	ok = ok and items.size() == expected and expected > 0
	ok = ok and not excluded.is_empty()

	# 数字: this page carries NO number badge any more - the item's 持续时间 is appended to the
	# 描述 the hover box prints instead. The walkman / vhs cards must still be gone.
	var item_names: Dictionary = {}
	var descriptions: Dictionary = {}
	for entry: Dictionary in items:
		var page_badge := str(entry.get("badge", ""))
		item_names[str(entry.get("id", ""))] = str(entry.get("name", ""))
		descriptions[str(entry.get("id", ""))] = str(entry.get("description", ""))
		if not page_badge.is_empty():
			ok = false
			print("  ! the page still carries a 数字 badge: ", entry.get("id", ""), " -> ", page_badge)
		for banned in excluded:
			if str(entry.get("id", "")) == "item_%s" % str(banned):
				ok = false
				print("  ! excluded item still on the page: ", entry.get("id", ""))
	print("items page names=", item_names)
	print("items page descriptions=", descriptions)
	# 悬停说明框: the name line is the item's own name (no reward suffix) and the 描述 line carries
	# the 持续时间 - the six mouth items run 1 / 2 / 3 / 4 / 5 / 6 分钟, so their descriptions say so.
	ok = ok and str(item_names.get("item_tomato", "")) == "番茄钟"
	ok = ok and str(descriptions.get("item_tomato", "")) == "基础待机动画 · 1 分钟"
	ok = ok and str(descriptions.get("item_cassette", "")).ends_with("2 分钟")
	ok = ok and str(descriptions.get("item_pager", "")).ends_with("3 分钟")
	ok = ok and str(descriptions.get("item_crt", "")).ends_with("4 分钟")
	ok = ok and str(descriptions.get("item_computer", "")).ends_with("5 分钟")
	ok = ok and str(descriptions.get("item_controller", "")).ends_with("6 分钟")
	# 数字: the mouth balls' plates must read the SAME six numbers
	var minutes_by_item: Dictionary = {}
	for mouth_id in ["tomato", "cassette", "pager", "crt", "computer", "controller"]:
		minutes_by_item[mouth_id] = int(scene.call("_fridge_item_minutes", mouth_id))
	print("mouth minutes 1..6=", minutes_by_item)
	ok = ok and int(minutes_by_item.get("tomato", 0)) == 1
	ok = ok and int(minutes_by_item.get("cassette", 0)) == 2
	ok = ok and int(minutes_by_item.get("pager", 0)) == 3
	ok = ok and int(minutes_by_item.get("crt", 0)) == 4
	ok = ok and int(minutes_by_item.get("computer", 0)) == 5
	ok = ok and int(minutes_by_item.get("controller", 0)) == 6
	# an item without its own duration still follows 专注秒数: 90 秒 -> 2 分钟
	scene.set("fridge_work_duration", 90.0)
	var walkman_two := int(scene.call("_fridge_item_minutes", "walkman"))
	scene.set("fridge_work_duration", save_work_duration)
	print("minutes helper: 90 秒 -> ", walkman_two, " 分钟 (expect 2)")
	ok = ok and walkman_two == 2
	for entry: Dictionary in items:
		var entry_id := str(entry.get("id", ""))
		var icon := str(entry.get("icon", ""))
		if not entry_id.begins_with("item_"):
			ok = false
			print("  ! bad id ", entry_id)
		if not icon.ends_with("paper_icon_%s.png" % entry_id.trim_prefix("item_")):
			ok = false
			print("  ! bad icon ", icon, " for ", entry_id)

	# ---- 3b) 分页书签: both tabs wear the bookmark art, and the CHOSEN one carries a different
	#          colour from the other (切换时颜色变化) ----
	var tab_a: Button = panel.find_child("SkeletonTab", true, false) as Button
	var tab_b: Button = panel.find_child("ItemsTab", true, false) as Button
	var tab_box: Button = panel.find_child("BoxTab", true, false) as Button
	var tab_c: Button = panel.find_child("ProgressTab", true, false) as Button
	var style_a: StyleBoxTexture = null
	var style_b: StyleBoxTexture = null
	var style_c: StyleBoxTexture = null
	if tab_a != null:
		style_a = tab_a.get_theme_stylebox("normal") as StyleBoxTexture
	if tab_b != null:
		style_b = tab_b.get_theme_stylebox("normal") as StyleBoxTexture
	if tab_c != null:
		style_c = tab_c.get_theme_stylebox("normal") as StyleBoxTexture
	print("bookmarks: art=", style_a.texture.get_size() if (style_a != null and style_a.texture != null) else "none",
		" min_size=", tab_a.custom_minimum_size if tab_a != null else Vector2.ZERO,
		" tints=", tab_a.modulate if tab_a != null else Color.WHITE, " / ",
		tab_b.modulate if tab_b != null else Color.WHITE)
	ok = ok and tab_a != null and tab_b != null and tab_box != null and tab_c != null
	# 进度在最下面: ProgressTab is the last child of TabRow
	ok = ok and tab_c.get_parent() != null and tab_c.get_index() == tab_c.get_parent().get_child_count() - 1
	ok = ok and style_a != null and style_a.texture != null and style_b != null and style_b.texture != null and style_c != null and style_c.texture != null
	# (each button loads its own texture instance, so compare the ART, not the object identity)
	# 横向放在右边: the art is rotated 90° to 160x70 so the horizontal strip keeps the V notch's shape.
	ok = ok and style_a.texture.get_size() == Vector2(160.0, 70.0) \
		and style_b.texture.get_size() == Vector2(160.0, 70.0)
	# 素净书签: a horizontal strip, and it carries NOTHING - no text and no icon (its colour and its
	# place in the column mark which page is on show)
	ok = ok and tab_a.custom_minimum_size == Vector2(140.0, 92.0 * 2.0 / 3.0)
	ok = ok and tab_a.icon == null and tab_b.icon == null
	ok = ok and tab_a.text.is_empty() and tab_b.text.is_empty()
	# 白色边缘: every bookmark button carries a white rim overlay (`TabBorder`)
	ok = ok and tab_a.find_child("TabBorder", false, false) != null \
		and tab_b.find_child("TabBorder", false, false) != null \
		and tab_box.find_child("TabBorder", false, false) != null \
		and tab_c.find_child("TabBorder", false, false) != null
	# 图层在书本页面下面、红色封面上面: TabHolder is NOT behind the panel (`show_behind_parent == false`)
	# and carries `TabPageCover` over the ribbons
	var tab_holder_node: Node2D = panel.find_child("TabHolder", true, false) as Node2D
	var page_cover_node: Control = panel.find_child("TabPageCover", true, false) as Control
	ok = ok and tab_holder_node != null and not tab_holder_node.show_behind_parent
	ok = ok and page_cover_node != null
	# 摊开的书 + 去掉边框: the board IS the open-book art, and the cells carry NO artwork - the icons
	# and names print straight onto the pages
	var board_style: StyleBoxTexture = panel.get_theme_stylebox("panel") as StyleBoxTexture
	var grid: GridContainer = null
	for node in panel.find_children("", "GridContainer", true, false):
		grid = node as GridContainer
	var bare_cells := 0
	var cells := 0
	if grid != null:
		cells = grid.get_child_count()
		for card in grid.get_children():
			if (card as Control).get_theme_stylebox("panel") is StyleBoxEmpty:
				bare_cells += 1
	print("board art=", board_style.texture.get_size() if (board_style != null and board_style.texture != null) else "none",
		" panel=", panel.size, " cells=", cells, " bare=", bare_cells)
	ok = ok and board_style != null and board_style.texture != null
	ok = ok and board_style.texture.get_size() == Vector2(768.0, 576.0)
	ok = ok and cells > 0 and bare_cells == cells
	# 把文字说明去掉: the book's cells carry NO text at all - the name and the 说明 live in the
	# hover tooltip instead
	var cell_labels := 0
	if grid != null:
		for card in grid.get_children():
			for holder in (card as Control).get_children():
				for part in holder.get_children():
					if part is Label:
						cell_labels += 1
	print("cell labels=", cell_labels)
	ok = ok and cell_labels == 0
	# 每次只加载4个: one wheel notch moves the list exactly one visible page - 2 rows x 2 columns
	var page_scroll: ScrollContainer = panel.find_child("EntryScroll", true, false) as ScrollContainer
	var card_size: Vector2 = level_consts.get("FRIDGE_GALLERY_BOOK_CARD_SIZE", Vector2.ZERO)
	var card_gap: float = float(level_consts.get("FRIDGE_GALLERY_BOOK_CARD_GAP", 8.0))
	var page_height: int = int(round(2.0 * card_size.y + card_gap))
	var scroll_before: int = page_scroll.scroll_vertical
	panel.call("page_by", 1)
	var scroll_after: int = page_scroll.scroll_vertical
	print("paging: ", scroll_before, " -> ", scroll_after, " (one page = ", page_height, ")")
	ok = ok and page_scroll != null and page_height > 0
	ok = ok and scroll_after - scroll_before == page_height
	panel.call("page_by", -1)
	ok = ok and page_scroll.scroll_vertical == scroll_before
	# 挂在上边: the bookmark row is NOT a laid-out child of the board's content column - it lives in
	# a plain holder so it can overlap the board's top edge. (The panel is not laid out yet at this
	# point, so this checks the structure; the real rects are checked once it is open, in step 7.)
	var content: VBoxContainer = null
	for child in panel.get_children():
		if child is VBoxContainer:
			content = child
	var order: Array = []
	if content != null:
		for child in content.get_children():
			order.append(str(child.name))
	var tab_row: Node = panel.find_child("TabRow", true, false)
	var scroll: Node = panel.find_child("EntryScroll", true, false)
	print("layout: content order=", order, " tab_row=", tab_row != null, " scroll=", scroll != null)
	ok = ok and tab_row != null and scroll != null
	# the bookmarks overlay the cover, so they live in a non-Control holder (a PanelContainer
	# would lay out a plain Control child and throw the rect away)
	ok = ok and not order.has("TabRow")
	ok = ok and tab_row.get_parent() != panel
	ok = ok and tab_row.get_parent().get_parent() == panel
	# 底部那段提示的字去掉: this panel shows no 下拉查看更多 line any more
	var hint_text := ""
	for child in panel.get_children():
		for grand in child.get_children():
			if grand is Label and str(grand.text).contains("下拉查看更多"):
				hint_text = str(grand.text)
	print("hint=", "none" if hint_text.is_empty() else hint_text)
	ok = ok and hint_text.is_empty()
	# 切换时颜色变化: the bookmarks wear different tints, and from left to right their active tints are
	# 绿 (skeleton) / 黄 (items) / 红 (progress)
	var tint_a: Color = style_a.modulate_color
	var tint_b: Color = style_b.modulate_color
	var ink_a: Color = tab_a.get_theme_color("font_color")
	var ink_b: Color = tab_b.get_theme_color("font_color")
	ok = ok and tint_a != tint_b
	# Tab 1 (skeleton, leftmost) is GREEN when active: g > r and g > b
	ok = ok and tint_a.g > tint_a.r and tint_a.g > tint_a.b
	ok = ok and ink_a != ink_b
	# the tint must live on the STYLEBOX, never on the button's own modulate (which would tint the
	# label as well and made the chosen bookmark's text unreadable)
	ok = ok and tab_a.modulate == Color(1.0, 1.0, 1.0, 1.0) \
		and tab_b.modulate == Color(1.0, 1.0, 1.0, 1.0)

	# ---- 4) switching rebuilds the page in place and announces itself ----
	var changed := [0]
	panel.tab_changed.connect(func(_id: String) -> void: changed[0] += 1)
	panel.call("select_tab", "items")
	await process_frame
	print("after select_tab(items): active=", panel.call("get_active_tab"),
		" signal_count=", changed[0], " size=", panel.size)
	ok = ok and str(panel.call("get_active_tab")) == "items"
	ok = ok and changed[0] == 1
	ok = ok and panel.size.x > 0.0 and panel.size.y > 0.0
	# ...only one page's worth of cards lives in the panel at a time
	var cards := 0
	for child in panel.get_children():
		for grand in child.get_children():
			if str(grand.name) == "EntryScroll":
				for page in grand.get_children():
					cards += 1
	print("pages inside the scroll: ", cards)
	ok = ok and cards <= 1
	# ...and Tab 2 (items, middle) wears YELLOW when active while Tab 1 returns to the idle tint
	var swapped_a: Color = (tab_a.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color
	var swapped_b: Color = (tab_b.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color
	print("bookmark tints after switch to items: ", swapped_a, " / ", swapped_b)
	ok = ok and swapped_a == tint_b
	ok = ok and swapped_b != tint_b and swapped_b != tint_a
	ok = ok and swapped_b.r > swapped_b.b and swapped_b.g > swapped_b.b
	# ...and Tab 3 (box) wears BLUE when active, and Tab 4 (progress, bottom) wears RED when active
	panel.call("select_tab", "box")
	await process_frame
	var box_tint: Color = (tab_box.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color
	ok = ok and changed[0] == 2
	ok = ok and box_tint.b > box_tint.r and box_tint.b > box_tint.g
	panel.call("select_tab", "progress")
	await process_frame
	var progress_c: Color = (tab_c.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color
	var progress_b: Color = (tab_b.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color
	print("bookmark tints after switch to progress: ", progress_b, " / ", progress_c)
	ok = ok and changed[0] == 3
	ok = ok and progress_b == tint_b
	ok = ok and progress_c.r > progress_c.g and progress_c.r > progress_c.b
	panel.call("select_tab", "skeleton")
	await process_frame
	ok = ok and str(panel.call("get_active_tab")) == "skeleton"
	ok = ok and changed[0] == 4
	ok = ok and (tab_a.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color == tint_a \
		and (tab_b.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color == tint_b

	# ---- 5) 点击图标播放动画: a click on an item card plays THAT item's fridge-man animation as a
	# ----     preview (it is no longer an inert/照相-only click), and keeps the idle rotation quiet
	# ----     for the preview's length.
	var suppress_before: float = float(scene.get("fridge_idle_suppress"))
	scene.call("_on_fridge_gallery_entry_pressed", "item_tomato")
	var suppress_after: float = float(scene.get("fridge_idle_suppress"))
	var mouth_player: Node = scene.get("fridge_player") as Node
	var mouth_juggle: float = float(mouth_player.get("juggle_preview_timer"))
	print("item card click: idle_suppress ", suppress_before, " -> ", suppress_after,
		" juggle_preview=", snappedf(mouth_juggle, 0.01))
	ok = ok and suppress_after > suppress_before
	ok = ok and mouth_juggle > 0.0
	mouth_player.set("juggle_preview_timer", 0.0)

	# ---- 6) 公文包 open art: the handle is gone but the body sits where it always did ----
	var open_path: String = str(level_consts.get("FRIDGE_BOX_OPEN_TEXTURE"))
	var closed_path: String = str(level_consts.get("FRIDGE_BOX_CLOSED_TEXTURE"))
	var old_open := _measure("res://assets/generated/paper_briefcase_open.png")
	var new_open := _measure(open_path)
	var closed := _measure(closed_path)
	print("open art=", open_path)
	print("  old open bbox=", old_open, "  new open bbox=", new_open, "  closed bbox=", closed)
	ok = ok and open_path.ends_with("paper_briefcase_open_v3.png")
	ok = ok and new_open.size.y > 0
	# same canvas, same left edge, same content height (so the drawn case cannot resize)...
	ok = ok and new_open.position.x == old_open.position.x
	ok = ok and absf(new_open.size.y - old_open.size.y) <= 4.0
	# ...and the case body still lands on the SAME ground row as the closed art
	ok = ok and new_open.position.y + new_open.size.y == closed.position.y + closed.size.y

	# ---- 7) 打开书架: the stand's toggle shows the panel on screen, with its tabs, and a tab
	#         switch while open re-places it (a page can be a different height) ----
	var gpanel: Node = scene.get("fridge_gallery_panel")
	scene.call("_on_fridge_gallery_stand_toggled", true)
	await process_frame
	var view_size: Vector2 = scene.get_viewport().get_visible_rect().size
	print("open: visible=", gpanel.visible, " pos=", gpanel.position, " size=", gpanel.size,
		" active=", gpanel.call("get_active_tab"))
	ok = ok and gpanel.visible
	ok = ok and gpanel.position.x >= 0.0 and gpanel.position.y >= 0.0
	ok = ok and gpanel.position.x + gpanel.size.x <= view_size.x
	# ...and, now that it is laid out, the bookmark column really does hang along the board's RIGHT edge
	var row_rect: Rect2 = tab_row.get_global_rect()
	var scroll_rect: Rect2 = scroll.get_global_rect()
	# the row's rect in the PANEL's own space, since the checks below compare it with the panel size
	row_rect.position -= gpanel.global_position
	print("laid out: tab row=", row_rect, " scroll=", scroll_rect, " panel=", gpanel.size)
	# 横向放在书本右边: each ribbon sticks out PAST the board's right edge while overlapping it on the left
	ok = ok and row_rect.position.x < gpanel.size.x
	ok = ok and row_rect.end.x > gpanel.size.x
	ok = ok and row_rect.position.y >= 0.0
	ok = ok and row_rect.end.y <= gpanel.size.y

	# ---- 7b) 向下箭头: a pulsing paper arrow on the page's RIGHT edge, shown while there is another
	#          page below the fold (若隐若现) and never eating a click meant for a cell ----
	var arrow: Control = gpanel.find_child("ScrollArrow", true, false) as Control
	print("scroll arrow node=", arrow != null)
	ok = ok and arrow != null
	if arrow != null:
		var arrow_rect: Rect2 = arrow.get_global_rect()
		arrow_rect.position -= gpanel.global_position
		var first_alpha: float = arrow.modulate.a
		# 若隐若现: the pulse runs on real time and a headless run's frames are tiny, so step frames
		# until the alpha has VISIBLY moved (or give up after 2 s of wall clock).
		var arrow_consts: Dictionary = (gpanel.get_script() as Script).get_script_constant_map()
		var faint: float = float(arrow_consts.get("SCROLL_ARROW_FAINT_ALPHA", 0.15))
		var moved := 0.0
		var started_ms := Time.get_ticks_msec()
		var steps := 0
		while Time.get_ticks_msec() - started_ms < 2000 and moved < 0.05:
			await process_frame
			steps += 1
			moved = maxf(moved, absf(arrow.modulate.a - first_alpha))
		print("scroll arrow: rect=", arrow_rect, " visible=", arrow.visible,
			" alpha=", snappedf(first_alpha, 0.001), " moved=", snappedf(moved, 0.001),
			" over ", steps, " frames  panel=", gpanel.size)
		ok = ok and arrow_rect.get_center().x > gpanel.size.x * 0.5
		ok = ok and arrow_rect.end.x <= gpanel.size.x
		ok = ok and arrow_rect.position.y >= 0.0 and arrow_rect.end.y <= gpanel.size.y
		ok = ok and moved > 0.05
		ok = ok and arrow.modulate.a >= faint - 0.02
		# 10 entries in 2 columns over 2 visible rows leaves another page below, so it is on show
		ok = ok and arrow.visible
		# 点击箭头: a click on the hint pages the list down exactly like one wheel notch, so the arrow
		# is more than decoration - and it is CLICKABLE now, not mouse-IGNORE.
		ok = ok and arrow.mouse_filter == Control.MOUSE_FILTER_STOP
		var hint_before: int = int(scroll.scroll_vertical)
		var hint_click := InputEventMouseButton.new()
		hint_click.button_index = MOUSE_BUTTON_LEFT
		hint_click.pressed = true
		arrow.gui_input.emit(hint_click)
		for click_step in 3:
			await process_frame
		print("scroll arrow click: ", hint_before, " -> ", scroll.scroll_vertical,
			" visible=", arrow.visible)
		ok = ok and int(scroll.scroll_vertical) > hint_before
		# ...and once the LAST page is on show the hint takes itself away again. ⚠ Page until it does:
		# how many pages there are depends on the entry count (the cat-mouth animations were added later).
		for end_step in 4:
			panel.call("page_by", 1)
			for settle in 3:
				await process_frame
		print("scroll arrow at the end: visible=", arrow.visible,
			" scroll=", scroll.scroll_vertical)
		ok = ok and not arrow.visible
		# ...and back at the top it comes back
		panel.call("page_by", -4)
		for click_step in 3:
			await process_frame
		ok = ok and arrow.visible
		ok = ok and int(scroll.scroll_vertical) == hint_before
		# 白边: the BOOK's arrow KEEPS its pale halo - its board is cream paper, where the halo is what
		# keeps the ink readable (the briefcase's, sitting on leather, turns it off instead).
		ok = ok and bool(arrow.get("halo"))
	# 悬停说明框: with the book's cells label-less, hovering one pops the paper box with its name
	# and its 说明, and leaving hides it again
	var tip: Control = gpanel.find_child("HoverTooltip", true, false) as Control
	var tip_name: Label = null
	var tip_desc: Label = null
	if tip != null:
		tip_name = tip.find_child("TooltipName", true, false) as Label
		tip_desc = tip.find_child("TooltipDescription", true, false) as Label
	ok = ok and tip != null and tip_name != null and tip_desc != null
	if tip != null:
		ok = ok and not tip.visible
		gpanel.call("_on_card_hover", "man_rest_stand", true)
		await process_frame
		var hovered: Dictionary = {}
		for candidate: Dictionary in gallery:
			if str(candidate.get("id", "")) == "man_rest_stand":
				hovered = candidate
		print("tooltip: visible=", tip.visible, " name=", tip_name.text, " desc=", tip_desc.text,
			" pos=", tip.global_position, " size=", tip.size)
		ok = ok and tip.visible
		ok = ok and tip_name.text == str(hovered.get("name", ""))
		ok = ok and tip_desc.text == str(hovered.get("description", ""))
		ok = ok and tip_desc.visible
		ok = ok and tip.global_position.x >= 0.0 and tip.global_position.y >= 0.0
		ok = ok and tip.global_position.x + tip.size.x <= view_size.x
		ok = ok and tip.global_position.y + tip.size.y <= view_size.y
		gpanel.call("_on_card_hover", "man_rest_stand", false)
		await process_frame
		ok = ok and not tip.visible
	gpanel.call("select_tab", "items")
	await process_frame
	print("open+switch: active=", gpanel.call("get_active_tab"), " pos=", gpanel.position,
		" size=", gpanel.size)
	ok = ok and gpanel.visible and str(gpanel.call("get_active_tab")) == "items"
	ok = ok and gpanel.position.x + gpanel.size.x <= view_size.x
	scene.call("_on_fridge_gallery_stand_toggled", false)
	await process_frame
	print("closed: visible=", gpanel.visible)
	ok = ok and not gpanel.visible

	# ⚠ 猫嘴物品的动画图标删掉: 磁带机舞 / 渔民垂钓 are NOT on the 骨架 page any more - those performances
	# belong to the cat's mouth items, and clicking THOSE items' own icons on the 猫嘴物品 page plays
	# them (see _play_fridge_mouth_item_preview).
	var gallery_ids: Array = []
	for entry: Dictionary in gallery:
		gallery_ids.append(str(entry.get("id", "")))
	print("skeleton page carries the removed ones: ", gallery_ids.has("man_cassette"),
		" / ", gallery_ids.has("man_tv"), " of ", gallery_ids.size(), " entries")
	ok = ok and not gallery_ids.has("man_cassette") and not gallery_ids.has("man_tv")
	# 点击图标播放动画: every unlocked mouth item previews its OWN fridge-man animation from the item
	# page. The four items map onto the four previews their countdowns run, and each preview stays
	# the one it belongs to.
	var gallery_player: Node = scene.get("fridge_player") as Node
	var preview_timers: Array = ["juggle_preview_timer", "pager_preview_timer",
		"cassette_preview_timer", "tv_preview_timer", "computer_preview_timer", "controller_preview_timer"]
	for pair: Array in [
			["tomato", "juggle_preview_timer"],
			["cassette", "cassette_preview_timer"],
			["pager", "pager_preview_timer"],
			["crt", "tv_preview_timer"],
			["computer", "computer_preview_timer"],
			["controller", "controller_preview_timer"],
		]:
		var mouth_id := str(pair[0])
		var timer_name := str(pair[1])
		for other_name: String in preview_timers:
			gallery_player.set(other_name, 0.0)
		scene.call("_on_fridge_gallery_entry_pressed", "item_%s" % mouth_id)
		await process_frame
		await process_frame
		var left: float = float(gallery_player.get(timer_name))
		var expected_duration: float = float(scene.call("_get_fridge_item_duration", mouth_id))
		var leaked := 0.0
		for other_name: String in preview_timers:
			if other_name != timer_name:
				leaked = maxf(leaked, float(gallery_player.get(other_name)))
		print("item page preview ", mouth_id, ": ", timer_name, "=", snappedf(left, 0.01),
			" expected=", expected_duration, " other=", snappedf(leaked, 0.01))
		ok = ok and left > 0.0 and absf(left - expected_duration) < 1.0
		ok = ok and is_zero_approx(leaked)
		gallery_player.call("stop_cassette_reaction")
		gallery_player.call("stop_tv_reaction")
		gallery_player.call("stop_pager_reaction")
		gallery_player.call("stop_computer_reaction")
		gallery_player.call("stop_controller_reaction")
		gallery_player.set("juggle_preview_timer", 0.0)
		for step in range(2):
			await process_frame

	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.set("fridge_owned_items", save_owned)
	scene.set("fridge_work_duration", save_work_duration)
	scene.call("_save_fridge_progress")
	print("GALLERY_TABS_TEST=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0)


## The alpha content box of a PNG, measured straight off disk (alpha > 0.5, so soft shadows do
## not inflate it).
func _measure(path: String) -> Rect2:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) != OK:
		print("  ! cannot load ", path)
		return Rect2()
	var size := img.get_size()
	var min_x := size.x
	var min_y := size.y
	var max_x := -1
	var max_y := -1
	for y in size.y:
		for x in size.x:
			if img.get_pixel(x, y).a > 0.5:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)