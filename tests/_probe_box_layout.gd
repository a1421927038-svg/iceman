extends SceneTree

## Throwaway probe (test-only): measures the prop box's new 左侧按钮 + 右格子 layout headlessly.
## The live run_scene capture is blocked while the user's own run holds the Game tab, so this
## checks the geometry instead: the action buttons, the item grid, the panel's own rect and
## whether it all still lands on screen. Leaves no game state behind.

var save_coins := 0
var save_active := ""
var save_owned: Array = []


func _init() -> void:
	var level: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	root.add_child(level)
	for i in range(8):
		await process_frame
	level.set("fridge_idle_rotation_enabled", false)
	save_coins = int(level.get("fridge_coin_count"))
	save_active = str(level.get("fridge_active_item_id"))
	save_owned = (level.get("fridge_owned_items") as Array).duplicate()

	level.call("_on_fridge_box_toggled", true)
	for i in range(10):
		await process_frame

	var panel: Control = level.get("fridge_box_panel") as Control
	var view: Vector2 = panel.get_viewport_rect().size
	print("view=", view)
	print("panel: visible=", panel.visible, " pos=", panel.position, " size=", panel.size,
		" min=", panel.custom_minimum_size)
	var rect: Rect2 = panel.get_global_rect()
	print("panel on screen: left=", rect.position.x >= 0.0, " top=", rect.position.y >= 0.0,
		" right=", rect.end.x <= view.x, " bottom=", rect.end.y <= view.y)

	var box: Node2D = panel.find_child("ActionHolder", true, false) as Node2D
	var row: Control = panel.find_child("ActionRow", true, false) as Control
	var grid: Control = panel.find_child("ActionItemGrid", true, false) as Control
	if box != null:
		print("action holder (on the lid) pos=", box.position)
	if row != null:
		print("action row rect=", row.get_global_rect(), " min=", row.get_combined_minimum_size())
	if grid != null:
		print("grid rect=", grid.get_global_rect(), " columns=", (grid as GridContainer).columns,
			" cells=", grid.get_child_count())

	var buttons: Array = panel.find_children("ActionButton*", "", true, false)
	for node: Node in buttons:
		var card := node as Control
		var icon := card.find_child("ActionIcon", true, false) as TextureRect
		print("  action button '", card.name, "' rect=", card.get_global_rect(),
			" min=", card.get_combined_minimum_size(),
			" logo=", icon != null, " logo_rect=", icon.get_global_rect() if icon != null else Rect2())
	# 格子偏移: every cell's rect relative to the panel, so even spacing can be checked against the screenshot.
	var panel_rect: Rect2 = panel.get_global_rect()
	if panel != null:
		var content: Control = panel.get_child(0) as Control
		print("content min=", content.get_combined_minimum_size() if content != null else Vector2.ZERO,
			" rect rel=", (content.get_global_rect().position - panel_rect.position) if content != null else Vector2.ZERO,
			" size=", content.size if content != null else Vector2.ZERO)
		var scroll: Control = panel.find_child("EntryScroll", true, false) as Control
		if scroll != null:
			print("scroll min=", scroll.custom_minimum_size, " rect rel=",
				scroll.get_global_rect().position - panel_rect.position, " size=", scroll.size)
	if grid != null:
		for cell: Node in grid.get_children():
			var cell_rect: Rect2 = (cell as Control).get_global_rect()
			var icon_node: Node = cell.find_child("CellIcon", true, false)
			var icon_rect := Rect2()
			if icon_node != null:
				icon_rect = (icon_node as Control).get_global_rect()
			print("  cell '", cell.name, "' rel=", cell_rect.position - panel_rect.position,
				" size=", cell_rect.size, " icon_rel=", icon_rect.position - panel_rect.position,
				" icon_size=", icon_rect.size)
	print("tray: grid cells=", grid.get_child_count() if grid != null else -1,
		" empty compartments=", (grid.get_child_count() - (panel.get("_cards") as Dictionary).size()) if grid != null else -1,
		" filled=", (panel.get("_cards") as Dictionary).size())
	print("active action=", panel.call("get_active_action"),
		" cards=", (panel.get("_cards") as Dictionary).keys())

	if buttons.size() > 1:
		# 只留图标: the button is a PanelContainer, so a click is its gui_input handler.
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		(buttons[1] as Control).gui_input.emit(press)
		for i in range(6):
			await process_frame
		print("after pressing button 2: active=", panel.call("get_active_action"),
			" cards=", (panel.get("_cards") as Dictionary).keys(), " size=", panel.size)
		var rect2: Rect2 = panel.get_global_rect()
		print("still on screen: ", rect2.position.x >= 0.0, " ", rect2.position.y >= 0.0,
			" ", rect2.end.x <= view.x, " ", rect2.end.y <= view.y)

	level.set("fridge_coin_count", save_coins)
	level.set("fridge_active_item_id", save_active)
	level.set("fridge_owned_items", save_owned)
	level.call("_save_fridge_progress")
	level.queue_free()
	await process_frame
	print("PROBE_DONE")
	quit()