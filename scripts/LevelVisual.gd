extends Node2D

var level_id := "hub"
var base_color := Color(0.72, 0.82, 0.78)


func setup(new_level_id: String, new_base_color: Color) -> void:
	level_id = new_level_id
	base_color = new_base_color
	queue_redraw()


func _draw() -> void:
	match level_id:
		"hub":
			_draw_hub()
		"fridge_people":
			_draw_fridge_pomodoro_level()
		"desktop_fish_tank":
			_draw_desktop_fish_tank_level()
		"wizard_keyboard":
			_draw_wizard_keyboard_level()
		"robot_town":
			pass
		"meow_energy":
			_draw_meow_energy_level()
		"mouse_genesis":
			_draw_mouse_genesis_level()
		"nana_shrine":
			_draw_clay_level()
		"tiny_prison":
			_draw_tiny_prison_level()
		"corpse_farm":
			_draw_corpse_farm_level()
		"archaeology_team":
			_draw_archaeology_level()
		"scary_barbie":
			_draw_scary_barbie_level()
		"fairy_academy":
			_draw_xianxia_level()
		"blank_level":
			_draw_blank_level()
		_:
			_draw_hub()


func _draw_hub() -> void:
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color(0.78, 0.84, 0.74))
	draw_rect(Rect2(-580.0, -285.0, 1160.0, 590.0), Color(0.92, 0.88, 0.76))
	for x in range(-540, 581, 80):
		draw_line(Vector2(x, -270.0), Vector2(x, 290.0), Color(0.80, 0.75, 0.62), 1.0)
	for y in range(-260, 291, 80):
		draw_line(Vector2(-560.0, y), Vector2(560.0, y), Color(0.80, 0.75, 0.62), 1.0)
	draw_rect(Rect2(-590.0, -295.0, 1180.0, 610.0), Color(0.28, 0.33, 0.27), false, 6.0)


func _draw_pixel_level() -> void:
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color(0.12, 0.13, 0.18))
	for y in range(-280, 301, 32):
		for x in range(-560, 561, 32):
			var color := Color(0.25, 0.28, 0.35) if int(float(x + y) / 32.0) % 2 == 0 else Color(0.18, 0.20, 0.27)
			draw_rect(Rect2(x, y, 32.0, 32.0), color)
	draw_rect(Rect2(-570.0, -290.0, 1140.0, 610.0), Color(0.72, 0.84, 1.0), false, 6.0)
	for i in range(7):
		draw_rect(Rect2(-450.0 + i * 150.0, -180.0 + (i % 2) * 80.0, 48.0, 48.0), Color(0.91, 0.34, 0.26))


func _draw_meow_energy_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.96, 0.94, 0.90))
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color(0.99, 0.96, 0.92))
	for i in range(12):
		var x := -620.0 + i * 112.0
		var y := -250.0 + sin(float(i) * 1.3) * 38.0
		draw_circle(Vector2(x, y), 54.0, Color(0.78, 0.92, 0.88, 0.10))
	for i in range(9):
		var x := -560.0 + i * 140.0
		draw_line(Vector2(x, -300.0), Vector2(x + 48.0, 292.0), Color(0.68, 0.54, 0.45, 0.07), 2.0)
	draw_rect(Rect2(-606.0, -318.0, 1212.0, 640.0), Color(0.34, 0.22, 0.16, 0.25), false, 3.0)


const PAPER_BG_TEXTURE_PATH := "res://assets/generated/paper_level_background.png"
var paper_bg_texture: Texture2D


func _draw_fridge_pomodoro_level() -> void:
	if paper_bg_texture == null and ResourceLoader.exists(PAPER_BG_TEXTURE_PATH):
		paper_bg_texture = load(PAPER_BG_TEXTURE_PATH) as Texture2D
	
	if paper_bg_texture != null:
		# Draw the paper texture centered over the camera viewport (1280x720 centered at 0,0)
		draw_texture_rect(paper_bg_texture, Rect2(-640.0, -360.0, 1280.0, 720.0), false)
	else:
		draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.85, 0.85, 0.55))


func _draw_desktop_fish_tank_level() -> void:
	return


func _draw_wizard_keyboard_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.03, 0.03, 0.04))


func _draw_robot_town_level() -> void:
	return


func _draw_mouse_genesis_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.012, 0.014, 0.020))


func _draw_archaeology_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color.BLACK)


func _draw_scary_barbie_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.018, 0.010, 0.020))
	draw_rect(Rect2(-600.0, -305.0, 1200.0, 620.0), Color(0.08, 0.03, 0.06))
	draw_rect(Rect2(-600.0, -305.0, 1200.0, 620.0), Color(0.66, 0.10, 0.30, 0.22), false, 6.0)
	for i in range(10):
		var x := -540.0 + i * 108.0
		draw_line(Vector2(x, -286.0), Vector2(x + sin(i * 1.8) * 18.0, 312.0), Color(0.18, 0.05, 0.11, 0.22), 1.0)
	for i in range(6):
		var y := -250.0 + i * 96.0
		draw_line(Vector2(-560.0, y), Vector2(560.0, y + cos(i * 1.2) * 8.0), Color(0.26, 0.06, 0.15, 0.18), 1.0)


func _draw_clay_level() -> void:
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color(0.70, 0.76, 0.65))
	draw_rect(Rect2(-575.0, -290.0, 1150.0, 610.0), Color(0.78, 0.62, 0.45))
	for i in range(8):
		var center := Vector2(-480.0 + i * 140.0, -90.0 + sin(i * 1.7) * 90.0)
		draw_circle(center, 42.0 + (i % 3) * 10.0, base_color.lightened(0.1 * (i % 2)))
		draw_circle(center + Vector2(10.0, -12.0), 18.0, Color(1.0, 0.88, 0.68, 0.25))
	draw_rect(Rect2(-585.0, -300.0, 1170.0, 630.0), Color(0.42, 0.28, 0.22), false, 7.0)


func _draw_corpse_farm_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color.BLACK)


func _draw_tiny_prison_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.12, 0.13, 0.14))


func _draw_cartoon_level() -> void:
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color(0.77, 0.91, 1.0))
	draw_rect(Rect2(-580.0, -285.0, 1160.0, 605.0), Color(0.70, 0.91, 0.50))
	for i in range(6):
		var pos := Vector2(-470.0 + i * 185.0, -120.0 + (i % 2) * 110.0)
		draw_circle(pos, 36.0, Color(1.0, 0.95, 0.18))
		draw_circle(pos, 25.0, Color(1.0, 0.72, 0.19))
		draw_line(pos + Vector2(-42.0, 42.0), pos + Vector2(42.0, -42.0), Color(0.08, 0.08, 0.08), 5.0)
	draw_rect(Rect2(-590.0, -295.0, 1180.0, 625.0), Color(0.05, 0.05, 0.06), false, 8.0)


func _draw_xianxia_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.94, 0.91, 0.76))
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color(0.98, 0.94, 0.78))
	for i in range(11):
		var y := -334.0 + i * 62.0
		draw_line(Vector2(-640.0, y), Vector2(640.0, y + sin(float(i) * 1.7) * 28.0), Color(0.25, 0.32, 0.26, 0.05), 2.0)
	for i in range(7):
		var center := Vector2(-510.0 + i * 170.0, -236.0 + sin(float(i) * 1.1) * 30.0)
		draw_circle(center, 82.0 + float(i % 3) * 18.0, Color(0.38, 0.48, 0.39, 0.05))
	draw_rect(Rect2(-608.0, -318.0, 1216.0, 642.0), Color(0.12, 0.14, 0.11, 0.44), false, 3.0)


func _draw_blank_level() -> void:
	draw_rect(Rect2(-4096.0, -4096.0, 8192.0, 8192.0), Color(0.90, 0.91, 0.93))
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color(0.96, 0.96, 0.97))
	draw_rect(Rect2(-590.0, -295.0, 1180.0, 620.0), base_color.darkened(0.25), false, 6.0)
