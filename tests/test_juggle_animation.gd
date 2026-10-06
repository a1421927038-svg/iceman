extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var script: GDScript = load("res://scripts/FridgePomodoroPlayer.gd")
	var player: Node = script.new()
	get_root().add_child(player)
	await process_frame
	await process_frame

	var anim: AnimatedSprite2D = player.get_node("Sprite") as AnimatedSprite2D
	var sf: SpriteFrames = anim.sprite_frames
	print("has intro=", sf.has_animation("tomato_intro"))
	print("has juggle=", sf.has_animation("tomato_juggle"), " frames=", sf.get_frame_count("tomato_juggle"), " loop=", sf.get_animation_loop("tomato_juggle"))
	for i in sf.get_frame_count("tomato_juggle"):
		var tex: Texture2D = sf.get_frame_texture("tomato_juggle", i)
		var region := Rect2()
		if tex is AtlasTexture:
			region = (tex as AtlasTexture).region
		print("  juggle frame ", i, " tex=", tex != null, " region=", region)

	# Entering a juggle preview must go STRAIGHT to the juggle loop (no intro).
	player.call("play_juggle_preview", 5.0)
	await process_frame
	var after_juggle: String = anim.animation
	print("after juggle preview: anim=", after_juggle, " visible_objects=", _count_visible(player))
	player.call("play_rest_preview", 5.0)
	await process_frame
	print("after rest preview: anim=", anim.animation, " visible_objects=", _count_visible(player))
	player.call("stop_performances")
	await process_frame
	var after_stop: String = anim.animation
	print("after stop: anim=", after_stop)

	var ok := not sf.has_animation("tomato_intro") and sf.get_frame_count("tomato_juggle") == 4 and after_juggle == "tomato_juggle" and after_stop == "idle"
	print("JUGGLE_ANIM_TEST=", "PASS" if ok else "FAIL")

	player.queue_free()
	await process_frame
	quit(0)


func _count_visible(player: Node) -> int:
	var n := 0
	for child in player.get_children():
		if child is Sprite2D and (child as Sprite2D).visible:
			n += 1
	return n