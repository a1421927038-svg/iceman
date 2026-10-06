extends SceneTree
## Layered composition of the fridge cat.
##
## The collar used to be composited FLAT onto a finished pose, which has no correct answer: tucked at the
## chin it covered the muzzle, moved down it looked too low. Building the cat from separate layers fixes
## both - the band's top tucks UNDER the chin and the head (drawn after it) hides the tuck, and the paws
## are drawn LAST so they sit in front of the body instead of leaving notches cut out of it.
##
## Draw order:  body -> collar -> head -> paws
## Layers:      cat_layer_body.png / cat_layer_head.png / cat_layer_paws.png / cat_collar_v2.png
##              plus one head per other pose: the 2x2 cat_head_open_sheet.png, cat_head_doze.png,
##              cat_head_startle.png
## Run:         godot --path <project> --headless -s res://tests/_cat_compose.gd

const F := 256
const GROUND := 255
const TOTAL_H := 252.0        # subject height BEFORE the head drop; the art itself lands at ~244
const HEAD_W_RATIO := 1.05    # the head is a touch wider than the body
const COLLAR_W_RATIO := 0.95  # collar width relative to the head's width
const PAW_W_RATIO := 0.74     # both paws together, relative to the body's width
const OVERLAP_FRAC := 0.055   # the head sits DOWN onto the collar and covers its upper part
const HEAD_DROP := 8.0        # 猫头再往下移动些 - push the head straight down
const CHIN_TUCK := 17.0       # 9 + HEAD_DROP: keeps the collar exactly where it was on the body while the
							  # head sinks further over it, so the chin covers even more of the band

func load_rgba(path: String) -> Image:
	var im := Image.new()
	im.load(ProjectSettings.globalize_path(path))
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	return im

func crop_to_used(im: Image) -> Image:
	var u: Rect2i = im.get_used_rect()
	if u.size.x <= 0 or u.size.y <= 0:
		return Image.create(1, 1, true, Image.FORMAT_RGBA8)
	return im.get_region(u)

## crop to the subject, then scale to the requested width (aspect kept)
func at_width(im: Image, w: int) -> Image:
	var c: Image = crop_to_used(im)
	var h: int = maxi(int(round(float(c.get_height()) * float(w) / float(c.get_width()))), 1)
	var out: Image = c.duplicate()
	out.resize(maxi(w, 1), h, Image.INTERPOLATE_LANCZOS)
	return out

func compose(body: Image, head: Image, collar: Image, paws: Image) -> Image:
	var canvas := Image.create(F, F, true, Image.FORMAT_RGBA8)
	var bu: Rect2i = body.get_used_rect()
	var hu: Rect2i = head.get_used_rect()
	var pu: Rect2i = paws.get_used_rect()
	if bu.size.x <= 0 or bu.size.y <= 0 or hu.size.x <= 0 or hu.size.y <= 0 or pu.size.x <= 0:
		print("!! compose: an empty layer (body=%s head=%s paws=%s)" % [str(bu.size), str(hu.size), str(pu.size)])
		return canvas
	var ba := float(bu.size.y) / float(bu.size.x)
	var ha := float(hu.size.y) / float(hu.size.x)
	var denom: float = ba + HEAD_W_RATIO * ha - OVERLAP_FRAC
	if denom <= 0.01:
		return canvas
	var wb: float = TOTAL_H / denom
	var wh: float = wb * HEAD_W_RATIO
	var body_img: Image = at_width(body, int(round(wb)))
	var head_img: Image = at_width(head, int(round(wh)))
	var collar_img: Image = at_width(collar, int(round(wh * COLLAR_W_RATIO)))
	var paw_img: Image = at_width(paws, int(round(wb * PAW_W_RATIO)))
	var body_top: int = GROUND - body_img.get_height() + 1
	var overlap: int = int(round(wb * OVERLAP_FRAC))
	var head_bottom: int = body_top + overlap + int(round(HEAD_DROP))
	var head_top: int = head_bottom - head_img.get_height() + 1
	# 1. body (bottom layer)
	canvas.blend_rect(body_img, Rect2i(0, 0, body_img.get_width(), body_img.get_height()),
		Vector2i((F - body_img.get_width()) / 2, body_top))
	# 2. collar - its band's top edge tucks up behind the chin
	canvas.blend_rect(collar_img, Rect2i(0, 0, collar_img.get_width(), collar_img.get_height()),
		Vector2i((F - collar_img.get_width()) / 2, head_bottom - int(CHIN_TUCK)))
	# 3. head over the collar, so only the part below the chin shows
	canvas.blend_rect(head_img, Rect2i(0, 0, head_img.get_width(), head_img.get_height()),
		Vector2i((F - head_img.get_width()) / 2, head_top))
	# 4. paws IN FRONT of the body
	canvas.blend_rect(paw_img, Rect2i(0, 0, paw_img.get_width(), paw_img.get_height()),
		Vector2i((F - paw_img.get_width()) / 2, GROUND - paw_img.get_height() + 1))
	return canvas

func blank() -> Image:
	return Image.create(F, F, true, Image.FORMAT_RGBA8)

func squash(src: Image, f: float) -> Image:
	var h := maxi(int(round(F * f)), 1)
	var t: Image = src.duplicate()
	t.resize(F, h, Image.INTERPOLATE_LANCZOS)
	var out := blank()
	out.blend_rect(t, Rect2i(0, 0, F, h), Vector2i(0, GROUND - (h - 1)))
	return out

func hop(src: Image, dx: int, dy: int) -> Image:
	var out := blank()
	out.blend_rect(src, Rect2i(0, 0, F, F), Vector2i(dx, dy))
	return out

func sample_clamped(src: Image, fx: float, fy: float) -> Color:
	var x0 := clampi(int(floor(fx)), 0, F - 2)
	var y0 := clampi(int(floor(fy)), 0, F - 2)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var a: Color = src.get_pixel(x0, y0).lerp(src.get_pixel(x0 + 1, y0), tx)
	var b: Color = src.get_pixel(x0, y0 + 1).lerp(src.get_pixel(x0 + 1, y0 + 1), tx)
	return a.lerp(b, ty)

func rock(src: Image, deg: float) -> Image:
	var rad := deg * PI / 180.0
	var ca := cos(rad)
	var sa := sin(rad)
	var pivot := Vector2(F * 0.5, float(GROUND))
	var out := blank()
	for y in F:
		for x in F:
			var dx := float(x) - pivot.x
			var dy := float(y) - pivot.y
			var sx := pivot.x + dx * ca + dy * sa
			var sy := pivot.y - dx * sa + dy * ca
			if sx < 0.0 or sy < 0.0 or sx > float(F - 2) or sy > float(F - 2):
				continue
			out.set_pixel(x, y, sample_clamped(src, sx, sy))
	var u: Rect2i = out.get_used_rect()
	if u.size.x <= 0 or u.size.y <= 0:
		return out
	var target: int = GROUND - (u.position.y + u.size.y - 1)
	if target != 0:
		return hop(out, 0, target)
	return out

func write_atlas(frames: Array, path: String) -> void:
	var out := Image.create(F * frames.size(), F, true, Image.FORMAT_RGBA8)
	for i in frames.size():
		out.blend_rect(frames[i], Rect2i(0, 0, F, F), Vector2i(F * i, 0))
	if out.get_used_rect().size.x <= 0:
		print("!! atlas %s empty - not saving" % path.get_file())
		return
	out.save_png(ProjectSettings.globalize_path(path))

func fit_into(img: Image, canvas_size: int, limit: int) -> Image:
	var u: Rect2i = img.get_used_rect()
	var canvas := Image.create(canvas_size, canvas_size, true, Image.FORMAT_RGBA8)
	if u.size.x <= 0 or u.size.y <= 0:
		return canvas
	var crop: Image = img.get_region(u)
	var s: float = minf(1.0, minf(float(limit) / float(crop.get_width()), float(limit) / float(crop.get_height())))
	var scaled: Image = crop.duplicate()
	if absf(s - 1.0) > 0.002:
		scaled.resize(maxi(int(round(float(crop.get_width()) * s)), 1), maxi(int(round(float(crop.get_height()) * s)), 1), Image.INTERPOLATE_LANCZOS)
	var su: Rect2i = scaled.get_used_rect()
	canvas.blend_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()),
		Vector2i((canvas_size - su.size.x) / 2 - su.position.x, (canvas_size - su.size.y) / 2 - su.position.y))
	return canvas

func _init() -> void:
	var body: Image = load_rgba("res://assets/generated/cat_layer_body_v2.png")
	var idle_head: Image = load_rgba("res://assets/generated/cat_layer_head.png")
	var paws: Image = load_rgba("res://assets/generated/cat_layer_paws.png")
	var collar: Image = load_rgba("res://assets/generated/cat_collar_v2.png")

	print("--- composing the front poses (body -> collar -> head -> paws) ---")
	var idle: Image = compose(body, idle_head, collar, paws)
	idle.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_idle.png"))
	print("idle            used=%s" % str(idle.get_used_rect()))

	var doze: Image = compose(body, load_rgba("res://assets/generated/cat_head_doze.png"), collar, paws)
	doze.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_doze.png"))
	print("doze            used=%s" % str(doze.get_used_rect()))

	var startle: Image = compose(body, load_rgba("res://assets/generated/cat_head_startle.png"), collar, paws)
	startle.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_startle.png"))
	print("startle         used=%s" % str(startle.get_used_rect()))

	var sheet: Image = load_rgba("res://assets/generated/cat_head_open_sheet.png")
	var cells := [Vector2i(0, 0), Vector2i(512, 0), Vector2i(0, 512), Vector2i(512, 512)]
	for i in 4:
		var cell: Image = sheet.get_region(Rect2i(cells[i].x, cells[i].y, 512, 512))
		var framed: Image = compose(body, cell, collar, paws)
		framed.save_png(ProjectSettings.globalize_path("res://assets/generated/paper_cat_open_cow_0%d.png" % (i + 1)))
		print("open_0%d         used=%s" % [i + 1, str(framed.get_used_rect())])

	# the lying and side poses are their own full-body art, kept from the previous pipeline
	var sleep: Image = load_rgba("res://tests/_fit_fridge_sleep.png")
	var side: Image = load_rgba("res://tests/_fit_fridge_side.png")
	print("sleep (kept)    used=%s" % str(sleep.get_used_rect()))
	print("side  (kept)    used=%s" % str(side.get_used_rect()))

	print("--- atlases ---")
	var idle_f := [1.0, 1.006, 1.012, 1.006, 1.0, 1.004]
	var idle_dx := [0, 1, 1, 0, -1, -1]
	var frames: Array = []
	for i in 6:
		frames.append(hop(squash(idle, idle_f[i]), idle_dx[i], 0))
	write_atlas(frames, "res://assets/generated/cat_idle_cow.png")
	var sleep_f := [1.0, 1.004, 1.008, 1.004, 1.0, 1.002]
	frames = []
	for i in 6:
		frames.append(squash(sleep, sleep_f[i]))
	write_atlas(frames, "res://assets/generated/cat_sleep_cow.png")
	var play_rock := [0.0, -1.8, -3.0, -1.8, 0.0, 1.8]
	var play_hop := [0, -3, -5, -3, 0, 1]
	frames = []
	for i in 6:
		frames.append(hop(rock(squash(idle, 1.0), play_rock[i]), 0, play_hop[i]))
	write_atlas(frames, "res://assets/generated/cat_play_ball_cow.png")
	var hair_base: Image = idle.duplicate()
	hair_base.resize(F, F, Image.INTERPOLATE_LANCZOS)
	var hair_f := [1.0, 1.02, 1.05, 1.02, 1.0, 1.01]
	frames = []
	for i in 6:
		frames.append(squash(hair_base, hair_f[i]))
	write_atlas(frames, "res://assets/generated/cat_hairball_cow.png")
	var run_rock := [-2.6, -1.3, 0.0, 1.3, 2.6, 1.3]
	frames = []
	for i in 6:
		frames.append(rock(side, run_rock[i]))
	write_atlas(frames, "res://assets/generated/cat_run_cow.png")
	write_atlas([doze], "res://assets/generated/cat_doze_cow.png")
	write_atlas([startle], "res://assets/generated/cat_startle_cow.png")

	print("--- gallery icons ---")
	var icon_src := {"rest_stand": idle, "doze": doze, "sleep": sleep, "play_ball": idle, "hairball": idle, "run": side}
	var toy: Image = load_rgba("res://assets/generated/cat_play_toy.png")
	for key: String in icon_src.keys():
		var icon: Image = fit_into(icon_src[key], 96, 84)
		if key == "play_ball":
			var t2: Image = fit_into(toy, 34, 30)
			icon.blend_rect(t2, Rect2i(0, 0, 34, 34), Vector2i(58, 54))
		icon.save_png(ProjectSettings.globalize_path("res://assets/generated/paper_icon_cat_%s.png" % key))
		print("  icon %-32s used=%s" % ["paper_icon_cat_%s.png" % key, str(icon.get_used_rect())])

	# pink check: the right ear's inner must survive the downscale
	var pink_n := 0
	for y in F:
		for x in F:
			var c: Color = idle.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.45 and c.r - c.g > 0.06:
				pink_n += 1
	print("idle pink pixels = %d (right ear inner)" % pink_n)
	print("done")
	quit()