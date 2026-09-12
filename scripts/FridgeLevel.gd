class_name FridgeLevel
extends Node2D

## 「冰箱人」关卡 —— 从 Arts 项目（scripts/Game.gd）中提取的独立关卡。
## 原版在关卡选择大厅（carousel）里通过冰箱门进入本关，离开时回到大厅；
## 这里作为独立场景运行，因此去掉了大厅与其它关卡，退出按钮改为“重新进入本关”。

const DoorScript := preload("res://scripts/Door.gd")
const LevelVisualScript := preload("res://scripts/LevelVisual.gd")
const FridgePomodoroPlayerScript := preload("res://scripts/FridgePomodoroPlayer.gd")
const FridgeCatPetScript := preload("res://scripts/FridgeCatPet.gd")
const FridgeMouthInventoryPanelScript := preload("res://scripts/FridgeMouthInventoryPanel.gd")
const FridgeRoundChoiceScript := preload("res://scripts/FridgeRoundChoice.gd")
const FridgeItemIconScript := preload("res://scripts/FridgeItemIcon.gd")
const FridgeYarnBallScript := preload("res://scripts/FridgeYarnBall.gd")
const CoinPriceButtonScript := preload("res://scripts/CoinPriceButton.gd")

const LEVEL_ID := "fridge_people"
const LEVEL_NAME := "冰箱人"
const LEVEL_COLOR := Color(0.42, 0.76, 0.96)

const FRIDGE_SAVE_PATH := "user://fridge_people_save.json"
const FRIDGE_DEFAULT_WORK_DURATION := 18.0
const FRIDGE_DEFAULT_BREAK_DURATION := 4.0
const FRIDGE_DEFAULT_REWARD_COINS := 5
const FRIDGE_DEFAULT_VARIANT_ID := "tomato"
const FRIDGE_ITEMS := [
	{"id": "tomato", "name": "番茄钟", "price": 0, "reward": 5, "variant_id": "tomato", "free": true, "description": "基础待机动画"},
	{"id": "cassette", "name": "磁带机", "price": 5, "reward": 5, "variant_id": "cassette", "description": "磁带转动待机"},
	{"id": "pager", "name": "寻呼机", "price": 10, "reward": 10, "variant_id": "pager", "description": "屏幕闪烁待机"},
	{"id": "walkman", "name": "随身听", "price": 15, "reward": 15, "variant_id": "walkman", "description": "耳机律动待机"},
	{"id": "crt", "name": "显像管电视", "price": 20, "reward": 20, "variant_id": "crt", "description": "扫描线待机"},
	{"id": "vhs", "name": "录像带", "price": 25, "reward": 25, "variant_id": "vhs", "description": "胶带循环待机"},
]

const FRIDGE_ESCAPE_POSITION := Vector2(500.0, -235.0)
const FRIDGE_CAT_POSITION := Vector2(250.0, 190.0)
const FRIDGE_ESCAPE_HIT_RECT := Rect2(-54.0, -54.0, 108.0, 108.0)
const FRIDGE_PLAYER_DRAG_HIT_RECT := Rect2(-118.0, -286.0, 236.0, 344.0)
const FRIDGE_TOOLBAR_SIZE := Vector2(380.0, 380.0)
const FRIDGE_SETTINGS_SIZE := Vector2(250.0, 238.0)
const FRIDGE_YARN_PILE_SIZE := Vector2(260.0, 160.0)

var world: Node2D
var camera: Camera2D
var is_changing_scene := false

var fridge_overlay: CanvasLayer
var fridge_overlay_root: Control
var fridge_item_panel: PanelContainer
var fridge_settings_panel: PanelContainer
var fridge_coin_label: Label
var fridge_status_label: Label
var fridge_timer_label: Label
var fridge_reward_label: Label
var fridge_reset_button: Button
var fridge_round_choice_root: Node2D
var fridge_shop_list: VBoxContainer
var fridge_yarn_pile: Control
var fridge_yarn_balls: Array[Control] = []
var fridge_item_widgets: Dictionary = {}
var fridge_work_duration_spin: SpinBox
var fridge_break_duration_spin: SpinBox
var fridge_coin_popups: Array[Dictionary] = []
var fridge_dragged_panel: Control
var fridge_drag_offset := Vector2.ZERO
var fridge_dragged_yarn_ball: Control
var fridge_yarn_drag_offset := Vector2.ZERO
var fridge_yarn_drag_origin_parent: Node
var fridge_yarn_drag_origin_position := Vector2.ZERO
var fridge_yarn_drag_release_velocity := Vector2.ZERO
var fridge_item_panel_has_manual_position := false
var fridge_settings_panel_has_manual_position := false
var fridge_player_is_dragging := false
var fridge_player_drag_offset := Vector2.ZERO
var fridge_player: Node2D
var fridge_cat_pet: Node2D
var fridge_coin_count := 0
var fridge_owned_items: Array[String] = [FRIDGE_DEFAULT_VARIANT_ID]
var fridge_active_item_id := FRIDGE_DEFAULT_VARIANT_ID
var fridge_phase := "idle"
var fridge_time_left := 0.0
var fridge_pulse := 0.0
var fridge_work_duration := FRIDGE_DEFAULT_WORK_DURATION
var fridge_break_duration := FRIDGE_DEFAULT_BREAK_DURATION


func _ready() -> void:
	set_process(true)
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	camera = Camera2D.new()
	camera.name = "TopDownCamera"
	camera.position = Vector2.ZERO
	camera.enabled = true
	add_child(camera)

	_build_level()


func _process(delta: float) -> void:
	if fridge_overlay == null or not is_instance_valid(fridge_overlay):
		return
	_position_fridge_popups()
	_update_fridge_yarn_pile(delta)
	_update_fridge_coin_popups(delta)
	_update_fridge_pomodoro(delta)


func _input(event: InputEvent) -> void:
	if _handle_fridge_yarn_drag(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_fridge_panel_drag(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_fridge_player_drag(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_mouse_over_fridge_escape():
			_on_return_door_clicked(LEVEL_ID)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_return_door_clicked(LEVEL_ID)


func _build_level() -> void:
	_clear_world()
	_clear_overlay()
	_reset_fridge_runtime()

	var visual := LevelVisualScript.new()
	visual.setup(LEVEL_ID, LEVEL_COLOR)
	world.add_child(visual)

	var exit_door := DoorScript.new()
	exit_door.name = "ReturnDoor"
	exit_door.position = FRIDGE_ESCAPE_POSITION
	exit_door.z_index = 3000
	exit_door.setup("hub", "", "Emergency Exit", Color(0.12, 0.62, 0.34), true)
	exit_door.clicked.connect(_on_return_door_clicked)
	world.add_child(exit_door)

	_load_fridge_progress()
	_spawn_fridge_player()
	_spawn_fridge_cat_pet()
	_create_fridge_overlay()
	_refresh_fridge_ui()
	is_changing_scene = false


func _spawn_fridge_player() -> void:
	fridge_player = FridgePomodoroPlayerScript.new()
	fridge_player.name = "Player"
	fridge_player.global_position = Vector2(0.0, 170.0)
	world.add_child(fridge_player)


func _spawn_fridge_cat_pet() -> void:
	fridge_cat_pet = FridgeCatPetScript.new()
	fridge_cat_pet.name = "FridgeCatPet"
	fridge_cat_pet.global_position = FRIDGE_CAT_POSITION
	fridge_cat_pet.clicked.connect(_on_fridge_cat_pet_clicked)
	world.add_child(fridge_cat_pet)


func _clear_world() -> void:
	if world == null:
		return
	for child in world.get_children():
		child.queue_free()
	fridge_player = null
	fridge_cat_pet = null
	fridge_round_choice_root = null


func _on_return_door_clicked(_level_id: String) -> void:
	if is_changing_scene:
		return
	_save_fridge_progress()
	is_changing_scene = true
	call_deferred("_build_level")


func _on_fridge_cat_pet_clicked() -> void:
	_show_fridge_item_toolbar()


func _clear_overlay() -> void:
	if fridge_overlay != null and is_instance_valid(fridge_overlay):
		fridge_overlay.queue_free()
	fridge_overlay = null
	fridge_overlay_root = null
	fridge_item_panel = null
	fridge_settings_panel = null
	fridge_coin_label = null
	fridge_status_label = null
	fridge_timer_label = null
	fridge_reward_label = null
	fridge_reset_button = null
	_clear_fridge_round_choices()
	fridge_shop_list = null
	fridge_yarn_pile = null
	fridge_yarn_balls.clear()
	fridge_work_duration_spin = null
	fridge_break_duration_spin = null
	fridge_item_widgets.clear()
	fridge_coin_popups.clear()
	fridge_dragged_panel = null
	fridge_drag_offset = Vector2.ZERO
	fridge_dragged_yarn_ball = null
	fridge_yarn_drag_offset = Vector2.ZERO
	fridge_yarn_drag_origin_parent = null
	fridge_yarn_drag_origin_position = Vector2.ZERO
	fridge_yarn_drag_release_velocity = Vector2.ZERO
	fridge_item_panel_has_manual_position = false
	fridge_settings_panel_has_manual_position = false
	fridge_player_is_dragging = false
	fridge_player_drag_offset = Vector2.ZERO


func _create_fridge_overlay() -> void:
	_clear_overlay()

	fridge_overlay = CanvasLayer.new()
	fridge_overlay.name = "FridgeOverlay"
	fridge_overlay.layer = 20
	add_child(fridge_overlay)

	fridge_overlay_root = Control.new()
	fridge_overlay_root.name = "Root"
	fridge_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fridge_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fridge_overlay.add_child(fridge_overlay_root)

	_create_fridge_item_toolbar()
	_create_fridge_settings_panel()
	_position_fridge_popups()


func _create_fridge_panel_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	return style


func _create_fridge_item_toolbar() -> void:
	fridge_item_panel = FridgeMouthInventoryPanelScript.new()
	fridge_item_panel.name = "ItemToolbar"
	fridge_item_panel.visible = false
	fridge_item_panel.size = FRIDGE_TOOLBAR_SIZE
	fridge_item_panel.custom_minimum_size = FRIDGE_TOOLBAR_SIZE
	fridge_item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var transparent_style := StyleBoxEmpty.new()
	transparent_style.content_margin_left = 60.0
	transparent_style.content_margin_top = 110.0
	transparent_style.content_margin_right = 60.0
	transparent_style.content_margin_bottom = 50.0
	fridge_item_panel.add_theme_stylebox_override("panel", transparent_style)
	fridge_overlay_root.add_child(fridge_item_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	fridge_item_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(Callable(self, "_on_fridge_panel_drag_handle_input").bind(fridge_item_panel, "item"))
	content.add_child(header)

	var title := Label.new()
	title.text = "猫嘴背包"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	header.add_child(title)

	fridge_coin_label = Label.new()
	fridge_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fridge_coin_label.add_theme_font_size_override("font_size", 12)
	fridge_coin_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
	header.add_child(fridge_coin_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "关闭"
	close_button.custom_minimum_size = Vector2(24.0, 24.0)
	close_button.pressed.connect(_on_fridge_item_toolbar_close_pressed)
	header.add_child(close_button)

	fridge_yarn_pile = Control.new()
	fridge_yarn_pile.name = "YarnPile"
	fridge_yarn_pile.custom_minimum_size = FRIDGE_YARN_PILE_SIZE
	fridge_yarn_pile.size = FRIDGE_YARN_PILE_SIZE
	fridge_yarn_pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fridge_yarn_pile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fridge_yarn_pile.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(fridge_yarn_pile)

	for i in FRIDGE_ITEMS.size():
		_create_fridge_yarn_ball(FRIDGE_ITEMS[i], i)

	call_deferred("_scatter_fridge_yarn_balls")


func _create_fridge_settings_panel() -> void:
	fridge_settings_panel = PanelContainer.new()
	fridge_settings_panel.name = "PomodoroSettings"
	fridge_settings_panel.visible = false
	fridge_settings_panel.size = FRIDGE_SETTINGS_SIZE
	fridge_settings_panel.custom_minimum_size = FRIDGE_SETTINGS_SIZE
	fridge_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	fridge_settings_panel.add_theme_stylebox_override("panel", _create_fridge_panel_style(Color(0.08, 0.08, 0.09, 0.78)))
	fridge_overlay_root.add_child(fridge_settings_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	fridge_settings_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(Callable(self, "_on_fridge_panel_drag_handle_input").bind(fridge_settings_panel, "settings"))
	content.add_child(header)

	var title := Label.new()
	title.text = "番茄钟设置"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "关闭"
	close_button.custom_minimum_size = Vector2(30.0, 30.0)
	close_button.pressed.connect(_on_fridge_settings_close_pressed)
	header.add_child(close_button)

	fridge_timer_label = Label.new()
	fridge_timer_label.add_theme_font_size_override("font_size", 15)
	content.add_child(fridge_timer_label)

	fridge_status_label = Label.new()
	fridge_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fridge_status_label.add_theme_font_size_override("font_size", 13)
	content.add_child(fridge_status_label)

	fridge_reward_label = Label.new()
	fridge_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fridge_reward_label.add_theme_font_size_override("font_size", 12)
	content.add_child(fridge_reward_label)

	var work_row := HBoxContainer.new()
	work_row.add_theme_constant_override("separation", 8)
	content.add_child(work_row)
	var work_label := Label.new()
	work_label.text = "专注秒数"
	work_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work_row.add_child(work_label)
	fridge_work_duration_spin = SpinBox.new()
	fridge_work_duration_spin.min_value = 5.0
	fridge_work_duration_spin.max_value = 3600.0
	fridge_work_duration_spin.step = 5.0
	fridge_work_duration_spin.value = fridge_work_duration
	fridge_work_duration_spin.custom_minimum_size = Vector2(82.0, 0.0)
	fridge_work_duration_spin.value_changed.connect(_on_fridge_work_duration_changed)
	work_row.add_child(fridge_work_duration_spin)

	var break_row := HBoxContainer.new()
	break_row.add_theme_constant_override("separation", 8)
	content.add_child(break_row)
	var break_label := Label.new()
	break_label.text = "休息秒数"
	break_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	break_row.add_child(break_label)
	fridge_break_duration_spin = SpinBox.new()
	fridge_break_duration_spin.min_value = 2.0
	fridge_break_duration_spin.max_value = 1800.0
	fridge_break_duration_spin.step = 2.0
	fridge_break_duration_spin.value = fridge_break_duration
	fridge_break_duration_spin.custom_minimum_size = Vector2(82.0, 0.0)
	fridge_break_duration_spin.value_changed.connect(_on_fridge_break_duration_changed)
	break_row.add_child(fridge_break_duration_spin)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	content.add_child(action_row)

	fridge_reset_button = Button.new()
	fridge_reset_button.text = "重置"
	fridge_reset_button.pressed.connect(_on_fridge_reset_pressed)
	action_row.add_child(fridge_reset_button)


func _create_fridge_yarn_ball(item: Dictionary, index: int) -> void:
	if fridge_yarn_pile == null:
		return

	var item_id := str(item.get("id", ""))
	var item_name := str(item.get("name", item_id))
	var ball := FridgeYarnBallScript.new()
	ball.name = "%sYarnBall" % item_id.capitalize()
	ball.setup(item_id, item_name, true, _get_fridge_item_reward(item_id))
	ball.pressed_for_drag.connect(_on_fridge_yarn_ball_pressed)
	ball.unlock_requested.connect(_on_fridge_item_unlock_pressed)
	fridge_yarn_pile.add_child(ball)
	fridge_yarn_balls.append(ball)

	var centers := [
		Vector2(28.0, 35.0),
		Vector2(68.0, 24.0),
		Vector2(108.0, 36.0),
		Vector2(150.0, 25.0),
		Vector2(190.0, 38.0),
		Vector2(90.0, 72.0),
	]
	var center: Vector2 = centers[index % centers.size()]
	if index >= centers.size():
		center += Vector2((float(index) / float(centers.size())) * 12.0, 0.0)
	ball.call("set_center_position", center)
	ball.call("set_velocity", Vector2(24.0 + float(index % 3) * 9.0, -18.0 + float(index % 2) * 12.0))

	fridge_item_widgets[item_id] = {
		"ball": ball,
	}


func _create_fridge_shop_row(item: Dictionary) -> void:
	if fridge_shop_list == null:
		return

	var item_id := str(item.get("id", ""))
	var row_panel := PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	row_style.corner_radius_top_left = 5
	row_style.corner_radius_top_right = 5
	row_style.corner_radius_bottom_left = 5
	row_style.corner_radius_bottom_right = 5
	row_style.content_margin_left = 5
	row_style.content_margin_top = 4
	row_style.content_margin_right = 5
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", row_style)
	fridge_shop_list.add_child(row_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row_panel.add_child(row)

	var item_icon := FridgeItemIconScript.new()
	item_icon.setup(item_id, true)
	item_icon.custom_minimum_size = Vector2(42.0, 42.0)
	item_icon.activated.connect(_on_fridge_item_icon_pressed)
	row.add_child(item_icon)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.add_theme_constant_override("separation", 1)
	row.add_child(info_column)

	var name_label := Label.new()
	name_label.text = str(item.get("name", item_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	info_column.add_child(name_label)

	var duration_label := Label.new()
	duration_label.text = "倒计时：%s" % _format_fridge_duration(fridge_work_duration)
	duration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	duration_label.add_theme_font_size_override("font_size", 10)
	duration_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	info_column.add_child(duration_label)

	var description_label := Label.new()
	description_label.text = "说明：%s" % str(item.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 9)
	description_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.82, 0.86))
	info_column.add_child(description_label)

	var controls := VBoxContainer.new()
	controls.custom_minimum_size = Vector2(54.0, 0.0)
	controls.add_theme_constant_override("separation", 4)
	row.add_child(controls)

	var price_button := CoinPriceButtonScript.new()
	price_button.tooltip_text = "点击解锁"
	price_button.custom_minimum_size = Vector2(52.0, 26.0)
	price_button.pressed.connect(Callable(self, "_on_fridge_item_unlock_pressed").bind(item_id))
	controls.add_child(price_button)

	fridge_item_widgets[item_id] = {
		"icon": item_icon,
		"price_button": price_button,
		"name_label": name_label,
		"duration_label": duration_label,
		"description_label": description_label,
		"row_panel": row_panel,
	}


func _load_fridge_progress() -> void:
	var default_state := {
		"coins": 0,
		"owned_items": [FRIDGE_DEFAULT_VARIANT_ID],
		"active_item_id": FRIDGE_DEFAULT_VARIANT_ID,
		"work_duration": FRIDGE_DEFAULT_WORK_DURATION,
		"break_duration": FRIDGE_DEFAULT_BREAK_DURATION,
	}

	if not FileAccess.file_exists(FRIDGE_SAVE_PATH):
		_apply_fridge_progress(default_state)
		return

	var file := FileAccess.open(FRIDGE_SAVE_PATH, FileAccess.READ)
	if file == null:
		_apply_fridge_progress(default_state)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_apply_fridge_progress(default_state)
		return

	_apply_fridge_progress(parsed)


func _apply_fridge_progress(data: Dictionary) -> void:
	fridge_coin_count = int(data.get("coins", 0))
	if fridge_coin_count < 0:
		fridge_coin_count = 0
	fridge_owned_items = _normalize_fridge_owned_items(data.get("owned_items", []))
	fridge_active_item_id = str(data.get("active_item_id", FRIDGE_DEFAULT_VARIANT_ID))
	if not fridge_owned_items.has(fridge_active_item_id):
		fridge_active_item_id = FRIDGE_DEFAULT_VARIANT_ID
	if not fridge_owned_items.has(FRIDGE_DEFAULT_VARIANT_ID):
		fridge_owned_items.append(FRIDGE_DEFAULT_VARIANT_ID)
	if fridge_active_item_id == "":
		fridge_active_item_id = FRIDGE_DEFAULT_VARIANT_ID
	fridge_work_duration = clamp(float(data.get("work_duration", FRIDGE_DEFAULT_WORK_DURATION)), 5.0, 3600.0)
	fridge_break_duration = clamp(float(data.get("break_duration", FRIDGE_DEFAULT_BREAK_DURATION)), 2.0, 1800.0)


func _normalize_fridge_owned_items(value: Variant) -> Array[String]:
	var owned: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var item_id := str(item).strip_edges()
			if item_id == "":
				continue
			if _get_fridge_item_record(item_id).is_empty():
				continue
			if not owned.has(item_id):
				owned.append(item_id)
	if not owned.has(FRIDGE_DEFAULT_VARIANT_ID):
		owned.insert(0, FRIDGE_DEFAULT_VARIANT_ID)
	return owned


func _save_fridge_progress() -> void:
	var data := {
		"version": 1,
		"coins": fridge_coin_count,
		"owned_items": fridge_owned_items,
		"active_item_id": fridge_active_item_id,
		"work_duration": fridge_work_duration,
		"break_duration": fridge_break_duration,
	}
	var file := FileAccess.open(FRIDGE_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))


func _refresh_fridge_ui() -> void:
	if fridge_player != null and is_instance_valid(fridge_player):
		fridge_player.call("set_active_item", fridge_active_item_id)
		fridge_player.call("set_pomodoro_state", fridge_phase, _get_fridge_phase_progress(), _format_fridge_time(fridge_time_left))

	if fridge_coin_label != null:
		fridge_coin_label.text = "%d 金币" % fridge_coin_count

	if fridge_reward_label != null:
		fridge_reward_label.text = "完成一次专注奖励 %d 金币。" % _get_fridge_active_reward()

	if fridge_reset_button != null:
		fridge_reset_button.disabled = fridge_phase == "idle"

	if fridge_timer_label != null:
		if fridge_phase == "idle":
			fridge_timer_label.text = "待机：%s" % _get_fridge_item_name(fridge_active_item_id)
		else:
			fridge_timer_label.text = "%s：%s" % [_get_fridge_phase_label(fridge_phase), _format_fridge_time(fridge_time_left)]

	if fridge_status_label != null:
		var active_name := _get_fridge_item_name(fridge_active_item_id)
		fridge_status_label.text = "当前道具：%s。%s" % [active_name, _get_fridge_phase_hint()]

	if fridge_work_duration_spin != null:
		fridge_work_duration_spin.editable = fridge_phase == "idle"
		fridge_work_duration_spin.value = fridge_work_duration

	if fridge_break_duration_spin != null:
		fridge_break_duration_spin.editable = fridge_phase == "idle"
		fridge_break_duration_spin.value = fridge_break_duration

	for item: Dictionary in FRIDGE_ITEMS:
		var item_id := str(item.get("id", ""))
		var widgets: Variant = fridge_item_widgets.get(item_id, {})
		if not widgets is Dictionary:
			continue
		var ball := widgets.get("ball") as Control
		var icon := widgets.get("icon") as Control
		var price_button := widgets.get("price_button") as Button
		var name_label := widgets.get("name_label") as Label
		var duration_label := widgets.get("duration_label") as Label
		var description_label := widgets.get("description_label") as Label
		var row_panel := widgets.get("row_panel") as PanelContainer
		var price := int(item.get("price", 0))
		var reward := _get_fridge_item_reward(item_id)
		var unlocked := fridge_owned_items.has(item_id)
		var is_active := fridge_active_item_id == item_id
		if ball != null:
			ball.call("set_state", unlocked, is_active, fridge_phase == "idle", reward)
		if icon != null:
			icon.call("set_state", unlocked, is_active)
		if price_button != null:
			price_button.call("setup_price", reward, unlocked, fridge_phase == "idle" and price <= fridge_coin_count)
		if name_label != null:
			name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90) if unlocked else Color(0.62, 0.62, 0.62))
		if duration_label != null:
			duration_label.text = "倒计时：%s" % _format_fridge_duration(fridge_work_duration)
			duration_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28) if unlocked else Color(0.56, 0.56, 0.56))
		if description_label != null:
			description_label.text = "说明：%s" % str(item.get("description", ""))
			description_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.82, 0.86) if unlocked else Color(0.50, 0.50, 0.50, 0.80))
		if row_panel != null:
			row_panel.modulate = Color.WHITE if unlocked else Color(0.58, 0.58, 0.58, 0.88)


func _update_fridge_pomodoro(delta: float) -> void:
	if fridge_phase != "idle":
		fridge_time_left -= delta
		if fridge_time_left < 0.0:
			fridge_time_left = 0.0
		if fridge_time_left <= 0.0:
			if fridge_phase == "work":
				var reward := _get_fridge_active_reward()
				fridge_coin_count += reward
				_show_fridge_coin_popup(reward)
				fridge_phase = "idle"
				fridge_time_left = 0.0
				_save_fridge_progress()
				_show_fridge_round_choices()
			elif fridge_phase == "break":
				fridge_phase = "idle"
				fridge_time_left = 0.0
				_save_fridge_progress()

	fridge_pulse += delta
	_refresh_fridge_ui()


func _start_fridge_session() -> void:
	if fridge_phase != "idle":
		return
	_clear_fridge_round_choices()
	fridge_phase = "work"
	fridge_time_left = fridge_work_duration
	_refresh_fridge_ui()


func _show_fridge_round_choices() -> void:
	_clear_fridge_round_choices()
	if fridge_player == null or not is_instance_valid(fridge_player):
		return

	fridge_round_choice_root = Node2D.new()
	fridge_round_choice_root.name = "RoundChoiceRoot"
	fridge_round_choice_root.position = Vector2(0.0, -382.0)
	fridge_round_choice_root.z_index = 120
	fridge_player.add_child(fridge_round_choice_root)

	var devil := FridgeRoundChoiceScript.new()
	devil.name = "DevilContinue"
	devil.position = Vector2(-68.0, 0.0)
	devil.setup("devil", "res://assets/generated/paper_round_choice_devil.png")
	devil.selected.connect(_on_fridge_round_choice_selected)
	fridge_round_choice_root.add_child(devil)

	var angel := FridgeRoundChoiceScript.new()
	angel.name = "AngelPause"
	angel.position = Vector2(68.0, 0.0)
	angel.setup("angel", "res://assets/generated/paper_round_choice_angel.png")
	angel.selected.connect(_on_fridge_round_choice_selected)
	fridge_round_choice_root.add_child(angel)

	var tween := create_tween()
	fridge_round_choice_root.scale = Vector2(0.65, 0.65)
	fridge_round_choice_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tween.parallel().tween_property(fridge_round_choice_root, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fridge_round_choice_root, "modulate:a", 1.0, 0.14)


func _clear_fridge_round_choices() -> void:
	if fridge_round_choice_root != null and is_instance_valid(fridge_round_choice_root):
		fridge_round_choice_root.queue_free()
	fridge_round_choice_root = null


func _on_fridge_round_choice_selected(choice_id: String) -> void:
	_clear_fridge_round_choices()
	match choice_id:
		"devil":
			_start_fridge_session()
		"angel":
			fridge_phase = "idle"
			fridge_time_left = 0.0
			_save_fridge_progress()
			_refresh_fridge_ui()
		_:
			pass


func _reset_fridge_session() -> void:
	_reset_fridge_runtime()
	_refresh_fridge_ui()


func _reset_fridge_runtime() -> void:
	fridge_phase = "idle"
	fridge_time_left = 0.0
	_clear_fridge_round_choices()


func _on_fridge_reset_pressed() -> void:
	_reset_fridge_session()


func _on_fridge_work_duration_changed(value: float) -> void:
	if fridge_phase != "idle":
		return
	fridge_work_duration = clamp(value, 5.0, 3600.0)
	_save_fridge_progress()
	_refresh_fridge_ui()


func _on_fridge_break_duration_changed(value: float) -> void:
	if fridge_phase != "idle":
		return
	fridge_break_duration = clamp(value, 2.0, 1800.0)
	_save_fridge_progress()
	_refresh_fridge_ui()


func _show_fridge_item_toolbar() -> void:
	if fridge_item_panel == null:
		return
	fridge_item_panel_has_manual_position = false
	fridge_item_panel.visible = true
	fridge_item_panel.pivot_offset = Vector2(FRIDGE_TOOLBAR_SIZE.x * 0.5, FRIDGE_TOOLBAR_SIZE.y - 26.0)
	fridge_item_panel.scale = Vector2(0.18, 0.18)
	if fridge_cat_pet != null and is_instance_valid(fridge_cat_pet):
		fridge_cat_pet.call("set_bag_open", true)
	_scatter_fridge_yarn_balls()
	_position_fridge_popups()
	_refresh_fridge_ui()
	var tween := create_tween()
	tween.tween_property(fridge_item_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_fridge_item_toolbar_close_pressed() -> void:
	if fridge_dragged_yarn_ball != null:
		_return_fridge_yarn_ball_to_pile(fridge_dragged_yarn_ball, false)
		fridge_dragged_yarn_ball = null
	if fridge_item_panel != null:
		fridge_item_panel.visible = false
		fridge_item_panel.scale = Vector2.ONE
	if fridge_cat_pet != null and is_instance_valid(fridge_cat_pet):
		fridge_cat_pet.call("set_bag_open", false)
	if fridge_dragged_panel == fridge_item_panel:
		fridge_dragged_panel = null


func _on_fridge_settings_close_pressed() -> void:
	if fridge_settings_panel != null:
		fridge_settings_panel.visible = false
	if fridge_dragged_panel == fridge_settings_panel:
		fridge_dragged_panel = null


func _show_fridge_settings_panel(item_id: String = "") -> void:
	if fridge_settings_panel == null:
		return
	if item_id != "" and fridge_owned_items.has(item_id) and fridge_phase == "idle":
		fridge_active_item_id = item_id
		_save_fridge_progress()
	fridge_settings_panel_has_manual_position = false
	fridge_settings_panel.visible = true
	_position_fridge_popups()
	_refresh_fridge_ui()


func _on_fridge_item_icon_pressed(item_id: String) -> void:
	_start_fridge_item_from_inventory(item_id)


func _start_fridge_item_from_inventory(item_id: String) -> void:
	if not fridge_owned_items.has(item_id):
		return
	if fridge_phase != "idle":
		return
	fridge_active_item_id = item_id
	_save_fridge_progress()
	_refresh_fridge_ui()
	_start_fridge_session()


func _on_fridge_yarn_ball_pressed(ball: Control, pointer_offset: Vector2) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if fridge_phase != "idle":
		return
	if fridge_overlay_root == null or fridge_yarn_pile == null:
		return

	fridge_dragged_yarn_ball = ball
	fridge_yarn_drag_offset = pointer_offset
	fridge_yarn_drag_origin_parent = ball.get_parent()
	fridge_yarn_drag_origin_position = ball.position
	fridge_yarn_drag_release_velocity = Vector2.ZERO
	var global_position_before_drag := ball.global_position
	if fridge_yarn_drag_origin_parent != null:
		fridge_yarn_drag_origin_parent.remove_child(ball)
	fridge_overlay_root.add_child(ball)
	ball.global_position = global_position_before_drag
	ball.z_index = 2500
	ball.call("set_dragging_visual", true)


func _handle_fridge_yarn_drag(event: InputEvent) -> bool:
	if fridge_dragged_yarn_ball == null or not is_instance_valid(fridge_dragged_yarn_ball):
		fridge_dragged_yarn_ball = null
		return false

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		fridge_dragged_yarn_ball.global_position = get_viewport().get_mouse_position() - fridge_yarn_drag_offset
		fridge_yarn_drag_release_velocity = mouse_motion.relative * 8.0
		return true

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			var dragged_ball := fridge_dragged_yarn_ball
			var item_id := str(dragged_ball.call("get_item_id"))
			var dropped_outside := not (_get_fridge_yarn_mouth_global_rect().has_point(dragged_ball.global_position + dragged_ball.size * 0.5))
			_return_fridge_yarn_ball_to_pile(dragged_ball, not dropped_outside)
			fridge_dragged_yarn_ball = null

			if dropped_outside and fridge_owned_items.has(item_id) and fridge_phase == "idle":
				if fridge_item_panel != null:
					fridge_item_panel.visible = false
					fridge_item_panel.scale = Vector2.ONE
				if fridge_cat_pet != null and is_instance_valid(fridge_cat_pet):
					fridge_cat_pet.call("set_bag_open", false)
				_start_fridge_item_from_inventory(item_id)
			return true

	return false


func _return_fridge_yarn_ball_to_pile(ball: Control, keep_drop_position: bool) -> void:
	if ball == null or fridge_yarn_pile == null:
		return

	var global_center := ball.global_position + ball.size * 0.5
	if ball.get_parent() != null:
		ball.get_parent().remove_child(ball)
	fridge_yarn_pile.add_child(ball)
	ball.z_index = 0
	ball.call("set_dragging_visual", false)

	if keep_drop_position:
		var pile_rect := fridge_yarn_pile.get_global_rect()
		ball.call("set_center_position", global_center - pile_rect.position)
	else:
		ball.position = fridge_yarn_drag_origin_position
	ball.call("set_velocity", fridge_yarn_drag_release_velocity)
	_keep_yarn_ball_inside_mouth(ball)


func _scatter_fridge_yarn_balls() -> void:
	for i in fridge_yarn_balls.size():
		var ball := fridge_yarn_balls[i]
		if ball == null or not is_instance_valid(ball):
			continue
		if ball.get_parent() != fridge_yarn_pile:
			continue
		var angle := float(i) * 1.37
		var speed := 34.0 + float(i % 3) * 12.0
		ball.call("set_velocity", Vector2(cos(angle), sin(angle)) * speed)


func _update_fridge_yarn_pile(delta: float) -> void:
	if fridge_item_panel == null or not fridge_item_panel.visible or fridge_yarn_pile == null:
		return
	if fridge_yarn_pile.size.x <= 8.0 or fridge_yarn_pile.size.y <= 8.0:
		return

	for i in fridge_yarn_balls.size():
		var ball := fridge_yarn_balls[i]
		if ball == null or not is_instance_valid(ball):
			continue
		if ball == fridge_dragged_yarn_ball or ball.get_parent() != fridge_yarn_pile:
			continue

		var center: Vector2 = ball.call("get_center_position")
		var velocity: Vector2 = ball.call("get_velocity")
		var radius := float(ball.call("get_radius"))
		var idle_force := Vector2(sin(fridge_pulse * 2.0 + float(i) * 1.4), cos(fridge_pulse * 1.7 + float(i))) * 2.2
		velocity += idle_force * delta
		center += velocity * delta

		var min_center := Vector2(radius + 4.0, radius + 4.0)
		var max_center := fridge_yarn_pile.size - Vector2(radius + 4.0, radius + 4.0)
		if center.x < min_center.x:
			center.x = min_center.x
			velocity.x = abs(velocity.x) * 0.55
		elif center.x > max_center.x:
			center.x = max_center.x
			velocity.x = -abs(velocity.x) * 0.55
		if center.y < min_center.y:
			center.y = min_center.y
			velocity.y = abs(velocity.y) * 0.55
		elif center.y > max_center.y:
			center.y = max_center.y
			velocity.y = -abs(velocity.y) * 0.55

		velocity *= pow(0.90, delta * 60.0)
		ball.call("set_center_position", center)
		ball.call("set_velocity", velocity)

	_resolve_fridge_yarn_collisions()


func _resolve_fridge_yarn_collisions() -> void:
	for i in fridge_yarn_balls.size():
		var first := fridge_yarn_balls[i]
		if first == null or not is_instance_valid(first) or first.get_parent() != fridge_yarn_pile:
			continue
		for j in range(i + 1, fridge_yarn_balls.size()):
			var second := fridge_yarn_balls[j]
			if second == null or not is_instance_valid(second) or second.get_parent() != fridge_yarn_pile:
				continue

			var first_center: Vector2 = first.call("get_center_position")
			var second_center: Vector2 = second.call("get_center_position")
			var delta := second_center - first_center
			var distance := delta.length()
			var min_distance := float(first.call("get_radius")) + float(second.call("get_radius")) - 5.0
			if distance >= min_distance:
				continue

			var normal := Vector2.RIGHT if distance <= 0.001 else delta / distance
			var push := (min_distance - distance) * 0.5
			first_center -= normal * push
			second_center += normal * push
			first.call("set_center_position", first_center)
			second.call("set_center_position", second_center)
			_keep_yarn_ball_inside_mouth(first)
			_keep_yarn_ball_inside_mouth(second)

			var first_velocity: Vector2 = first.call("get_velocity")
			var second_velocity: Vector2 = second.call("get_velocity")
			var first_normal_speed := first_velocity.dot(normal)
			var second_normal_speed := second_velocity.dot(normal)
			first_velocity += normal * (second_normal_speed - first_normal_speed) * 0.45
			second_velocity += normal * (first_normal_speed - second_normal_speed) * 0.45
			first.call("set_velocity", first_velocity)
			second.call("set_velocity", second_velocity)


func _keep_yarn_ball_inside_mouth(ball: Control) -> void:
	if ball == null or fridge_yarn_pile == null:
		return
	if fridge_yarn_pile.size.x <= 8.0 or fridge_yarn_pile.size.y <= 8.0:
		return
	var center: Vector2 = ball.call("get_center_position")
	var radius := float(ball.call("get_radius"))
	center.x = clamp(center.x, radius + 4.0, fridge_yarn_pile.size.x - radius - 4.0)
	center.y = clamp(center.y, radius + 4.0, fridge_yarn_pile.size.y - radius - 4.0)
	ball.call("set_center_position", center)


func _get_fridge_yarn_mouth_global_rect() -> Rect2:
	if fridge_yarn_pile == null:
		return Rect2()
	return fridge_yarn_pile.get_global_rect().grow(-2.0)


func _position_fridge_popups() -> void:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	var screen_position: Vector2 = _get_fridge_player_screen_position()
	var item_position: Vector2 = _get_fridge_mouth_inventory_position()

	if fridge_item_panel != null and not fridge_item_panel_has_manual_position and fridge_dragged_panel != fridge_item_panel:
		fridge_item_panel.position = item_position
		fridge_item_panel.size = FRIDGE_TOOLBAR_SIZE

	if fridge_settings_panel != null and not fridge_settings_panel_has_manual_position and fridge_dragged_panel != fridge_settings_panel:
		var settings_position: Vector2 = _clamp_fridge_panel_position(fridge_settings_panel, screen_position + Vector2(300.0, -252.0))
		fridge_settings_panel.position = settings_position
		fridge_settings_panel.size = FRIDGE_SETTINGS_SIZE


func _on_fridge_panel_drag_handle_input(event: InputEvent, panel: Control, panel_id: String) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			fridge_dragged_panel = panel
			fridge_drag_offset = get_viewport().get_mouse_position() - panel.position
			_set_fridge_panel_manual_position(panel_id, true)
			get_viewport().set_input_as_handled()


func _handle_fridge_panel_drag(event: InputEvent) -> bool:
	if fridge_dragged_panel == null or not is_instance_valid(fridge_dragged_panel):
		fridge_dragged_panel = null
		return false

	if event is InputEventMouseMotion:
		var mouse_position: Vector2 = get_viewport().get_mouse_position()
		fridge_dragged_panel.position = _clamp_fridge_panel_position(fridge_dragged_panel, mouse_position - fridge_drag_offset)
		return true

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			fridge_dragged_panel = null
			return true

	return false


func _handle_fridge_player_drag(event: InputEvent) -> bool:
	if fridge_player_is_dragging:
		if event is InputEventMouseMotion:
			fridge_player.global_position = get_global_mouse_position() + fridge_player_drag_offset
			return true

		if event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
				fridge_player_is_dragging = false
				fridge_player_drag_offset = Vector2.ZERO
				return true

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and _is_mouse_over_fridge_player():
			fridge_player_is_dragging = true
			fridge_player_drag_offset = fridge_player.global_position - get_global_mouse_position()
			return true

	return false


func _is_mouse_over_fridge_player() -> bool:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return false
	var local_mouse := fridge_player.to_local(get_global_mouse_position())
	return FRIDGE_PLAYER_DRAG_HIT_RECT.has_point(local_mouse)


func _set_fridge_panel_manual_position(panel_id: String, value: bool) -> void:
	match panel_id:
		"item":
			fridge_item_panel_has_manual_position = value
		"settings":
			fridge_settings_panel_has_manual_position = value
		_:
			pass


func _clamp_fridge_panel_position(panel: Control, target_position: Vector2) -> Vector2:
	if panel == null:
		return target_position
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel.custom_minimum_size
	var max_x: float = max(12.0, viewport_size.x - panel_size.x - 12.0)
	var max_y: float = max(12.0, viewport_size.y - panel_size.y - 12.0)
	return Vector2(
		clamp(target_position.x, 12.0, max_x),
		clamp(target_position.y, 12.0, max_y)
	)


func _get_fridge_player_screen_position() -> Vector2:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return get_viewport_rect().size * 0.5
	var canvas_transform := get_viewport().get_canvas_transform()
	return canvas_transform * fridge_player.global_position


func _get_fridge_cat_screen_position() -> Vector2:
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		return _get_fridge_player_screen_position()
	var canvas_transform := get_viewport().get_canvas_transform()
	return canvas_transform * fridge_cat_pet.global_position


func _get_fridge_mouth_inventory_position() -> Vector2:
	var cat_position := _get_fridge_cat_screen_position()
	var mouth_anchor := cat_position + Vector2(0.0, -124.0)
	var target := mouth_anchor + Vector2(-FRIDGE_TOOLBAR_SIZE.x * 0.5 + 40.0, -FRIDGE_TOOLBAR_SIZE.y + 28.0)
	return _clamp_fridge_panel_position(fridge_item_panel, target)


func _show_fridge_coin_popup(amount: int) -> void:
	if fridge_overlay_root == null:
		return
	var label := Label.new()
	label.text = "+%d 金币" % amount
	label.z_index = 1000
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(120.0, 34.0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.16))
	label.add_theme_color_override("font_shadow_color", Color(0.18, 0.10, 0.02, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	var start_position := _get_fridge_player_screen_position() + Vector2(-60.0, -338.0)
	label.position = start_position
	fridge_overlay_root.add_child(label)
	fridge_coin_popups.append({
		"label": label,
		"elapsed": 0.0,
		"start_position": start_position,
	})


func _update_fridge_coin_popups(delta: float) -> void:
	for i in range(fridge_coin_popups.size() - 1, -1, -1):
		var popup: Dictionary = fridge_coin_popups[i]
		var label := popup.get("label") as Label
		if label == null or not is_instance_valid(label):
			fridge_coin_popups.remove_at(i)
			continue

		var elapsed: float = float(popup.get("elapsed", 0.0)) + delta
		var t: float = clamp(elapsed / 1.15, 0.0, 1.0)
		var start_position: Vector2 = popup.get("start_position", Vector2.ZERO)
		label.position = start_position + Vector2(0.0, -56.0 * t)
		label.modulate = Color(1.0, 1.0, 1.0, 1.0 - t)
		popup["elapsed"] = elapsed
		fridge_coin_popups[i] = popup

		if t >= 1.0:
			label.queue_free()
			fridge_coin_popups.remove_at(i)


func _is_mouse_over_fridge_escape() -> bool:
	var local_mouse := get_global_mouse_position() - FRIDGE_ESCAPE_POSITION
	return FRIDGE_ESCAPE_HIT_RECT.has_point(local_mouse)


func _on_fridge_item_unlock_pressed(item_id: String) -> void:
	var record := _get_fridge_item_record(item_id)
	if record.is_empty():
		return
	if fridge_owned_items.has(item_id):
		return
	_unlock_fridge_item(item_id, record)


func _unlock_fridge_item(item_id: String, record: Dictionary) -> void:
	var price := int(record.get("price", 0))
	if price > fridge_coin_count:
		return
	fridge_coin_count -= price
	fridge_owned_items.append(item_id)
	fridge_active_item_id = item_id
	_save_fridge_progress()
	_refresh_fridge_ui()


func _get_fridge_item_record(item_id: String) -> Dictionary:
	for item: Dictionary in FRIDGE_ITEMS:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func _get_fridge_item_name(item_id: String) -> String:
	var record := _get_fridge_item_record(item_id)
	if record.is_empty():
		return "番茄"
	return str(record.get("name", "番茄"))


func _get_fridge_active_reward() -> int:
	return _get_fridge_item_reward(fridge_active_item_id)


func _get_fridge_item_reward(item_id: String) -> int:
	var record := _get_fridge_item_record(item_id)
	if record.is_empty():
		return FRIDGE_DEFAULT_REWARD_COINS
	var reward := int(record.get("reward", FRIDGE_DEFAULT_REWARD_COINS))
	if reward <= 0:
		reward = FRIDGE_DEFAULT_REWARD_COINS
	return reward


func _get_fridge_phase_label(phase: String) -> String:
	match phase:
		"work":
			return "专注中"
		"break":
			return "休息中"
		_:
			return "开始专注"


func _get_fridge_phase_hint() -> String:
	match fridge_phase:
		"work":
			return "专注结束后会发放金币，并询问是否继续下一轮。"
		"break":
			return "先休息一下，再继续下一轮。"
		_:
			return "在道具栏里点击物品图标开始一轮番茄钟。"


func _get_fridge_phase_progress() -> float:
	match fridge_phase:
		"work":
			return 1.0 - clamp(fridge_time_left / fridge_work_duration, 0.0, 1.0)
		"break":
			return 1.0 - clamp(fridge_time_left / fridge_break_duration, 0.0, 1.0)
		_:
			return 0.0


func _format_fridge_time(time_left: float) -> String:
	var total_seconds: int = int(ceil(time_left))
	if total_seconds < 0:
		total_seconds = 0
	var minutes: int = int(floor(float(total_seconds) / 60.0))
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _format_fridge_duration(duration: float) -> String:
	var total_seconds: int = int(round(duration))
	var minutes: int = int(floor(float(total_seconds) / 60.0))
	var seconds: int = total_seconds % 60
	if minutes <= 0:
		return "%d 秒" % seconds
	return "%d 分 %02d 秒" % [minutes, seconds]
