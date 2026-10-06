extends Node2D

## Throwaway capture harness (test-only): parks the cat on its 打瞌睡 idle action so the
## drowsiness progression can be checked in the running game - 眼睛睁开 (the plain idle)
## -> 半眯眼 (nodding off) -> 闭眼 (fast asleep, sleep bubbles rising).
## Capture points:
##   ~1.0 s -> nodding off, half-lidded
##   ~2.6 s -> fast asleep, both eyes shut

var level: Node
var elapsed := 0.0
var fired := false


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)


func _process(delta: float) -> void:
	elapsed += delta
	if not fired and elapsed >= 0.6:
		fired = true
		level.set("fridge_idle_rotation_enabled", false)
		level.call("_play_fridge_cat_idle_action", "doze")