extends Node2D

## Throwaway capture harness (test-only): gives the BB机's animation the 泡泡 item
## from the prop box and then the 字体 item again - the swap that used to leave the
## bubbles still coming out - and plays the pager performance, so the spray can be
## screenshotted with run_scene.

const SCHEDULE := [
	{"at": 0.4, "call": "_on_fridge_box_entry_pressed", "arg": "spray_bubble"},
	{"at": 0.8, "call": "_on_fridge_box_entry_pressed", "arg": "spray_text"},
	{"at": 1.2, "call": "_on_fridge_gallery_entry_pressed", "arg": "man_pager"},
]

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
	for i in range(SCHEDULE.size()):
		if fired[i]:
			continue
		var entry: Dictionary = SCHEDULE[i]
		if elapsed >= float(entry["at"]):
			fired[i] = true
			level.set("fridge_idle_rotation_enabled", false)
			level.call(str(entry["call"]), entry["arg"])