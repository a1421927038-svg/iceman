extends Node2D

## Throwaway preview for the 磁带机 (cassette) countdown performance. The Area2D props
## cannot be clicked reliably under synthetic input, so this instantiates the level,
## turns the idle rotation off and drives the performance by CALL. Capture it with
## run_scene: ~1500 ms shows the boombox landing on his shoulder, ~3400 ms shows the
## held dance with the 音乐符号 flying out of it.

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
		if not (owned as Array).has("cassette"):
			(owned as Array).append("cassette")
	elif owned is Dictionary:
		if not (owned as Dictionary).has("cassette"):
			(owned as Dictionary)["cassette"] = true
	level.call("_take_fridge_item_out_of_mouth", "cassette")