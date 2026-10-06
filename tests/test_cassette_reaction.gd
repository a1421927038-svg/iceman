extends SceneTree

## Covers the 磁带机 (cassette) countdown performance: taking the cassette out of the
## cat's mouth makes the fridge man yank out a boombox, hoist it over his head, shoulder
## it and dance with it - sunglasses, gold chain and sneakers are painted into the art -
## while musical notes fly out of its speakers. The dance is HELD until the countdown
## ends, he paces SIDEWAYS while it plays (a click turns him around, the screen edges
## bounce him), and switching items mid-dance cancels it at once.
## (The 电视机 fisherman performance has its own suite: test_tv_reaction.gd.)

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
	if sf.has_animation("cassette_party"):
		for i in sf.get_frame_count("cassette_party"):
			durations.append(snappedf(sf.get_frame_duration("cassette_party", i), 0.001))
			var tex: Texture2D = sf.get_frame_texture("cassette_party", i)
			regions.append((tex as AtlasTexture).region.position.x if tex is AtlasTexture else -1.0)
	var expected_beats := [0.5, 0.35, 0.45, 0.6, 0.6]
	var beats_match := durations.size() == expected_beats.size()
	for i in durations.size():
		if i >= expected_beats.size() or absf(float(durations[i]) - float(expected_beats[i])) > 0.001:
			beats_match = false
	print("boombox dance: has=", sf.has_animation("cassette_party"),
		" frames=", sf.get_frame_count("cassette_party") if sf.has_animation("cassette_party") else -1,
		" loop=", sf.get_animation_loop("cassette_party") if sf.has_animation("cassette_party") else true,
		" durations=", durations, " region_x=", regions)
	ok = ok and sf.has_animation("cassette_party") and sf.get_frame_count("cassette_party") == 5
	ok = ok and not sf.get_animation_loop("cassette_party")
	ok = ok and beats_match
	ok = ok and regions == [0.0, 512.0, 1024.0, 1536.0, 2048.0]

	# The art: five frames, each with COMPLETE sneaker soles (a frame chopped by the
	# canvas edge has a silhouette that GROWS toward its lowest row), all with the feet on
	# the idle's ground line (row 510), and all five visibly different poses.
	var atlas_img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/generated/paper_fridge_boombox_party.png"))
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

	# The notes sheet really holds four separate notes - that is what
	# _spawn_cassette_notes slices (128px cells).
	var notes_img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/generated/paper_music_notes.png"))
	notes_img.convert(Image.FORMAT_RGBA8)
	var note_cells := 0
	for i in 4:
		if notes_img.get_region(Rect2i(i * 128, 0, 128, 128)).get_used_rect().size.x > 20:
			note_cells += 1
	print("notes sheet = ", notes_img.get_size(), " filled note cells = ", note_cells)
	ok = ok and notes_img.get_width() == 512 and note_cells == 4

	# ---- the performance itself ----
	var finished := [0]
	player.performance_finished.connect(func() -> void: finished[0] += 1)
	player.call("play_cassette_reaction")
	print("started: active=", player.get("cassette_reaction_active"), " anim=", anim.animation,
		" frame=", anim.frame, " notes=", (player.get("cassette_notes") as Array).size())
	ok = ok and bool(player.get("cassette_reaction_active")) \
		and anim.animation == "cassette_party" and anim.frame == 0

	# The beats run on the player's own clock (its _process is parked for determinism).
	var e := 0.0
	while e < 1.05:
		player.call("_update_cassette_reaction", 0.05)
		e += 0.05
	var notes_before: int = (player.get("cassette_notes") as Array).size()
	print("before the shoulder beat: notes=", notes_before, " active=", player.get("cassette_reaction_active"))
	ok = ok and notes_before == 0
	while e < 1.9:
		player.call("_update_cassette_reaction", 0.05)
		e += 0.05
	var notes_after: int = (player.get("cassette_notes") as Array).size()
	var live := 0
	for c in player.get("cassette_notes"):
		if c is Sprite2D and (c as Sprite2D).visible:
			live += 1
	print("after the shoulder beat: pooled=", notes_after, " visible=", live,
		" origin=", player.call("_get_cassette_note_origin"))
	ok = ok and notes_after > 0 and live > 0
	var risen := false
	var first: Sprite2D = null
	for c: Sprite2D in player.get("cassette_notes"):
		if c.visible:
			first = c
			break
	if first != null:
		var y0: float = first.position.y
		player.call("_update_cassette_notes", 0.1)
		risen = first.position.y < y0
	print("note rises: ", risen)
	ok = ok and risen

	# ---- the dance is HELD after the beats, it does not drop back to idle ----
	while e < 2.9:
		player.call("_update_cassette_reaction", 0.05)
		e += 0.05
	var frame_a: int = anim.frame
	var held := 0.0
	while held < 0.45:
		player.call("_update_cassette_reaction", 0.02)
		held += 0.02
	var frame_b: int = anim.frame
	print("hold: active=", player.get("cassette_reaction_active"), " hold=", player.get("cassette_hold_active"),
		" frames=", frame_a, "->", frame_b, " finished=", finished[0])
	ok = ok and bool(player.get("cassette_hold_active")) and not bool(player.get("cassette_reaction_active"))
	ok = ok and finished[0] == 1
	ok = ok and frame_a != frame_b  # the held dance bops between the last two beats

	# ---- stop_cassette_reaction hands him back to idle ----
	player.call("stop_cassette_reaction")
	var any_visible := false
	for c: Sprite2D in player.get("cassette_notes"):
		if c.visible:
			any_visible = true
	print("after stop: hold=", player.get("cassette_hold_active"), " anim=", anim.animation,
		" notes_visible=", any_visible)
	ok = ok and not bool(player.get("cassette_hold_active")) and anim.animation == "idle" and not any_visible

	# ---- stop_performances wipes a running dance too ----
	player.call("play_cassette_reaction")
	player.call("stop_performances")
	print("after stop_performances: active=", player.get("cassette_reaction_active"),
		" hold=", player.get("cassette_hold_active"), " anim=", anim.animation)
	ok = ok and not bool(player.get("cassette_reaction_active")) \
		and not bool(player.get("cassette_hold_active")) and anim.animation == "idle"
	player.queue_free()
	await process_frame

	# ---- taking the cassette out of the cat's mouth starts it (the real level path) ----
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
		if not (owned as Array).has("cassette"):
			(owned as Array).append("cassette")
	else:
		if not (owned as Dictionary).has("cassette"):
			(owned as Dictionary)["cassette"] = true
	scene.call("_take_fridge_item_out_of_mouth", "cassette")
	var level_anim: AnimatedSprite2D = level_player.get("animated_sprite") as AnimatedSprite2D
	print("level: phase=", scene.get("fridge_phase"), " active_item=", scene.get("fridge_active_item_id"),
		" cassette_active=", level_player.get("cassette_reaction_active"), " anim=", level_anim.animation)
	ok = ok and str(scene.get("fridge_active_item_id")) == "cassette"
	ok = ok and bool(level_player.get("cassette_reaction_active")) and level_anim.animation == "cassette_party"
	ok = ok and str(scene.get("fridge_phase")) == "work"

	# ...and the countdown's end releases the dance.
	level_player.call("_update_cassette_reaction", 3.0)
	var holding: bool = bool(level_player.get("cassette_hold_active"))
	scene.set("fridge_time_left", 0.05)
	scene.call("_update_fridge_pomodoro", 0.1)
	print("at countdown end: held_during_countdown=", holding, " hold_now=", level_player.get("cassette_hold_active"),
		" anim=", level_anim.animation, " phase=", scene.get("fridge_phase"))
	ok = ok and holding
	ok = ok and not bool(level_player.get("cassette_hold_active")) and level_anim.animation == "idle"
	ok = ok and str(scene.get("fridge_phase")) == "idle"

	# ---- switching items mid-dance cancels it at once (the existing 立即切换 rule) ----
	scene.call("_take_fridge_item_out_of_mouth", "cassette")
	level_player.call("_update_cassette_reaction", 3.0)
	scene.call("_take_fridge_item_out_of_mouth", "tomato")
	print("switched mid-dance: cassette_active=", level_player.get("cassette_reaction_active"),
		" hold=", level_player.get("cassette_hold_active"),
		" active_item=", scene.get("fridge_active_item_id"))
	ok = ok and not bool(level_player.get("cassette_reaction_active")) \
		and not bool(level_player.get("cassette_hold_active"))

	# ---- 水平方向移动 + 点击换向: with the boombox on his shoulder he paces SIDEWAYS, a
	# click (a quick press that does not drag him) turns him around, the screen edges
	# bounce him, and it all stops when the countdown ends. ----
	scene.set("fridge_phase", "idle")
	scene.call("_take_fridge_item_out_of_mouth", "cassette")
	level_player.call("_update_cassette_reaction", 3.0)
	var dancing: bool = bool(level_player.call("is_cassette_dancing"))
	var start_pos: Vector2 = level_player.global_position
	var dir_before: float = float(scene.get("fridge_player_flight_dir"))
	for i in 20:
		scene.call("_update_fridge_player_flight", 0.05)
	var moved_x: float = level_player.global_position.x - start_pos.x
	var moved_y: float = level_player.global_position.y - start_pos.y
	print("dance pacing: dancing=", dancing, " dir=", dir_before, " moved_x=", snappedf(moved_x, 0.1),
		" moved_y=", snappedf(moved_y, 0.1))
	ok = ok and dancing
	ok = ok and absf(moved_x) > 30.0 and absf(moved_y) < 0.001
	ok = ok and signf(moved_x) == signf(dir_before)

	# A real click on him (a press + release with no motion) flips the direction, through
	# the same _input path a player uses.
	var mouse_world: Vector2 = (scene.get_viewport().get_canvas_transform().affine_inverse()
		* scene.get_viewport().get_mouse_position())
	level_player.global_position = mouse_world
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.get_viewport().get_mouse_position()
	scene.call("_input", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	scene.call("_input", release)
	var dir_after: float = float(scene.get("fridge_player_flight_dir"))
	print("click flip: ", dir_before, " -> ", dir_after)
	ok = ok and is_equal_approx(dir_before, -dir_after)
	# ...and the pacing follows whatever the direction is now. (The click needs the mouse
	# over him, and in a headless run the mouse sits in the screen corner, so he is parked
	# there - which is exactly the edge, so re-centre him before measuring the travel.)
	level_player.global_position = Vector2(0.0, level_player.global_position.y)
	var dir_now: float = float(scene.get("fridge_player_flight_dir"))
	var before_x: float = level_player.global_position.x
	for i in 20:
		scene.call("_update_fridge_player_flight", 0.05)
	var after_x: float = level_player.global_position.x
	print("pacing follows dir ", dir_now, ": ", snappedf(before_x, 0.1), " -> ", snappedf(after_x, 0.1))
	ok = ok and absf(after_x - before_x) > 30.0 and signf(after_x - before_x) == signf(dir_now)

	# The screen edge turns him around instead of letting him walk out of the view.
	var screen: Rect2 = scene.call("_fridge_screen_world_rect")
	level_player.global_position.x = screen.position.x + screen.size.x - 130.0
	scene.set("fridge_player_flight_dir", 1.0)
	for i in 6:
		scene.call("_update_fridge_player_flight", 0.05)
	var edge_limit: float = screen.position.x + screen.size.x - 122.0
	print("edge turn: dir=", scene.get("fridge_player_flight_dir"),
		" x=", snappedf(level_player.global_position.x, 1.0), " limit=", snappedf(edge_limit, 1.0))
	ok = ok and float(scene.get("fridge_player_flight_dir")) < 0.0
	ok = ok and level_player.global_position.x <= edge_limit + 0.6

	# At the countdown's end the dance stops, so the pacing stops with it.
	scene.set("fridge_time_left", 0.05)
	scene.call("_update_fridge_pomodoro", 0.1)
	var still_dancing: bool = bool(level_player.call("is_cassette_dancing"))
	var park_x: float = level_player.global_position.x
	for i in 10:
		scene.call("_update_fridge_player_flight", 0.05)
	print("after the countdown: dancing=", still_dancing, " x ", snappedf(park_x, 1.0), " -> ",
		snappedf(level_player.global_position.x, 1.0))
	ok = ok and not still_dancing

	# Keep the real save byte-identical (this test drives the real take-out path).
	if owned is Array:
		scene.set("fridge_owned_items", save_owned)
	else:
		scene.set("fridge_owned_items", save_owned)
	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.call("_save_fridge_progress")
	print("CASSETTE_REACTION_TEST=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0)