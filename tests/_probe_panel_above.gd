extends SceneTree

## 正上方 probe: the notebook's book panel and the briefcase's prop box panel must sit DIRECTLY ABOVE
## their own prop and FOLLOW it, so a moved prop is never covered by the UI it opened.
## The prop's art is measured INDEPENDENTLY here (the union of its visible sprite children) rather
## than through the level's own helper, and each prop is moved twice: a normal nudge, and up to the
## top of the screen where no room is left above it - where the panel must hang BELOW the prop
## instead of covering it. Every case also checks the panel is still fully on screen.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	scene.set("fridge_idle_rotation_enabled", false)

	var ok := true

	# ---- the notebook's book panel ----
	scene.call("_on_fridge_gallery_stand_toggled", true)
	await process_frame
	await process_frame
	ok = _check(scene, "book home") and ok
	ok = _nudge(scene, "fridge_gallery_stand", Vector2(-240.0, 150.0), "book moved") and ok
	var stand: Node2D = scene.get("fridge_gallery_stand") as Node2D
	stand.global_position = Vector2(stand.global_position.x, -200.0)
	await process_frame
	await process_frame
	ok = _check(scene, "book dragged to the top") and ok
	scene.call("_on_fridge_gallery_stand_toggled", false)
	await process_frame

	# ---- the briefcase's prop box panel ----
	scene.call("_on_fridge_box_toggled", true)
	await process_frame
	await process_frame
	ok = _check(scene, "box home") and ok
	ok = _nudge(scene, "fridge_box", Vector2(180.0, 90.0), "box moved") and ok
	var box: Node2D = scene.get("fridge_box") as Node2D
	box.global_position = Vector2(box.global_position.x, -180.0)
	await process_frame
	await process_frame
	ok = _check(scene, "box dragged to the top") and ok

	print("PANEL_ABOVE_PROBE=", "PASS" if ok else "FAIL")
	scene.queue_free()
	await process_frame
	quit()


func _nudge(scene: Node, prop_var: String, delta: Vector2, label: String) -> bool:
	var prop: Node2D = scene.get(prop_var) as Node2D
	if prop != null:
		prop.global_position += delta
	return _check(scene, label)


func _check(scene: Node, label: String) -> bool:
	var book_side := label.begins_with("book")
	var panel: Control = scene.get("fridge_gallery_panel" if book_side else "fridge_box_panel") as Control
	var prop: Node2D = scene.get("fridge_gallery_stand" if book_side else "fridge_box") as Node2D
	if panel == null or prop == null or not panel.visible:
		print(label, ": MISSING prop=", prop != null, " panel=", panel != null)
		return false
	var screen: Vector2 = get_root().get_viewport().get_visible_rect().size
	var panel_rect: Rect2 = panel.get_global_rect()
	var art := _art_rect(prop)
	var measured: bool = art.size != Vector2.ZERO
	var overlaps: bool = measured and panel_rect.intersects(art)
	var above: bool = measured and panel_rect.end.y <= art.position.y + 0.5
	var below: bool = measured and panel_rect.position.y >= art.end.y - 0.5
	var on_screen: bool = screen.x > 0.0 and panel_rect.position.x >= -0.5 and panel_rect.end.x <= screen.x + 0.5
	var centre_dx: float = absf(panel_rect.get_center().x - art.get_center().x) if measured else -1.0
	print(label, ": prop=", prop.global_position, " art=", art, " panel=", panel_rect,
		" above=", above, " below=", below, " overlaps=", overlaps,
		" centre_dx=", centre_dx, " on_screen=", on_screen)
	if not measured or overlaps or not on_screen:
		return false
	return above or below


## The prop's drawn art, measured HERE (never through the level's own helper): the union of every
## visible sprite child. Sprite2D has NO get_global_rect(), so each rect is rebuilt from the global
## transform + the texture size + the node's own offset/centered flags.
func _art_rect(prop: Node2D) -> Rect2:
	var rect := Rect2()
	var found := false
	for node: Node in prop.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite == null or sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var r := _sprite_rect(sprite, sprite.texture, sprite.offset, sprite.centered)
		rect = r if not found else rect.merge(r)
		found = true
	for node: Node in prop.find_children("*", "AnimatedSprite2D", true, false):
		var anim := node as AnimatedSprite2D
		if anim == null or anim.sprite_frames == null or not anim.is_visible_in_tree():
			continue
		var frame_texture: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		if frame_texture == null:
			continue
		var r := _sprite_rect(anim, frame_texture, anim.offset, anim.centered)
		rect = r if not found else rect.merge(r)
		found = true
	if not found:
		return Rect2()
	# the panels live in SCREEN space, so the measured art must be pushed through the same camera
	# transform the level's own helper uses - otherwise an "above" test compares two spaces.
	var canvas: Transform2D = get_root().get_viewport().get_canvas_transform()
	return Rect2(canvas * rect.position, rect.size)


func _sprite_rect(node: Node2D, texture: Texture2D, offset: Vector2, centered: bool) -> Rect2:
	var transform := node.get_global_transform()
	var art_scale: Vector2 = transform.get_scale()
	var size: Vector2 = texture.get_size() * art_scale
	var top_left: Vector2 = transform.origin - offset * art_scale
	if centered:
		top_left -= size * 0.5
	return Rect2(top_left, size)