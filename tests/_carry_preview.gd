extends Node2D

## Throwaway preview of FridgeLevel on its own (it used to place the carried notebook +
## briefcase; the 手持 feature has since been removed, so all this does is show the level).

var level: Node


func _ready() -> void:
	level = load("res://scenes/FridgeLevel.tscn").instantiate()
	add_child(level)