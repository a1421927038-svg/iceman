extends SceneTree

## Throwaway probe (test-only): opens the prop box headlessly and reports what ART each cell actually
## holds - the entry's icon path, the icon node's texture size and the mean colour of that texture -
## plus the sizes of the four item arts themselves, so a cell can be matched back to its source image.

var save_coins := 0
var save_active := ""
var save_owned: Array = []


func _init() -> void:
	var level: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	root.add_child(level)
	for i in range(8):
		await process_frame
	level.set("fridge_idle_rotation_enabled", false)
	save_coins = int(level.get("fridge_coin_count"))
	save_active = str(level.get("fridge_active_item_id"))
	save_owned = (level.get("fridge_owned_items") as Array).duplicate()
	level.call("_on_fridge_box_toggled", true)
	for i in range(10):
		await process_frame
	var panel: Node = level.get("fridge_box_panel")
	print("active=", panel.call("get_active_action"))
	print("selected=", panel.call("get_selected"))
	var cards: Dictionary = panel.get("_cards")
	print("cards=", cards.keys())
	var icons: Dictionary = panel.get("_icons")
	var info: Dictionary = panel.get("_entry_info")
	for id: String in cards.keys():
		var entry: Dictionary = info.get(id, {})
		print("card ", id, " entry_icon=", entry.get("icon", "<none>"))
		var icon: TextureRect = icons.get(id, null)
		if icon == null or icon.texture == null:
			print("   <no icon node/texture>")
			continue
		var texture: Texture2D = icon.texture
		print("   texture class=", texture.get_class(), " size=", texture.get_size())
		var image: Image = texture.get_image()
		if image != null and image.get_width() > 0 and image.get_height() > 0:
			var c: Color = image.get_pixel(image.get_width() / 2, image.get_height() / 2)
			print("   centre pixel=", c)
	print("--- the four item arts on their own ---")
	for path: String in [
		"res://assets/generated/paper_tomato_projectile.png",
		"res://assets/generated/paper_juggle_ball.png",
		"res://assets/generated/paper_icon_spray_text.png",
		"res://assets/generated/paper_icon_spray_bubble.png",
	]:
		var texture: Texture2D = load(path)
		if texture == null:
			print(path, " MISSING")
			continue
		var image: Image = texture.get_image()
		var centre := Color(0, 0, 0, 0)
		if image != null and image.get_width() > 0:
			centre = image.get_pixel(image.get_width() / 2, image.get_height() / 2)
		print(path.get_file(), " size=", texture.get_size(), " centre=", centre)
	level.set("fridge_coin_count", save_coins)
	level.set("fridge_active_item_id", save_active)
	level.set("fridge_owned_items", save_owned)
	level.call("_save_fridge_progress")
	level.queue_free()
	await process_frame
	print("PROBE_DONE")
	quit()