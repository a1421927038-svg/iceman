extends Node2D
## TEMPORARY harness: takes the 寻呼机 out of the cat's mouth so the levitation, its raised-arm
## float pose and the flight can be photographed/sampled. Not part of the game.

const LEVEL_SCENE := preload("res://scenes/FridgeLevel.tscn")
const TAKE_FRAME := 40

var level: Node
var frame := 0
var taken := false
var last_report := 0.0
var last_drag := false
var last_dir := 1.0


func _ready() -> void:
	level = LEVEL_SCENE.instantiate()
	add_child(level)


func _process(_delta: float) -> void:
	frame += 1
	var player: Node = level.get("fridge_player")
	if player == null:
		return
	if not taken and frame >= TAKE_FRAME:
		taken = true
		level.call("_take_fridge_item_out_of_mouth", "pager")
	var drag: bool = bool(level.get("fridge_player_is_dragging"))
	var dir: float = float(level.get("fridge_player_flight_dir"))
	if drag != last_drag:
		last_drag = drag
		print(">>> drag=%s at pos=%s dir=%s" % [str(drag), str(player.global_position), str(dir)])
	if not is_equal_approx(dir, last_dir):
		last_dir = dir
		print(">>> DIRECTION FLIP -> %s at pos=%s" % [str(dir), str(player.global_position)])
	var secs: float = Time.get_ticks_msec() / 1000.0
	if secs - last_report >= 1.0:
		last_report = secs
		var rect: Rect2 = level.call("_fridge_screen_world_rect")
		var ct: Transform2D = get_viewport().get_canvas_transform()
		print("t=%.1fs pos=%s dir=%s drag=%s flying=%s screen_rect=%s canvas=%s mouse=%s over=%s" % [
			secs, str(player.global_position), str(dir), str(drag),
			str(player.call("is_pager_flying")), str(rect),
			str(ct.origin), str(get_viewport().get_mouse_position()),
			str(level.call("_is_mouse_over_fridge_player"))])