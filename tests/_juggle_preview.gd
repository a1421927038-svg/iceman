extends Node2D

# Temporary preview harness: shows FridgePomodoroPlayer juggling so the
# regenerated juggle animation can be eyeballed without click/drag quirks.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.97, 0.955, 0.78)
	bg.position = Vector2(-576.0, -324.0)
	bg.size = Vector2(1152.0, 648.0)
	add_child(bg)

	var cam := Camera2D.new()
	cam.enabled = true
	cam.position = Vector2.ZERO
	add_child(cam)

	var player: Node = load("res://scripts/FridgePomodoroPlayer.gd").new()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.call("play_juggle_preview", 60.0)