extends SceneTree

## Throwaway probe: how tall does one gallery card really come out, and how tall is the
## scroll viewport it has to live in? Prints the numbers so the card/icon sizes can be
## pinned instead of guessed.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/FridgeLevel.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var panel: Node = scene.get("fridge_gallery_panel")
	scene.call("_on_fridge_gallery_stand_toggled", true)
	await process_frame
	await process_frame
	var scroll: ScrollContainer = panel.find_child("EntryScroll", true, false)
	var grid: GridContainer = null
	for node in panel.find_children("", "GridContainer", true, false):
		grid = node as GridContainer
	print("scroll rect      = ", scroll.get_rect())
	if grid != null:
		print("grid children    = ", grid.get_child_count(), " grid rect=", grid.get_rect())
		for card in grid.get_children():
			var c: Control = card as Control
			var parts := PackedStringArray()
			for child in c.get_children():
				for grand in child.get_children():
					parts.append("%s=%s" % [grand.name, str((grand as Control).get_rect().size)])
			print("  card ", c.name, " size=", c.size,
				" min=", c.get_combined_minimum_size(), " ", " ".join(parts))
	print("CARDS_PROBE_DONE")
	scene.queue_free()
	await process_frame
	quit(0)