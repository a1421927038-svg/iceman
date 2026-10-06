extends Node2D

## Throwaway capture harness (test-only) for this round's doze work. It drives the
## level through the moments to screenshot, so run_scene's duration_ms alone picks
## the moment - no clicking the skeleton stand (whose drag-by-relative input the
## harness cannot drive reliably) and no waiting out the 10 s idle rotation.
##
## Capture points:
##   ~1.4 s  -> 骨架背包 open, top rows: the 打瞌睡 slots in the 2x3 grid
##   ~1.9 s  -> the panel pulled down to its last rows (the rest of the cards)
##   ~5.7 s  -> the fridge man nodding off, the cat still standing in the idle
##   ~9.3 s  -> the man's sleep bubble bursting into shards
##   ~10.0 s -> the man waking with a start while the cat nods off

const SCHEDULE := [
	{"at": 0.8, "call": "_on_fridge_gallery_stand_toggled", "arg": true},
	{"at": 2.2, "call": "_on_fridge_gallery_entry_pressed", "arg": "man_doze"},
	{"at": 3.0, "call": "_on_fridge_gallery_entry_pressed", "arg": "cat_doze"},
]

# Pull the backpack grid down once, to show the rows that are scrolled out of sight.
const SCROLL_AT := 1.6

var level: Node
var elapsed := 0.0
var fired: Array[bool] = []


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)
	for i in range(SCHEDULE.size()):
		fired.append(false)


func _process(delta: float) -> void:
	elapsed += delta
	# Pull the backpack grid down. Set it across a few frames: a ScrollContainer
	# clamps scroll_vertical until its content has actually been laid out.
	if elapsed >= SCROLL_AT and elapsed <= SCROLL_AT + 0.4:
		_force_scroll()
	for i in range(SCHEDULE.size()):
		if fired[i]:
			continue
		var entry: Dictionary = SCHEDULE[i]
		if elapsed >= float(entry["at"]):
			fired[i] = true
			level.set("fridge_idle_rotation_enabled", false)
			level.call(str(entry["call"]), entry["arg"])


## Walks the gallery panel for its ScrollContainer (by type, not by name) and
## scrolls it to the end.
func _force_scroll() -> void:
	var panel: Node = level.get("fridge_gallery_panel")
	if panel == null:
		return
	for child in panel.get_children():
		if child is ScrollContainer:
			(child as ScrollContainer).scroll_vertical = 100000
		for grandchild in child.get_children():
			if grandchild is ScrollContainer:
				(grandchild as ScrollContainer).scroll_vertical = 100000