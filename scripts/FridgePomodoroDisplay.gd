class_name FridgePomodoroDisplay
extends Control

var variant_id := "tomato"
var phase := "idle"
var progress := 0.0
var pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_variant_id(new_variant_id: String) -> void:
	variant_id = new_variant_id
	queue_redraw()


func set_phase(new_phase: String) -> void:
	phase = new_phase
	queue_redraw()


func set_progress(new_progress: float) -> void:
	progress = clamp(new_progress, 0.0, 1.0)
	queue_redraw()


func set_pulse(new_pulse: float) -> void:
	pulse = new_pulse
	queue_redraw()


func _draw() -> void:
	var panel_rect := Rect2(Vector2.ZERO, size)
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0:
		return

	var phase_accent := Color(0.38, 0.83, 0.92)
	if phase == "work":
		phase_accent = Color(0.95, 0.60, 0.26)
	elif phase == "break":
		phase_accent = Color(0.40, 0.88, 0.58)
	elif phase == "idle":
		phase_accent = Color(0.72, 0.74, 0.80)

	var inset := 10.0
	var body := panel_rect.grow(-inset)
	var shadow := body.grow(6.0)
	draw_rect(shadow, Color(0.04, 0.04, 0.05, 0.45))
	draw_rect(body, Color(0.10, 0.11, 0.13, 0.96), true)
	draw_rect(body, Color(phase_accent.darkened(0.55)), false, 4.0)
	draw_rect(body.grow(-8.0), Color(1.0, 1.0, 1.0, 0.04), false, 2.0)

	var center := body.get_center()
	var shortest_side: float = body.size.x if body.size.x < body.size.y else body.size.y
	var ring_radius: float = shortest_side * 0.34
	var wobble := sin(pulse * TAU) * 3.0
	_draw_progress_ring(center + Vector2(0.0, wobble * 0.3), ring_radius + wobble, phase_accent)

	match variant_id:
		"cassette":
			_draw_cassette(center, phase_accent)
		"pager":
			_draw_pager(center, phase_accent)
		"walkman":
			_draw_walkman(center, phase_accent)
		"crt":
			_draw_crt(center, phase_accent)
		"vhs":
			_draw_vhs(center, phase_accent)
		_:
			_draw_tomato(center, phase_accent)


func _draw_progress_ring(center: Vector2, radius: float, accent: Color) -> void:
	var ring_color := accent.lightened(0.15)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + progress * TAU, 48, ring_color, 7.0, true)
	draw_arc(center, radius + 8.0, -PI * 0.3, -PI * 0.3 + progress * TAU, 48, Color(1.0, 1.0, 1.0, 0.10), 2.0, true)


func _draw_tomato(center: Vector2, accent: Color) -> void:
	var body_color := Color(0.84, 0.24, 0.20)
	draw_circle(center, 64.0, body_color)
	draw_circle(center + Vector2(-18.0, -14.0), 18.0, Color(1.0, 1.0, 1.0, 0.12))
	draw_circle(center + Vector2(18.0, -18.0), 12.0, Color(1.0, 1.0, 1.0, 0.08))
	for i in range(5):
		var angle := -PI * 0.9 + float(i) * 0.38 + pulse * 0.2
		var leaf := center + Vector2(cos(angle), sin(angle)) * 34.0
		draw_line(center + Vector2(0.0, -52.0), leaf, Color(0.42, 0.63, 0.26), 6.0)
	draw_circle(center + Vector2(0.0, -56.0), 10.0, Color(0.42, 0.63, 0.26))
	_draw_needle(center, accent)


func _draw_cassette(center: Vector2, accent: Color) -> void:
	var body := Rect2(center - Vector2(74.0, 52.0), Vector2(148.0, 104.0))
	draw_rect(body, Color(0.20, 0.19, 0.17))
	draw_rect(body.grow(-8.0), Color(0.86, 0.80, 0.68))
	draw_rect(Rect2(body.position + Vector2(12.0, 14.0), Vector2(124.0, 22.0)), Color(0.70, 0.66, 0.56))
	draw_circle(center + Vector2(-34.0, 8.0), 21.0, Color(0.25, 0.22, 0.18))
	draw_circle(center + Vector2(34.0, 8.0), 21.0, Color(0.25, 0.22, 0.18))
	draw_circle(center + Vector2(-34.0, 8.0), 9.0, accent.lightened(0.2))
	draw_circle(center + Vector2(34.0, 8.0), 9.0, accent.lightened(0.2))
	draw_rect(Rect2(center - Vector2(18.0, 34.0), Vector2(36.0, 14.0)), accent)
	_draw_needle(center + Vector2(0.0, -24.0), accent)


func _draw_pager(center: Vector2, accent: Color) -> void:
	var body := Rect2(center - Vector2(50.0, 72.0), Vector2(100.0, 144.0))
	draw_rect(body, Color(0.22, 0.24, 0.26))
	draw_rect(body.grow(-7.0), Color(0.84, 0.88, 0.74))
	draw_rect(Rect2(body.position + Vector2(12.0, 18.0), Vector2(76.0, 34.0)), Color(0.18, 0.32, 0.22))
	draw_rect(Rect2(body.position + Vector2(20.0, 64.0), Vector2(60.0, 10.0)), accent)
	draw_rect(Rect2(body.position + Vector2(20.0, 82.0), Vector2(44.0, 10.0)), accent.darkened(0.08))
	draw_line(body.position + Vector2(82.0, 18.0), body.position + Vector2(96.0, -20.0), accent, 6.0)
	draw_circle(body.position + Vector2(96.0, -22.0), 8.0, accent.lightened(0.2))
	_draw_needle(center + Vector2(0.0, -4.0), accent)


func _draw_walkman(center: Vector2, accent: Color) -> void:
	var body := Rect2(center - Vector2(72.0, 48.0), Vector2(144.0, 96.0))
	draw_rect(body, Color(0.17, 0.18, 0.21))
	draw_rect(body.grow(-8.0), Color(0.79, 0.84, 0.79))
	draw_rect(Rect2(body.position + Vector2(20.0, 20.0), Vector2(60.0, 26.0)), Color(0.13, 0.15, 0.16))
	draw_circle(center + Vector2(-34.0, 36.0), 18.0, Color(0.25, 0.23, 0.20))
	draw_circle(center + Vector2(34.0, 36.0), 18.0, Color(0.25, 0.23, 0.20))
	draw_line(center + Vector2(-34.0, 18.0), center + Vector2(-70.0, -30.0), Color(0.27, 0.25, 0.22), 4.0)
	draw_line(center + Vector2(34.0, 18.0), center + Vector2(70.0, -30.0), Color(0.27, 0.25, 0.22), 4.0)
	draw_circle(center + Vector2(-70.0, -30.0), 10.0, accent)
	draw_circle(center + Vector2(70.0, -30.0), 10.0, accent)
	_draw_needle(center + Vector2(0.0, -8.0), accent)


func _draw_crt(center: Vector2, accent: Color) -> void:
	var body := Rect2(center - Vector2(74.0, 60.0), Vector2(148.0, 120.0))
	draw_rect(body, Color(0.15, 0.16, 0.18))
	draw_rect(body.grow(-8.0), Color(0.75, 0.82, 0.86))
	draw_rect(Rect2(body.position + Vector2(16.0, 18.0), Vector2(116.0, 64.0)), Color(0.11, 0.13, 0.16))
	var scan_y := body.position.y + 20.0 + progress * 52.0
	draw_rect(Rect2(body.position + Vector2(18.0, scan_y - body.position.y), Vector2(112.0, 6.0)), accent.lightened(0.25))
	draw_line(body.position + Vector2(34.0, -8.0), body.position + Vector2(12.0, -36.0), Color(0.25, 0.23, 0.18), 5.0)
	draw_line(body.position + Vector2(114.0, -8.0), body.position + Vector2(136.0, -36.0), Color(0.25, 0.23, 0.18), 5.0)
	draw_circle(body.position + Vector2(12.0, -36.0), 8.0, accent)
	draw_circle(body.position + Vector2(136.0, -36.0), 8.0, accent)
	_draw_needle(center + Vector2(0.0, -18.0), accent)


func _draw_vhs(center: Vector2, accent: Color) -> void:
	var body := Rect2(center - Vector2(78.0, 44.0), Vector2(156.0, 88.0))
	draw_rect(body, Color(0.14, 0.13, 0.12))
	draw_rect(body.grow(-8.0), Color(0.82, 0.80, 0.73))
	draw_rect(Rect2(body.position + Vector2(16.0, 16.0), Vector2(124.0, 18.0)), accent)
	draw_circle(center + Vector2(-42.0, 10.0), 22.0, Color(0.24, 0.22, 0.18))
	draw_circle(center + Vector2(42.0, 10.0), 22.0, Color(0.24, 0.22, 0.18))
	draw_circle(center + Vector2(-42.0, 10.0), 10.0, accent.lightened(0.18))
	draw_circle(center + Vector2(42.0, 10.0), 10.0, accent.lightened(0.18))
	draw_rect(Rect2(center - Vector2(18.0, 30.0), Vector2(36.0, 8.0)), Color(0.30, 0.29, 0.25))
	_draw_needle(center + Vector2(0.0, -10.0), accent)


func _draw_needle(center: Vector2, accent: Color) -> void:
	var angle := -PI * 0.5 + progress * TAU
	var reach := Vector2(cos(angle), sin(angle)) * 34.0
	draw_line(center, center + reach, accent.lightened(0.3), 4.0)
	draw_circle(center, 7.0, Color(0.98, 0.93, 0.80))
	draw_circle(center, 4.0, accent)
