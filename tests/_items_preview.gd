extends Node2D

## Throwaway capture harness (test-only): opens the mouth-bag item list and leaves it
## open, so each item's own 倒计时 line (番茄钟 30 秒 / 寻呼机 1 分钟) can be
## screenshotted with run_scene.

const BAG_AT := 0.4

var level: Node
var elapsed := 0.0
var fired := false


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)


func _process(delta: float) -> void:
	elapsed += delta
	if not fired and elapsed >= BAG_AT:
		fired = true
		level.set("fridge_idle_rotation_enabled", false)
		level.call("_show_fridge_item_toolbar")