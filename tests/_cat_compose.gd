extends SceneTree
## Layered composition of the fridge cat.
##
## The collar used to be composited FLAT onto a finished pose, which has no correct answer: tucked at the
## chin it covered the muzzle, moved down it looked too low. Building the cat from separate layers fixes
## both - the band's top tucks UNDER the chin and the head (drawn after it) hides the tuck, and the paws
## are drawn LAST so they sit in front of the body instead of leaving notches cut out of it.
##
## Draw order:  body -> collar -> head -> paws
## Layers:      cat_layer_body_v2.png / cat_layer_head.png / cat_layer_paws.png / cat_collar_v2.png
## Head variants (composed onto the shared body):  cat_head_open_sheet.png (2x2), cat_head_doze_v2.png,
##              cat_head_startle_v2.png
## Full-body poses (their own art, regenerated in the same look incl. the collar):
##              cat_pose_sleep.png (lying, no paws visible), cat_pose_run.png (4-leg side view),
##              cat_pose_hairball.png (hunched, coughing up a hairball)
## Run:         godot --path <project> --headless -s res://tests/_cat_compose.gd

const F := 256
const GROUND := 255
const TOTAL_H := 252.0        # subject height BEFORE the head drop; the art itself lands at ~244
const HEAD_W_RATIO := 1.05    # the head is a touch wider than the body
const COLLAR_W_RATIO := 0.95  # collar width relative to the head's width
const PAW_W_RATIO := 0.74     # both paws together, relative to the body's width

## 睡觉: 四个关键帧 (per the reference art) - 正常坐姿睁眼 -> 犯困半眯 -> 摊开 -> 熟睡猫饼.
## The four keys anchor a MELT that is played once (cat_sleep_melt_cow.png); the flat end
## then carries on as the accordion loop (cat_sleep_cow.png), which is what the sleep
## ACTION loops and whose frame 0 must stay a compact ball (see test_idle_animations).
## 小猫睡觉: 打了个哈气 -> 变成一个圆球 -> 像被黑洞吸走了 -> 消失. The once-played melt is
## the first two beats; the atlas (which the `sleep` action plays) is the last two.
## Melt: the sitting cat, the three yawn openings (the eyes squeeze shut as the mouth widens),
## then the cat condensing, then the ball - whose full-size frame IS the atlas' frame 0.
const SLEEP_MELT_MORPH_SCALE := 0.62
## 被黑洞吸走: one entry per atlas frame - the ball's SIZE and `t`, how far along a spiral it
## has been dragged. The spiral is SLEEP_SPIRAL_TURNS turns and tightens to nothing around the
## spot the cat was standing on, so the last frames are simply empty: 消失.
const SLEEP_SPIRAL_TURNS := 2.4
const SLEEP_SPIRAL_RADIUS := 48.0
const SLEEP_SPIRAL_STEPS := [
	{"size": 1.00, "t": 0.00},
	{"size": 0.94, "t": 0.16},
	{"size": 0.82, "t": 0.32},
	{"size": 0.66, "t": 0.50},
	{"size": 0.50, "t": 0.66},
	{"size": 0.34, "t": 0.80},
	{"size": 0.20, "t": 0.92},
	{"size": 0.08, "t": 1.00},
]
## 扔出一个大拖鞋: the slipper the fridge man lobs over for the cat - its own generated art
## (matte paper, deep red with a cream fleece trim; its opening, a dark hollow, faces up and
## to the LEFT, which is the side the cat creeps in from).
const SLEEP_SLIPPER_PATH := "res://assets/generated/cat_sleep_slipper_2.png"
## How big the slipper is once it has landed, and where it lands relative to the cat's spot.
const SLEEP_SLIPPER_WIDTH := 190.0
const SLEEP_SLIPPER_OFFSET := 24.0
## 冒出脑袋: once the slipper has LANDED the cat is simply there - no shrinking, no walking in
## (瞬间移动到鞋子里). It pops its head out and blinks awake, then shuts its eyes and sleeps:
## one step per face, `sink` being how far the body has dropped behind the slipper's front wall.
## At 84 the cat's own top row is 96, so the bbox is 204x160 - well inside the 210px the test
## allows for the action's frame 0.
const SLEEP_POPPED_STEPS := [
	{"head": "idle", "sink": 96.0},
	{"head": "doze", "sink": 88.0},
	{"head": "closed", "sink": 84.0},
]
## How much of the lost height turns into width: 1.0 keeps the cat's bulk, so it puddles
## out sideways as it flattens. (The front-view pose is only ~138px of the 256px frame, so
## this is free to be large - unlike the old side-view lying pose, which filled the frame.)
const SLEEP_PANCAKE_SPREAD := 1.0
## The z z Z that float above the sleeping pancake (its own art, like everything else).
const SLEEP_ZZ_PATH := "res://assets/generated/cat_sleep_zz.png"
const SLEEP_ZZ_SCALE := 0.40
const SLEEP_ZZ_ORIGIN := Vector2i(138, 54)
const OVERLAP_FRAC := 0.055   # the head sits DOWN onto the collar and covers its upper part
const HEAD_DROP := 8.0        # 猫头再往下移动些 - push the head straight down
const CHIN_TUCK := 17.0       # 9 + HEAD_DROP: keeps the collar exactly where it was on the body while the
	# head sinks further over it, so the chin covers even more of the band

## Aspect (height / width) of the idle head layer. Every head variant is forced to it,
## because compose derives BOTH the body width and the head width from the head's aspect:
## a variant a few percent off made the whole cat a few px wider with its head a few px
## higher than the idle ("打盹的猫脑袋发生偏移" - the doze keyframes must be the same size
## as the idle's head). Forcing the aspect keeps every pose's head and height identical.
var head_ref_aspect := 0.8672

func load_rgba(path: String) -> Image:
	var im := Image.new()
	im.load(ProjectSettings.globalize_path(path))
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	return im

func blank() -> Image:
	return Image.create(F, F, true, Image.FORMAT_RGBA8)

## crop to the subject and fit it on a 256 canvas: feet on row 255, centred, never upscaled
func fit_pose(path: String, limit: int) -> Image:
	var src: Image = load_rgba(path)
	var u: Rect2i = src.get_used_rect()
	if u.size.x <= 0 or u.size.y <= 0:
		print("!! fit_pose: %s is empty" % path.get_file())
		return blank()
	var crop: Image = src.get_region(u)
	var s: float = minf(1.0, minf(float(limit) / float(crop.get_width()), float(limit) / float(crop.get_height())))
	var scaled: Image = crop.duplicate()
	if absf(s - 1.0) > 0.002:
		scaled.resize(maxi(int(round(float(crop.get_width()) * s)), 1), maxi(int(round(float(crop.get_height()) * s)), 1), Image.INTERPOLATE_LANCZOS)
	var canvas := blank()
	var su: Rect2i = scaled.get_used_rect()
	canvas.blend_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()),
		Vector2i((F - su.size.x) / 2 - su.position.x, GROUND - (su.position.y + su.size.y - 1)))
	return canvas

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

## Where compose() last seated the head, so melt_frame() can put the SAME head back at
## full size on the squashed cat instead of shrinking it with everything else.
var _head_rect := Rect2i()


func compose(body: Image, head: Image, collar: Image, paws: Image) -> Image:
	var canvas := Image.create(F, F, true, Image.FORMAT_RGBA8)
	# force the head variant onto the idle head's aspect: generated head layers drift a
	# few percent, and compose turns that drift into a different head size AND a different
	# body width, so the pose would not line up with the idle
	var hc: Image = crop_to_used(head)
	var target_h: int = maxi(int(round(float(hc.get_width()) * head_ref_aspect)), 1)
	if target_h != hc.get_height():
		hc.resize(hc.get_width(), target_h, Image.INTERPOLATE_LANCZOS)
	head = hc
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
	_head_rect = Rect2i((F - head_img.get_width()) / 2, head_top,
		head_img.get_width(), head_img.get_height())
	# 4. paws IN FRONT of the body
	canvas.blend_rect(paw_img, Rect2i(0, 0, paw_img.get_width(), paw_img.get_height()),
		Vector2i((F - paw_img.get_width()) / 2, GROUND - paw_img.get_height() + 1))
	return canvas

func squash(src: Image, f: float) -> Image:
	var h := maxi(int(round(F * f)), 1)
	var t: Image = src.duplicate()
	# A "resize" to the same size is NOT a no-op: LANCZOS' negative lobes undershoot small
	# high-contrast details, which visibly dulled the cat's pink inner ear on some frames
	# (小猫绕圈跑: "耳朵突然颜色变了" - only the identity frames were affected). Scale only
	# when the size really changes.
	if h != F:
		t.resize(F, h, Image.INTERPOLATE_LANCZOS)
	var out := blank()
	out.blend_rect(t, Rect2i(0, 0, F, h), Vector2i(0, GROUND - (h - 1)))
	return out

## Scales a pose about the ground line (its own bottom row) and keeps it centred - used to
## grow the curled sleeping ball in at the end of the melt.
func scale_grounded(src: Image, s: float) -> Image:
	var w := maxi(1, int(round(float(F) * s)))
	var h := maxi(1, int(round(float(F) * s)))
	var t: Image = src.duplicate()
	t.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := blank()
	out.blend_rect(t, Rect2i(0, 0, w, h), Vector2i((F - w) / 2, GROUND - (h - 1)))
	return out


## The width flatten() spreads a pose to when it squeezes it by `sy`.
func flatten_sx(src: Image, sy: float) -> float:
	var used: Rect2i = src.get_used_rect()
	var room: float = float(F) * 0.99 / maxf(1.0, float(used.size.x))
	return minf(1.0 + (1.0 - sy) * SLEEP_PANCAKE_SPREAD, room)


## A copy of the z z Z at a fraction of their alpha, so they fade in over the melt's last
## steps instead of appearing fully formed the instant the loop starts.
func faded(src: Image, f: float) -> Image:
	var out: Image = src.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			var c: Color = out.get_pixel(x, y)
			if c.a > 0.0:
				c.a *= clampf(f, 0.0, 1.0)
				out.set_pixel(x, y, c)
	return out


## 猫饼: squash the pose down towards the ground line and let it spread sideways in
## proportion, so the cat MELTS into a pancake instead of just shrinking (the head sinks
## into the body and the whole thing flattens). The bottom row stays on GROUND.
func flatten(src: Image, sy: float) -> Image:
	var sx: float = flatten_sx(src, sy)
	var w := maxi(1, int(round(float(F) * sx)))
	var h := maxi(1, int(round(float(F) * sy)))
	var t: Image = src.duplicate()
	t.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := blank()
	out.blend_rect(t, Rect2i(0, 0, w, h), Vector2i((F - w) / 2, GROUND - (h - 1)))
	return out


## The composed cat scaled by `s` about the ground line and shifted by `off` - how it creeps
## across to the slipper without ever leaving its own 256 box.
func pose_at(pose: Image, s: float, off: Vector2) -> Image:
	var w := maxi(1, int(round(float(F) * s)))
	var h := maxi(1, int(round(float(F) * s)))
	var t: Image = pose.duplicate()
	# a resize to the SAME size is not a no-op: LANCZOS' negative lobes undershoot the small
	# high-contrast details (see squash()).
	if w != F or h != F:
		t.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := blank()
	out.blend_rect(t, Rect2i(0, 0, w, h),
		Vector2i((F - w) / 2 + int(round(off.x)), GROUND - (h - 1) + int(round(off.y))))
	return out


## 拖鞋: one frame holding both the cat and the slipper. `s` scales the slipper, `cx` and
## `bottom` place it (bottom row on the ground once it has landed), and `in_front` puts the
## slipper OVER the cat - which is what swallows it as it dives into the opening.
func slipper_frame(cat: Image, slipper: Image, s: float, cx: float, bottom: float, in_front: bool) -> Image:
	var sl: Image = at_width(slipper, maxi(1, int(round(float(SLEEP_SLIPPER_WIDTH) * s))))
	var pos := Vector2i(int(round(cx - float(sl.get_width()) * 0.5)),
		int(round(bottom - float(sl.get_height()) + 1.0)))
	if in_front:
		var out: Image = cat.duplicate()
		out.blend_rect(sl, Rect2i(0, 0, sl.get_width(), sl.get_height()), pos)
		return out
	var base := blank()
	base.blend_rect(sl, Rect2i(0, 0, sl.get_width(), sl.get_height()), pos)
	base.blend_rect(cat, Rect2i(0, 0, F, F), Vector2i.ZERO)
	return base


## 被黑洞吸走: one frame of the ball at `size` of its full width, its centre
## dragged `t` of the way along a spiral that tightens to nothing around the spot the cat was
## standing on. At t = 1 the ball is a speck, so the last frames are simply empty.
func ball_frame(ball: Image, size: float, t: float) -> Image:
	var out := blank()
	if size <= 0.03:
		return out
	var b: Image = at_width(ball, maxi(1, int(round(float(ball.get_width()) * size))))
	var angle: float = t * SLEEP_SPIRAL_TURNS * TAU
	var radius: float = (1.0 - t) * SLEEP_SPIRAL_RADIUS
	var cx: float = float(F) * 0.5 + cos(angle) * radius
	var cy: float = float(GROUND) - float(b.get_height()) * 0.5 - 20.0 + sin(angle) * radius
	out.blend_rect(b, Rect2i(0, 0, b.get_width(), b.get_height()),
		Vector2i(int(round(cx - float(b.get_width()) * 0.5)), int(round(cy - float(b.get_height()) * 0.5))))
	return out


## (被子 quilt_frame was removed with the quilt: see SLEEP_BALL_PATH / ball_frame above.)


## 变形: the reference's third key - the BODY puddles out sideways while the HEAD keeps the
## size it has when the cat is sitting. flatten() alone shrinks the head along with
## everything else, which read as the whole cat deflating and then "突然就变大了" when the
## next pose took over. Here the squashed cat is drawn first and the full-size head is
## seated back on it: `sy` therefore squashes the BODY, not the cat.
## A point at row `y` ends up at `GROUND + 1 - sy * (F - y)`, which is the map flatten()
## itself applies, so the head walks down with the body instead of floating.
func melt_frame(pose: Image, head: Image, sy: float) -> Image:
	var out: Image = flatten(pose, sy)
	var hr: Rect2i = _head_rect
	if hr.size.x <= 0 or hr.size.y <= 0:
		return out
	# the same normalisation compose() applies, so the head is EXACTLY the one in `pose`
	var forced: Image = crop_to_used(head)
	var target_h: int = maxi(int(round(float(forced.get_width()) * head_ref_aspect)), 1)
	if target_h != forced.get_height():
		forced.resize(forced.get_width(), target_h, Image.INTERPOLATE_LANCZOS)
	var full: Image = at_width(forced, hr.size.x)
	var hr_bottom: int = hr.position.y + hr.size.y - 1
	var bottom: int = GROUND + 1 - int(round(sy * float(F - hr_bottom)))
	out.blend_rect(full, Rect2i(0, 0, full.get_width(), full.get_height()),
		Vector2i((F - full.get_width()) / 2, bottom - full.get_height() + 1))
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
	var ihu: Rect2i = idle_head.get_used_rect()
	if ihu.size.x > 0:
		head_ref_aspect = float(ihu.size.y) / float(ihu.size.x)
	var paws: Image = load_rgba("res://assets/generated/cat_layer_paws.png")
	var collar: Image = load_rgba("res://assets/generated/cat_collar_v2.png")

	print("--- composing the front poses (body -> collar -> head -> paws) ---")
	var idle: Image = compose(body, idle_head, collar, paws)
	idle.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_idle.png"))
	print("idle            used=%s" % str(idle.get_used_rect()))

	var doze: Image = compose(body, load_rgba("res://assets/generated/cat_head_doze_v3.png"), collar, paws)
	doze.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_doze.png"))
	print("doze            used=%s" % str(doze.get_used_rect()))

	var startle: Image = compose(body, load_rgba("res://assets/generated/cat_head_startle_v3.png"), collar, paws)
	startle.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_startle.png"))
	print("startle         used=%s" % str(startle.get_used_rect()))

	# 打盹第三帧: 眼睛完全闭上 (the sleep keyframe), same body/collar/paws as the idle
	var closed: Image = compose(body, load_rgba("res://assets/generated/cat_head_closed_v2.png"), collar, paws)
	closed.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_closed.png"))
	print("closed          used=%s" % str(closed.get_used_rect()))

	var sheet: Image = load_rgba("res://assets/generated/cat_head_open_sheet.png")
	var cells := [Vector2i(0, 0), Vector2i(512, 0), Vector2i(0, 512), Vector2i(512, 512)]
	for i in 4:
		var cell: Image = sheet.get_region(Rect2i(cells[i].x, cells[i].y, 512, 512))
		var framed: Image = compose(body, cell, collar, paws)
		framed.save_png(ProjectSettings.globalize_path("res://assets/generated/paper_cat_open_cow_0%d.png" % (i + 1)))
		print("open_0%d         used=%s" % [i + 1, str(framed.get_used_rect())])

	print("--- full-body poses (regenerated in the same look, they carry their own collar) ---")
	# (睡觉's poses are the four keyframes built in the atlas section below - the old
	# side-view lying pose is no longer used by any animation.)
	var side: Image = fit_pose("res://assets/generated/cat_pose_run.png", 226)
	side.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_side.png"))
	print("side            used=%s" % str(side.get_used_rect()))
	var hairball_base: Image = fit_pose("res://assets/generated/cat_pose_hairball.png", 236)
	hairball_base.save_png(ProjectSettings.globalize_path("res://tests/_fit_fridge_hairball.png"))
	print("hairball        used=%s" % str(hairball_base.get_used_rect()))

	print("--- atlases ---")
	var idle_f := [1.0, 1.006, 1.012, 1.006, 1.0, 1.004]
	var idle_dx := [0, 1, 1, 0, -1, -1]
	var frames: Array = []
	for i in 6:
		frames.append(hop(squash(idle, idle_f[i]), idle_dx[i], 0))
	write_atlas(frames, "res://assets/generated/cat_idle_cow.png")

	# 睡觉: the four keyframes melt the cat down, then the flat end breathes (with the z z Z).
	var sleep_heads := {
		"idle": idle_head,
		"doze": load_rgba("res://assets/generated/cat_head_doze_v3.png"),
		"closed": load_rgba("res://assets/generated/cat_head_closed_v2.png"),
	}
	var sleep_poses := {}
	for key: String in sleep_heads.keys():
		sleep_poses[key] = compose(body, sleep_heads[key], collar, paws)
	## The z z Z, built BEFORE the melt: the melt's last steps fade them in, so they do not POP
## into existence on the very first looping frame.
	var zz: Image = crop_to_used(load_rgba(SLEEP_ZZ_PATH))
	var zz_w: int = maxi(int(round(float(zz.get_width()) * SLEEP_ZZ_SCALE)), 1)
	var zz_h: int = maxi(int(round(float(zz.get_height()) * SLEEP_ZZ_SCALE)), 1)
	if zz.get_width() > 1:
		zz.resize(zz_w, zz_h, Image.INTERPOLATE_LANCZOS)
	var slipper: Image = at_width(load_rgba(SLEEP_SLIPPER_PATH), int(SLEEP_SLIPPER_WIDTH))
	print("slipper         used=%s" % str(slipper.get_used_rect()))
	# 扔出一个大拖鞋: the fridge man lobs it in from his side (the left); it drops and lands
	# just to the cat's right, and the cat then shrinks and creeps into its opening.
	# 1. the fridge man winds up (the level plays his 扔鞋子 alongside this): the cat stands.
	var melt_frames: Array = [sleep_poses["idle"], sleep_poses["idle"], sleep_poses["idle"]]
	# 2. the slipper leaves his hand and flies in from his side (the left), then lands.
	melt_frames.append(slipper_frame(sleep_poses["idle"], slipper, 0.74, 44.0, float(GROUND) - 128.0, true))
	melt_frames.append(slipper_frame(sleep_poses["idle"], slipper, 0.88, 104.0, float(GROUND) - 56.0, true))
	melt_frames.append(slipper_frame(sleep_poses["idle"], slipper, 1.00,
		float(F) * 0.5 + SLEEP_SLIPPER_OFFSET, float(GROUND), true))
	# 瞬间移动到鞋子里: the instant the slipper is down the cat is inside it, head already out.
	for step: Dictionary in SLEEP_POPPED_STEPS:
		melt_frames.append(slipper_frame(
			pose_at(sleep_poses[str(step["head"])], 1.0,
				Vector2(-16.0, float(step["sink"]))),
			slipper, 1.00, float(F) * 0.5 + SLEEP_SLIPPER_OFFSET, float(GROUND), true))
	write_atlas(melt_frames, "res://assets/generated/cat_sleep_melt_cow.png")
	print("sleep melt      frames=%d first=%s last=%s" % [melt_frames.size(),
		str(melt_frames[0].get_used_rect()), str(melt_frames[melt_frames.size() - 1].get_used_rect())])
	var last: Dictionary = SLEEP_POPPED_STEPS[SLEEP_POPPED_STEPS.size() - 1]
	var loop_frames: Array = []
	for i in 8:
		# asleep in the slipper: the same tucked-in frame with a small breath either way
		var fin: float = 1.0 + 0.03 * sin(float(i) / 8.0 * TAU)
		var frame: Image = slipper_frame(
			pose_at(sleep_poses[str(last["head"])], fin,
				Vector2(-16.0, float(last["sink"]))),
			slipper, 1.00, float(F) * 0.5 + SLEEP_SLIPPER_OFFSET, float(GROUND), true)
		loop_frames.append(frame)
	write_atlas(loop_frames, "res://assets/generated/cat_sleep_cow.png")
	print("sleep loop      frames=%d used=%s zz=%dx%d" % [loop_frames.size(),
		str(loop_frames[0].get_used_rect()), zz_w, zz_h])

	var play_rock := [0.0, -1.8, -3.0, -1.8, 0.0, 1.8]
	var play_hop := [0, -3, -5, -3, 0, 1]
	frames = []
	for i in 6:
		frames.append(hop(rock(squash(idle, 1.0), play_rock[i]), 0, play_hop[i]))
	write_atlas(frames, "res://assets/generated/cat_play_ball_cow.png")

	# 吐毛球: a smooth heave with real in-between frames. The old six stepped 1.00 -> 1.02
	# -> 1.05, which read as a jump rather than a cough, so it is ten frames now (and the
	# action's fps was raised to match - see IDLE_ACTIONS["hairball"]).
	var hair_f := [1.0, 1.006, 1.016, 1.03, 1.044, 1.052, 1.05, 1.034, 1.014, 1.004]
	frames = []
	for i in 10:
		frames.append(squash(hairball_base, hair_f[i]))
	write_atlas(frames, "res://assets/generated/cat_hairball_cow.png")

	var run_rock := [-2.6, -1.3, 0.0, 1.3, 2.6, 1.3]
	frames = []
	for i in 6:
		frames.append(rock(side, run_rock[i]))
	write_atlas(frames, "res://assets/generated/cat_run_cow.png")

	write_atlas([doze], "res://assets/generated/cat_doze_cow.png")
	write_atlas([closed], "res://assets/generated/cat_doze_closed_cow.png")
	write_atlas([startle], "res://assets/generated/cat_startle_cow.png")

	print("--- gallery icons ---")
	var icon_src := {"rest_stand": idle, "doze": doze, "sleep": loop_frames[0], "play_ball": idle,
		"hairball": hairball_base, "run": side}
	var toy: Image = load_rgba("res://assets/generated/cat_play_toy.png")
	for key: String in icon_src.keys():
		var icon: Image = fit_into(icon_src[key], 96, 84)
		if key == "play_ball":
			var t2: Image = fit_into(toy, 34, 30)
			icon.blend_rect(t2, Rect2i(0, 0, 34, 34), Vector2i(58, 54))
		icon.save_png(ProjectSettings.globalize_path("res://assets/generated/paper_icon_cat_%s.png" % key))
		print("  icon %-32s used=%s" % ["paper_icon_cat_%s.png" % key, str(icon.get_used_rect())])

	var pink_n := 0
	for y in F:
		for x in F:
			var c: Color = idle.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.45 and c.r - c.g > 0.06:
				pink_n += 1
	print("idle pink pixels = %d (right ear inner)" % pink_n)
	print("done")
	quit()