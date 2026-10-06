extends Node2D

## Throwaway preview: open the notebook's panel for a run_scene capture (the injected-click
## pointer warp drags the stand instead of clicking it, so the open path is driven directly).
## Capture ~1300 ms for the 骨架 page, ~2900 ms after it has switched to 猫嘴物品, or ~3300 ms to
## also see the 悬停说明框 (the hover is driven through the panel's own handler, because a real
## click would also fire the entry). The 骨架 page's SECOND page - where the two cat-mouth
## animations (磁带机 / 电视机) sit - is on show between PAGE_DELAY (0.95 s) and the tab switch, so
## capture ~1200 ms to see those two icons.

const OPEN_DELAY := 0.5
## One wheel notch on the 骨架 page (4 entries), so the later entries - and the two cat-mouth
## animations among them - come into view before the tab switches away.
const PAGE_DELAY := 0.95
const SWITCH_DELAY := 1.6
## 正上方: move the notebook prop once the page is open, so the capture shows the panel following it
## (the injected-click pointer warp makes a real drag unreliable, so the prop is nudged by CALL).
const MOVE_DELAY := 1.9
const MOVE_BY := Vector2(-300.0, 170.0)
const HOVER_DELAY := 2.6

var level: Node
var elapsed := 0.0
var opened := false
var paged := false
var switched := false
var moved := false
var hovered := false


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)


func _process(delta: float) -> void:
	if level == null:
		return
	elapsed += delta
	if not opened and elapsed >= OPEN_DELAY:
		opened = true
		level.set("fridge_idle_rotation_enabled", false)
		level.call("_on_fridge_gallery_stand_toggled", true)
		return
	if opened and not paged and elapsed >= PAGE_DELAY:
		paged = true
		var page_panel: Node = level.get("fridge_gallery_panel")
		if page_panel != null:
			print("[gallery] cards before the turn: ", (page_panel.get("_cards") as Dictionary).keys())
			page_panel.call("page_by", 1)
		return
	if opened and not switched and elapsed >= SWITCH_DELAY:
		switched = true
		var panel: Node = level.get("fridge_gallery_panel")
		if panel != null:
			panel.call("select_tab", "items")
		return
	if switched and not moved and elapsed >= MOVE_DELAY:
		moved = true
		var stand: Node2D = level.get("fridge_gallery_stand") as Node2D
		if stand != null:
			stand.global_position += MOVE_BY
		return
	if switched and not hovered and elapsed >= HOVER_DELAY:
		hovered = true
		var panel2: Node = level.get("fridge_gallery_panel")
		if panel2 != null:
			var entries: Array = panel2.call("get_tab_entries", panel2.call("get_active_tab"))
			if not entries.is_empty():
				panel2.call("_on_card_hover", str((entries[0] as Dictionary).get("id", "")), true)