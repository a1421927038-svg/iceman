extends Node2D

## Throwaway capture harness (test-only): opens the prop box and leaves it open, so the
## briefcase's left-hand action buttons and the cells they swap can be screenshotted with
## run_scene. 左侧按钮: at SWITCH_AT it presses the second action's button, so a later capture
## shows the cells on the right switched over to that action's items.

const BOX_AT := 0.5
const SWITCH_AT := 1.6
## 鼠标滑动: turns the lid's action row to its SECOND page, so a later capture shows the actions that
## do not fit in the first three logos (the two the cat's bag gained later).
const PAGE_AT := 2.6
## ...and then picks the action on that page, so the tray below swaps over to ITS props.
const PICK_AT := 3.1

var level: Node
var panel: Node
var elapsed := 0.0
var fired := false
var switched := false
var paged := false
var picked := false
var reported := false
var early_reported := false


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)


func _process(delta: float) -> void:
	if level == null:
		return
	elapsed += delta
	if not fired and elapsed >= BOX_AT:
		fired = true
		level.set("fridge_idle_rotation_enabled", false)
		level.call("_on_fridge_box_toggled", true)
		return
	if fired and not early_reported and elapsed >= 0.7:
		early_reported = true
		panel = level.get("fridge_box_panel")
		print("[preview] at 0.7s: active=", panel.call("get_active_action"),
			" selected=", panel.call("get_selected"),
			" cards=", (panel.get("_cards") as Dictionary).keys())
		var icons: Dictionary = panel.get("_icons")
		for id: String in icons.keys():
			var icon: TextureRect = icons[id]
			var source := "<none>"
			if icon != null and icon.texture != null:
				source = icon.texture.resource_path
			print("   cell ", id, " -> ", source)
		return
	if fired and not switched and elapsed >= SWITCH_AT:
		switched = true
		panel = level.get("fridge_box_panel")
		if panel == null:
			return
		# Press the button of an action that is NOT the current one - the panel opens on the action of the
		# item in hand, so pressing that one again would change nothing on screen.
		var buttons: Dictionary = panel.get("_action_buttons")
		var active := str(panel.call("get_active_action"))
		print("[preview] buttons=", buttons.keys(), " active=", active)
		for key in buttons.keys():
			if str(key) == active:
				continue
			print("[preview] press ", key)
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			(buttons[key] as Control).gui_input.emit(press)
			print("[preview] right after: ", panel.call("get_active_action"),
				" cards=", (panel.get("_cards") as Dictionary).keys())
			break
		return
	if switched and not reported and elapsed >= 2.3:
		reported = true
		print("[preview] now (", elapsed, "s): ", panel.call("get_active_action"),
			" cards=", (panel.get("_cards") as Dictionary).keys())
		# 箭头: where the row's flashing hint really is in the LIVE layout, and whether it is drawable.
		var row_arrow: Control = panel.find_child("ActionArrow", true, false) as Control
		if row_arrow != null:
			var panel_rect: Rect2 = panel.get_global_rect()
			var arrow_rect: Rect2 = row_arrow.get_global_rect()
			print("[preview] arrow: in_tree=", row_arrow.is_visible_in_tree(),
				" visible=", row_arrow.visible, " alpha=", snappedf(row_arrow.modulate.a, 0.001),
				" size=", row_arrow.size,
				" panel-relative=", arrow_rect.position - panel_rect.position,
				" alpha_owner=", row_arrow.modulate,
				" parent_z=", (row_arrow.get_parent() as Node2D).z_index if row_arrow.get_parent() is Node2D else -99)
			var holder: Node = row_arrow.get_parent()
			print("[preview] arrow holder=", holder.name, " children_after=",
				holder.get_parent().get_child_count(),
				" panel_children=", panel.get_child_count())
		return
	if switched and not paged and elapsed >= PAGE_AT:
		paged = true
		panel.call("_page_actions", 1)
		print("[preview] paged (", elapsed, "s): buttons=",
			(panel.get("_action_buttons") as Dictionary).keys(),
			" cards=", (panel.get("_cards") as Dictionary).keys())
		return
	if paged and not picked and elapsed >= PICK_AT:
		picked = true
		var buttons: Dictionary = panel.get("_action_buttons")
		for key in buttons.keys():
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			(buttons[key] as Control).gui_input.emit(press)
			print("[preview] picked (", elapsed, "s): ", panel.call("get_active_action"),
				" cards=", (panel.get("_cards") as Dictionary).keys())
			break