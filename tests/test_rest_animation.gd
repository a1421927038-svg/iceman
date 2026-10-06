extends SceneTree

func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	# Let the tree iterate so the level's _ready/_process actually run.
	await process_frame
	await process_frame

	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# The devil choice runs real rounds, which really pay out; keep the player's
	# own save state (coins + active item) intact.
	var save_coins: int = int(scene.get("fridge_coin_count"))
	var save_active_item: String = str(scene.get("fridge_active_item_id"))

	var player: Node = scene.get("fridge_player")
	if player == null:
		print("TEST_FAIL player not found")
		quit(1)
		return

	var failures: Array[String] = []
	var animated_sprite: AnimatedSprite2D = player.get_node_or_null("Sprite") as AnimatedSprite2D
	var sprite_frames: SpriteFrames = animated_sprite.sprite_frames

	# 1. The rest animation must be registered with ping-pong frames.
	if not sprite_frames.has_animation("pomodoro_rest"):
		failures.append("rest animation missing from SpriteFrames")
	elif sprite_frames.get_frame_count("pomodoro_rest") != 4:
		failures.append("rest animation should have 4 ping-pong frames, has %d" % sprite_frames.get_frame_count("pomodoro_rest"))

	# 2. Devil (left) button: run another round with the same item, so a tomato
	#    round makes the fridge man juggle.
	var owned_items: Array = scene.get("fridge_owned_items")
	if not owned_items.has("tomato"):
		owned_items.append("tomato")
	scene.set("fridge_active_item_id", "tomato")
	scene.call("_on_fridge_round_choice_selected", "devil")
	await process_frame
	if not bool(player.get("juggling")):
		failures.append("devil choice should start the item's own performance (tomato juggles)")
	if bool(player.get("resting")):
		failures.append("devil choice should not rest")

	# 3. Angel (right) button: play the rest animation, replacing the juggle.
	scene.call("_on_fridge_round_choice_selected", "angel")
	await process_frame
	if not bool(player.get("resting")):
		failures.append("angel choice should start resting")
	if bool(player.get("juggling")):
		failures.append("angel choice should stop juggling")
	if animated_sprite.animation != "pomodoro_rest":
		failures.append("resting should play pomodoro_rest, plays %s" % animated_sprite.animation)
	for object_sprite in player.get("juggle_objects"):
		if (object_sprite as Sprite2D).visible:
			failures.append("juggle objects should be hidden while resting")
			break

	# 4. Starting a new session must clear any performance.
	scene.set("fridge_phase", "idle")
	scene.set("fridge_player_juggling", false)
	player.call("play_rest_preview", 8.0)
	scene.call("_start_fridge_session")
	await process_frame
	if bool(player.get("resting")) or bool(player.get("juggling")):
		failures.append("session start should stop performances")
	if str(scene.get("fridge_phase")) != "work":
		failures.append("session should be running after start")
	if bool(scene.get("fridge_round_choices_pending")):
		failures.append("session start should cancel the choice flow")

	# 5. Play both previews directly through the player API as well.
	player.call("stop_performances")
	player.call("play_juggle_preview", 2.0)
	if not bool(player.get("juggling")):
		failures.append("play_juggle_preview failed")
	player.call("play_rest_preview", 2.0)
	if not bool(player.get("resting")) or bool(player.get("juggling")):
		failures.append("play_rest_preview should replace juggle")

	# 6. After the work countdown ends, the head buttons must pop up again
	#    once the chosen replay performance finishes (choice flow loop).
	scene.set("fridge_phase", "idle")
	scene.call("_show_fridge_round_choices")
	if not bool(scene.get("fridge_round_choices_pending")):
		failures.append("_show_fridge_round_choices should arm the choice flow")
	if player.get_node_or_null("RoundChoiceRoot") == null:
		failures.append("choice buttons missing after round completion")
	if not owned_items.has("cassette"):
		owned_items.append("cassette")
	scene.set("fridge_player_juggling", false)
	scene.set("fridge_active_item_id", "cassette")
	scene.call("_on_fridge_round_choice_selected", "devil")
	await process_frame
	if player.get_node_or_null("RoundChoiceRoot") != null:
		failures.append("choice buttons should hide while the replay plays")
	if str(scene.get("fridge_phase")) != "work":
		failures.append("devil choice should run one more round")
	if str(scene.get("fridge_active_item_id")) != "cassette":
		failures.append("devil choice should keep the previous item")
	if float(scene.get("fridge_time_left")) <= 0.0:
		failures.append("devil choice should start a fresh countdown")
	# Winding that countdown out must bring the two buttons back.
	scene.set("fridge_time_left", 0.05)
	scene.call("_update_fridge_pomodoro", 0.1)
	for i in 3:
		await process_frame
	if player.get_node_or_null("RoundChoiceRoot") == null:
		failures.append("choice buttons should pop up again after the round ends")

	# 7. Picking angel (right) ENDS the loop: once the rest expires the fridge man
	#    is back to idle and the choice buttons stay gone.
	scene.call("_on_fridge_round_choice_selected", "angel")
	player.set("rest_preview_timer", 0.05)
	for i in 10:
		await process_frame
	if bool(player.get("resting")):
		failures.append("rest preview should have expired")
	if player.get_node_or_null("RoundChoiceRoot") != null:
		failures.append("angel should end the sequence (buttons must be gone)")
	if bool(scene.get("fridge_round_choices_pending")):
		failures.append("angel should clear the pending flag")

	# 7b. When a juggle work countdown ends, the 打破第四面墙 screen-toss ending plays
	#     first (the last objects rush the camera) and the round choices appear only
	#     once it finishes.
	scene.set("fridge_phase", "work")
	scene.set("fridge_player_juggling", true)
	scene.set("fridge_time_left", 0.0)
	scene.call("_update_fridge_pomodoro", 0.016)
	await process_frame
	if not (bool(scene.get("fridge_round_ending_in_flight")) and bool(player.get("screen_toss_active"))):
		failures.append("round end while juggling should play the screen-toss ending")
	if player.get_node_or_null("RoundChoiceRoot") != null:
		failures.append("choice buttons must wait for the ending")
	var drop_guard := 0
	while bool(player.get("screen_toss_active")) and drop_guard < 600:
		await process_frame
		drop_guard += 1
	for i in 3:
		await process_frame
	if player.get_node_or_null("RoundChoiceRoot") == null:
		failures.append("choice buttons should appear after the ending")

	# 8. Starting a session from the re-shown buttons cancels the loop.
	scene.call("_start_fridge_session")
	await process_frame
	if bool(scene.get("fridge_round_choices_pending")):
		failures.append("new session should cancel the choice loop")
	if player.get_node_or_null("RoundChoiceRoot") != null:
		failures.append("choice buttons should be gone after session start")

	scene.set("fridge_coin_count", save_coins)
	scene.set("fridge_active_item_id", save_active_item)
	scene.call("_save_fridge_progress")

	if failures.is_empty():
		print("ALL_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures:
			print("TEST_FAIL: ", failure)
		quit(1)
