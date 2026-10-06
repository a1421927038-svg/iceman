extends SceneTree

## 白色底板 + 骨头滚动条 probe: builds the skeleton backpack panel with the
## same options FridgeLevel uses and inspects its scrollbar styling headlessly.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array = []
	var panel_script: GDScript = load("res://addons/骨骼动画/action_gallery_panel.gd")
	var panel: PanelContainer = panel_script.new()
	panel.visible = true
	get_root().add_child(panel)
	await process_frame
	await process_frame
	var entries: Array = [
		{"id": "juggle", "name": "juggle", "icon": "res://assets/generated/paper_skeleton_juggle_icon.png"},
		{"id": "man_smoke", "name": "smoke", "icon": "res://assets/generated/paper_icon_man_smoke.png"},
		{"id": "man_pet_cat", "name": "pet", "icon": "res://assets/generated/paper_icon_man_pet_cat.png"},
		{"id": "man_pager", "name": "pager", "icon": "res://assets/generated/paper_icon_man_pager.png"},
	]
	panel.call("setup", "probe", entries, {
		"grid_columns": 2,
		"card_size": Vector2(148.0, 128.0),
		"icon_size": Vector2(62.0, 62.0),
		"cell_texture": "res://assets/generated/ui_bone_cell_frame.png",
		"cell_margin": 10.0,
		"cell_margin_top": 12.0,
		"board": "white",
		"show_title": false,
		"show_hint": false,
	})
	await process_frame
	await process_frame

	# The board behind the cells is the plain white panel.
	var style: StyleBox = panel.get_theme_stylebox("panel")
	if not (style is StyleBoxFlat):
		failures.append("panel style is %s, not the white StyleBoxFlat" % style.get_class())
	else:
		var bg: Color = (style as StyleBoxFlat).bg_color
		if bg.r < 0.95 or bg.g < 0.95 or bg.b < 0.95:
			failures.append("board bg is %s, not white" % bg)

	# The scrollbar: invisible track, bone grabber.
	var bar: VScrollBar = null
	for child in panel.find_children("", "VScrollBar", true, false):
		bar = child
	if bar == null:
		failures.append("no VScrollBar found in the panel")
	else:
		var track: StyleBox = bar.get_theme_stylebox("scroll")
		if not (track is StyleBoxEmpty):
			failures.append("scrollbar track is %s, not invisible" % track.get_class())
		var grab: StyleBox = bar.get_theme_stylebox("grabber")
		if not (grab is StyleBoxTexture):
			failures.append("grabber is %s, not a texture" % grab.get_class())
		else:
			var tex: Texture2D = (grab as StyleBoxTexture).texture
			if tex == null:
				failures.append("grabber has no texture")
			else:
				print("grabber art=", tex.get_size(), " margin_l=", (grab as StyleBoxTexture).texture_margin_left)
				if tex.get_size() != Vector2(128.0, 64.0):
					failures.append("grabber art is %s, not the 128x64 paper button" % tex.get_size())
				if (grab as StyleBoxTexture).texture_margin_left <= 0.0:
					failures.append("the button grabber is stretched whole instead of 9-patched")
		print("bar width=", bar.custom_minimum_size, " grabber class=", grab.get_class() if grab != null else "<none>")

	print("panel size=", panel.custom_minimum_size, " failures=", failures.size())
	for f in failures:
		print("FAIL: ", f)
	print("SCROLLBAR_PROBE=", "PASS" if failures.is_empty() else "FAIL")
	panel.queue_free()
	await process_frame
	quit(0)
