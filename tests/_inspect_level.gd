extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/FridgeLevel.tscn")
	var level: Node = packed.instantiate()
	get_root().add_child(level)
	for i in 4:
		await process_frame
	var world: Node = level.get_node_or_null("World")
	if world == null:
		print("no World node")
		quit(0)
		return
	print("World children: ", world.get_child_count())
	for child in world.get_children():
		var pos := Vector2.ZERO
		var vis := true
		if child is Node2D:
			pos = (child as Node2D).global_position
			vis = (child as Node2D).visible
		print("  ", child.name, " type=", child.get_class(), " pos=", pos, " visible=", vis, " class=", child.get_script().resource_path if child.get_script() != null else "none")
		if child.name == "ActionSkeletonStand":
			var spr := child.get_node_or_null("Sprite") as Sprite2D
			if spr == null:
				# list its children
				for c in child.get_children():
					var t := ""
					if c is Sprite2D and (c as Sprite2D).texture != null:
						t = str((c as Sprite2D).texture.get_size())
					print("     child: ", c.name, " ", c.get_class(), " tex_size=", t)
			else:
				print("     Sprite texture=", spr.texture, " size=", spr.texture.get_size() if spr.texture != null else Vector2.ZERO)
	level.queue_free()
	await process_frame
	quit(0)