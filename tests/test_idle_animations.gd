extends SceneTree

## Verifies the idle ("待机") animations added for both characters:
##   fridge man - 站立歇息 / 抽烟吐烟圈 / 摸摸小猫 / 打瞌睡
##   cat        - 站立歇息 / 玩球 / 绕着冰箱人跑圈 / 打瞌睡
## plus the gallery entries, the automatic idle rotation and the cat
## choreography (orbit + sit-under-the-hand + walk home).
## The plain standing idle itself is a relaxed 4-frame breathing loop built from
## poses normalised onto one frame geometry - it never scales the character, and
## 打瞌睡 is an action, not the stance either character walks around in.

func _init() -> void:
	_run.call_deferred()


## True while the cat's sprite is showing one of the plain standing idle's frames.
func _is_idle_pose(sprite: Sprite2D, cat: Node) -> bool:
	if sprite == null:
		return false
	var frames: Array = cat.call("_get_idle_action_frames", "rest_stand")
	return frames.has(sprite.texture)


func _run() -> void:
	var failures: Array[String] = []

	# ---------- fridge man: every idle action is a registered animation ----------
	var player: Node = load("res://scripts/FridgePomodoroPlayer.gd").new()
	get_root().add_child(player)
	await process_frame
	await process_frame
	var anim: AnimatedSprite2D = player.get_node("Sprite") as AnimatedSprite2D
	var sf: SpriteFrames = anim.sprite_frames

	for action_id: String in FridgePomodoroPlayer.IDLE_ACTIONS:
		var entry: Dictionary = FridgePomodoroPlayer.IDLE_ACTIONS[action_id]
		var animation_name := str(entry["animation"])
		if not sf.has_animation(animation_name):
			failures.append("man idle action has no animation: %s" % action_id)
			continue
		# 站立歇息 IS the default idle pose: it has no atlas of its own and plays
		# the plain "idle" animation.
		if action_id == "rest_stand":
			print("man ", action_id, " anim=", animation_name, " (the default idle pose)")
			if animation_name != "idle":
				failures.append("站立歇息 no longer plays the default idle animation")
			continue
		# 打瞌睡 is driven by FridgeDozeCycle, so its "animation" is just the single
		# dozing pose the cycle starts on and switches away from again.
		if action_id == "doze":
			print("man ", action_id, " anim=", animation_name, " frames=", sf.get_frame_count(animation_name))
			if not sf.has_animation(FridgePomodoroPlayer.DOZE_ANIMATION_NAME) or not sf.has_animation(FridgePomodoroPlayer.STARTLE_ANIMATION_NAME):
				failures.append("the man's doze poses are no longer registered")
			continue
		var frames: int = sf.get_frame_count(animation_name)
		var expected: int = int(entry.get("frames", 3))
		if bool(entry.get("ping_pong", false)):
			expected += expected - 2
		print("man ", action_id, " anim=", animation_name, " frames=", frames, " loop=", sf.get_animation_loop(animation_name), " fps=", sf.get_animation_speed(animation_name))
		if frames != expected:
			failures.append("man %s frame count %d != %d" % [action_id, frames, expected])
		if not sf.get_animation_loop(animation_name):
			failures.append("man %s does not loop" % action_id)
		var frame0: Texture2D = sf.get_frame_texture(animation_name, 0)
		if frame0 == null or frame0.get_width() != 512:
			failures.append("man %s frame 0 is not a 512px atlas frame" % action_id)

	# Playing one owns the sprite, then hands it back to idle when it times out.
	player.call("play_idle_action", "smoke", 0.3)
	var smoke_animation := anim.animation
	var smoke_active: bool = bool(player.call("is_idle_action_active"))
	var smoke_scale: float = anim.scale.x
	var smoke_drop: float = float(player.get("sprite_scale_drop"))
	var guard := 0
	while bool(player.call("is_idle_action_active")) and guard < 300:
		await process_frame
		guard += 1
	print("man smoke: animation=", smoke_animation, " active=", smoke_active, " frames=", guard, " after=", anim.animation)
	# 抽烟吐烟圈: its art is regenerated at the idle's own scale (the man fills his
	# 512px frame and stands on the same ground line), so nothing is resized at
	# runtime and he no longer shrinks during the animation.
	var idle_scale: float = float(player.get("display_height")) / 512.0
	var smoke_img: Image = (sf.get_frame_texture("idle_smoke", 0) as Texture2D).get_image()
	var sy0 := 999999
	var sy1 := -1
	for y in range(smoke_img.get_height()):
		for x in range(smoke_img.get_width()):
			if smoke_img.get_pixel(x, y).a > 0.06:
				sy0 = mini(sy0, y)
				sy1 = maxi(sy1, y)
	var smoke_h: int = sy1 - sy0 + 1
	print("man smoke scale=", smoke_scale, " idle_scale=", idle_scale, " drop=", smoke_drop, " art_h=", smoke_h, " of ", smoke_img.get_height())
	if smoke_h < 480:
		failures.append("the smoke art still draws the man smaller than idle (%dpx)" % smoke_h)
	if not is_equal_approx(smoke_scale, idle_scale) or not is_zero_approx(smoke_drop):
		failures.append("the smoke animation is resized at runtime again")
	if not smoke_active or smoke_animation != str(FridgePomodoroPlayer.IDLE_ACTIONS["smoke"]["animation"]):
		failures.append("smoke idle action did not take the sprite")
	if bool(player.call("is_idle_action_active")) or anim.animation != "idle":
		failures.append("idle action did not return to idle")

	# An idle action replaces a running performance (they never stack).
	player.call("play_rest_preview", 30.0)
	player.call("play_idle_action", "pet_cat", 0.2)
	var rest_cleared: bool = float(player.get("rest_preview_timer")) <= 0.0
	print("idle action cleared rest preview=", rest_cleared, " animation=", anim.animation)
	if not rest_cleared:
		failures.append("idle action did not replace the running performance")
	player.call("stop_performances")

	# ---------- level: gallery entries, rotation and cat choreography ----------
	var level: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(level)
	# Deterministic: the automatic rotation is driven explicitly below. Set before
	# the first processed frame so nothing starts on its own.
	level.set("fridge_idle_rotation_enabled", false)
	level.set("fridge_idle_timer", 0.0)
	await process_frame
	await process_frame
	# Keep the player's own save state intact: this test must not pay out coins.
	var save_coins: int = int(level.get("fridge_coin_count"))
	var save_active_item: String = str(level.get("fridge_active_item_id"))
	var cat: Node = level.get("fridge_cat_pet")
	var level_player: Node = level.get("fridge_player")
	var cat_sprite: Sprite2D = cat.get("sprite") as Sprite2D
	var cat_idle_texture: Texture2D = cat.get("idle_texture") as Texture2D
	var cat_home: Vector2 = cat.global_position

	# ---------- cat: each idle atlas slices into clean 256px frames ----------
	# Six is the house convention; 睡觉's 猫饼 accordion carries eight, because its big
	# squash <-> stretch swing needs the smaller per-frame steps to stay smooth.
	for action_id: String in FridgeCatPet.IDLE_ACTIONS:
		var sliced: Array = cat.call("_get_idle_action_frames", action_id)
		print("cat ", action_id, " frames=", sliced.size(), " fps=", FridgeCatPet.IDLE_ACTIONS[action_id]["fps"])
		# 站立歇息 IS the plain standing idle, so it slices the idle loop itself.
		if action_id == "rest_stand":
			if sliced.is_empty() or sliced[0] != cat_idle_texture:
				failures.append("the cat's 站立歇息 no longer uses the default idle art")
			continue
		# 打瞌睡 is driven by FridgeDozeCycle, which owns its own two poses.
		if action_id == "doze":
			if not sliced.is_empty():
				failures.append("the cat's 打瞌睡 should not carry its own frame atlas")
			continue
		# Six is the house convention for every cat action atlas.
		var expected_frames: int = 6
		if sliced.size() != expected_frames:
			failures.append("cat %s sliced %d frames, expected %d" % [action_id, sliced.size(), expected_frames])
		else:
			var first: Texture2D = sliced[0]
			if first == null or first.get_width() != 256:
				failures.append("cat %s frame 0 is not 256px" % action_id)

	await process_frame
	var entries: Array = level.get("FRIDGE_GALLERY_ENTRIES")

	print("gallery entries=", entries.size(), " cat_home=", cat_home)
	if entries.size() < 10:
		failures.append("gallery is missing entries (%d)" % entries.size())
	var has_pager := false
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == "man_pager":
			has_pager = true
		var icon_path := str(entry.get("icon", ""))
		if not FileAccess.file_exists(ProjectSettings.globalize_path(icon_path)):
			failures.append("gallery entry %s has no icon file (%s)" % [entry.get("id", "?"), icon_path])
	if not has_pager:
		failures.append("the BB机 (pager) entry is not in the gallery")

	# A gallery entry drives the cat's animation (小猫玩球).
	level.call("_on_fridge_gallery_entry_pressed", "cat_play_ball")
	await process_frame
	var cat_active: bool = bool(cat.call("is_idle_action_active"))
	var cat_texture: Texture2D = cat_sprite.texture
	var suppress: float = float(level.get("fridge_idle_suppress"))
	print("gallery cat_play_ball: active=", cat_active, " swapped_texture=", cat_texture != cat_idle_texture, " suppress=", suppress)
	if not cat_active or cat_texture == cat_idle_texture:
		failures.append("gallery entry did not start the cat idle animation")
	if suppress <= 0.0:
		failures.append("gallery entry did not suppress the idle rotation")

	# 背包格子: entries sit in a 3-wide grid of which two rows show at once, and
	# everything past that has to be pulled into view.
	var panel: Control = level.get("fridge_gallery_panel")
	var scroll: ScrollContainer = null
	var grid: GridContainer = null
	for node in panel.find_children("", "ScrollContainer", true, false):
		scroll = node as ScrollContainer
	if scroll != null:
		for node in scroll.find_children("", "GridContainer", true, false):
			grid = node as GridContainer
	var columns: int = grid.columns if grid != null else 0
	var expected_columns: int = int(level.get_script().get_script_constant_map().get("FRIDGE_GALLERY_GRID_COLUMNS", 2))
	var cards: int = grid.get_child_count() if grid != null else 0
	var visible_h: float = scroll.custom_minimum_size.y if scroll != null else 0.0
	var content_h: float = grid.get_combined_minimum_size().y if grid != null else 0.0
	print("backpack: scroll=", scroll != null, " columns=", columns, " cards=", cards, "/", entries.size(), " visible_h=", visible_h, " content_h=", content_h, " panel_h=", panel.custom_minimum_size.y)
	if columns != expected_columns:
		failures.append("backpack grid is not %d columns wide (%d)" % [expected_columns, columns])
	if cards != entries.size():
		failures.append("backpack shows %d of %d cards" % [cards, entries.size()])
	if content_h <= visible_h:
		failures.append("backpack content fits without scrolling, so the pull-down is untested")
	# 分页 raised the backpack by its two-page bookmark row, so the ceiling sits just above the
	# two-row tabbed panel (~280 now the bookmark ribbons live at the top corner) rather than at 400.
	if panel.custom_minimum_size.y > 480.0:
		failures.append("backpack grew past two rows (%.0f)" % panel.custom_minimum_size.y)
	# 隐藏滑块: the backpack shows no scroll slider any more - the wheel still scrolls it.
	if scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		failures.append("the backpack still shows its scroll slider")
	if scroll != null:
		scroll.scroll_vertical = 250
		print("backpack hidden bar: scroll_vertical=", scroll.scroll_vertical, " of ", int(content_h - visible_h), " available")
		if scroll.scroll_vertical <= 0:
			failures.append("the backpack cannot scroll with its bar hidden")

	# 道具箱同款纸片 UI, minus the 标题: the backpack wears the prop box's cream paper board
	# (a StyleBoxTexture with the backing card) behind debossed paper pockets. Its 标题 is gone (the
	# 分页 bookmarks took that line) and so is the 下拉查看更多 hint - the bookmark ribbons now sit at
	# the board's top corner, and the mouse wheel still pulls the list down.
	# (Its scroll slider is a paper button; that is checked in _scrollbar_probe.gd.)
	var panel_style := panel.get_theme_stylebox("panel")
	var paper_board: bool = panel_style is StyleBoxTexture
	var panel_title: String = str(level.get_script().get_script_constant_map().get("FRIDGE_GALLERY_TITLE", ""))
	var title_labels := 0
	var hint_labels := 0
	for label_node: Node in panel.find_children("", "Label", true, false):
		var label_text := (label_node as Label).text
		if label_text == panel_title:
			title_labels += 1
		if label_text.contains("下拉查看更多"):
			hint_labels += 1
	var stand_prop: Node2D = level.get("fridge_gallery_stand") as Node2D
	var panel_rect: Rect2 = panel.get_global_rect()
	var stand_art: Rect2 = level.call("_fridge_prop_art_rect", stand_prop)
	print("backpack panel: style=", panel_style.get_class() if panel_style != null else "<none>",
		" paper_board=", paper_board, " title=", title_labels, " hint=", hint_labels,
		" rect=", panel_rect, " stand_art=", stand_art)
	if not paper_board:
		failures.append("the backpack is not wearing the paper board the prop box uses")
	if title_labels > 0:
		failures.append("the backpack still shows its 标题 (%d labels)" % title_labels)
	if hint_labels > 0:
		failures.append("the backpack still shows the 下拉查看更多 line (%d labels)" % hint_labels)

	var card_count := 0
	var bare_cards := 0
	# 去掉边框: the notebook's panel is the open book itself - the cells carry NO artwork, so the
	# icons and names print straight onto the cream pages.
	if grid != null:
		# Count the grid's own children: the scroll container also carries a built-in
		# "_focus" PanelContainer, which is not a cell.
		card_count = grid.get_child_count()
		for card_node in grid.get_children():
			var card_style := (card_node as Control).get_theme_stylebox("panel")
			if card_style is StyleBoxEmpty:
				bare_cards += 1
	print("backpack cells: ", card_count, " total, ", bare_cards, " bare, for ", entries.size(), " entries")
	if card_count < entries.size():
		failures.append("the backpack shows %d cells for %d entries" % [card_count, entries.size()])
	if bare_cards < card_count:
		failures.append("only %d of %d backpack cells are bare" % [bare_cards, card_count])
	# 正上方: the panel must really sit ABOVE the stand's own art - it is pinned to the MEASURED art
	# every frame, not to a fixed offset, so moving the stand can never leave the opened book over it.
	if stand_art.size == Vector2.ZERO or panel_rect.end.y > stand_art.position.y + 0.5:
		failures.append("the backpack panel is not above the stand's art (panel %s vs art %s)" % [panel_rect, stand_art])

	# BB机来讯: the pager reaction plays from the gallery, and because it is a
	# preview it ends on its own instead of being held until a countdown ends.
	var pager_duration: float = float(level.get_script().get_script_constant_map().get("FRIDGE_PAGER_PREVIEW_DURATION", 0.0))
	level.call("_stop_fridge_idle_actions")
	level.call("_on_fridge_gallery_entry_pressed", "man_pager")
	# Read before awaiting a frame: the preview clock ticks down with frame deltas.
	var pager_started: bool = bool(level_player.get("pager_reaction_active")) or bool(level_player.get("pager_hold_active"))
	var pager_preview: float = float(level_player.get("pager_preview_timer"))
	await process_frame
	print("gallery man_pager: started=", pager_started, " preview=", pager_preview, "/", pager_duration)
	if not pager_started:
		failures.append("gallery entry did not start the pager reaction")
	if absf(pager_preview - pager_duration) > 0.2:
		failures.append("the pager preview is not on its own clock (%.2f)" % pager_preview)
	level_player.set("pager_preview_timer", 0.05)
	level_player.call("_update_pager_reaction", 0.1)
	var pager_stopped: bool = not bool(level_player.get("pager_reaction_active")) and not bool(level_player.get("pager_hold_active"))
	print("gallery man_pager: ended_itself=", pager_stopped)
	if not pager_stopped:
		failures.append("the pager gallery preview did not end by itself")
	await process_frame

	# 小猫绕着冰箱人跑圈: the cat circles the fridge man, then trots back home.
	cat.call("stop_idle_action")
	level.call("_start_fridge_cat_orbit", 0.5)
	var orbit_motion := str(level.get("fridge_cat_motion"))
	var orbit_animation := str(cat_sprite.texture != cat_idle_texture)
	var min_d := 999999.0
	var max_d := 0.0
	var moved_frames := 0
	var orbit_guard := 0
	# 前后遮挡: while circling it must spend time BEHIND the fridge man and time in
	# front of him, judged by z_index against the man's own.
	var z_behind := false
	var z_front := false
	while str(level.get("fridge_cat_motion")) != "" and orbit_guard < 900:
		await process_frame
		orbit_guard += 1
		var d: float = cat.global_position.distance_to(level_player.global_position)
		min_d = minf(min_d, d)
		max_d = maxf(max_d, d)
		moved_frames += 1
		if cat.z_index < level_player.z_index:
			z_behind = true
		elif cat.z_index > level_player.z_index:
			z_front = true
	var cat_back_home: bool = cat.global_position.distance_to(cat_home) < 1.0
	var z_after_home: int = cat.z_index
	print("orbit: motion=", orbit_motion, " swapped=", orbit_animation, " dist=[", min_d, ",", max_d, "] frames=", orbit_guard, " back_home=", cat_back_home, " curve=", cat.global_position, " z_behind=", z_behind, " z_front=", z_front, " z_after=", z_after_home, " man_z=", level_player.z_index)
	if orbit_motion != "orbit" and orbit_motion != "approach":
		failures.append("orbit did not start (%s)" % orbit_motion)
	if not cat_back_home:
		failures.append("cat did not return home after the orbit")
	if max_d - min_d < 40.0:
		failures.append("cat barely moved during the orbit (%.1f)" % (max_d - min_d))
	if not z_behind or not z_front:
		failures.append("the orbit has no front/back occlusion (behind=%s front=%s)" % [z_behind, z_front])
	if z_after_home <= level_player.z_index:
		failures.append("the cat did not return to its normal draw order after the orbit (%d)" % z_after_home)
	if str(cat.get("idle_action_id")) != "":
		failures.append("cat idle action still running after the orbit")

	# 摸摸小猫: the cat comes to the fridge man and sits under his hand.
	level.call("_start_fridge_pet_cat")
	var pet_motion := str(level.get("fridge_cat_motion"))
	var pet_near: float = cat.global_position.distance_to(level_player.global_position)
	var man_petting: bool = str(level_player.get("idle_action_id")) == "pet_cat"
	print("pet: motion=", pet_motion, " dist_to_man=", pet_near, " man_petting=", man_petting)
	if pet_motion != "wait" or not man_petting:
		failures.append("petting did not start on both characters")
	if pet_near > 130.0:
		failures.append("cat did not walk over to the fridge man (%.1f)" % pet_near)
	# Skip the long stroking beat and let the walk home run.
	level.set("fridge_cat_motion_time", 999.0)
	await process_frame
	var pet_guard := 0
	while str(level.get("fridge_cat_motion")) != "" and pet_guard < 400:
		await process_frame
		pet_guard += 1
	var pet_back_home: bool = cat.global_position.distance_to(cat_home) < 1.0
	print("pet return frames=", pet_guard, " back_home=", pet_back_home)
	if not pet_back_home:
		failures.append("cat did not walk home after being petted")

	# The automatic rotation picks something on its own when the level is idle.
	level.call("_stop_fridge_idle_actions")
	# (The gallery press above left the manual-preview suppression running.)
	level.set("fridge_idle_suppress", 0.0)
	level.set("fridge_idle_rotation_enabled", true)
	level.set("fridge_idle_timer", 0.0)
	await process_frame
	await process_frame
	var rotated := bool(level_player.call("is_idle_action_active")) \
		or bool(cat.call("is_idle_action_active")) \
		or str(level.get("fridge_cat_motion")) != ""
	var next_delay: float = float(level.get("fridge_idle_timer"))
	print("rotation fired=", rotated, " next_delay=", next_delay)
	if not rotated:
		failures.append("idle rotation did not play an animation")
	if next_delay <= 0.0:
		failures.append("idle rotation did not schedule the next action")
	# The wait that follows a fired animation is a full FRIDGE_IDLE_DELAY, not a
	# leftover: that is what makes the rotation wait 20 s again before the next one.
	var scheduled: float = float(level.get_script().get_script_constant_map().get("FRIDGE_IDLE_DELAY", 0.0))
	if absf(next_delay - scheduled) > 0.1:
		failures.append("the rotation did not schedule a full idle delay (%.2f of %.2f)" % [next_delay, scheduled])

	# 每个播放一次: the rotation draws from a shuffled bag holding every idle
	# animation exactly once, so nothing repeats until they have all played.
	var consts_here: Dictionary = level.get_script().get_script_constant_map()
	var man_actions: Array = consts_here.get("FRIDGE_IDLE_MAN_ACTIONS", [])
	var cat_actions: Array = consts_here.get("FRIDGE_IDLE_CAT_ACTIONS", [])
	var expected_total: int = man_actions.size() + cat_actions.size()
	var bag: Array = level.call("_build_fridge_idle_bag")
	var seen: Dictionary = {}
	var duplicated := false
	for item: Dictionary in bag:
		var key := "%s:%s" % [item["who"], item["action"]]
		if seen.has(key):
			duplicated = true
		seen[key] = true
	var bag_left: int = (level.get("fridge_idle_bag") as Array).size()
	print("idle bag: built=", bag.size(), "/", expected_total, " duplicates=", duplicated, " after one fire=", bag_left)
	if bag.size() != expected_total or duplicated:
		failures.append("the idle rotation bag does not hold every animation exactly once")
	if bag_left != expected_total - 1:
		failures.append("the rotation did not draw exactly one animation from the bag")

	# 冰箱人先来: every rebuilt bag leads with a VISIBLE fridge man animation, so
	# the first thing the player sees after the idle pause is the man performing
	# (never the cat, and never 站立歇息 - which just replays his default pose).
	var man_leads := true
	var lead_action := ""
	for _rebuild in range(12):
		var probe_bag: Array = level.call("_build_fridge_idle_bag")
		lead_action = "%s:%s" % [probe_bag[0]["who"], probe_bag[0]["action"]]
		if str(probe_bag[0]["who"]) != "man" or str(probe_bag[0]["action"]) == "rest_stand":
			man_leads = false
	print("bag leads with=", lead_action, " man_leads=", man_leads)
	if not man_leads:
		failures.append("the idle rotation does not lead with a visible fridge man animation")

	# Nothing idle plays during a running round.
	level.call("_stop_fridge_idle_actions")
	level.set("fridge_phase", "work")
	# A long countdown keeps this a pure "is idle suppressed?" probe: with
	# time_left at 0 the level would finish a real round and pay its reward.
	level.set("fridge_time_left", 999.0)
	level.set("fridge_idle_timer", 0.0)
	await process_frame
	await process_frame
	var blocked := not bool(level_player.call("is_idle_action_active")) \
		and not bool(cat.call("is_idle_action_active")) \
		and str(level.get("fridge_cat_motion")) == ""
	print("rotation quiet during work=", blocked)
	if not blocked:
		failures.append("idle animations played during a running round")

	level.set("fridge_phase", "idle")
	level.call("_stop_fridge_idle_actions")

	# ---------- 待机超时: 10 s, and mouse activity is what counts as interaction ----
	var delay_const: float = float(level.get_script().get_script_constant_map().get("FRIDGE_IDLE_DELAY", 0.0))
	print("idle delay=", delay_const, " s")
	if not is_equal_approx(delay_const, 10.0):
		failures.append("idle delay is not 10 s (%.2f)" % delay_const)

	# 10 秒静默: nothing may play before the countdown runs out. Force the level
	# unambiguously idle, hand it a full countdown, and check the animation does
	# not start while the timer is still ticking down.
	level.set("fridge_phase", "idle")
	level.set("fridge_round_choices_pending", false)
	level.set("fridge_round_ending_in_flight", false)
	level.set("fridge_cat_motion", "")
	level.set("fridge_player_is_dragging", false)
	level.set("fridge_idle_suppress", 0.0)
	level.set("fridge_idle_rotation_enabled", true)
	level.call("_stop_fridge_idle_actions")
	level.set("fridge_idle_timer", delay_const)
	await process_frame
	await process_frame
	var waiting_timer: float = float(level.get("fridge_idle_timer"))
	var waiting_active: bool = bool(level_player.call("is_idle_action_active")) \
		or bool(cat.call("is_idle_action_active")) \
		or str(level.get("fridge_cat_motion")) != ""
	print("countdown holds: timer=", snappedf(waiting_timer, 0.01), " active=", waiting_active)
	if waiting_active:
		failures.append("an idle animation started before the idle delay ran out")
	if waiting_timer >= delay_const or waiting_timer <= 0.0:
		failures.append("the idle countdown is not running down from the delay (%.2f)" % waiting_timer)

	level.set("fridge_idle_suppress", 0.0)
	level.set("fridge_idle_rotation_enabled", true)
	level.call("_stop_fridge_idle_actions")
	level.call("_play_fridge_cat_idle_action", "play_ball")
	await process_frame
	var hover_before: bool = bool(cat.call("is_idle_action_active"))
	# The engine drives hover_amount from the cat's own Area2D; a headless run has
	# no real pointer, so set the same value mouse_entered would set. Moving the
	# mouse there is real input, so the input age is fresh at the same time.
	cat.set("hover_amount", 1.0)
	level.set("fridge_idle_input_age", 0.0)
	level.set("fridge_idle_timer", 0.0)
	await process_frame
	await process_frame
	var hover_after: bool = bool(cat.call("is_idle_action_active"))
	var hover_timer: float = float(level.get("fridge_idle_timer"))
	var cat_pose_restored: bool = _is_idle_pose(cat_sprite, cat)
	print("hover cat: before=", hover_before, " after=", hover_after, " default_pose=", cat_pose_restored, " timer=", hover_timer)
	if not hover_before:
		failures.append("hover probe: the cat idle animation did not start")
	if hover_after or not cat_pose_restored:
		failures.append("hovering the cat did not return it to the default idle pose")
	if not is_equal_approx(hover_timer, delay_const):
		failures.append("hovering the cat did not restart the idle pause (%.2f)" % hover_timer)
	# And it stays quiet while the pointer is being moved around / has just landed.
	await process_frame
	await process_frame
	var hover_quiet := not bool(cat.call("is_idle_action_active"))
	print("hover cat stays quiet=", hover_quiet)
	if not hover_quiet:
		failures.append("an idle animation restarted while the pointer was on the cat")

	# 停在那不动不算互动: a cursor simply left RESTING on a character must not keep
	# the rotation suppressed forever - that is exactly what stopped the idle
	# animations from ever playing. With a stale input age the rotation fires here
	# even though the pointer is still sitting on the cat.
	level.set("fridge_idle_input_age", 5.0)
	cat.set("hover_amount", 1.0)
	level.set("fridge_idle_timer", 0.0)
	await process_frame
	await process_frame
	var parked_active: bool = bool(level_player.call("is_idle_action_active")) \
		or bool(cat.call("is_idle_action_active")) \
		or str(level.get("fridge_cat_motion")) != ""
	print("parked pointer: rotation fired=", parked_active)
	if not parked_active:
		failures.append("a pointer resting on a character blocked the idle rotation")
	cat.set("hover_amount", 0.0)

	# 鼠标移到冰箱人身上: same rule. His hover is a rect test inside the level, so
	# aim the real pointer at his body and let that test report it.
	level.call("_stop_fridge_idle_actions")
	level.call("_play_fridge_man_idle_action", "smoke")
	await process_frame
	var man_hover_before: bool = bool(level_player.call("is_idle_action_active"))
	var hit_rect: Rect2 = level.get_script().get_script_constant_map().get("FRIDGE_PLAYER_DRAG_HIT_RECT", Rect2())
	var man_world: Vector2 = level_player.global_transform * hit_rect.get_center()
	get_root().warp_mouse(get_root().get_canvas_transform() * man_world)
	await process_frame
	var man_hovered: bool = bool(level.call("_is_mouse_over_fridge_player"))
	print("hover man: hit_rect=", hit_rect, " probe=", man_hovered, " before=", man_hover_before)
	if man_hovered:
		level.set("fridge_idle_timer", 0.0)
		await process_frame
		await process_frame
		var man_after: bool = bool(level_player.call("is_idle_action_active"))
		var man_timer: float = float(level.get("fridge_idle_timer"))
		print("hover man: after=", man_after, " timer=", man_timer)
		if man_after:
			failures.append("hovering the fridge man did not return him to the default idle pose")
		if not is_equal_approx(man_timer, delay_const):
			failures.append("hovering the fridge man did not restart the idle pause (%.2f)" % man_timer)
	else:
		print("hover man: this run cannot warp the pointer, skipped")

	level.set("fridge_phase", "idle")
	level.call("_stop_fridge_idle_actions")

	# ---------- 打瞌睡: an idle ACTION, for BOTH characters ----------
	# The doze loop (stand a while, nod off with sleep bubbles rising, the bubble
	# pops, wake with a start) is NOT the default stance - the default idle is the
	# calm relaxed breathing loop. One shared FridgeDozeCycle drives both dozes and
	# only the 打瞌睡 action (the skeleton stand's gallery) starts one.
	print("doze cycle: stand=", FridgeDozeCycle.STAND_TIME, " nod=", FridgeDozeCycle.NOD_TIME, " doze=", FridgeDozeCycle.DOZE_TIME, " pop=", FridgeDozeCycle.POP_TIME, " startle=", FridgeDozeCycle.STARTLE_TIME, " total=", FridgeDozeCycle.TOTAL_TIME)
	if FridgeDozeCycle.TOTAL_TIME < 8.0:
		failures.append("the doze cycle is too short to read (%.1f s)" % FridgeDozeCycle.TOTAL_TIME)

	# 大小一致: every doze pose is drawn in its character's idle frame geometry - the same
	# subject height with the feet on the same ground line - so dozing never grows or
	# shrinks either character and the outlines match the idle's art. The man's art is
	# 512px; the cat's is 256px with a 244px-tall subject, every pose measured from the
	# clean front-facing still so each entry carries its own expected height and ground row.
	for art: Array in [
		["res://assets/generated/paper_fridge_doze_v2.png", 502, 510],
		["res://assets/generated/paper_fridge_startle_v2.png", 502, 510],
		["res://assets/generated/cat_doze_cow.png", 244, 255],
		["res://assets/generated/cat_doze_closed_cow.png", 244, 255],
		["res://assets/generated/cat_startle_cow.png", 244, 255],
	]:
		var doze_art: Image = Image.load_from_file(ProjectSettings.globalize_path(str(art[0])))
		if doze_art == null:
			failures.append("missing doze art: %s" % str(art[0]))
			continue
		var doze_rect: Rect2i = doze_art.get_used_rect()
		var doze_bottom: int = doze_rect.position.y + doze_rect.size.y - 1
		print("doze art ", str(art[0]).get_file(), " used_h=", doze_rect.size.y, " bottom=", doze_bottom)
		if absi(doze_rect.size.y - int(art[1])) > 2:
			failures.append("%s is not at the idle's size (%dpx)" % [str(art[0]).get_file(), doze_rect.size.y])
		if absi(doze_bottom - int(art[2])) > 2:
			failures.append("%s does not stand on the idle's ground line (%d)" % [str(art[0]).get_file(), doze_bottom])

	level.set("fridge_idle_rotation_enabled", false)
	level.set("fridge_idle_suppress", 999.0)
	level.call("_stop_fridge_idle_actions")
	await process_frame
	await process_frame

	var man_doze: FridgeDozeCycle = level_player.get("doze") as FridgeDozeCycle
	var cat_doze: FridgeDozeCycle = cat.get("doze") as FridgeDozeCycle
	# Everything above probed the standalone man; the doze assertions below are
	# about the LEVEL's man, so point `anim` at his own sprite.
	anim = level_player.get_node("Sprite") as AnimatedSprite2D
	if man_doze == null or cat_doze == null:
		failures.append("a character has no doze cycle")
	print("doze stand times: man=", man_doze.stand_time, " cat=", cat_doze.stand_time)
	if is_equal_approx(man_doze.stand_time, cat_doze.stand_time):
		failures.append("the two characters nod off in lockstep (both stand %.1f s)" % man_doze.stand_time)
	var man_bubble: Sprite2D = man_doze.get_node_or_null("SleepBubble") as Sprite2D
	var man_small: Sprite2D = man_doze.get_node_or_null("SleepBubbleSmall") as Sprite2D
	var man_pop: Sprite2D = man_doze.get_node_or_null("SleepPop") as Sprite2D
	var cat_bubble: Sprite2D = cat_doze.get_node_or_null("SleepBubble") as Sprite2D
	var cat_pop: Sprite2D = cat_doze.get_node_or_null("SleepPop") as Sprite2D
	var bubble_art_ok: bool = man_bubble != null and man_bubble.texture != null and man_bubble.texture.get_width() == 256 \
		and man_pop != null and man_pop.texture != null and man_pop.texture.get_width() == 256
	print("doze effects: bubble=", man_bubble != null, " small=", man_small != null, " pop=", man_pop != null, " art256=", bubble_art_ok)
	if man_bubble == null or man_small == null or man_pop == null or cat_bubble == null or cat_pop == null:
		failures.append("the doze cycle is missing its bubble / pop effects")
	if not bubble_art_ok:
		failures.append("the sleep bubble / pop art did not load")

	# The plain standing idle must NOT doze: nobody nods off unless the 打瞌睡
	# action is the thing running.
	level_player.call("_update_doze", 0.0)
	cat.call("_update_doze", 0.0)
	print("doze in the plain idle: man=", man_doze.is_enabled(), " cat=", cat_doze.is_enabled(), " bubble=", man_bubble.visible)
	if man_doze.is_enabled() or cat_doze.is_enabled():
		failures.append("a character dozes off as its default idle again")
	if man_bubble.visible or man_pop.visible or cat_bubble.visible:
		failures.append("doze effects showed while nobody was dozing")

	# Ask both to doze, the way the skeleton stand's gallery does.
	level.call("_on_fridge_gallery_entry_pressed", "man_doze")
	level.call("_on_fridge_gallery_entry_pressed", "cat_doze")
	await process_frame
	print("doze action: man=", level_player.get("idle_action_id"), " cat=", cat.get("idle_action_id"), " cycles=", man_doze.is_enabled(), "/", cat_doze.is_enabled())
	if str(level_player.get("idle_action_id")) != FridgePomodoroPlayer.DOZE_ACTION_ID or str(cat.get("idle_action_id")) != FridgeCatPet.DOZE_ACTION_ID:
		failures.append("the gallery's 打瞌睡 entries did not start the doze action")
	if not man_doze.is_enabled() or not cat_doze.is_enabled():
		failures.append("the doze cycle did not start when its action did")

	# 立即播放: a doze that was ASKED for nods off at once instead of standing around
	# first (which used to be 3.2 s for the man and 6.6 s for the cat, and read as the
	# click having failed). The phases below are advanced by the cycle's OWN stand
	# time, so the arc is walked correctly however long that stand now is.
	print("requested doze stand times: man=", man_doze.stand_time, " cat=", cat_doze.stand_time)
	if man_doze.stand_time > 0.5 or cat_doze.stand_time > 0.5:
		failures.append("a requested doze still stands around first (man=%.2f cat=%.2f)" % [man_doze.stand_time, cat_doze.stand_time])

	# --- fridge man: the whole doze arc, phase by phase ---
	man_doze.reset()
	man_doze.tick(man_doze.stand_time + 0.01)
	level_player.call("_update_doze", 0.0)
	var man_nod_anim := anim.animation
	print("doze man: phase=", man_doze.phase, " anim=", man_nod_anim, " bubble=", man_bubble.visible, " small=", man_small.visible)
	if man_doze.phase != FridgeDozeCycle.PHASE_NOD or man_nod_anim != FridgePomodoroPlayer.DOZE_ANIMATION_NAME:
		failures.append("the man does not nod off on his own (phase=%s anim=%s)" % [man_doze.phase, man_nod_anim])
	if not man_bubble.visible:
		failures.append("no sleep bubble appeared while the man nodded off")

	man_doze.tick(FridgeDozeCycle.NOD_TIME + 0.01)
	level_player.call("_update_doze", 0.0)
	var man_sag: float = float(level_player.get("doze_body_offset").y)
	print("doze man: phase=", man_doze.phase, " anim=", anim.animation, " sag=", man_sag, " small=", man_small.visible)
	if man_doze.phase != FridgeDozeCycle.PHASE_DOZE or anim.animation != FridgePomodoroPlayer.DOZE_ANIMATION_NAME:
		failures.append("the man did not fall asleep")
	if man_sag <= 0.0:
		failures.append("the man does not sag while he sleeps")

	man_doze.tick(FridgeDozeCycle.DOZE_TIME + 0.01)
	level_player.call("_update_doze", 0.0)
	print("doze man: phase=", man_doze.phase, " anim=", anim.animation, " pop=", man_pop.visible)
	if man_doze.phase != FridgeDozeCycle.PHASE_POP or not man_pop.visible:
		failures.append("the man's sleep bubble did not pop")

	man_doze.tick(FridgeDozeCycle.POP_TIME + 0.01)
	level_player.call("_update_doze", 0.0)
	print("doze man: phase=", man_doze.phase, " anim=", anim.animation)
	if man_doze.phase != FridgeDozeCycle.PHASE_STARTLE or anim.animation != FridgePomodoroPlayer.STARTLE_ANIMATION_NAME:
		failures.append("the man did not wake with a start")

	man_doze.tick(FridgeDozeCycle.STARTLE_TIME + 0.01)
	level_player.call("_update_doze", 0.0)
	print("doze man: phase=", man_doze.phase, " anim=", anim.animation, " bubble=", man_bubble.visible, " pop=", man_pop.visible)
	if man_doze.phase != FridgeDozeCycle.PHASE_STAND or anim.animation != FridgePomodoroPlayer.IDLE_ANIMATION_NAME:
		failures.append("the man did not settle back into the plain idle")
	if man_bubble.visible or man_pop.visible:
		failures.append("the doze effects stayed on screen after the man woke up")
	if not is_zero_approx(float(level_player.get("doze_body_offset").y)):
		failures.append("the man stayed sagged after waking up")

	# --- cat: the same arc with its own art ---
	cat_doze.reset()
	cat_doze.tick(cat_doze.stand_time + 0.01)
	cat.call("_update_doze", 0.0)
	var cat_doze_tex: Texture2D = cat.get("doze_texture") as Texture2D
	var cat_startle_tex: Texture2D = cat.get("startle_texture") as Texture2D
	print("doze cat: phase=", cat_doze.phase, " doze_art=", cat_sprite.texture == cat_doze_tex, " bubble=", cat_bubble.visible, " drop=", cat.get("idle_action_drop"))
	if cat_doze.phase != FridgeDozeCycle.PHASE_NOD or cat_sprite.texture != cat_doze_tex:
		failures.append("the cat does not nod off on its own")
	if not cat_bubble.visible:
		failures.append("no sleep bubble appeared while the cat nodded off")
	if not is_zero_approx(float(cat.get("idle_action_drop"))):
		failures.append("the cat's doze pose is resized at runtime")

	cat_doze.tick(FridgeDozeCycle.NOD_TIME + 0.01)
	cat.call("_update_doze", 0.0)
	print("doze cat: phase=", cat_doze.phase, " sag=", cat.get("doze_body_offset"))
	if cat_doze.phase != FridgeDozeCycle.PHASE_DOZE:
		failures.append("the cat did not fall asleep")

	cat_doze.tick(FridgeDozeCycle.DOZE_TIME + 0.01)
	cat.call("_update_doze", 0.0)
	print("doze cat: phase=", cat_doze.phase, " pop=", cat_pop.visible)
	if cat_doze.phase != FridgeDozeCycle.PHASE_POP or not cat_pop.visible:
		failures.append("the cat's sleep bubble did not pop")

	cat_doze.tick(FridgeDozeCycle.POP_TIME + 0.01)
	cat.call("_update_doze", 0.0)
	print("doze cat: phase=", cat_doze.phase, " startle_art=", cat_sprite.texture == cat_startle_tex)
	if cat_doze.phase != FridgeDozeCycle.PHASE_STARTLE or cat_sprite.texture != cat_startle_tex:
		failures.append("the cat did not wake with a start")

	cat_doze.tick(FridgeDozeCycle.STARTLE_TIME + 0.01)
	cat.call("_update_doze", 0.0)
	print("doze cat: phase=", cat_doze.phase, " idle_art=", cat_sprite.texture == cat_idle_texture, " bubble=", cat_bubble.visible)
	if cat_doze.phase != FridgeDozeCycle.PHASE_STAND or cat_sprite.texture != cat_idle_texture:
		failures.append("the cat did not settle back into the plain idle")
	if cat_bubble.visible or cat_pop.visible:
		failures.append("the doze effects stayed on screen after the cat woke up")

	# The doze ends with its action and must not restart on its own.
	level_player.call("stop_idle_action")
	cat.call("stop_idle_action")
	level_player.call("stop_performances")
	await process_frame
	await process_frame
	print("doze after the action ended: man=", man_doze.is_enabled(), " cat=", cat_doze.is_enabled(), " phases=", man_doze.phase, "/", cat_doze.phase, " anim=", anim.animation)
	if man_doze.is_enabled() or cat_doze.is_enabled():
		failures.append("the doze kept running after its action ended")
	if man_doze.phase != FridgeDozeCycle.PHASE_STAND or cat_doze.phase != FridgeDozeCycle.PHASE_STAND:
		failures.append("the doze did not park back at a calm stand when it ended")
	if man_bubble.visible or man_pop.visible or cat_bubble.visible:
		failures.append("the doze effects stayed on screen after its action ended")
	if anim.animation != FridgePomodoroPlayer.IDLE_ANIMATION_NAME:
		failures.append("the man did not return to the plain stand after the doze")
	if not _is_idle_pose(cat_sprite, cat):
		failures.append("the cat did not return to the plain standing idle after the doze")

	# Something else owning a character still pauses the doze.
	level_player.call("play_idle_action", "smoke", 1.0)
	cat.call("play_idle_action", "play_ball", 1.0)
	level_player.call("_update_doze", 0.0)
	cat.call("_update_doze", 0.0)
	print("doze paused by other actions: man=", not man_doze.is_enabled(), " cat=", not cat_doze.is_enabled())
	if man_doze.is_enabled() or cat_doze.is_enabled():
		failures.append("another idle action did not pause the doze")
	if not is_zero_approx(float(level_player.get("doze_body_offset").y)):
		failures.append("the doze offset stayed applied while another animation ran")
	level_player.call("stop_idle_action")
	cat.call("stop_idle_action")
	level_player.call("stop_performances")
	await process_frame
	await process_frame

	# ---------- the default idle: a relaxed breathing loop, not a zoom ----------
	# The old idle strip only scaled the character up and down across its three
	# frames. The new one is assembled from separate poses normalised onto one
	# frame geometry, so every frame is the SAME size with the feet on the same
	# ground line, and only the pose moves.
	# The cat's atlas is 256px frames since its art was regenerated from the cow-cat base,
	# while the man's is still 512px, so each atlas carries its own frame size.
	# 244px is the cat subject's own height: every pose is placed from the clean
	# front-facing still with the feet on row 255, so the ears are never clipped at the
	# top of the frame and the breathing is free to move the chest inside that margin.
	for atlas_info: Array in [
		["res://assets/generated/paper_fridge_idle_relaxed.png", 3, 502, "man", 512],
		["res://assets/generated/cat_idle_cow.png", 6, 244, "cat", 256],
	]:
		var atlas_path := str(atlas_info[0])
		var atlas_img: Image = Image.load_from_file(ProjectSettings.globalize_path(atlas_path))
		if atlas_img == null:
			failures.append("missing relaxed idle atlas: %s" % atlas_path)
			continue
		var frame_size := int(atlas_info[4])
		var atlas_count := int(float(atlas_img.get_width()) / float(frame_size))
		var heights: Array = []
		var bottoms: Array = []
		for i in atlas_count:
			var region: Image = atlas_img.get_region(Rect2i(i * frame_size, 0, frame_size, frame_size))
			var rr: Rect2i = region.get_used_rect()
			heights.append(rr.size.y)
			bottoms.append(rr.position.y + rr.size.y - 1)
		print(str(atlas_info[3]), " idle atlas frames=", atlas_count, " heights=", heights, " ground=", bottoms)
		if atlas_count != int(atlas_info[1]):
			failures.append("%s has %d frames, expected %d" % [atlas_path.get_file(), atlas_count, int(atlas_info[1])])
		# The cat's frames differ by a few px - its breathing moves the chest/tail tip, so the
		# bbox is not bit-identical. A real art-size bug (e.g. the 190px sleeping ball leaking
		# into the idle) is far larger than this tolerance.
		for h in heights:
			if absi(int(h) - int(atlas_info[2])) > 6:
				failures.append("%s frame height %s is not the idle's ~%dpx" % [atlas_path.get_file(), str(h), int(atlas_info[2])])
		for b in bottoms:
			if absi(int(b) - int(bottoms[0])) > 1:
				failures.append("%s frames do not share one ground line" % atlas_path.get_file())

	var man_idle_frames: int = anim.sprite_frames.get_frame_count(FridgePomodoroPlayer.IDLE_ANIMATION_NAME)
	print("man idle animation frames=", man_idle_frames, " fps=", anim.sprite_frames.get_animation_speed(FridgePomodoroPlayer.IDLE_ANIMATION_NAME))
	if man_idle_frames != 3:
		failures.append("the man's idle is no longer the 3-frame relaxed loop (%d)" % man_idle_frames)
	if absf(anim.sprite_frames.get_animation_speed(FridgePomodoroPlayer.IDLE_ANIMATION_NAME) - 2.0) > 0.01:
		failures.append("the man's idle no longer breathes slowly")

	# The cat steps its own loop in code; the frame is a pure function of its clock.
	# Probed over one full lap plus the wrap, so the check adapts to however many
	# poses the idle art carries instead of pinning one count.
	var cat_idle_frames: Array = cat.call("_get_idle_action_frames", "rest_stand")
	var probe_times: Array = []
	var stepped: Array = []
	for i in range(cat_idle_frames.size() + 1):
		probe_times.append(float(i) / FridgeCatPet.IDLE_ANIMATION_FPS)
	for probe_t in probe_times:
		cat.set("time", float(probe_t))
		cat.call("_update_idle_animation")
		stepped.append(cat_idle_frames.find(cat_sprite.texture))
	var expected: Array = []
	for i in range(cat_idle_frames.size()):
		expected.append(i)
	expected.append(0)
	print("cat idle stepping -> frames ", stepped, " of ", cat_idle_frames.size())
	if stepped != expected:
		failures.append("the cat's standing idle does not step through its frames (%s, expected %s)" % [str(stepped), str(expected)])

	level.set("fridge_coin_count", save_coins)
	level.set("fridge_active_item_id", save_active_item)
	level.call("_save_fridge_progress")

	for failure in failures:
		print("FAILURE: ", failure)
	print("IDLE_ANIMATION_TEST=", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	level.queue_free()
	player.queue_free()
	await process_frame
	quit(0)