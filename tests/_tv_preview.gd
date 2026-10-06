extends Node2D

## Throwaway preview for the 电视机 (CRT) fisherman performance. The Area2D props cannot be
## clicked reliably under synthetic input, so this instantiates the level, turns the idle
## rotation off and drives it by CALL. Capture with run_scene: ~1300 ms shows the
## transformation landing with the 乌篷船 popping in, ~2800 ms shows him poling it with
## 白娘子 and 许仙 seated at the far end.

const START_DELAY := 0.4

var level: Node
var elapsed := 0.0
var started := false


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)


func _process(delta: float) -> void:
	elapsed += delta
	if started or elapsed < START_DELAY or level == null:
		return
	started = true
	level.set("fridge_idle_rotation_enabled", false)
	var owned: Variant = level.get("fridge_owned_items")
	if owned is Array:
		if not (owned as Array).has("crt"):
			(owned as Array).append("crt")
	elif owned is Dictionary:
		if not (owned as Dictionary).has("crt"):
			(owned as Dictionary)["crt"] = true
	level.call("_take_fridge_item_out_of_mouth", "crt")