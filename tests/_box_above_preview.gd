extends Node2D

## Throwaway capture harness (test-only): opens the prop box (panel + the chest's own
## open art) and then MOVES the chest, so 箱子上方 can be checked live - the panel has
## to follow the box and stay centred above it. Capture at ~2200ms.

const BOX_AT := 0.5
const MOVE_AT := 1.1
const MOVE_BY := Vector2(150.0, -30.0)

var level: Node
var elapsed := 0.0
var opened := false
var moved := false


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)


func _process(delta: float) -> void:
	elapsed += delta
	if not opened and elapsed >= BOX_AT:
		opened = true
		level.set("fridge_idle_rotation_enabled", false)
		# The chest swaps its own art; the level's handler shows and places the panel.
		level.get("fridge_box").call("set_open", true)
		level.call("_on_fridge_box_toggled", true)
	if not moved and elapsed >= MOVE_AT:
		moved = true
		var box: Node2D = level.get("fridge_box")
		box.global_position += MOVE_BY
		var sprite: Sprite2D = box.get_node_or_null("Sprite") as Sprite2D
		var art_h := 0.0
		if sprite != null and sprite.texture != null:
			art_h = float(sprite.texture.get_image().get_used_rect().size.y)
		print("box_above: is_open=", box.get("is_open"), " art_used_h=", art_h,
			" texture=", sprite.texture.get_size() if sprite != null and sprite.texture != null else Vector2.ZERO)