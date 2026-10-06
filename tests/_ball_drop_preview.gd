extends Node2D

# Temporary preview harness: loops the FridgePomodoroPlayer ball-to-the-face
# ending so it can be eyeballed without any click/drag quirks.

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
	while true:
		player.call("play_ball_drop_ending")
		await get_tree().create_timer(2.0).timeout