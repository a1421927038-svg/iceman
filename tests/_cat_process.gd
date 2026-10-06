extends SceneTree
## Fridge-cat art pipeline: fit -> strip the dark outline (protecting colour) -> put a controlled
## amount of edge back by height band -> repaint the right-ear pink -> wrap the collar + bell ->
## rebuild the atlases and the gallery icons.
##
## Run it with:   godot --path <project> --headless -s res://tests/_cat_process.gd
## Sources:       assets/generated/cat_v5_base.png      (sitting, front)
##                assets/generated/cat_v6_doze.png      (sitting, drowsy)
##                assets/generated/cat_v6_startle.png   (sitting, startled)
##                assets/generated/cat_v6_open_sheet.png(2x2, eyes closed, mouth stages)
##                assets/generated/cat_v6_side.png      (4 legs, right-facing, for the run)
##                assets/generated/cat_v3_sleep.png     (lying, paws hidden)
##                assets/generated/cat_collar.png       (red band + bell, transparent)
##
## NOTE the backpack panel (paper_cat_mouth_inventory_panel.png) is NOT touched here - its inner
## ear was blackened once and re-running that step is not idempotent.

const F := 256
const GROUND := 255
const PAW_STRENGTH := 0.10      # the user wants 没有描边的可爱圆润的 paws -> no edge at all
const JUNCTION_STRENGTH := 0.92 # head/body contact shadow: a full-strength edge, no grey specks
const OTHER_STRENGTH := 0.15
const EAR_PINK := Color(0.905, 0.600, 0.585, 1.0)  # the backpack panel's inner-ear pink
# 1.00 = the band is exactly as wide as the neck's narrowest row, so it reads as a ring that
# goes around the neck instead of a long strip sticking out past the body's silhouette.
const COLLAR_WIDTH_BOOST := 1.00
# 1.00 keeps the bell perfectly ROUND - squashing the height flattens it into an ellipse.
const COLLAR_HEIGHT_SQUASH := 1.00

func lum(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0

func chroma(c: Color) -> float:
	return maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)

func is_pink(c: Color) -> bool:
	return c.a > 0.5 and c.r > 0.45 and c.r - c.g > 0.06 and c.r - c.b > 0.03

## The offsets are for blitting the SCALED CROP (its origin is 0), so the source's own used-rect
## position must NOT be subtracted again - doing that pushes the whole image off-canvas.
func fit_transform(src: Image, limit: int) -> Dictionary:
	var u: Rect2i = src.get_used_rect()
	var s: float = minf(1.0, minf(float(limit) / float(u.size.x), float(limit) / float(u.size.y)))
	var sw: int = maxi(int(round(float(u.size.x) * s)), 1)
	var sh: int = maxi(int(round(float(u.size.y) * s)), 1)
	return {"src": u, "s": s, "w": sw, "h": sh, "ox": (F - sw) / 2, "oy": GROUND - (sh - 1)}

func fit_image(src: Image, limit: int) -> Image:
	var t: Dictionary = fit_transform(src, limit)
	var u: Rect2i = t["src"]
	var crop: Image = src.get_region(u)
	var scaled: Image = crop.duplicate()
	if absf(t["s"] - 1.0) > 0.002:
		scaled.resize(t["w"], t["h"], Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(F, F, true, Image.FORMAT_RGBA8)
	canvas.blend_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()), Vector2i(t["ox"], t["oy"]))
	return canvas

## BFS outward from interior seeds; rewrite a pixel when the nearest seed colour is clearly
## lighter. A CHROMATIC pixel is its own seed and is never recoloured: the pink inner ear sits
## too close to the transparent background to qualify geometrically and was being washed out.
func strip_outline(canvas: Image) -> Dictionary:
	var before := canvas.duplicate()
	var seeds := {}
	var colour := {}
	var queue: Array = []
	for y in F:
		for x in F:
			var p := Vector2i(x, y)
			var c: Color = canvas.get_pixel(x, y)
			if c.a <= 0.9:
				continue
			if chroma(c) > 0.06:
				seeds[p] = true
				colour[p] = c
				queue.append(p)
				continue
			var interior := true
			for dy in range(-8, 9):
				for dx in range(-8, 9):
					if maxi(absi(dx), absi(dy)) > 8:
						continue
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= F or ny >= F or canvas.get_pixel(nx, ny).a < 0.15:
						interior = false
						break
				if not interior:
					break
			if interior:
				seeds[p] = true
				colour[p] = c
				queue.append(p)
	var touched := {}
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var base: Color = colour[p]
		var c: Color = canvas.get_pixel(p.x, p.y)
		if not seeds.has(p) and c.a >= 0.15 and lum(base) > lum(c) + 0.15:
			canvas.set_pixel(p.x, p.y, Color(base.r, base.g, base.b, c.a))
			touched[p] = true
			colour[p] = Color(base.r, base.g, base.b, 1.0)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := Vector2i(p.x + dx, p.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= F or n.y >= F or colour.has(n):
					continue
				colour[n] = base
				queue.append(n)
	return {"before": before, "touched": touched}

func restore_edges(canvas: Image, info: Dictionary) -> void:
	var before: Image = info["before"]
	var touched: Dictionary = info["touched"]
	var u: Rect2i = canvas.get_used_rect()
	var top := float(u.position.y)
	var bot := float(u.position.y + u.size.y - 1)
	var span: float = maxf(bot - top, 1.0)
	for p: Vector2i in touched.keys():
		var frac: float = (float(p.y) - top) / span
		var strength := OTHER_STRENGTH
		if frac >= 0.42 and frac <= 0.68:
			strength = JUNCTION_STRENGTH
		elif frac >= 0.80:
			strength = PAW_STRENGTH
		canvas.set_pixel(p.x, p.y, canvas.get_pixel(p.x, p.y).lerp(before.get_pixel(p.x, p.y), strength))

func repaint_right_ear(canvas: Image, src: Image, t: Dictionary) -> int:
	var u: Rect2i = t["src"]
	var s: float = t["s"]
	var cutoff: int = u.position.y + int(float(u.size.y) * 0.30)   # ears only, the nose sits lower
	var mask := {}
	for y in range(u.position.y, mini(cutoff, u.position.y + u.size.y)):
		for x in range(u.position.x, u.position.x + u.size.x):
			if not is_pink(src.get_pixel(x, y)):
				continue
			var tx: int = int(round(float(x - u.position.x) * s)) + t["ox"]
			var ty: int = int(round(float(y - u.position.y) * s)) + t["oy"]
			for dy in range(0, 2):
				for dx in range(0, 2):
					var p := Vector2i(tx + dx, ty + dy)
					if p.x >= 0 and p.y >= 0 and p.x < F and p.y < F:
						mask[p] = true
	var painted := 0
	for p: Vector2i in mask.keys():
		if canvas.get_pixel(p.x, p.y).a <= 0.5:
			continue
		canvas.set_pixel(p.x, p.y, Color(EAR_PINK.r, EAR_PINK.g, EAR_PINK.b, canvas.get_pixel(p.x, p.y).a))
		painted += 1
	return painted

## The neck is the narrowest row between the head's widest row and the body's widest row. The band
## is laid PERPENDICULAR to the head-to-body direction, which keeps it upright on the front poses
## and turns it correctly on the side/lying ones. atan2(v) - 90 puts the BELL BELOW the band (with
## atan2(v) + 90 the band comes out upside-down, the bell above it).
func add_collar(canvas: Image, collar: Image, width_boost: float, height_squash: float) -> bool:
	var u: Rect2i = canvas.get_used_rect()
	if u.size.x <= 0 or u.size.y <= 0:
		return false
	var top := u.position.y
	var bot := u.position.y + u.size.y - 1
	var span: float = maxf(float(bot - top), 1.0)
	var minx := {}
	var maxx := {}
	for y in range(top, bot + 1):
		var mn := 99999
		var mx := -1
		for x in range(u.position.x, u.position.x + u.size.x):
			if canvas.get_pixel(x, y).a > 0.5:
				mn = mini(mn, x)
				mx = maxi(mx, x)
		if mx >= 0:
			minx[y] = mn
			maxx[y] = mx
	if minx.is_empty():
		return false
	var neck := Vector2.ZERO
	var neck_w := 0
	var ang := 0.0
	if u.size.x > u.size.y:
		# A LYING subject (the sleep art): we see the cat head-on with the body receding, so the
		# collar sits UPRIGHT at the head's lower edge. The row-based neck search below would pick a
		# row as wide as the whole body and blow the collar up to the size of the cat. The head's end
		# is the half that carries the pink (the nose / inner ear).
		var pink_x := 0.0
		var pink_n := 0
		for y in range(top, bot + 1):
			for x in range(u.position.x, u.position.x + u.size.x):
				if is_pink(canvas.get_pixel(x, y)):
					pink_x += float(x)
					pink_n += 1
		var head_left := true
		if pink_n > 0:
			head_left = (pink_x / float(pink_n)) < (float(u.position.x) + float(u.size.x) * 0.5)
		var hx0: int = u.position.x
		var hx1: int = u.position.x + u.size.x / 2
		if not head_left:
			hx0 = u.position.x + u.size.x / 2
			hx1 = u.position.x + u.size.x - 1
		var head_bot := top
		for y in range(top, bot + 1):
			for x in range(hx0, hx1 + 1):
				if canvas.get_pixel(x, y).a > 0.5:
					head_bot = y
		var probe: int = maxi(head_bot - 8, top)
		var run_l := hx0
		var run_r := hx0
		for x in range(hx0, hx1 + 1):
			if canvas.get_pixel(x, probe).a > 0.5:
				run_r = x
		for x in range(hx0, hx1 + 1):
			if canvas.get_pixel(x, probe).a > 0.5:
				run_l = x
				break
		neck_w = maxi(run_r - run_l + 1, 40)
		# lift the collar off the art's bottom edge, otherwise the bell hangs off-canvas
		neck = Vector2(float(run_l + run_r) * 0.5, float(head_bot) - 34.0)
		ang = 0.0
	else:
		var head_row := top
		var body_row := bot
		var head_w := 0
		var body_w := 0
		for y: int in minx.keys():
			var frac := float(y - top) / span
			var w: int = maxx[y] - minx[y] + 1
			if frac <= 0.5 and w > head_w:
				head_w = w
				head_row = y
			if frac >= 0.55 and w > body_w:
				body_w = w
				body_row = y
		var neck_row := head_row
		neck_w = 99999
		# Keep the neck at the head/body junction. A SIDE view's width profile has a second pinch
		# much lower down (the chest), which put the collar on the belly instead.
		var search_end: int = mini(maxi(body_row, head_row + 2), top + int(span * 0.55) + 1)
		for y in range(head_row + 1, search_end):
			if not minx.has(y):
				continue
			var w: int = maxx[y] - minx[y] + 1
			if w < neck_w:
				neck_w = w
				neck_row = y
		if neck_w > 99998 or neck_row <= head_row:
			neck_row = top + int(span * 0.47)
			neck_w = head_w
		var hc := Vector2.ZERO
		var hn := 0
		var bc := Vector2.ZERO
		var bn := 0
		for y: int in minx.keys():
			var frac := float(y - top) / span
			var cx := float(minx[y] + maxx[y]) * 0.5
			if frac <= 0.42:
				hc += Vector2(cx, float(y))
				hn += 1
			elif frac >= 0.60:
				bc += Vector2(cx, float(y))
				bn += 1
		if hn == 0 or bn == 0:
			return false
		hc /= float(hn)
		bc /= float(bn)
		var v := bc - hc
		ang = atan2(v.y, v.x) - PI * 0.5
		# The width profile's narrowest row sits ON THE MUZZLE for this sitting pose (the black cap's
		# edge fakes a pinch at ~y116 while the face's light area runs to ~y146), which put the collar
		# across the chin. Find where the LIGHT face actually ends and hang the collar under that.
		var face_limit: int = top + int(span * 0.70)
		for y in range(top, face_limit):
			var rmn := 99999
			var rmx := -1
			for x in range(u.position.x, u.position.x + u.size.x):
				if canvas.get_pixel(x, y).a > 0.5:
					rmn = mini(rmn, x)
					rmx = maxi(rmx, x)
			if rmx < 0:
				continue
			var rw: int = rmx - rmn + 1
			var cx0: int = rmn + int(float(rw) * 0.25)
			var cx1: int = rmn + int(float(rw) * 0.75)
			var lights := 0
			for x in range(cx0, cx1 + 1):
				var lc: Color = canvas.get_pixel(x, y)
				if lc.a > 0.5 and lum(lc) > 0.62:
					lights += 1
			if lights >= maxi(6, int(float(rw) * 0.15)):
				neck = Vector2(neck.x, float(y))
		neck = Vector2(float(minx[neck_row] + maxx[neck_row]) * 0.5, neck.y)
	var cu: Rect2i = collar.get_used_rect()
	var sc: float = (float(neck_w) * width_boost) / float(cu.size.x)
	var out_w: int = maxi(int(round(float(cu.size.x) * sc)), 2)
	var out_h: int = maxi(int(round(float(cu.size.y) * sc * height_squash)), 2)
	var band: Image = collar.get_region(cu).duplicate()
	band.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)
	var diag: int = int(ceil(sqrt(float(out_w * out_w + out_h * out_h)))) + 4
	var rot := Image.create(diag, diag, true, Image.FORMAT_RGBA8)
	var ca := cos(-ang)
	var sa := sin(-ang)
	var c0 := Vector2(float(diag) * 0.5, float(diag) * 0.5)
	var bcx := float(out_w) * 0.5
	var bcy := float(out_h) * 0.5
	for oy in diag:
		for ox in diag:
			var dx := float(ox) - c0.x
			var dy := float(oy) - c0.y
			var rx := c0.x + dx * ca + dy * sa
			var ry := c0.y - dx * sa + dy * ca
			var ux := rx + (bcx - c0.x)
			var uy := ry + (bcy - c0.y)
			if ux < 0.0 or uy < 0.0 or ux >= float(out_w - 1) or uy >= float(out_h - 1):
				continue
			var x0 := clampi(int(floor(ux)), 0, out_w - 2)
			var y0 := clampi(int(floor(uy)), 0, out_h - 2)
			var tx := ux - float(x0)
			var ty := uy - float(y0)
			var pa: Color = band.get_pixel(x0, y0).lerp(band.get_pixel(x0 + 1, y0), tx)
			var pb: Color = band.get_pixel(x0, y0 + 1).lerp(band.get_pixel(x0 + 1, y0 + 1), tx)
			rot.set_pixel(ox, oy, pa.lerp(pb, ty))
	# the band's TOP edge goes just under the face (sitting) / above the art's bottom (lying)
	var place_y: float
	if u.size.x > u.size.y:
		place_y = neck.y - c0.y + float(neck_w) * 0.10
	else:
		place_y = neck.y - c0.y + float(out_h) * 0.5 + 10.0
	var place := Vector2i(int(round(neck.x - c0.x)), int(round(place_y)))
	var ok := false
	for oy in diag:
		for ox in diag:
			var c: Color = rot.get_pixel(ox, oy)
			if c.a <= 0.02:
				continue
			var tx2 := place.x + ox
			var ty2 := place.y + oy
			if tx2 < 0 or ty2 < 0 or tx2 >= F or ty2 >= F:
				continue
			var dst: Color = canvas.get_pixel(tx2, ty2)
			var col := Color(c.r, c.g, c.b, 1.0)
			if dst.a > 0.5:
				col = col.lerp(Color(dst.r, dst.g, dst.b, 1.0), 1.0 - c.a)
			canvas.set_pixel(tx2, ty2, Color(col.r, col.g, col.b, maxf(c.a, dst.a)))
			ok = true
	print("    collar neck row=%d w=%d ang=%.0f band=%dx%d" % [int(neck.y), neck_w, rad_to_deg(ang), out_w, out_h])
	return ok

func load_fresh(path: String) -> Image:
	var im := Image.new()
	im.load(ProjectSettings.globalize_path(path))
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	return im

func process(src_path: String, dst: String, limit: int, collar: Image, ear_fix: bool) -> Image:
	var src: Image = load_fresh(src_path)
	var t: Dictionary = fit_transform(src, limit)
	var framed: Image = fit_image(src, limit)
	var u: Rect2i = framed.get_used_rect()
	if u.size.x <= 0 or u.size.y <= 0:
		print("!! %s came out EMPTY - NOT saving (src=%s)" % [dst.get_file(), src_path.get_file()])
		return framed
	var info: Dictionary = strip_outline(framed)
	restore_edges(framed, info)
	var ear_n := 0
	if ear_fix:
		ear_n = repaint_right_ear(framed, src, t)
	add_collar(framed, collar, COLLAR_WIDTH_BOOST, COLLAR_HEIGHT_SQUASH)
	framed.save_png(ProjectSettings.globalize_path(dst))
	print("%-26s used=%s ear_px=%d" % [dst.get_file(), str(framed.get_used_rect()), ear_n])
	return framed

func blank() -> Image:
	return Image.create(F, F, true, Image.FORMAT_RGBA8)

func squash(src: Image, f: float) -> Image:
	var h := maxi(int(round(F * f)), 1)
	var tt: Image = src.duplicate()
	tt.resize(F, h, Image.INTERPOLATE_LANCZOS)
	var out := blank()
	out.blend_rect(tt, Rect2i(0, 0, F, h), Vector2i(0, GROUND - (h - 1)))
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
	var collar: Image = load_fresh("res://assets/generated/cat_collar_v2.png")
	print("--- poses ---")
	var idle: Image = process("res://assets/generated/cat_v5_base.png", "res://tests/_fit_fridge_idle.png", 244, collar, true)
	var doze: Image = process("res://assets/generated/cat_v6_doze.png", "res://tests/_fit_fridge_doze.png", 244, collar, true)
	var startle: Image = process("res://assets/generated/cat_v6_startle.png", "res://tests/_fit_fridge_startle.png", 244, collar, true)
	var sleep: Image = process("res://assets/generated/cat_v3_sleep.png", "res://tests/_fit_fridge_sleep.png", 244, collar, false)
	var side: Image = process("res://assets/generated/cat_v6_side.png", "res://tests/_fit_fridge_side.png", 226, collar, false)

	print("--- 张嘴 sheet ---")
	var sheet: Image = load_fresh("res://assets/generated/cat_v6_open_sheet.png")
	var cells := [Vector2i(0, 0), Vector2i(512, 0), Vector2i(0, 512), Vector2i(512, 512)]
	for i in 4:
		var cell: Image = sheet.get_region(Rect2i(cells[i].x, cells[i].y, 512, 512))
		var t: Dictionary = fit_transform(cell, 244)
		var framed: Image = fit_image(cell, 244)
		if framed.get_used_rect().size.x <= 0:
			print("!! open_0%d EMPTY" % (i + 1))
			continue
		var info: Dictionary = strip_outline(framed)
		restore_edges(framed, info)
		var n: int = repaint_right_ear(framed, cell, t)
		add_collar(framed, collar, COLLAR_WIDTH_BOOST, COLLAR_HEIGHT_SQUASH)
		framed.save_png(ProjectSettings.globalize_path("res://assets/generated/paper_cat_open_cow_0%d.png" % (i + 1)))
		print("  open_0%d used=%s ear_px=%d" % [i + 1, str(framed.get_used_rect()), n])

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
	var toy: Image = load_fresh("res://assets/generated/cat_play_toy.png")
	for key: String in icon_src.keys():
		var icon: Image = fit_into(icon_src[key], 96, 84)
		if key == "play_ball":
			var t2: Image = fit_into(toy, 34, 30)
			icon.blend_rect(t2, Rect2i(0, 0, 34, 34), Vector2i(58, 54))
		icon.save_png(ProjectSettings.globalize_path("res://assets/generated/paper_icon_cat_%s.png" % key))
		print("  icon %-32s used=%s" % ["paper_icon_cat_%s.png" % key, str(icon.get_used_rect())])
	print("done")
	quit()