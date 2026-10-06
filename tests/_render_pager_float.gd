extends SceneTree

## Renders the pager reaction's float beat offscreen and saves it as a PNG, so the
## composite (lifted character + levitating device) can be eyeballed without
## launching the game into the editor's Game tab.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(460, 560)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	get_root().add_child(vp)

	var player: Node = load("res://scripts/FridgePomodoroPlayer.gd").new()
	vp.add_child(player)
	player.position = Vector2(230, 430)
	await process_frame
	await process_frame

	player.call("play_pager_reaction")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3650:
		await process_frame
	for i in 3:
		await process_frame

	var device: Sprite2D = player.get("pager_device_sprite") as Sprite2D
	print("render at float: active=", player.get("pager_reaction_active"),
		" device_visible=", device.visible, " device_pos=", device.position)
	var img: Image = vp.get_texture().get_image()
	var distinct := {}
	for i in 400:
		var px := img.get_pixel(i * 7 % img.get_width(), i * 13 % img.get_height())
		distinct[px.to_rgba32()] = true
	print("image=", img.get_width(), "x", img.get_height(), " distinct_sampled_colours=", distinct.size())
	var path := ProjectSettings.globalize_path("res://tests/_pager_float_render.png")
	var err := img.save_png(path)
	print("saved=", path, " err=", err)
	quit(0)