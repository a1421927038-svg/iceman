extends Node2D

## Throwaway capture harness (test-only): parks the cat on its 玩球 idle action so
## the restored toy mouse can be seen in the running game.
## Capture points:
##   ~3.0 s -> the cat mid play_ball, toy mouse at its paws on the ground line

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
		level.call("_play_fridge_cat_idle_action", "play_ball")