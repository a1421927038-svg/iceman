extends Node2D

## Throwaway probe (test-only): prints the idle-rotation state at fixed moments so
## a live run_scene capture can be read as numbers instead of guessed from pixels
## (the man's 站立歇息 pose looks almost identical to his plain idle one).

const REPORTS := [2.0, 9.5, 11.5, 13.5, 14.5]

var level: Node
var elapsed := 0.0
var reported := 0
var printed := false


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)


func _process(delta: float) -> void:
	elapsed += delta
	while reported < REPORTS.size() and elapsed >= float(REPORTS[reported]):
		_report(float(REPORTS[reported]))
		reported += 1
	if not printed and reported >= REPORTS.size():
		printed = true
		print("PROBE_DONE")


func _report(at: float) -> void:
	var man: Node = level.get("fridge_player")
	var cat: Node = level.get("fridge_cat_pet")
	print("T=%.1f timer=%.2f can=%s hover=%s [man_over=%s cat_hover=%.1f] man=%s cat=%s motion=%s phase=%s suppress=%.1f" % [
		at,
		float(level.get("fridge_idle_timer")),
		str(level.call("_can_play_fridge_idle")),
		str(level.call("_is_fridge_idle_pointer_interacting")),
		str(level.call("_is_mouse_over_fridge_player")),
		float(cat.get("hover_amount")),
		str(man.get("idle_action_id")),
		str(cat.get("idle_action_id")),
		str(level.get("fridge_cat_motion")),
		str(level.get("fridge_phase")),
		float(level.get("fridge_idle_suppress"))])