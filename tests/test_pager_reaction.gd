extends SceneTree

## Covers the pager (BB机) reaction triggered by clicking the pager item in the
## cat's mouth: the four chart keyframes (present, device buzz, body buzz, float)
## play once with the chart's own beat lengths, the man buzzes and then lifts off
## the ground, and the detached device levitates in front of his chest bobbing up
## and down.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := true

	var player: Node = load("res://scripts/FridgePomodoroPlayer.gd").new()
	get_root().add_child(player)
	await process_frame
	await process_frame
	# Drive the timeline by hand so the checks are deterministic.
	player.set_process(false)

	var anim: AnimatedSprite2D = player.get("animated_sprite") as AnimatedSprite2D
	var sf: SpriteFrames = anim.sprite_frames
	var durations: Array = []
	var regions: Array = []
	for i in sf.get_frame_count("pager_react"):
		durations.append(snappedf(sf.get_frame_duration("pager_react", i), 0.001))
		var tex: Texture2D = sf.get_frame_texture("pager_react", i)
		regions.append((tex as AtlasTexture).region.position.x if tex is AtlasTexture else -1.0)
	print("has_pager=", sf.has_animation("pager_react"), " frames=", sf.get_frame_count("pager_react"),
		" loop=", sf.get_animation_loop("pager_react"), " durations=", durations, " region_x=", regions)
	ok = ok and sf.has_animation("pager_react") and sf.get_frame_count("pager_react") == 6
	ok = ok and not sf.get_animation_loop("pager_react")
	var expected_beats := [0.7, 1.0, 1.1, 0.4, 0.4, 1.6]
	var beats_match := durations.size() == expected_beats.size()
	for i in durations.size():
		if i >= expected_beats.size() or absf(float(durations[i]) - float(expected_beats[i])) > 0.001:
			beats_match = false
	ok = ok and beats_match
	ok = ok and regions == [0.0, 512.0, 1024.0, 1536.0, 2048.0, 2560.0]

	# The circular countdown ring used to be drawn behind the character; it is gone
	# for this and the other performances (source-level check - nothing to draw).
	var source_file := FileAccess.open("res://scripts/FridgePomodoroPlayer.gd", FileAccess.READ)
	var source := source_file.get_as_text()
	source_file.close()
	var ring_gone := not source.contains("ring_radius")
	print("ring_removed=", ring_gone)
	ok = ok and ring_gone

	# 抓住BB机, 手臂过头顶: the float keyframe must actually have BOTH ARMS RAISED OVER HIS
	# HEAD with the two fists meeting up there, and the device's offset must land between
	# them - otherwise the device floats above an empty-handed man (the hands are art).
	var atlas_img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/generated/paper_fridge_pager_react.png"))
	atlas_img.convert(Image.FORMAT_RGBA8)
	var float_frame: Image = atlas_img.get_region(Rect2i(512 * 5, 0, 512, 512))
	var float_used: Rect2i = float_frame.get_used_rect()
	var hand_rows: Array[int] = []
	for x in range(180, 332, 2):
		for y in range(0, 96):
			var c := float_frame.get_pixel(x, y)
			if c.a > 0.6 and c.r > 0.82 and c.g > 0.5 and c.g < 0.86 \
					and (c.r - c.b) > 0.18 and (c.r - c.g) > 0.15:
				hand_rows.append(y)
	var hand_top := 999
	for y: int in hand_rows:
		hand_top = mini(hand_top, y)
	var grip_py := 0.0
	if not hand_rows.is_empty():
		grip_py = float(hand_rows[hand_rows.size() / 2])
	# where his head starts: the first row wide enough to be the hair, not a raised arm
	var head_top := 511
	for y in range(512):
		var count := 0
		for x in range(512):
			if float_frame.get_pixel(x, y).a > 0.5:
				count += 1
		if count >= 120:
			head_top = y
			break
	var player_consts: Dictionary = (player.get_script() as Script).get_script_constant_map()
	var device_local: float = (player_consts.get("PAGER_FLOAT_POSITION", Vector2.ZERO) as Vector2).y
	var grip_local: float = -145.0 + (grip_py - 256.0) * 0.625
	print("grip frame: used=", float_used, " hand_rows=", hand_rows.size(), " hand_top=", hand_top,
		" head_top=", head_top, " grip_py=", grip_py,
		" grip_local=", snappedf(grip_local, 0.1), " device_local=", snappedf(device_local, 0.1))
	ok = ok and float_used.size.y >= 505
	ok = ok and hand_rows.size() >= 8
	ok = ok and absf(grip_local - device_local) <= 10.0
	# 手臂过头顶: the fists reach above the top of his head
	ok = ok and hand_top < head_top

	var finished := [0]
	player.performance_finished.connect(func() -> void: finished[0] += 1)

	player.call("play_pager_reaction")
	var device: Sprite2D = player.get("pager_device_sprite") as Sprite2D
	print("started active=", player.get("pager_reaction_active"), " anim=", anim.animation,
		" frame=", anim.frame, " device=", device != null, " device_visible=", device.visible)
	ok = ok and bool(player.get("pager_reaction_active")) and anim.animation == "pager_react"
	ok = ok and device != null and not device.visible

	# ---- beat 1 runs: only the device buzzes, the man is still planted ----
	player.call("_update_pager_reaction", 0.2)
	var still: Vector2 = player.call("_get_pager_reaction_offset")
	player.call("_update_pager_reaction", 0.8)  # -> elapsed 1.0 s, inside beat 2
	var buzz: Vector2 = player.call("_get_pager_reaction_offset")
	print("beat1 offset=", still, " beat2 offset=", buzz, " device_visible=", device.visible)
	ok = ok and still == Vector2.ZERO and buzz.length() > 0.5 and not device.visible

	# ---- the whole body buzzes harder in beat 3 ----
	var strong := 0.0
	var weak := 0.0
	var e := 1.0
	while e < 1.7:  # beat 2 window
		weak = maxf(weak, (player.call("_get_pager_reaction_offset") as Vector2).length())
		player.call("_update_pager_reaction", 0.05)
		e += 0.05
	while e < 2.75:  # beat 3 window (stops just before the float beat)
		strong = maxf(strong, (player.call("_get_pager_reaction_offset") as Vector2).length())
		player.call("_update_pager_reaction", 0.05)
		e += 0.05
	print("buzz peak: device-only=", snappedf(weak, 0.1), " body-together=", snappedf(strong, 0.1), " device_visible=", device.visible)
	ok = ok and strong > weak and not device.visible

	# ---- beat 4: he lifts off the ground and the device floats, bobbing ----
	var ys: Array = []
	while e < 4.35:
		player.call("_update_pager_reaction", 0.05)
		e += 0.05
		if device.visible:
			ys.append(device.position.y)
	var bob_range := 0.0
	if not ys.is_empty():
		bob_range = float(ys.max()) - float(ys.min())
	var man: Vector2 = player.call("_get_pager_reaction_offset")
	print("float: device_visible=", device.visible, " samples=", ys.size(),
		" bob_range=", snappedf(bob_range, 0.1), " man_offset=", man)
	ok = ok and device.visible and bob_range > 8.0 and man.y < -15.0

	# ---- the float beat ends into a HELD levitation, it does not drop back to idle ----
	player.call("_update_pager_reaction", 0.95)
	player.call("_update_pager_reaction", 0.05)
	var hold_man: Vector2 = player.call("_get_pager_reaction_offset")
	var hold_started: bool = bool(player.get("pager_hold_active")) \
		and not bool(player.get("pager_reaction_active")) and device.visible
	var hold_ys: Array = []
	var held := 0.0
	while held < 1.6:
		player.call("_update_pager_reaction", 0.05)
		held += 0.05
		hold_ys.append(device.position.y)
	var hold_bob := float(hold_ys.max()) - float(hold_ys.min())
	hold_man = player.call("_get_pager_reaction_offset")
	print("hold: active=", player.get("pager_hold_active"), " anim=", anim.animation,
		" device_visible=", device.visible, " bob_range=", snappedf(hold_bob, 0.1),
		" man_offset=", hold_man, " finished=", finished[0])
	ok = ok and hold_started and anim.animation == "pager_react"
	ok = ok and hold_bob > 8.0 and (hold_man as Vector2).y < -15.0 and finished[0] == 1

	# The level refreshes the character's form every frame; the hold must survive it.
	player.call("set_pomodoro_juggle", false)
	print("hold survives form refresh: active=", player.get("pager_hold_active"),
		" anim=", anim.animation, " device_visible=", device.visible)
	ok = ok and bool(player.get("pager_hold_active")) and anim.animation == "pager_react" and device.visible

	# ---- stop_pager_reaction releases it (the level calls this at countdown end) ----
	player.call("stop_pager_reaction")
	print("after stop_pager_reaction: hold=", player.get("pager_hold_active"),
		" anim=", anim.animation, " device_visible=", device.visible)
	ok = ok and not bool(player.get("pager_hold_active")) and anim.animation == "idle" and not device.visible

	# 抓住BB机: between the buzzing keyframes and the overhead float there must be a real
	# reach-up-then-catch beat, and the device must CLIMB through those hands. (Probed with
	# the reaction stopped, so _get_pager_reaction_offset is zero and the keys are absolute.)
	var reach_frame: Image = atlas_img.get_region(Rect2i(512 * 3, 0, 512, 512))
	var grab_frame: Image = atlas_img.get_region(Rect2i(512 * 4, 0, 512, 512))
	var keys_reached: Array[Vector2] = []
	for t: float in [0.0, 0.4, 0.8, 2.0]:
		player.call("_update_pager_device", t)
		keys_reached.append(device.position - (player.call("_get_pager_reaction_offset") as Vector2))
	print("device rise path=", keys_reached, " (final target ", snappedf(device_local, 0.1), ")")
	var rises_everywhere := true
	for i in range(1, keys_reached.size()):
		if keys_reached[i].y > keys_reached[i - 1].y - 5.0:
			rises_everywhere = false
	ok = ok and rises_everywhere
	ok = ok and absf(keys_reached[keys_reached.size() - 1].y - device_local) < 3.0
	# The reaching and catching frames really are their own poses, and the two buzz keyframes
	# are no longer near-copies of the present frame (they were - that is what read as
	# "表情和动作还不够夸张").
	var present_frame: Image = atlas_img.get_region(Rect2i(0, 0, 512, 512))
	var buzz1_frame: Image = atlas_img.get_region(Rect2i(512, 0, 512, 512))
	var buzz2_frame: Image = atlas_img.get_region(Rect2i(1024, 0, 512, 512))
	var diff_buzz1_buzz2 := 0
	var diff_present_buzz2 := 0
	var diff_reach_grab := 0
	for y in range(0, 512, 4):
		for x in range(0, 512, 4):
			if buzz1_frame.get_pixel(x, y) != buzz2_frame.get_pixel(x, y):
				diff_buzz1_buzz2 += 1
			if present_frame.get_pixel(x, y) != buzz2_frame.get_pixel(x, y):
				diff_present_buzz2 += 1
			if reach_frame.get_pixel(x, y) != grab_frame.get_pixel(x, y):
				diff_reach_grab += 1
	print("pose distinctness: buzz1-vs-buzz2=", diff_buzz1_buzz2,
		" present-vs-buzz2=", diff_present_buzz2, " reach-vs-grab=", diff_reach_grab)
	ok = ok and diff_buzz1_buzz2 > 200 and diff_present_buzz2 > 200 and diff_reach_grab > 200

	# 脚部完整: every keyframe must END in a natural tapering boot sole, not be chopped flat by
	# the canvas edge - a frame whose silhouette GROWS toward its lowest pixel is cut off (that
	# is what made the startle beat's boots look incomplete). The boots widen on the way down and
	# only then taper, so the test compares the lowest opaque row with the row 3 above it.
	var cut_frames: Array[int] = []
	for i in 6:
		var f: Image = atlas_img.get_region(Rect2i(512 * i, 0, 512, 512))
		var counts: Array[int] = []
		for y in range(480, 512):
			var n := 0
			for x in range(512):
				if f.get_pixel(x, y).a > 0.5:
					n += 1
			counts.append(n)
		var last := -1
		for k in range(counts.size()):
			if counts[k] > 0:
				last = k
		if last < 4:
			continue
		if counts[last] > counts[last - 3]:
			cut_frames.append(i)
	print("frames whose bottom is chopped flat: ", cut_frames)
	ok = ok and cut_frames.is_empty()

	# ---- a new session wipes a running reaction ----
	player.call("play_pager_reaction")
	player.call("stop_performances")
	print("after stop_performances: active=", player.get("pager_reaction_active"),
		" hold=", player.get("pager_hold_active"), " anim=", anim.animation)
	ok = ok and not bool(player.get("pager_reaction_active")) \
		and not bool(player.get("pager_hold_active")) and anim.animation == "idle"
	player.queue_free()
	await process_frame

	# ---- clicking the pager in the cat's mouth starts the sequence ----
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	# Taking the pager out drives the real (saving) path; keep the player's own
	# state (coins + active item) intact.
	var save_coins: int = int(scene.get("fridge_coin_count"))
	var save_active_item: String = str(scene.get("fridge_active_item_id"))
	var level_player: Node = scene.get("fridge_player")
	level_player.set_process(false)
	scene.call("_take_fridge_item_out_of_mouth", "pager")
	var level_anim: AnimatedSprite2D = level_player.get("animated_sprite") as AnimatedSprite2D
	print("level: phase=", scene.get("fridge_phase"), " pager_active=", level_player.get("pager_reaction_active"),
		" anim=", level_anim.animation, " panel_visible=", (scene.get("fridge_item_panel") as Control).visible)
	ok = ok and bool(level_player.get("pager_reaction_active")) and level_anim.animation == "pager_react"
	ok = ok and str(scene.get("fridge_phase")) == "work"

	# ---- the levitation lasts until the countdown ends, then he drops to idle ----
	# 随着BB机向上移动: the levitation lifts him off where he stands and then carries him
	# upward with the pager (see the flight checks further down).
	var man_home: Vector2 = level_player.global_position
	level_player.call("_update_pager_reaction", 5.3)
	var holding: bool = bool(level_player.get("pager_hold_active"))

	# ---- 喷射: while he floats with the 寻呼机, pieces squirt out from under the
	# device, fall, and vanish where they land on the ground ----
	var spray: Node = scene.get("fridge_spray")
	var spray_textures := int(spray.call("texture_count")) if spray != null else -1
	print("spray: node=", spray != null, " payload=", scene.get("fridge_spray_payload_id"),
		" textures=", spray_textures, " name=", spray.get("payload_name") if spray != null else "")
	ok = ok and spray != null and str(scene.get("fridge_spray_payload_id")) == "text"
	var level_consts: Dictionary = (scene.get_script() as Script).get_script_constant_map()
	ok = ok and int(level_consts.get("FRIDGE_SPRAY_GROUND_Y", -1)) == 184
	ok = ok and (level_consts.get("FRIDGE_SPRAY_PAYLOADS", {}) as Dictionary).has("tomato")
	ok = ok and spray_textures == 15
	# 字体 and 泡泡 are SEPARATE payloads - the glyph spray must not carry the bubble
	# sheet with it, or picking 泡泡 and then 字体 again leaves bubbles coming out.
	var spray_payloads: Dictionary = level_consts.get("FRIDGE_SPRAY_PAYLOADS", {})
	var text_payload: Dictionary = spray_payloads.get("text", {})
	var bubble_payload: Dictionary = spray_payloads.get("bubble", {})
	print("spray payloads: text_regions=", (text_payload.get("regions", []) as Array).size(),
		" text_extras=", (text_payload.get("extra", []) as Array).size(),
		" bubble_regions=", (bubble_payload.get("regions", []) as Array).size(),
		" bubble_atlas=", bubble_payload.get("atlas", ""))
	ok = ok and (text_payload.get("regions", []) as Array).size() == 15
	ok = ok and (text_payload.get("extra", []) as Array).is_empty()
	ok = ok and (bubble_payload.get("regions", []) as Array).size() == 8
	ok = ok and str(bubble_payload.get("atlas", "")).ends_with("paper_spray_bubbles.png")
	ok = ok and int(bubble_payload.get("height", 0)) < int(text_payload.get("height", 0))
	var levitating: bool = bool(level_player.call("is_pager_levitating"))
	var saw_emitting := false
	var frames := 0
	while frames < 96:
		await process_frame
		frames += 1
		if frames == 40:
			saw_emitting = bool(spray.get("emitting"))
	var positions: PackedVector2Array = spray.call("get_piece_positions")
	var lowest: float = spray.call("lowest_y")
	var device_pos: Vector2 = level_player.call("get_pager_device_global_position")
	var spray_offset: Vector2 = level_consts.get("FRIDGE_SPRAY_OFFSET", Vector2.ZERO)
	var origin: Vector2 = spray.get("origin")
	var above_ground := true
	for p: Vector2 in positions:
		if p.y > 184.5:
			above_ground = false
	print("spray flying: levitating=", levitating, " emitting=", saw_emitting, " live=", positions.size(),
		" lowest=", snappedf(lowest, 0.1), " device=", device_pos,
		" origin_error=", snappedf(origin.distance_to(device_pos + spray_offset), 0.1),
		" above_ground=", above_ground)
	ok = ok and levitating and saw_emitting and positions.size() > 0
	# The spray really does squirt from under the device: the level sets the spray's
	# origin to the device's world position every frame, and it follows him as he
	# flies, so the pieces leave from underneath the BB机 wherever it is.
	ok = ok and origin.distance_to(device_pos + spray_offset) <= 2.0
	ok = ok and above_ground

	# Both sheets really are in play: the live pieces carry the glyphs' scale and the
	# smaller bubbles' one.
	var piece_scales: Array = []
	for child in spray.get_children():
		if child is Sprite2D:
			var piece_scale: float = (child as Sprite2D).scale.x
			var known := false
			for existing: float in piece_scales:
				if absf(existing - piece_scale) < 0.005:
					known = true
			if not known:
				piece_scales.append(piece_scale)
	print("spray pieces: scales=", piece_scales)
	ok = ok and piece_scales.size() >= 2
	# ...and not one live piece comes off another sheet while the payload is 字体.
	var other_sheet_pieces := 0
	for child in spray.get_children():
		if child is Sprite2D and (child as Sprite2D).texture is AtlasTexture:
			var piece_atlas: AtlasTexture = (child as Sprite2D).texture
			if piece_atlas.atlas != null and piece_atlas.atlas.get_size() != Vector2(1024.0, 1024.0):
				other_sheet_pieces += 1
	print("spray pieces from other sheets on 字体: ", other_sheet_pieces)
	ok = ok and other_sheet_pieces == 0

	# ---- 随着BB机向上移动: once the float settles he travels up with the pager ----
	# (The old behaviour - 原地起飞, no travel at all - is superseded: the levitation now
	# carries him up and around the screen until the countdown ends.)
	# This test parks the player's own _process, so advance the held float clock by hand,
	# then let the LEVEL run a few frames of its flight.
	level_player.set("pager_hold_time", 4.0)
	for i in 40:
		await process_frame
	var drift: float = level_player.global_position.distance_to(man_home)
	var rose: float = man_home.y - level_player.global_position.y
	print("flight with the pager: drift=", snappedf(drift, 0.1), " rose=", snappedf(rose, 1.0),
		" flying=", bool(level_player.call("is_pager_flying")))
	ok = ok and bool(level_player.call("is_pager_flying")) and rose > 20.0

	# 控制住冰箱人: a real drag still owns his position.
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.relative = Vector2(12.0, 0.0)
	drag_motion.position = Vector2(576.0, 300.0)
	scene.set("fridge_player_is_dragging", true)
	scene.set("fridge_player_drag_moved", true)
	var before_drag: Vector2 = level_player.global_position
	var drag_handled: bool = bool(scene.call("_handle_fridge_player_drag", drag_motion))
	var dragged: bool = level_player.global_position != before_drag
	scene.set("fridge_player_is_dragging", false)
	scene.set("fridge_player_drag_moved", false)
	print("pager float drag: handled=", drag_handled, " moved=", dragged)
	ok = ok and drag_handled and dragged

	# 改变飞行方向: a quick click that does not drag him turns the flying man around.
	var dir_before: float = float(scene.get("fridge_player_flight_dir"))
	scene.call("_flip_fridge_player_flight_dir")
	var dir_after: float = float(scene.get("fridge_player_flight_dir"))
	print("flight direction flip: ", dir_before, " -> ", dir_after)
	ok = ok and dir_after != 0.0 and is_equal_approx(dir_before, -dir_after)

	# ...and the same thing through the REAL input path: park him under the mouse and send
	# a press + release with no motion. A press that moves him is a grab instead.
	var mouse_world: Vector2 = (scene.get_viewport().get_canvas_transform().affine_inverse()
		* scene.get_viewport().get_mouse_position())
	level_player.global_position = mouse_world
	var click_press := InputEventMouseButton.new()
	click_press.button_index = MOUSE_BUTTON_LEFT
	click_press.pressed = true
	scene.call("_input", click_press)
	var grabbed: bool = bool(scene.get("fridge_player_is_dragging"))
	var click_release := InputEventMouseButton.new()
	click_release.button_index = MOUSE_BUTTON_LEFT
	click_release.pressed = false
	scene.call("_input", click_release)
	var flipped_by_click: bool = float(scene.get("fridge_player_flight_dir")) != dir_after
	print("click on the flying man: grabbed=", grabbed, " flipped=", flipped_by_click,
		" dir=", scene.get("fridge_player_flight_dir"))
	ok = ok and grabbed and flipped_by_click

	# 遇到屏幕上边界后，又从下方冒出来: once he is completely off the top he must come
	# back in below the screen's bottom on the very next frame.
	var top_offset: float = float(level_consts.get("FRIDGE_FLIGHT_TOP_OFFSET", -300.0))
	var bottom_offset: float = float(level_consts.get("FRIDGE_FLIGHT_BOTTOM_OFFSET", 16.0))
	var screen_rect: Rect2 = scene.call("_fridge_screen_world_rect")
	level_player.global_position = Vector2(0.0, screen_rect.position.y - bottom_offset - 4.0)
	await process_frame
	var screen_bottom: float = screen_rect.position.y + screen_rect.size.y
	var wrapped: float = level_player.global_position.y + top_offset
	print("top-edge wrap: re-entered at ", snappedf(wrapped, 1.0),
		" (screen bottom ", snappedf(screen_bottom, 1.0), ")")
	ok = ok and absf(wrapped - screen_bottom) <= 3.0
	# ...and he must NOT be bouncing between the two edges: one more frame of flight keeps
	# him heading up into view.
	var after_wrap: float = level_player.global_position.y
	await process_frame
	print("wrap settled: ", snappedf(after_wrap, 1.0), " -> ",
		snappedf(level_player.global_position.y, 1.0))
	ok = ok and level_player.global_position.y < after_wrap
	level_player.global_position = man_home

	# The payload is data: swapping it throws a different prop, no code change.
	scene.call("set_fridge_spray_payload", "tomato")
	var swapped: String = str(spray.get("payload_name"))
	print("spray swap: name=", swapped, " textures=", spray.call("texture_count"))
	ok = ok and swapped == "喷射番茄" and int(spray.call("texture_count")) == 1
	# 泡泡: the same swap the prop box's 泡泡 item makes - bubbles instead of glyphs.
	scene.call("set_fridge_spray_payload", "bubble")
	var bubbled: String = str(spray.get("payload_name"))
	print("spray swap 泡泡: name=", bubbled, " textures=", spray.call("texture_count"))
	ok = ok and int(spray.call("texture_count")) == 8
	scene.call("set_fridge_spray_payload", "text")

	scene.set("fridge_time_left", 0.05)
	scene.call("_update_fridge_pomodoro", 0.1)
	print("at countdown end: phase=", scene.get("fridge_phase"),
		" held_during_countdown=", holding, " hold_now=", level_player.get("pager_hold_active"),
		" anim=", level_anim.animation, " choices_pending=", scene.get("fridge_round_choices_pending"))
	ok = ok and holding
	ok = ok and not bool(level_player.get("pager_hold_active")) and level_anim.animation == "idle"
	ok = ok and str(scene.get("fridge_phase")) == "idle"

	# Once he drops out of the levitation the spray stops - and whatever is still
	# in the air lands on the ground and disappears on its own.
	var spray_stopped := true
	for _i in range(8):
		await process_frame
	if bool(spray.get("emitting")):
		spray_stopped = false
	var flight := 0
	while flight < 200 and int(spray.call("live_count")) > 0:
		await process_frame
		flight += 1
	print("spray settled: emitting_now=", spray.get("emitting"), " stopped=", spray_stopped,
		" live=", spray.call("live_count"), " frames_to_clear=", flight)
	ok = ok and spray_stopped and int(spray.call("live_count")) == 0

	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.call("_save_fridge_progress")
	print("PAGER_REACTION_TEST=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0)