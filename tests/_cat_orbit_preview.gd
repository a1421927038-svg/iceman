extends Node2D

## Throwaway capture harness (test-only): starts 小猫绕圈跑 at once so the four-legged
## run (and its 面朝方向 flip) can be screenshotted at chosen moments.
## The lap is slow on purpose (the cat is a walking box), so the capture points are
## fractions of the real FRIDGE_CAT_ORBIT_DURATION rather than fixed seconds:
##   ~29% of the lap -> the cat on the RIGHT of the circle, travelling right (art as drawn)
##   ~71% of the lap -> the cat on the LEFT of the circle, travelling left (sprite mirrored)

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
		level.call("_start_fridge_cat_orbit", FridgeLevel.FRIDGE_CAT_ORBIT_DURATION)
		print("orbit lap=%.1f s - capture at %.1f s / %.1f s" % [
			FridgeLevel.FRIDGE_CAT_ORBIT_DURATION,
			FridgeLevel.FRIDGE_CAT_ORBIT_DURATION * 0.29,
			FridgeLevel.FRIDGE_CAT_ORBIT_DURATION * 0.71,
		])
	elif elapsed > 1.0:
		var cat: Node2D = level.get("fridge_cat_pet")
		var sprite: Sprite2D = cat.get("sprite")
		if sprite != null and int(elapsed * 4.0) != int((elapsed - delta) * 4.0):
			print("t=%.2f cat=(%.1f, %.1f) flip=%s motion=%s" % [
				elapsed, cat.global_position.x, cat.global_position.y, str(sprite.flip_h), str(level.get("fridge_cat_motion"))])