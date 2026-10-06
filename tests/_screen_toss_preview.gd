extends Node2D
## TEMPORARY harness: starts a juggle, then fires the 打破第四面墙 screen-toss ending so the
## rush at the camera can be photographed. Not part of the game.

const LEVEL_SCENE := preload("res://scenes/FridgeLevel.tscn")
const JUGGLE_FRAME := 40
const TOSS_FRAME := 55

var level: Node
var frame := 0
var tossed := false


func _ready() -> void:
	level = LEVEL_SCENE.instantiate()
	add_child(level)


func _process(_delta: float) -> void:
	frame += 1
	var player: Node = level.get("fridge_player")
	if player == null:
		return
	if not tossed and frame == JUGGLE_FRAME:
		player.call("play_juggle_preview", 30.0)
	if not tossed and frame >= TOSS_FRAME:
		tossed = true
		player.call("play_screen_toss_ending")