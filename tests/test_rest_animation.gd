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

	# 2. Devil (left) button: replay the juggle performance.
	scene.call("_on_fridge_round_choice_selected", "devil")
	await process_frame
	if not bool(player.get("juggling")):
		failures.append("devil choice should start juggling")
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
	scene.call("_on_fridge_round_choice_selected", "devil")
	await process_frame
	if player.get_node_or_null("RoundChoiceRoot") != null:
		failures.append("choice buttons should hide while the replay plays")
	player.set("juggle_preview_timer", 0.05)
	for i in 10:
		await process_frame
	if bool(player.get("juggling")):
		failures.append("juggle preview should have expired")
	if player.get_node_or_null("RoundChoiceRoot") == null:
		failures.append("choice buttons should pop up again after the replay ends")

	# 7. The re-shown buttons must still work: pick angel, let rest expire.
	scene.call("_on_fridge_round_choice_selected", "angel")
	player.set("rest_preview_timer", 0.05)
	for i in 10:
		await process_frame
	if bool(player.get("resting")):
		failures.append("rest preview should have expired")
	if player.get_node_or_null("RoundChoiceRoot") == null:
		failures.append("choice buttons should pop up again after rest ends")
	if not bool(scene.get("fridge_round_choices_pending")):
		failures.append("choice flow should stay armed while looping")

	# 8. Starting a session from the re-shown buttons cancels the loop.
	scene.call("_start_fridge_session")
	await process_frame
	if bool(scene.get("fridge_round_choices_pending")):
		failures.append("new session should cancel the choice loop")
	if player.get_node_or_null("RoundChoiceRoot") != null:
		failures.append("choice buttons should be gone after session start")

	if failures.is_empty():
		print("ALL_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures:
			print("TEST_FAIL: ", failure)
		quit(1)
