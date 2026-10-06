extends Node2D

## Throwaway capture harness (test-only): drives the level through the moments
## added this round so each can be screenshotted with run_scene at a chosen time,
## without depending on clicking the skeleton stand (whose drag-by-relative input
## the harness cannot drive reliably).
##
## Capture points:
##   ~2.5 s  -> 骨架背包 open: 2x3 grid of action slots + pull-down hint
##   ~5.0 s  -> the BB机 (pager) preview playing from the gallery, panel still open
##   ~17.8 s -> 小猫绕圈跑 at the far side of the circle: it must pass BEHIND the man

const SCHEDULE := [
	{"at": 0.5, "call": "_on_fridge_gallery_stand_toggled", "arg": true},
	{"at": 3.0, "call": "_on_fridge_gallery_entry_pressed", "arg": "man_pager"},
	{"at": 11.0, "call": "_start_fridge_cat_orbit", "arg": 8.5},
]

var level: Node
var elapsed := 0.0
var fired: Array[bool] = []
var reported := 0

# One-off draw-order report, taken while the cat is on the far side of the orbit.
const REPORTS := [17.7]


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
	while reported < REPORTS.size() and elapsed >= float(REPORTS[reported]):
		_z_report()
		reported += 1


## Prints everything that decides who draws on top of whom, at the moment the cat
## should be passing behind the fridge man.
func _z_report() -> void:
	var man: Node2D = level.get("fridge_player")
	var cat: Node2D = level.get("fridge_cat_pet")
	var world: Node = man.get_parent()
	var y_sort := false
	if world is Node2D:
		y_sort = (world as Node2D).y_sort_enabled
	print("Z cat=", cat.z_index, " rel=", cat.z_as_relative, " pos=", cat.global_position, " | man=", man.z_index, " rel=", man.z_as_relative, " pos=", man.global_position)
	print("CAT idle_action=", cat.get("idle_action_id"), " timer=", cat.get("idle_action_timer"), " motion=", level.get("fridge_cat_motion"), " drop=", cat.get("idle_action_drop"))
	print("CAT node visible=", cat.visible, " modulate=", cat.modulate, " opening=", cat.get("is_opening"), " bag=", cat.get("is_bag_open"), " dragging=", cat.get("is_dragging"))
	var cat_sprite: Sprite2D = cat.get("sprite")
	if cat_sprite == null:
		print("CAT sprite=null")
	else:
		print("CAT sprite visible=", cat_sprite.visible, " pos=", cat_sprite.position, " scale=", cat_sprite.scale, " modulate=", cat_sprite.modulate, " tex=", (cat_sprite.texture.get_size() if cat_sprite.texture != null else Vector2.ZERO))
		print("CAT sprite gpos=", cat_sprite.global_position, " rect=", cat_sprite.get_rect())
		var idle_tex: Texture2D = cat.get("idle_texture")
		print("CAT tex==idle? ", cat_sprite.texture == idle_tex, " idle_tex=", (idle_tex.get_size() if idle_tex != null else Vector2.ZERO), " canvas_item_visible=", cat_sprite.is_visible_in_tree())
	if cat_sprite.texture != null:
		var im: Image = cat_sprite.texture.get_image()
		print("CAT tex fmt=", im.get_format(), " px(128,160)=", im.get_pixel(128, 160), " px(10,10)=", im.get_pixel(10, 10))
	var sleep_slices: Array = cat.call("_get_idle_action_frames", "sleep")
	print("CAT sleep slices=", sleep_slices.size(), " clock=", cat.get("idle_action_clock"))
	if not sleep_slices.is_empty():
		var s0: Image = (sleep_slices[0] as Texture2D).get_image()
		print("CAT slice0 fmt=", s0.get_format(), " px(128,160)=", s0.get_pixel(128, 160))
	print("Z world=", world.name, " ", world.get_class(), " y_sort=", y_sort)
	for child in man.get_children():
		if child is CanvasItem:
			print("Z man child ", child.name, " ", child.get_class(), " z=", (child as CanvasItem).z_index, " rel=", (child as CanvasItem).z_as_relative)
	for child in cat.get_children():
		if child is CanvasItem:
			print("Z cat child ", child.name, " ", child.get_class(), " z=", (child as CanvasItem).z_index, " rel=", (child as CanvasItem).z_as_relative)