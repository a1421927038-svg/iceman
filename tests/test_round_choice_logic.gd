extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/FridgeLevel.tscn")
	if packed == null:
		print("ROUND_CHOICE_TEST=FAIL (scene missing)")
		quit(1)
		return
	var level: Node = packed.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	# These rounds really run, so they really pay out; keep the player's own save
	# state (coins + active item) intact.
	var save_coins: int = int(level.get("fridge_coin_count"))
	var save_active_item: String = str(level.get("fridge_active_item_id"))

	# --- devil (left) runs one more round with the SAME item: that item's own
	#     animation plays for the whole countdown, and the buttons come back when
	#     the countdown ends (the devil loops)
	var owned: Array = level.get("fridge_owned_items")
	if not owned.has("pager"):
		owned.append("pager")
	level.set("fridge_active_item_id", "pager")
	level.call("_show_fridge_round_choices")
	await process_frame
	var shown_devil: bool = level.get("fridge_round_choice_root") != null and bool(level.get("fridge_round_choices_pending"))
	level.call("_on_fridge_round_choice_selected", "devil")
	await process_frame
	var cleared_on_pick: bool = level.get("fridge_round_choice_root") == null
	var devil_phase := str(level.get("fridge_phase"))
	var devil_countdown := float(level.get("fridge_time_left"))
	var devil_player: Node = level.get("fridge_player")
	var devil_anim: AnimatedSprite2D = devil_player.get("animated_sprite") as AnimatedSprite2D
	var devil_performs := bool(devil_player.get("pager_reaction_active")) and devil_anim.animation == "pager_react"
	# wind the countdown out: the buttons must come back
	level.set("fridge_time_left", 0.05)
	level.call("_update_fridge_pomodoro", 0.1)
	await process_frame
	var devil_reshows: bool = level.get("fridge_round_choice_root") != null and bool(level.get("fridge_round_choices_pending"))
	print("devil: shown=", shown_devil, " cleared_on_pick=", cleared_on_pick, " phase=", devil_phase,
		" countdown=", snappedf(devil_countdown, 0.1), " item_anim=", devil_anim.animation,
		" performs=", devil_performs, " reshows=", devil_reshows)

	# --- angel (right) must END the sequence: back to idle, buttons stay gone
	level.call("_on_fridge_round_choice_selected", "angel")
	await process_frame
	level.call("_on_fridge_performance_finished")
	await process_frame
	await process_frame
	var angel_root_gone: bool = level.get("fridge_round_choice_root") == null
	var angel_pending_off: bool = not bool(level.get("fridge_round_choices_pending"))
	# the level's player should be standing idle again (no performance previews left)
	var player: Node = level.get("fridge_player")
	var player_idle := true
	if player != null and is_instance_valid(player):
		player_idle = float(player.get("rest_preview_timer")) <= 0.0 and float(player.get("juggle_preview_timer")) <= 0.0
	print("angel: root_gone=", angel_root_gone, " pending_off=", angel_pending_off, " player_idle=", player_idle)

	var ok: bool = shown_devil and cleared_on_pick and devil_reshows and angel_root_gone and angel_pending_off and player_idle
	ok = ok and devil_phase == "work" and devil_countdown > 1.0 and devil_performs
	print("ROUND_CHOICE_TEST=", "PASS" if ok else "FAIL")

	level.set("fridge_coin_count", save_coins)
	level.set("fridge_active_item_id", save_active_item)
	level.call("_save_fridge_progress")
	level.queue_free()
	await process_frame
	quit(0)