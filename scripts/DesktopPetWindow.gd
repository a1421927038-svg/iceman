class_name DesktopPetWindow
extends Node
## 桌面宠物: the window side of the desktop pet. The game runs as a transparent, frameless,
## always-on-top sheet that carries only the characters (and whatever UI they have open) over the
## desktop: 没有窗口边框, 没有背景 (see LevelVisual), and no appetite for the desktop's clicks -
## every part of the window that is NOT one of the interactive regions below lets the click fall
## straight through to whatever is underneath.
##
## The project settings create the window like this as well (display/window/size/borderless,
## .../size/transparent, .../size/always_on_top, display/window/per_pixel_transparency/allowed,
## rendering/viewport/transparent_background and a transparent default_clear_color). They are
## re-applied here because the EDITOR's embedded game does not honour all of them, and because a
## build could ship without them.

## Slack every interactive rect gets. It must be generous: the polygon SHAPES the window, so anything
## drawn just outside the measured art (a drop shadow under the shoes, a yarn ball rolling past) would be
## cut off - 8 px was not enough (「脚部下面有部分显示不全」).
const HIT_SLACK := 20.0
## The grid those rects are snapped OUTWARD to, so a pet that is merely breathing does not toggle the
## window's passthrough flag (every write is a Win32 style change).
const HIT_GRID := 8.0
## How far above the WORK AREA's bottom (i.e. above the taskbar) the actors' feet are aimed - in window
## pixels, converted into the camera's canvas by `_cover_desktop()` before it is handed over.
const DESKTOP_FEET_MARGIN := 40.0
## ⚠ 铺满整个屏幕 instead of a small window parked in one corner. A pet is dragged to wherever on the
## desktop the player likes and the characters roam freely (the fridge man flies, the cat laps around
## him, the boat cruises, the BB机 floats up), so the window has to BE the screen: a fixed 1152x648 sheet
## both bounded every drag to its rectangle and CLIPPED every animation that left it. Every clamp in
## FridgeLevel measures `get_viewport_rect().size`, so nothing else had to change.
const COVER_DESKTOP := true
## The tray icon's art - the project's own icon, which every export already carries.
const TRAY_ICON_PATH := "res://icon.png"

## The level that supplies the interactive rects (see FridgeLevel.desktop_pet_hit_rects).
var host: Node
## 托盘图标: see `_create_tray_icon()`. It is the only way back into an overlay that (correctly) refuses
## focus and hides from the taskbar.
var tray_icon: Node = null
## Whether the tray icon's left click has parked the overlay (minimized). Also the honest state the tests
## assert, because the engine refuses `visible = false` on the main window.
var overlay_hidden := false
## What was ASKED of the window. Recorded rather than read back because a headless display server
## has no real window and reports every flag as false - the tests assert this intent, and the live
## render probe prints what the real window ended up with.
var window_flags := {
	"borderless": false,
	"transparent": false,
	"always_on_top": false,
	"mouse_passthrough": true,
}
## The rects the pointer is tested against, in window pixels (art rect + HIT_SLACK, snapped outward).
var hit_rects: Array[Rect2] = []
## The last few frames' `hit_rects`, unioned into the click-through polygon so fast motion cannot outrun it.
var region_history: Array[Array] = []
## How many frames of motion the polygon keeps covered.
const REGION_HISTORY := 6
## The click-through polygon last pushed to the window, in its own pixels.
var passthrough_region := PackedVector2Array()
## The passthrough state last applied to the window: true = the game takes the mouse (the polygon covers
## the window), false = clicks fall through to the desktop (the 2x2 sentinel).
var interactive_applied := false
## The screen rect last APPLIED to the window, and the canvas last framed against. ⚠ See
## `_cover_desktop()`: only act when the SCREEN changes - never when the window's own size differs from
## the target, or a window the OS sizes slightly differently would be re-set on every frame.
var applied_usable := Vector2i.ZERO
var applied_position := Vector2i.ZERO
var framed_canvas := Vector2.ZERO


func setup(new_host: Node) -> void:
	host = new_host


func _ready() -> void:
	_apply_window_flags()
	_cover_desktop()
	_update_passthrough()
	# 托盘图标 only where the OS has one (a headless display server reports no such feature).
	if DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		_create_tray_icon()


## ⚠ 托盘图标: the project sets `display/window/size/no_focus` (the equivalent of the screenshots'
## `ShowInTaskbar = false`), which both keeps the pet from stealing the keyboard and HIDES the window from
## the taskbar and the task switcher. That leaves no taskbar entry to close and no Alt+F4 (the window never
## takes focus), so this tray icon is the only way back:
##   * LEFT click  -> show/hide the pets (the game keeps running while hidden, so a running pomodoro still
##                    counts down);
##   * RIGHT click -> quit.
## It uses the `pressed` signal on purpose rather than the `menu` property: a PopupMenu is a sub-window
## that would need exactly the focus this overlay refuses.
func _create_tray_icon() -> void:
	if tray_icon != null and is_instance_valid(tray_icon):
		return
	var indicator := StatusIndicator.new()
	indicator.name = "TrayIcon"
	indicator.tooltip = "冰箱爷爷桌面宠物：左键显示/隐藏，右键退出"
	var icon_texture := load(TRAY_ICON_PATH) as Texture2D
	if icon_texture != null:
		indicator.icon = icon_texture
	indicator.pressed.connect(_on_tray_pressed)
	add_child(indicator)
	tray_icon = indicator


func _on_tray_pressed(mouse_button: int, _mouse_position: Vector2) -> void:
	if mouse_button == MOUSE_BUTTON_RIGHT:
		get_tree().quit()
		return
	# ⚠ `window.visible = false` is REFUSED on the main window ("Can't change visibility of main window"),
	# so the overlay hides by MINIMIZING (the docs' tray recipe does exactly that) and returns by going
	# windowed again - with the flags, the size and the framing re-applied, because a mode change can
	# reset them.
	var window := get_window()
	if window == null:
		return
	overlay_hidden = not overlay_hidden
	if overlay_hidden:
		window.mode = Window.MODE_MINIMIZED
		return
	window.mode = Window.MODE_WINDOWED
	_apply_window_flags()
	# Force the cover: the OS may have resized the window while it was minimized.
	applied_usable = Vector2i.ZERO
	_cover_desktop()
	_update_passthrough()


func _process(_delta: float) -> void:
	# 分辨率变化: re-cover so a changed screen (or a taskbar that moved) is picked up without a restart.
	if COVER_DESKTOP:
		_cover_desktop()
	_update_passthrough()


## 无边框 / 透明 / 置顶 / 点击穿透: the flags that turn an ordinary game window into a desktop overlay.
##
## ⚠ The passthrough starts in its "desktop owns the clicks" state - `mouse_passthrough = true` plus the
## 无边框 / 透明 / 置顶 / 点击穿透: the flags that turn an ordinary game window into a desktop overlay.
##
## ⚠⚠ 点击穿透 = the POLYGON, with **`mouse_passthrough = FALSE`**. The flag is NOT the passthrough on this
## build - setting it true makes the window ignore its own polygon, so the pets stay drawn but stop taking
## clicks (「点击冰箱人和其他场景中的元素都没有反应了，也打不开各种背包UI」). Every configuration in which the
## user could actually click a pet had the flag FALSE with a polygon set, and the region alone is what limits
## both hit-testing and drawing:
##   * inside the polygon  -> the game gets the click (the pets and their panels work);
##   * outside the polygon -> the click falls through to the desktop.
## `_update_passthrough()` therefore only ever pushes the polygon.
func _apply_window_flags() -> void:
	var window := get_window()
	if window == null:
		return
	window.borderless = true
	window.transparent = true
	window.always_on_top = true
	window.mouse_passthrough = false
	window.mouse_passthrough_polygon = _sentinel_region()
	window_flags = {
		"borderless": true,
		"transparent": true,
		"always_on_top": true,
		"mouse_passthrough": false,
	}


## 铺满桌面: the window is stretched over the screen, so the pets may be dragged anywhere on the desktop
## and no animation can run off a window edge. A headless display server reports no screen at all, and
## then the window is simply left as the project settings created it.
func _cover_desktop() -> void:
	var window := get_window()
	if window == null:
		return
	var screen: int = window.current_screen
	var screen_rect := Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	if screen_rect.size.x <= 0 or screen_rect.size.y <= 0:
		return
	# ⚠ Only when the DESKTOP changed - never when the window's own size differs from the target, or a
	# window the OS clamps by a couple of pixels would be resized on every frame and shake the scene.
	if screen_rect.size != applied_usable or screen_rect.position != applied_position:
		applied_usable = screen_rect.size
		applied_position = screen_rect.position
		# ⚠ 一个单位一像素: with the project's canvas_items stretch the 1152-wide canvas was blown up
		# 2.22x to cover a 2560-wide desktop, which is what made the pets 太大了. Disabling the stretch
		# puts the canvas at the desktop's own resolution, and the camera's zoom then adapts the pets'
		# size to it (see FridgeLevel.frame_fridge_desktop_camera).
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		# ⚠ 整个屏幕, not the usable rect: on this machine a borderless window asked for the work area
		# (2560x1528, inside a 2560x1600 screen) CAME BACK 2560x1526, so Godot kept re-asking and the
		# window flipped between the two sizes on EVERY frame - the canvas, the camera's zoom, the panel
		# placement and the click-through region all following. That is what shook the whole scene, worst
		# with a panel open and during a fast drag. The full screen size is honoured exactly as asked and
		# stays put; covering the taskbar strip costs nothing because the window is transparent there and
		# lets the clicks through (see the region below).
		window.size = screen_rect.size
		window.position = screen_rect.position
	var viewport := get_viewport()
	if viewport == null:
		return
	# The level's camera lives in CANVAS units, so it is framed against the canvas the window ended up
	# showing. Re-framed whenever that canvas changes (a resize, or the first frame after one), never
	# every frame.
	var canvas := Vector2(viewport.get_visible_rect().size)
	if canvas == framed_canvas:
		return
	framed_canvas = canvas
	if host != null and is_instance_valid(host) and host.has_method("frame_fridge_desktop_camera"):
		# 站在桌面上而不是悬空: the ground line is aimed at the WORK AREA's bottom (so the pets stand on
		# the desktop, not across the taskbar), converted from window pixels into the camera's canvas.
		var usable := DisplayServer.screen_get_usable_rect(screen)
		var ratio := content_scale_ratio()
		var ground_window: float = float(usable.position.y + usable.size.y - screen_rect.position.y) - DESKTOP_FEET_MARGIN
		host.call("frame_fridge_desktop_camera", canvas, ground_window / maxf(0.0001, ratio.y))


## 点击穿透 = 区域穿透: ONE polygon that covers the pets and their panels - and NOTHING else, because the
## polygon also SHAPES the window (video evidence: the pets were visible only while the cursor was over
## them, i.e. while the shape covered them). So:
##   * every pixel the player can see is inside the region (the pets) -> drawn AND clickable;
##   * every other pixel of the full-screen window is outside it -> clicks fall through to the desktop.
## ⚠ A few frames of rects are unioned in. A 35 px/frame drag would otherwise outrun the shape and lose its
## leading edge (the 「动画显示不全」/「瞬间撕裂」 symptom), and the history decays within a few frames of the
## motion stopping, so the swallowed desktop area only exists while something is actually moving.
func _update_passthrough() -> void:
	hit_rects = _collect_hit_rects()
	region_history.append(hit_rects)
	while region_history.size() > REGION_HISTORY:
		region_history.pop_front()
	var merged: Array[Rect2] = []
	for frame_rects: Array in region_history:
		for rect: Rect2 in frame_rects:
			merged.append(rect)
	var region := _region_for(merged, content_scale_ratio())
	if region == passthrough_region:
		return
	passthrough_region = region
	var window := get_window()
	if window != null:
		# ⚠ The flag stays FALSE: it is the POLYGON that does the work (see `_apply_window_flags()`).
		window.mouse_passthrough_polygon = region


## Is the OS cursor over one of the pets? ⚠ Read the REAL cursor from the display server: while the
## window is click-through it receives no mouse events at all, so Godot's own idea of the mouse position
## goes stale exactly when this question matters.
func _pointer_over_pets() -> bool:
	if hit_rects.is_empty():
		return false
	return _rects_cover_point(hit_rects, pointer_position())


## The OS cursor in WINDOW pixels.
func pointer_position() -> Vector2:
	var screen_point := Vector2(DisplayServer.mouse_get_position())
	var window := get_window()
	if window == null:
		return screen_point
	return screen_point - Vector2(window.position)


## Pure helper, so the tests can check the rule without a real cursor: is `point` inside any of `rects`?
## ⚠ `rects` are measured in the project's CANVAS, `point` comes from the OS in WINDOW pixels.
func _rects_cover_point(rects: Array[Rect2], point: Vector2) -> bool:
	var ratio := content_scale_ratio()
	var canvas_point := Vector2(point.x / maxf(0.0001, ratio.x), point.y / maxf(0.0001, ratio.y))
	for rect: Rect2 in rects:
		if rect.has_point(canvas_point):
			return true
	return false


## ⚠ The rects the pointer is tested against are measured in the project's CANVAS (a Control's
## get_global_rect, the art rects), while the cursor and the window are in WINDOW pixels (the content
## scale stretches one onto the other). With the old 1152x648 window the two happened to be 1:1 and the
## mismatch was invisible; a window covering a 2560-wide desktop stretched the canvas by 2.22, and without
## this factor every interactive rect sat in the top-left corner at 45% size - invisible, and every pet
## unreachable. ⚠ A headless display server is NOT 1:1 either (its stand-in window is 64x64), so the
## ratio is forced to ONE there - see below.
func content_scale_ratio() -> Vector2:
	var window := get_window()
	if window == null:
		return Vector2.ONE
	# ⚠ A headless display server has no real window - its stand-in reports a 64x64 size - so the canvas
	# IS the window there and the ratio would be nonsense (it shrank the whole region 18x when the test
	# suites ran). The suites run in exactly that mode.
	if DisplayServer.get_name() == "headless":
		return Vector2.ONE
	var canvas: Vector2 = window.get_visible_rect().size
	if canvas.x <= 0.0 or canvas.y <= 0.0:
		return Vector2.ONE
	return Vector2(window.size) / canvas


func _collect_hit_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if host == null or not is_instance_valid(host) or not host.has_method("desktop_pet_hit_rects"):
		return rects
	for rect: Rect2 in host.call("desktop_pet_hit_rects"):
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		rects.append(_snap_outward(rect.grow(HIT_SLACK)))
	return rects


## ⚠ The rect is snapped OUTWARD to a grid before the pointer test. They are re-measured every frame from
## layout the animations keep nudging (an idle bob, a hover scale, a panel re-placed from the camera), and
## the passthrough flag must not flip for a one-pixel dance. Snapping outward means it only flips when the
## cursor really crossed a pet's edge, and it can only ever make a pet MORE reachable.
func _snap_outward(rect: Rect2) -> Rect2:
	var left: float = floorf(rect.position.x / HIT_GRID) * HIT_GRID
	var top: float = floorf(rect.position.y / HIT_GRID) * HIT_GRID
	var right: float = ceilf(rect.end.x / HIT_GRID) * HIT_GRID
	var bottom: float = ceilf(rect.end.y / HIT_GRID) * HIT_GRID
	return Rect2(left, top, right - left, bottom - top)


## ⚠ A region can never be EMPTY: Godot reads an empty polygon as "no passthrough at all", which would put
## the whole sheet in front of the desktop's clicks. With no rects to wrap (the first frames, before the
## level's actors exist, or if they were freed) a 2x2 square in a corner keeps the region valid.
func _sentinel_region() -> PackedVector2Array:
	var size := Vector2(get_window().size)
	return PackedVector2Array([
		Vector2(0.0, size.y - 2.0), Vector2(2.0, size.y - 2.0),
		Vector2(2.0, size.y), Vector2(0.0, size.y),
	])


## The region is ONE polygon (window_set_mouse_passthrough takes a single contour), so the rects are wrapped
## by an x-monotone contour: sweep their x edges and, per column, take the extreme top and bottom of the rects
## covering it - which can only ever ADD slack around the pets, never leave one of them unreachable. The
## contour walks the top edge left to right and the bottom edge back, so it never crosses itself.
## ⚠ `ratio` maps the rects from canvas space (where they are measured) into the window's own pixels (what
## the OS gets) - see `content_scale_ratio()`.
func _region_for(rects_in: Array, ratio: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var rects: Array[Rect2] = []
	for source: Rect2 in rects_in:
		rects.append(Rect2(source.position * ratio, source.size * ratio))
	if rects.is_empty():
		return _sentinel_region()
	var edges: Array[float] = []
	for rect: Rect2 in rects:
		edges.append(rect.position.x)
		edges.append(rect.end.x)
	edges.sort()
	var columns: Array[Rect2] = []
	for i in range(edges.size() - 1):
		var left: float = edges[i]
		var right: float = edges[i + 1]
		if right - left <= 0.0:
			continue
		var top := INF
		var bottom := -INF
		for rect: Rect2 in rects:
			if rect.position.x <= left + 0.01 and rect.end.x >= right - 0.01:
				top = minf(top, rect.position.y)
				bottom = maxf(bottom, rect.end.y)
		if top == INF:
			continue
		var column := Rect2(left, top, right - left, bottom - top)
		# 同一段: two rects sharing both edges are one slab, so the contour stays short.
		if not columns.is_empty():
			var last := columns[columns.size() - 1]
			if is_equal_approx(last.end.x, column.position.x) \
					and is_equal_approx(last.position.y, column.position.y) \
					and is_equal_approx(last.end.y, column.end.y):
				columns[columns.size() - 1] = last.merge(column)
				continue
		columns.append(column)
	var points := PackedVector2Array()
	for column: Rect2 in columns:
		points.append(column.position)
		points.append(Vector2(column.end.x, column.position.y))
	for i in range(columns.size() - 1, -1, -1):
		points.append(columns[i].end)
		points.append(Vector2(columns[i].position.x, columns[i].end.y))
	return points