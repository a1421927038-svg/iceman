extends SceneTree

## Covers the 电视机 (CRT) countdown performance: taking the television out of the cat's
## mouth makes the fridge man get startled, turn into a Chinese fisherman in a puff of
## paper smoke, and pole his 乌篷船 - with 白娘子 and 许仙 sitting at the far end with their
## backs to the player - for the whole countdown. The stroke is HELD until it ends.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := true

	var player: Node = load("res://scripts/FridgePomodoroPlayer.gd").new()
	get_root().add_child(player)
	await process_frame
	await process_frame
	player.set_process(false)

	var anim: AnimatedSprite2D = player.get("animated_sprite") as AnimatedSprite2D
	var sf: SpriteFrames = anim.sprite_frames
	var durations: Array = []
	var regions: Array = []
	if sf.has_animation("tv_fisherman"):
		for i in sf.get_frame_count("tv_fisherman"):
			durations.append(snappedf(sf.get_frame_duration("tv_fisherman", i), 0.001))
			var tex: Texture2D = sf.get_frame_texture("tv_fisherman", i)
			regions.append((tex as AtlasTexture).region.position.x if tex is AtlasTexture else -1.0)
	var expected_beats := [0.5, 0.5, 0.5, 0.6, 0.6]
	var beats_match := durations.size() == expected_beats.size()
	for i in durations.size():
		if i >= expected_beats.size() or absf(float(durations[i]) - float(expected_beats[i])) > 0.001:
			beats_match = false
	print("fisherman: has=", sf.has_animation("tv_fisherman"),
		" frames=", sf.get_frame_count("tv_fisherman") if sf.has_animation("tv_fisherman") else -1,
		" loop=", sf.get_animation_loop("tv_fisherman") if sf.has_animation("tv_fisherman") else true,
		" durations=", durations, " region_x=", regions)
	ok = ok and sf.has_animation("tv_fisherman") and sf.get_frame_count("tv_fisherman") == 5
	ok = ok and not sf.get_animation_loop("tv_fisherman")
	ok = ok and beats_match
	ok = ok and regions == [0.0, 512.0, 1024.0, 1536.0, 2048.0]

	# The art: five frames, each with COMPLETE shoes (a frame chopped by the canvas edge has
	# a silhouette that GROWS toward its lowest row), all on the idle's ground line (510).
	var atlas_img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/generated/paper_fridge_tv_fisherman.png"))
	atlas_img.convert(Image.FORMAT_RGBA8)
	print("atlas = ", atlas_img.get_size())
	ok = ok and atlas_img.get_width() == 512 * 5 and atlas_img.get_height() == 512
	var cut_frames: Array[int] = []
	var bottoms: Array[int] = []
	for i in 5:
		var f: Image = atlas_img.get_region(Rect2i(512 * i, 0, 512, 512))
		var counts: Array[int] = []
		for y in range(470, 512):
			var n := 0
			for x in range(512):
				if f.get_pixel(x, y).a > 0.5:
					n += 1
			counts.append(n)
		var last := -1
		for k in range(counts.size()):
			if counts[k] > 0:
				last = k
		bottoms.append(470 + last)
		if last >= 4 and counts[last] > counts[last - 3]:
			cut_frames.append(i)
	print("frame bottoms=", bottoms, " chopped=", cut_frames)
	ok = ok and cut_frames.is_empty()
	var ground_ok := true
	for b: int in bottoms:
		if b != 510:
			ground_ok = false
	ok = ok and ground_ok
	var distinct := 0
	for i in range(1, 5):
		var a: Image = atlas_img.get_region(Rect2i(512 * (i - 1), 0, 512, 512))
		var b: Image = atlas_img.get_region(Rect2i(512 * i, 0, 512, 512))
		var diff := 0
		for y in range(0, 512, 4):
			for x in range(0, 512, 4):
				if a.get_pixel(x, y) != b.get_pixel(x, y):
					diff += 1
		print("   pose difference %d vs %d = %d" % [i - 1, i, diff])
		if diff > 200:
			distinct += 1
	ok = ok and distinct == 4

	# The boat: one wide sprite, and the two fridge-shaped passengers really are seated inside
	# its right half with the open bow deck clear for the fisherman. Read the path the CODE
	# uses, so a re-skin cannot leave this test inspecting a retired donor file.
	var consts_now: Dictionary = (player.get_script() as Script).get_script_constant_map()
	var boat_img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		str(consts_now.get("TV_BOAT_PATH", "res://assets/generated/wupeng_boat_fridges.png"))))
	boat_img.convert(Image.FORMAT_RGBA8)
	var boat_used: Rect2i = boat_img.get_used_rect()
	var deck_cells := 0
	var seated_cells := 0
	for x in range(0, boat_img.get_width(), 32):
		var deck_opaque := false
		var seated_opaque := false
		for y in range(0, boat_img.get_height(), 16):
			if boat_img.get_pixel(x, y).a > 0.5:
				if x < 420:
					deck_opaque = true
				else:
					seated_opaque = true
		if deck_opaque:
			deck_cells += 1
		if seated_opaque:
			seated_cells += 1
	print("boat = ", boat_img.get_size(), " used=", boat_used,
		" deck columns=", deck_cells, " right-half columns=", seated_cells)
	ok = ok and boat_img.get_width() == 1024 and boat_img.get_height() == 512
	ok = ok and boat_used.size.y > 200 and boat_used.size.x > 900

	# ---- the performance itself ----
	var finished := [0]
	player.performance_finished.connect(func() -> void: finished[0] += 1)
	player.call("play_tv_reaction")
	var boat: Sprite2D = player.get("tv_boat_sprite") as Sprite2D
	print("started: active=", player.get("tv_reaction_active"), " anim=", anim.animation,
		" frame=", anim.frame, " boat=", boat != null, " boat_visible=", boat.visible if boat != null else false)
	ok = ok and bool(player.get("tv_reaction_active")) and anim.animation == "tv_fisherman" and anim.frame == 0
	ok = ok and boat != null and not boat.visible

	# ⚠ The scale bug this suite exists to keep fixed: _process used to overwrite the sprite
	# scale with the FULL body scale every frame, so the game drew him at idle size no matter
	# what TV_PERFORMANCE_SCALE said - while this test, which parks _process, saw the scaled
	# version. Run one real frame through _process and check the multiplier survives.
	var consts_early: Dictionary = (player.get_script() as Script).get_script_constant_map()
	var expected_scale: float = float(player.get("display_height")) / 512.0 \
		* float(consts_early.get("TV_PERFORMANCE_SCALE", 1.0))
	player.call("_process", 0.016)
	print("after a real _process frame: anim.scale.x=", snappedf(anim.scale.x, 0.0001),
		" expected=", snappedf(expected_scale, 0.0001))
	ok = ok and absf(anim.scale.x - expected_scale) < 0.0005

	# Through the startling beat the boat is still hidden; it pops out with the poof.
	var e := 0.0
	while e < 0.4:
		player.call("_update_tv_reaction", 0.05)
		e += 0.05
	var hidden_early: bool = not boat.visible
	while e < 1.05:
		player.call("_update_tv_reaction", 0.05)
		e += 0.05
	print("boat pops: hidden_early=", hidden_early, " visible_now=", boat.visible,
		" pos=", boat.position, " scale=", snappedf(boat.scale.x, 0.001), " fishing=", player.call("is_tv_fishing"))
	ok = ok and hidden_early and boat.visible and bool(player.call("is_tv_fishing"))
	# 竹竿: a SEPARATE sprite (so it can reach down past the hull). Hidden while he is startled -
	# frames 0/1 have no pole in the art - then it swings through the stroke's three angles.
	var pole: Sprite2D = player.get("tv_pole_sprite") as Sprite2D
	var splash: Sprite2D = player.get("tv_splash_sprite") as Sprite2D
	print("pole during the startled beats: node=", pole != null, " visible=", pole.visible if pole != null else false,
		" splash_node=", splash != null)
	ok = ok and pole != null and not pole.visible
	ok = ok and splash != null and not splash.visible
	var man_scale_p: float = float(player.get("display_height")) / 512.0 \
		* float(consts_early.get("TV_PERFORMANCE_SCALE", 1.0))
	var feet_y_p: float = (consts_early.get("SPRITE_BASE_POSITION", Vector2.ZERO) as Vector2).y \
		+ float(player.get("sprite_scale_drop")) + (510.0 - 256.0) * man_scale_p
	# Drive the atlas frame by hand: an AnimatedSprite2D advances on REAL frames, and this test
	# parks the player's _process, so the sprite would otherwise sit on frame 0 forever. The
	# PUSH frame is the beat where the pole is out and its tip is deepest - the splash beat.
	anim.frame = 3
	player.call("_update_tv_reaction", 0.02)
	e += 0.02
	var pole_angles: Array = consts_early.get("TV_POLE_ANGLES", [])
	var tip: Vector2 = player.call("_get_tv_pole_tip")
	print("push frame ", anim.frame, ": pole_visible=", pole.visible,
		" angle=", snappedf(pole.rotation, 0.01), " tip=", tip, " feet_y=", snappedf(feet_y_p, 0.1),
		" splash_visible=", splash.visible, " life=", snappedf(float(player.get("tv_splash_time")), 0.01),
		" splash_at=", splash.position, " scale=", snappedf(splash.scale.x, 0.001))
	ok = ok and pole.visible and anim.frame >= 2
	# 棍子伸进船下方: the tip hangs well below his own shoe row.
	ok = ok and tip.y > feet_y_p + 20.0
	ok = ok and pole_angles.size() == 3 and absf(pole.rotation - float(pole_angles[1])) < 0.001
	# 一圈水花: it bursts at that tip, once per stroke, growing and fading out.
	ok = ok and splash.visible and float(player.get("tv_splash_time")) > 0.0
	ok = ok and absf(splash.position.x - tip.x) < 1.5 and absf(splash.position.y - tip.y) < 1.5
	ok = ok and splash.scale.x < float(consts_early.get("TV_SPLASH_SCALE", 0.38))
	var growth := 0.0
	while growth < 0.3:
		player.call("_update_tv_reaction", 0.05)
		e += 0.05
		growth += 0.05
	print("splash after 0.3s: visible=", splash.visible, " scale=", snappedf(splash.scale.x, 0.001),
		" alpha=", snappedf(splash.modulate.a, 0.01))
	ok = ok and splash.scale.x > float(consts_early.get("TV_SPLASH_SCALE", 0.38)) * 0.45
	# He stands IN the boat: his feet row and the boat's deck row must coincide. The sprite's
	# centre sits (deck_row - 256) * scale above the deck line, so recompute and compare.
	var consts: Dictionary = (player.get_script() as Script).get_script_constant_map()
	var base_position: Vector2 = consts.get("SPRITE_BASE_POSITION", Vector2.ZERO)
	var tv_scale: float = float(consts.get("TV_PERFORMANCE_SCALE", 1.0))
	var boat_scale: float = float(consts.get("TV_BOAT_SCALE", 0.74)) * tv_scale
	var deck_row: float = float(consts.get("TV_BOAT_DECK_ROW", 290.0))
	var center_x: float = float(consts.get("TV_BOAT_CENTER_X", 231.0)) * tv_scale
	# 整体缩小: the whole performance must really be drawn SMALLER than the idle body.
	print("scale: performance=", tv_scale, " sprite_scale=", snappedf(anim.scale.x, 0.0001),
		" drawn_height=", snappedf(anim.scale.x * 512.0, 0.1), " display_height=", player.get("display_height"))
	ok = ok and tv_scale < 1.0
	ok = ok and anim.scale.x * 512.0 < float(player.get("display_height")) * 0.95
	# The boat still hangs off his feet: the deck plank line sits on the row he stands on,
	# and his feet row is what _set_sprite_scale_for's compensation puts it on.
	var drop: float = float(player.get("sprite_scale_drop"))
	var man_scale: float = float(player.get("display_height")) / 512.0 * tv_scale
	var feet_y: float = base_position.y + drop + (510.0 - 256.0) * man_scale
	var deck_y: float = boat.position.y + (deck_row - 256.0) * boat_scale
	print("feet_y=", snappedf(feet_y, 0.1), " deck_y=", snappedf(deck_y, 0.1),
		" drop=", snappedf(drop, 0.1), " boat x=", snappedf(boat.position.x, 0.1),
		" boat scale=", snappedf(boat.scale.x, 0.0001))
	# The live boat position carries its own bob, so the deck line can only be compared to
	# his feet row up to that amplitude (TV_BOAT_BOB * the performance scale).
	ok = ok and absf(deck_y - feet_y) <= 6.0
	ok = ok and absf(boat.position.x - (base_position.x + center_x)) < 0.5
	ok = ok and absf(absf(boat.scale.x) - boat_scale) < 0.02
	ok = ok and boat.scale.x < 0.0  # mirrored: the bow faces him
	# 阴影去掉: while the performance plays his own ground shadow must stay OFF. Otherwise
	# that translucent olive polygon (0.28, 0.30, 0.18, 0.18) is painted across the boat's
	# deck, which is the patch the user circled in their screenshot.
	var shadow_node: Polygon2D = player.get_node_or_null("Shadow") as Polygon2D
	player.call("_update_shadow_visibility")
	print("ground shadow during the performance: node=", shadow_node != null,
		" visible=", shadow_node.visible if shadow_node != null else true)
	ok = ok and shadow_node != null and not shadow_node.visible

	# ---- the stroke is HELD after the beats, cycling the last three frames ----
	while e < 3.0:
		player.call("_update_tv_reaction", 0.05)
		e += 0.05
	var pole_frames: Array = []
	var held := 0.0
	while held < 1.4:
		player.call("_update_tv_reaction", 0.05)
		held += 0.05
		if not pole_frames.has(anim.frame):
			pole_frames.append(anim.frame)
	print("hold: active=", player.get("tv_reaction_active"), " hold=", player.get("tv_hold_active"),
		" pole frames=", pole_frames, " finished=", finished[0])
	ok = ok and bool(player.get("tv_hold_active")) and not bool(player.get("tv_reaction_active"))
	ok = ok and finished[0] == 1
	ok = ok and pole_frames.size() >= 3

	# ---- stop_tv_reaction hands him back to idle and takes the boat away ----
	player.call("stop_tv_reaction")
	print("after stop: hold=", player.get("tv_hold_active"), " anim=", anim.animation,
		" boat_visible=", boat.visible, " fishing=", player.call("is_tv_fishing"))
	ok = ok and not bool(player.get("tv_hold_active")) and anim.animation == "idle" and not boat.visible
	# ...and the shadow comes back with him.
	player.call("_update_shadow_visibility")
	print("ground shadow after stop: visible=", shadow_node.visible)
	ok = ok and shadow_node.visible
	ok = ok and not bool(player.call("is_tv_fishing"))

	# ---- stop_performances wipes a running trip too ----
	player.call("play_tv_reaction")
	player.call("stop_performances")
	print("after stop_performances: active=", player.get("tv_reaction_active"),
		" hold=", player.get("tv_hold_active"), " anim=", anim.animation, " boat_visible=", boat.visible)
	ok = ok and not bool(player.get("tv_reaction_active")) \
		and not bool(player.get("tv_hold_active")) and anim.animation == "idle" and not boat.visible
	player.queue_free()
	await process_frame

	# ---- taking the television out of the cat's mouth starts it (the real level path) ----
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var save_coins: int = int(scene.get("fridge_coin_count"))
	var save_active_item: String = str(scene.get("fridge_active_item_id"))
	var owned: Variant = scene.get("fridge_owned_items")
	var save_owned: Variant = (owned as Array).duplicate() if owned is Array else (owned as Dictionary).duplicate()
	var level_player: Node = scene.get("fridge_player")
	level_player.set_process(false)
	if owned is Array:
		if not (owned as Array).has("crt"):
			(owned as Array).append("crt")
	else:
		if not (owned as Dictionary).has("crt"):
			(owned as Dictionary)["crt"] = true
	scene.call("_take_fridge_item_out_of_mouth", "crt")
	var level_anim: AnimatedSprite2D = level_player.get("animated_sprite") as AnimatedSprite2D
	print("level: phase=", scene.get("fridge_phase"), " active_item=", scene.get("fridge_active_item_id"),
		" tv_active=", level_player.get("tv_reaction_active"), " anim=", level_anim.animation)
	ok = ok and str(scene.get("fridge_active_item_id")) == "crt"
	ok = ok and bool(level_player.get("tv_reaction_active")) and level_anim.animation == "tv_fisherman"
	ok = ok and str(scene.get("fridge_phase")) == "work"

	# ...and the countdown's end brings him back to shore.
	level_player.call("_update_tv_reaction", 3.2)
	var holding: bool = bool(level_player.get("tv_hold_active"))

	# 划船时船会移动 + 划到屏幕边缘就会返回: the boat is a child of the player, so the level's
	# cruise carries the whole ensemble, and the screen edge turns it around.
	var boat_start: Vector2 = level_player.global_position
	for i in 20:
		scene.call("_update_fridge_player_flight", 0.05)
	var boat_moved: float = level_player.global_position.x - boat_start.x
	var boat_dir: float = float(scene.get("fridge_player_flight_dir"))
	print("boat cruise: moved_x=", snappedf(boat_moved, 0.1), " moved_y=",
		snappedf(level_player.global_position.y - boat_start.y, 0.1), " dir=", boat_dir)
	ok = ok and absf(boat_moved) > 30.0 and absf(level_player.global_position.y - boat_start.y) < 0.001
	ok = ok and signf(boat_moved) == signf(boat_dir)
	var boat_screen: Rect2 = scene.call("_fridge_screen_world_rect")
	var level_consts: Dictionary = (scene.get_script() as Script).get_script_constant_map()
	var right_margin: float = float(level_consts.get("FRIDGE_BOAT_RIGHT_MARGIN", 110.0))
	var edge_limit: float = boat_screen.position.x + boat_screen.size.x - right_margin
	level_player.global_position.x = edge_limit - 10.0
	scene.set("fridge_player_flight_dir", 1.0)
	for i in 6:
		scene.call("_update_fridge_player_flight", 0.05)
	print("boat edge turn: dir=", scene.get("fridge_player_flight_dir"),
		" x=", snappedf(level_player.global_position.x, 1.0), " limit=", snappedf(edge_limit, 1.0))
	ok = ok and float(scene.get("fridge_player_flight_dir")) < 0.0
	ok = ok and level_player.global_position.x <= edge_limit + 0.6
	scene.set("fridge_time_left", 0.05)
	scene.call("_update_fridge_pomodoro", 0.1)
	print("at countdown end: held_during_countdown=", holding, " hold_now=", level_player.get("tv_hold_active"),
		" anim=", level_anim.animation, " phase=", scene.get("fridge_phase"))
	ok = ok and holding
	ok = ok and not bool(level_player.get("tv_hold_active")) and level_anim.animation == "idle"
	ok = ok and str(scene.get("fridge_phase")) == "idle"

	# Keep the real save byte-identical (this test drives the real take-out path).
	scene.set("fridge_owned_items", save_owned)
	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.call("_save_fridge_progress")
	print("TV_REACTION_TEST=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0)