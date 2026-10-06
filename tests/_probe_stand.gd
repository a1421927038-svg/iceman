extends SceneTree

## Harness: how the notebook prop and the briefcase are actually drawn.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var stand: Node = scene.get("fridge_gallery_stand")
	print("stand: visible=", stand.visible, " in_tree=", stand.is_visible_in_tree(),
		" open=", stand.get("is_open"), " art=", stand.get("art_texture_path"),
		" pos=", stand.global_position, " modulate=", stand.modulate)
	_report(stand)
	var box: Node = scene.get("fridge_box")
	print("box: visible=", box.visible, " open=", box.get("is_open"))
	_report(box)
	print("hidden_state=", scene.get("fridge_props_hidden"),
		" player=", scene.get("fridge_player").global_position)
	print("--- after the stand's own open path ---")
	scene.call("_on_fridge_gallery_stand_toggled", true)
	await process_frame
	print("stand: visible=", stand.visible, " open=", stand.get("is_open"))
	_report(stand)
	print("gallery panel visible=", scene.get("fridge_gallery_panel").visible,
		" pos=", scene.get("fridge_gallery_panel").position,
		" size=", scene.get("fridge_gallery_panel").size,
		" active=", scene.get("fridge_gallery_panel").call("get_active_tab"))
	quit()


func _report(node: Node) -> void:
	for child in node.get_children():
		var line := "   %s (%s) visible=%s" % [str(child.name), child.get_class(), str(child.visible)]
		if child is Node2D:
			line += " pos=%s scale=%s z=%d modulate=%s" % [str(child.position), str(child.scale),
				child.z_index, str(child.modulate)]
		if child is Sprite2D:
			line += " tex=%s" % ("null" if child.texture == null else str(child.texture.get_size()))
		print(line)
		for grand in child.get_children():
			var sub := "      %s (%s) visible=%s" % [str(grand.name), grand.get_class(), str(grand.visible)]
			if grand is Sprite2D:
				sub += " tex=%s scale=%s" % ["null" if grand.texture == null else str(grand.texture.get_size()),
					str(grand.scale)]
			print(sub)