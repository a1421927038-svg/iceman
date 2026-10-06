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
const FridgeCatNoseScript := preload("res://scripts/FridgeCatNose.gd")
const FridgeChestScript := preload("res://scripts/FridgeChest.gd")
const ActionSkeletonStandScript := preload("res://addons/骨骼动画/skeleton_stand.gd")
const ActionGalleryPanelScript := preload("res://addons/骨骼动画/action_gallery_panel.gd")
const FridgeGlyphSprayScript := preload("res://scripts/FridgeGlyphSpray.gd")

const LEVEL_ID := "fridge_people"
const LEVEL_NAME := "冰箱人"
const LEVEL_COLOR := Color(0.42, 0.76, 0.96)

const FRIDGE_SAVE_PATH := "user://fridge_people_save.json"
const FRIDGE_DEFAULT_WORK_DURATION := 18.0
const FRIDGE_DEFAULT_BREAK_DURATION := 4.0
const FRIDGE_DEFAULT_REWARD_COINS := 5
const FRIDGE_DEFAULT_VARIANT_ID := "tomato"
## Each item is a pomodoro of its own length: an entry may set "duration" (seconds),
## and anything without one follows 专注秒数 from the settings panel. The four MOUTH items are fixed
## to 1 / 2 / 3 / 4 分钟 - the number on each ball's plate reads straight off its own duration.
const FRIDGE_ITEMS := [
	{"id": "tomato", "name": "番茄钟", "price": 0, "reward": 5, "variant_id": "tomato", "free": true, "duration": 60.0, "description": "基础待机动画"},
	{"id": "cassette", "name": "磁带机", "price": 5, "reward": 5, "variant_id": "cassette", "duration": 120.0, "description": "磁带转动待机"},
	{"id": "pager", "name": "寻呼机", "price": 10, "reward": 10, "variant_id": "pager", "duration": 180.0, "description": "屏幕闪烁待机"},
	{"id": "walkman", "name": "随身听", "price": 15, "reward": 15, "variant_id": "walkman", "description": "耳机律动待机"},
	{"id": "crt", "name": "显像管电视", "price": 20, "reward": 20, "variant_id": "crt", "duration": 240.0, "description": "扫描线待机"},
	{"id": "vhs", "name": "录像带", "price": 25, "reward": 25, "variant_id": "vhs", "description": "胶带循环待机"},
]

## 猫嘴里去掉: the 随身听 (walkman) and the 录像带 (vhs tape) never appear in the cat's mouth any
## more - no ball in its mouth bag and no card in the book's 猫嘴物品 page. They stay in FRIDGE_ITEMS
## so the shop rows and the save format are untouched; they are simply never a mouth item.
const FRIDGE_MOUTH_EXCLUDED_ITEMS := ["walkman", "vhs"]


func _is_fridge_mouth_item(item_id: String) -> bool:
	return not FRIDGE_MOUTH_EXCLUDED_ITEMS.has(item_id)


## 数字: how many whole minutes one focused run of this item lasts - the digit a mouth ball floats
## above itself (1 = 1 分钟, 2 = 2 分钟). Never below 1.
func _fridge_item_minutes(item_id: String) -> int:
	return maxi(1, roundi(_get_fridge_item_duration(item_id) / 60.0))

const FRIDGE_ESCAPE_POSITION := Vector2(500.0, -235.0)
# The four actors stand in one row on the same ground line (visual bottoms
# measured from their art): wardrobe -> briefcase -> fridge man -> cat.
const FRIDGE_CAT_POSITION := Vector2(250.0, 131.0)
## 猫的右边: the notebook prop and the briefcase stand to the picture-RIGHT of the cat (the cat
## is at 250 and its art reaches x=324, so the two sit just clear of it on the same ground line,
## bottoms at y=185/194). Their panels are pinned 正上方 (see _fridge_prop_panel_position).
## 缩小一倍: the notebook art is drawn at HALF its old height (88, not 176). The stand centres its
## sprite 42px above the prop, so halving the art alone would lift the book off the ground - this
## position sits 44px lower to keep the book's bottom on the very same ground line (art y 97..185).
const FRIDGE_GALLERY_STAND_POSITION := Vector2(420.0, 183.0)
const FRIDGE_ESCAPE_HIT_RECT := Rect2(-54.0, -54.0, 108.0, 108.0)
const FRIDGE_PLAYER_DRAG_HIT_RECT := Rect2(-118.0, -286.0, 236.0, 344.0)
# 随着BB机向上移动: once the BB机 levitation settles the fridge man drifts upward with the
# pager, wraps around the screen edges, turns around when clicked and can still be dragged.
# The offsets describe his drawn body relative to his node (his raised fists reach about
# 300px above it, his feet about 16px below).
const FRIDGE_FLIGHT_SPEED := Vector2(58.0, -82.0)
const FRIDGE_FLIGHT_TOP_OFFSET := -300.0
const FRIDGE_FLIGHT_BOTTOM_OFFSET := 16.0
const FRIDGE_FLIGHT_HALF_WIDTH := 122.0
const FRIDGE_FLIGHT_RETURN_SPEED := 5.0
# 磁带机: while the boombox dance is held he paces SIDEWAYS at this speed (pure horizontal,
# no vertical drift) - a click turns him around, and the screen edges bounce him so he never
# walks out of view. Runs until the countdown ends.
const FRIDGE_DANCE_SPEED := 92.0
# 电视机: poling the 乌篷船 carries the whole ensemble (the boat is a child of the player, so
# moving his node moves it too) at this slower, statelier speed. 划到屏幕边缘就会返回 - it
# turns around just inside the edges, leaving room for the boat's own overhang: the boat is
# drawn to his LEFT (mirrored), so it reaches much further that way.
const FRIDGE_BOAT_SPEED := 52.0
const FRIDGE_BOAT_LEFT_MARGIN := 215.0
const FRIDGE_BOAT_RIGHT_MARGIN := 110.0
# A quick press that does not move him is a CLICK (turns him around); a longer press or a
# real movement is the player grabbing and steering him.
const FRIDGE_PLAYER_CLICK_MOVE_LIMIT := 8.0
const FRIDGE_PLAYER_CLICK_TIME_LIMIT := 0.25
const FRIDGE_TOOLBAR_SIZE := Vector2(500.0, 500.0)
const FRIDGE_SETTINGS_SIZE := Vector2(250.0, 238.0)
const FRIDGE_YARN_PILE_SIZE := Vector2(342.0, 263.0)
const FRIDGE_PANEL_FOLLOW_MARGIN := 72.0
const FRIDGE_ITEM_HEADER_DRAG_HEIGHT := 22.0
# The cat's painted nose on the mouth panel (position/size as fractions of the
# panel's rect, measured from paper_cat_mouth_inventory_panel.png). The nose stays
# red; an invisible hotspot sits on it, and hovering swaps in a YELLOW paper token
# of the same nose so the button lights up. Clicking re-deals the mouth balls.
# SIZE is the token texture's canvas (64x48), so the drawn token lines up with the
# painted nose 1:1 instead of being stretched to a different aspect.
# CENTRE is the painted nose's own bbox centre and SIZE is the hover token's canvas
# (57x38), so the token lands on the red nose pixel-for-pixel: same silhouette, colour only.
const FRIDGE_NOSE_CENTER_FRAC := Vector2(0.49902, 0.18945)
const FRIDGE_NOSE_SIZE_FRAC := Vector2(0.11133, 0.07422)
# Nose-refresh pour-out: every ball vanishes into the cat's throat, then pops
# out one after another (a gacha-style gush) and flies to a fresh spot.
const FRIDGE_REFILL_STAGGER := 0.07
const FRIDGE_REFILL_EMERGE_TIME := 0.32
const FRIDGE_REFILL_ORIGIN_FRAC := Vector2(0.5, 0.86)
const FRIDGE_REFILL_START_SCALE := 0.05
const FRIDGE_REFILL_HOP := 26.0
# The cursor parts the pile as it moves through the mouth.
const FRIDGE_POINTER_PUSH_RADIUS := 96.0
const FRIDGE_POINTER_PUSH_FORCE := 700.0
const FRIDGE_POINTER_NONE := Vector2(-100000.0, -100000.0)
const FRIDGE_GALLERY_TITLE := "动作选项"
## 分页: the notebook's panel has two pages - 骨架 (the animation gallery above) and 猫嘴物品
## (every item the player has unlocked, i.e. the ones on show in the cat's mouth).
const FRIDGE_GALLERY_TAB_SKELETON := "skeleton"
const FRIDGE_GALLERY_TAB_ITEMS := "items"
## 页签换图标: these two paper LOGOs (a jointed figure for the animation gallery, a cat with a pouch
## for the items the cat holds) are what the bookmarks carried when they were labelled. They are
## NOT wired right now - the user asked for 素净 ribbons with nothing on them - but the panel still
## supports a tab `icon`, so this is one line away from coming back.
const FRIDGE_GALLERY_TAB_SKELETON_LOGO := "res://assets/generated/ui_tab_logo_skeleton_pale.png"
const FRIDGE_GALLERY_TAB_ITEMS_LOGO := "res://assets/generated/ui_tab_logo_items_pale.png"
## 摊开的书: the notebook panel's grid geometry - two cells per row, each just its ICON (the names
## and 说明 live in the hover tooltip, see `cell_labels`). The icon size and the book's own page
## margins (38/32/38/42) are chosen together so the panel lands on the upright open-book art's 4:3
## aspect AND nothing spills off the cream pages: 2*146 + 8 + 76 = 376 wide, 2*100 + 8 + 74 = 282.
const FRIDGE_GALLERY_BOOK_CARD_SIZE := Vector2(146.0, 100.0)
const FRIDGE_GALLERY_BOOK_ICON_SIZE := Vector2(60.0, 60.0)
const FRIDGE_GALLERY_BOOK_CARD_GAP := 8.0
## 正上方: the backpack is pinned directly above the notebook prop - centred on the prop's own ART,
## with its bottom edge this far clear of the art's top. The art is MEASURED off the prop's sprites
## every frame (see _fridge_prop_panel_position), so moving the stand can never leave the opened
## panel sitting over it.
const FRIDGE_GALLERY_STAND_GAP := 12.0
## 红色本子: the stand prop's art is a big red notebook instead of the wardrobe now. The
## backpack's host is still the same stand node (the plugin's own skeleton art stays its
## default); only this swapped picture changed.
## 缩小一倍: the notebook is drawn at half the height the plugin defaults to (176 -> 88). Pair this
## with FRIDGE_GALLERY_STAND_POSITION: the stand centres its sprite 42px above the prop, so a smaller
## art would float unless the prop moves down by half the height it lost (44px).
const FRIDGE_GALLERY_STAND_DISPLAY_HEIGHT := 88.0
const FRIDGE_GALLERY_STAND_TEXTURE := "res://assets/generated/paper_red_book_star.png"
## 骨架背包 = 道具箱同款纸片 UI: the backpack wears exactly the prop box's style - the
## cream paper card with its even brown rim (一圈棕色边缘, with no painted background
## behind the cells), every cell a debossed paper pocket, the 标题 and the 下拉查看更多
## line on show, and the panel's own default card / icon / gap / margins. Only the column
## count is the gallery's own; the rows below the fold are pulled into view with the
## scrollbar.
const FRIDGE_GALLERY_CELL_TEXTURE := "res://assets/generated/ui_paper_pocket.png"
const FRIDGE_GALLERY_GRID_COLUMNS := 2
## 道具箱格子: a smaller icon so the hover zoom has room, and a bigger skeleton-action
## badge on the left of each row.
const FRIDGE_BOX_ICON_SIZE := Vector2(34.0, 34.0)
const FRIDGE_BOX_ACTION_ICON_SIZE := Vector2(64.0, 64.0)
const FRIDGE_BOX_ACTION_HEADER_WIDTH := 96.0
## 缩小些: the box's cells carry the item ART alone (the name lives in the hover tooltip), squared paper
## compartments - 62 -> 56 and the logo 38 -> 34, with the rim's margin scaled to match.
const FRIDGE_BOX_CARD_SIZE := Vector2(56.0, 56.0)
const FRIDGE_BOX_CELL_MARGIN := 6.0
## 公文包: the reference look - the opened case is the panel's board (its padded lining holds the tray), the
## cells are the case's recessed COMPARTMENTS, and the tray is a fixed 3x2 so the unused slots are drawn
## exactly like the filled ones.
const FRIDGE_BOX_CELL_TEXTURE := "res://assets/generated/ui_paper_prop_slot.png"
const FRIDGE_BOX_GRID_COLUMNS := 3
const FRIDGE_BOX_GRID_ROWS := 2
## 上面一排: the action logos run across the case's LID, three at a time; wheeling over the panel turns to
## the next three (the panel's own ACTION_PAGE_SIZE). This also caps the tray's rows.
const FRIDGE_BOX_VISIBLE_ROWS := 2
const FRIDGE_GALLERY_PREVIEW_DURATION := 5.0
# The BB机 reaction is 4.4 s of beats plus the levitation that follows, so it gets
# a longer preview than the other entries.
const FRIDGE_PAGER_PREVIEW_DURATION := 7.5
# After a work round's countdown finishes, the two choice buttons appear:
# the left (devil) button runs one more round with the SAME item, so that item's
# own animation plays for the whole countdown and the buttons come back when it
# ends; the right (angel) button plays the Gemini-generated exhausted rest
# animation and ends the sequence.
const FRIDGE_REST_PREVIEW_DURATION := 3.0
const FRIDGE_BOX_POSITION := Vector2(508.0, 172.0)
const FRIDGE_BOX_DISPLAY_HEIGHT := 128.0
const FRIDGE_BOX_TITLE := "道具箱"
## 90年代公文包: the prop box's art. Both states sit on the same canvas and ground row and
## share one case-body scale, so the lid flips up and the interior appears without the
## case moving or resizing. The chest art stays the prop's default.
const FRIDGE_BOX_CLOSED_TEXTURE := "res://assets/generated/paper_briefcase_closed.png"
const FRIDGE_BOX_OPEN_TEXTURE := "res://assets/generated/paper_briefcase_open_v3.png"
## 箱子上方: the prop box panel is centred on the chest and pinned just above the chest's
## ART, so it is always shown above the box - even while the box is being dragged.
const FRIDGE_BOX_PANEL_GAP := 12.0
## 屏幕内: the margin _clamp_panel_to_screen keeps between an auto-placed panel and the screen edge.
## 挂在上边: wide enough that the notebook's bookmark ribbons, which stick TAB_BOOKMARK_OVERHANG of
## their height above the panel, still land fully on screen.
const FRIDGE_PANEL_SCREEN_MARGIN := 48.0

## Action/animation entries shown by the wardrobe prop's gallery panel.
## New performances just get appended here and mapped in
## `_on_fridge_gallery_entry_pressed`.
const FRIDGE_GALLERY_ENTRIES := [
	{"id": "juggle", "name": "抛球杂耍", "description": "连续抛接小球", "icon": "res://assets/generated/paper_skeleton_juggle_icon.png"},
	{"id": "man_rest_stand", "name": "站立歇息", "description": "靠墙站一会儿", "icon": "res://assets/generated/paper_icon_man_rest_stand.png"},
	{"id": "man_smoke", "name": "抽烟吐圈", "description": "吐出一个个烟圈", "icon": "res://assets/generated/paper_icon_man_smoke.png"},
	{"id": "man_pet_cat", "name": "摸摸小猫", "description": "弯腰抚摸小猫", "icon": "res://assets/generated/paper_icon_man_pet_cat.png"},
	{"id": "man_pager", "name": "BB机来讯", "description": "腰间BB机响起", "icon": "res://assets/generated/paper_icon_man_pager.png"},
	{"id": "man_doze", "name": "冰箱人打盹", "description": "站着打起了瞌睡", "icon": "res://assets/generated/paper_icon_man_doze.png"},
	# 猫嘴里的动画: the two performances the cat's bag gained later are on the 骨架 page too, wearing the
	# mouth items' own logos. Clicking one previews it - see their cases in _on_fridge_gallery_entry_pressed.
	{"id": "man_cassette", "name": "磁带机舞", "description": "扛着录音机跳舞", "icon": "res://assets/generated/paper_icon_cassette.png"},
	{"id": "man_tv", "name": "渔民垂钓", "description": "划着乌篷船垂钓", "icon": "res://assets/generated/paper_icon_crt.png"},
	{"id": "cat_rest_stand", "name": "小猫歇息", "description": "原地伸展身体", "icon": "res://assets/generated/paper_icon_cat_rest_stand.png"},
	{"id": "cat_doze", "name": "小猫打盹", "description": "眯眼慢慢睡着", "icon": "res://assets/generated/paper_icon_cat_doze.png"},
	{"id": "cat_play_ball", "name": "小猫玩球", "description": "追着毛线球打转", "icon": "res://assets/generated/paper_icon_cat_play_ball.png"},
	{"id": "cat_run_circle", "name": "小猫绕圈跑", "description": "绕着冰箱人跑圈", "icon": "res://assets/generated/paper_icon_cat_run.png"},
]

## Idle ("待机") rotations: while the level is idle the fridge man and the cat
## occasionally play one of these animations on their own. `pet_cat` and `run`
## also move the cat (see _start_fridge_pet_cat / _start_fridge_cat_orbit).
const FRIDGE_IDLE_MAN_ACTIONS := ["rest_stand", "smoke", "pet_cat"]
const FRIDGE_IDLE_CAT_ACTIONS := ["rest_stand", "play_ball", "run"]
const FRIDGE_IDLE_ACTION_DURATIONS := {
	"rest_stand": 7.0,
	"smoke": 7.5,
	"pet_cat": 6.0,
	"play_ball": 7.0,
	# 打瞌睡 is a whole doze arc (stand, nod, sleep, pop, startle). The cat stands
	# longer than the man before nodding off (so they never doze in lockstep), so
	# the preview has to outlast its 12.15 s arc or it would cut the cat off
	# mid-sleep and snap it back awake.
	"doze": 13.0,
}
const FRIDGE_IDLE_ACTION_DURATION := 6.0
## How long the level waits with no interaction ("待机超时") before one of the two
## characters plays a random idle animation on its own: ten seconds of the player
## not touching the fridge man (or the cat). Moving the mouse or clicking counts
## as interaction, cancels a running animation and restarts the wait.
const FRIDGE_IDLE_DELAY := 10.0
## How recently the mouse must have moved or clicked for the pointer sitting ON a
## character to still count as interaction. Past this window a pointer that is
## merely parked there no longer blocks the rotation - otherwise a cursor left
## resting on the fridge man would silently suppress the idle animations for good.
const FRIDGE_IDLE_INPUT_GRACE := 0.75
## 小猫绕着冰箱人跑圈: the cat runs a flattened ellipse around the fridge man.
## The radius is wide enough that the whole lap stays visible beside him - only
## the moment it passes right behind him is hidden, so the circle always reads as
## a full circle.
const FRIDGE_CAT_ORBIT_RADIUS := 175.0
## 一蹦一跳: the cat BOUNDS along the ellipse - this many hops per lap, each this many
## pixels off the ground - instead of sliding round it, and plays its animation at this
## multiple of the action's own fps so the batting reads as busy and springy.
const FRIDGE_CAT_ORBIT_HOP_RATE := 1.4
const FRIDGE_CAT_ORBIT_HOP := 20.0
const FRIDGE_CAT_ORBIT_FPS_SCALE := 1.7
## 一蹦一跳, with no teleports: the cat first HOPPINGLY travels from where it was standing
## onto the ellipse (this many seconds), circles it, then hops back to the same spot. The
## hop's own amplitude fades in and out over this long, so the cat never leaves the ground
## on the first frame nor lands in mid air on the last.
const FRIDGE_CAT_ORBIT_APPROACH_TIME := 2.0
const FRIDGE_CAT_HOP_RAMP := 0.45
## 前后遮挡's dividing line, measured from the cat's own ground line (it is the orbit
## ellipse's y midpoint: the orbit's depth is negative exactly above it). The approach and
## the trip home test it too, so the cat is occluded by the fridge man whenever it really
## is on his far side - not only during the circling half.
const FRIDGE_CAT_BEHIND_LINE := -40.0
## How far the cat's path lifts at the back of the circle (screen-up reads as
## "further away"); the front of the path stays on the ground line, so the cat
## never sinks below the floor while it circles.
const FRIDGE_CAT_ORBIT_DEPTH := 40.0
## 前后遮挡: on the far half of the circle the cat passes BEHIND the fridge man
## (his z_index is 12), on the near half in front of him - which is also the
## cat's normal standing order, so both offsets are relative to his own z.
const FRIDGE_CAT_BACK_Z_OFFSET := -1
const FRIDGE_CAT_FRONT_Z_OFFSET := 2
## 小猫绕圈跑: it walks up to the fridge man's FRONT, rounds him on the LEFT to his BACK,
## then bounces home - half a lap, and this is how long that takes (deliberately unhurried:
## the cat is a walking box, so it lumbers rather than darts).
const FRIDGE_CAT_ORBIT_DURATION := 6.0
const FRIDGE_CAT_RETURN_TIME := 2.0
## 摸摸小猫: the cat walks over and sits under his hand while he strokes it.
const FRIDGE_PET_CAT_OFFSET := Vector2(96.0, -12.0)

## The prop box: the objects an animation can be given instead of its own. The
## entries are grouped BY SKELETON ACTION - clicking one gives that action this item:
##   * 抛球杂耍  -> what the fridge man juggles (changes live, mid-performance)
##   * BB机来讯  -> what the levitating BB机 squirts out (字体 glyphs / 泡泡 bubbles)
## 左侧改成按钮: the briefcase's opened panel shows those actions as a column of BUTTONS down its
## left side, and the cells on the right hold ONLY the chosen action's items - so picking 抛球杂耍
## offers 番茄 / 球 and picking BB机来讯 offers 字体 / 泡泡. A new action is one more group here: it
## becomes another button, and past ActionGalleryPanel.ACTION_BUTTON_MAX the column turns into a
## dropdown (下拉选择) so the list can keep growing.
const FRIDGE_BOX_ENTRIES := [
	{
		"id": "tomato",
		"name": "番茄",
		"icon": "res://assets/generated/paper_tomato_projectile.png",
		"action_icon": "res://assets/generated/paper_skeleton_juggle_icon.png",
		"action_name": "抛球杂耍",
	},
	{
		"id": "ball",
		"name": "球",
		"icon": "res://assets/generated/paper_juggle_ball.png",
		"action_icon": "res://assets/generated/paper_skeleton_juggle_icon.png",
		"action_name": "抛球杂耍",
	},
	{
		"id": "spray_text",
		"name": "字体",
		"icon": "res://assets/generated/paper_icon_spray_text.png",
		"action_icon": "res://assets/generated/paper_icon_man_pager.png",
		"action_name": "BB机来讯",
	},
	{
		"id": "spray_bubble",
		"name": "泡泡",
		"icon": "res://assets/generated/paper_icon_spray_bubble.png",
		"action_icon": "res://assets/generated/paper_icon_man_pager.png",
		"action_name": "BB机来讯",
	},
	# 猫嘴里的动画: the two items the cat's bag gained later are listed here too, a page further along
	# the lid's row. 只留图标 means the lid carries the MOUTH ITEM's own logo (the 磁带机 tape and the
	# 电视机 set) - and 不要显示自己的图标 means that item is not repeated as a card below it, so each of
	# these two actions shows ONLY the one replacement it unlocks.
	{
		"id": "cassette_note",
		"name": "音乐符号",
		"icon": "res://assets/generated/paper_icon_music_note.png",
		"action_icon": "res://assets/generated/paper_icon_cassette.png",
		"action_name": "磁带机",
	},
	{
		"id": "tv_boat",
		"name": "乌篷船",
		"icon": "res://assets/generated/paper_icon_boat.png",
		"action_icon": "res://assets/generated/paper_icon_crt.png",
		"action_name": "电视机",
	},
]

## 喷射: what squirts out from underneath the levitating BB机 while the fridge man
## floats up with it - a shower of paper pieces that falls to the ground and
## disappears there. The payload is plain data: 字体 (paper glyphs) and 泡泡 (paper
## bubbles) are two separate entries below, and any further prop is one more entry -
## no other code changes are needed.
const FRIDGE_SPRAY_PAYLOAD := "text"
## "regions" are the glyph boxes found inside the sheet, baked in so nothing has
## to scan the image while the level loads.
const FRIDGE_SPRAY_PAYLOADS := {
	"text": {
		"name": "喷射字体",
		"atlas": "res://assets/generated/paper_spray_text.png",
		"height": 46.0,
		"regions": [
			Rect2i(12, 0, 236, 241), Rect2i(276, 14, 222, 224),
			Rect2i(543, 0, 236, 241), Rect2i(835, 10, 177, 229),
			Rect2i(12, 272, 240, 228), Rect2i(283, 284, 214, 222),
			Rect2i(555, 276, 219, 239), Rect2i(835, 287, 177, 225),
			Rect2i(12, 543, 237, 234), Rect2i(308, 551, 182, 227),
			Rect2i(543, 552, 241, 225), Rect2i(883, 551, 103, 225),
			Rect2i(31, 802, 214, 222), Rect2i(277, 822, 315, 202),
			Rect2i(643, 808, 261, 216),
		],
	},
	"tomato": {
		"name": "喷射番茄",
		"texture": "res://assets/generated/paper_tomato_projectile.png",
		"height": 40.0,
	},
	# 泡泡: the same BB机 squirting bubbles instead of the glyphs - the swap the
	# 泡泡 item in the prop box makes.
	"bubble": {
		"name": "喷射泡泡",
		"atlas": "res://assets/generated/paper_spray_bubbles.png",
		"height": 34.0,
		"regions": [
			Rect2i(0, 1, 232, 234), Rect2i(265, 1, 232, 235),
			Rect2i(530, 1, 234, 234), Rect2i(795, 1, 229, 235),
			Rect2i(0, 279, 234, 231), Rect2i(264, 279, 234, 231),
			Rect2i(528, 279, 232, 231), Rect2i(794, 279, 230, 231),
		],
	},
}
## The pieces squirt out from just under the levitating device.
const FRIDGE_SPRAY_OFFSET := Vector2(0.0, 36.0)
## The actors' baseline: a piece that reaches it has landed and vanishes.
const FRIDGE_SPRAY_GROUND_Y := 184.0

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
# True while the post-round choice flow is active: the two head buttons keep
# re-appearing after each replay performance finishes, until a new pomodoro
# round starts (or the level resets).
var fridge_round_choices_pending := false
# Which head-button option the player picked for the round that just finished:
# "devil" loops (its juggle ends by bringing the buttons back), "angel" ends the
# whole sequence (the fridge man returns to idle and the buttons stay gone until
# a new round starts). Empty when no choice performance is in flight.
var fridge_round_choice_in_flight := ""
# True while the ball-to-the-face ending plays right after a work countdown; the
# post-round choice buttons appear only once it finishes.
var fridge_round_ending_in_flight := false
# --- Idle ("待机") behaviour state ------------------------------------------
# Whether the characters play idle animations on their own; tests switch this
# off so their assertions stay deterministic.
var fridge_idle_rotation_enabled := true
# Starts at a full pause so the game opens calm instead of with an animation.
var fridge_idle_timer := FRIDGE_IDLE_DELAY
# Shuffled queue of the idle animations still to play; refilled when it empties,
# so the rotation runs through every animation once before repeating any.
var fridge_idle_bag: Array = []
# Blocks the rotation while a manual gallery preview is playing.
var fridge_idle_suppress := 0.0
# Seconds since the last real mouse input (motion or a button press). Resetting
# this is what tells the rotation the player is actually interacting; letting it
# grow past FRIDGE_IDLE_INPUT_GRACE is what lets a parked pointer be ignored.
var fridge_idle_input_age := 999.0
# Cat locomotion driven by the level for the two "together" bits: "orbit" (running
# around the fridge man), "wait" (sitting beside him while he strokes it) and
# "return" (trotting back to where it was standing). "" while the cat is still.
var fridge_cat_motion := ""
var fridge_cat_motion_time := 0.0
var fridge_cat_motion_total := 1.0
# Where the cat was last frame, so its 面朝方向 can be read off the way it actually
# travels (see _update_fridge_cat_motion).
var fridge_cat_last_position := Vector2.ZERO
var fridge_cat_home := Vector2.ZERO
var fridge_cat_return_from := Vector2.ZERO
var fridge_cat_orbit_center := Vector2.ZERO
# Where the orbit's ellipse starts (and, since a lap is a full turn, where it ends), so
# the approach can aim at it and the return can leave from it - that is what keeps both
# hand offs free of teleports.
var fridge_cat_orbit_start := Vector2.ZERO
# 一蹦一跳's clock and the choreography's total length, kept ACROSS the phases: a hop
# clock that reset per phase would look like a bounce out of nowhere at every boundary.
var fridge_cat_hop_clock := 0.0
var fridge_cat_choreo_time := 0.0
var fridge_cat_choreo_total := 1.0
# The cat's own ground line (it is positioned by its centre, which sits above its
# feet), so the front of the orbit keeps its feet on the floor instead of sinking.
var fridge_cat_orbit_base_y := 0.0
var fridge_shop_list: VBoxContainer
# 喷射: the spray node and which payload it is throwing (see FRIDGE_SPRAY_PAYLOADS).
var fridge_spray: Node2D
var fridge_spray_payload_id := FRIDGE_SPRAY_PAYLOAD
var fridge_yarn_pile: Control
var fridge_yarn_balls: Array[Control] = []
# Invisible hotspot over the nose on the mouth art (see FridgeCatNose).
var fridge_nose_button: Control
# Balls mid pour-out, keyed by ball: {"time", "delay", "origin", "target",
# "burst"}. While a ball is in here it is hidden at the cat's throat and skipped
# by the pile physics until it emerges and lands in its new spot.
var fridge_yarn_spawn: Dictionary = {}
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
var fridge_item_panel_offset := Vector2.ZERO
var fridge_settings_panel_has_manual_position := false
var fridge_player_is_dragging := false
var fridge_player_drag_offset := Vector2.ZERO
# 改变飞行方向 / 控制住冰箱人: which way he is drifting during the levitation, where he
# lifted off from (so he can settle back down afterwards), and the click-vs-grab bookkeeping.
var fridge_player_flight_dir := 1.0
var fridge_player_flight_origin := Vector2.ZERO
var fridge_player_flight_has_origin := false
# 点击冰箱人: while he is idle, a click on him hides the notebook prop and the briefcase
# (a second click brings them back) so the player can clear the room. The cat stays put.
var fridge_props_hidden := false
var fridge_player_drag_moved := false
var fridge_player_press_msec := 0
var fridge_player_press_position := Vector2.ZERO
# True while the pomodoro juggle performance (open fridge door -> reveal
# tomatoes -> take out -> juggle loop) should play for the running work
# session; auto-cleared when the session ends.
var fridge_player_juggling := false
var fridge_player: Node2D
var fridge_cat_pet: Node2D
var fridge_gallery_stand: Node2D
var fridge_gallery_panel: PanelContainer
var fridge_box: Node2D
var fridge_box_panel: PanelContainer
# The prop box entry in hand; its card is highlighted in the panel.
var fridge_box_selected_id := "tomato"
var fridge_coin_count := 0
var fridge_owned_items: Array[String] = [FRIDGE_DEFAULT_VARIANT_ID]
var fridge_active_item_id := FRIDGE_DEFAULT_VARIANT_ID
var fridge_phase := "idle"
var fridge_time_left := 0.0
var fridge_pulse := 0.0
var fridge_work_duration := FRIDGE_DEFAULT_WORK_DURATION
var fridge_break_duration := FRIDGE_DEFAULT_BREAK_DURATION
# 打破第四面墙: when the juggle's last tosses reach the camera the whole VIEW is knocked about
# - a short decaying camera offset plus a paper-white flash at the moment of impact.
const FRIDGE_SCREEN_SHAKE_TIME := 0.55
const FRIDGE_SCREEN_SHAKE_AMOUNT := 22.0
const FRIDGE_SCREEN_FLASH_TIME := 0.28
var fridge_screen_shake_time := 0.0
var fridge_screen_flash_time := 0.0
var fridge_screen_flash: ColorRect


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
	_update_fridge_yarn_spawn(delta)
	_update_fridge_yarn_pile(delta)
	_update_fridge_coin_popups(delta)
	_update_fridge_pomodoro(delta)
	_update_fridge_player_form()
	_update_fridge_player_flight(delta)
	_update_fridge_screen_shake(delta)
	_update_fridge_idle(delta)
	_update_fridge_spray()


func _update_fridge_player_form() -> void:
	# The juggling performance only runs while its work session is active.
	if fridge_player_juggling and fridge_phase != "work":
		fridge_player_juggling = false
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	fridge_player.call("set_pomodoro_juggle", fridge_player_juggling)


## The screen's rectangle in world space (the camera is a plain child of this node, so this
## follows its transform and stays correct even while the view is being shaken).
func _fridge_screen_world_rect() -> Rect2:
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var size: Vector2 = get_viewport_rect().size
	var origin: Vector2 = inverse * Vector2.ZERO
	return Rect2(origin, (inverse * size) - origin)


## 随着BB机向上移动: while the BB机 levitation is held the fridge man drifts upward with the
## pager. 遇到屏幕上边界后，又从下方冒出来 - when he leaves one edge he comes back in at the
## opposite one, so he keeps circling the screen. A press-and-hold hands him to the player
## (the drag owns his position and this yields), and once the levitation ends he settles
## back down to where he lifted off from.
func _update_fridge_player_flight(delta: float) -> void:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	if fridge_player_is_dragging:
		return
	if bool(fridge_player.call("is_pager_flying")):
		if not fridge_player_flight_has_origin:
			fridge_player_flight_origin = fridge_player.global_position
			fridge_player_flight_has_origin = true
		var next_position: Vector2 = fridge_player.global_position
		next_position += Vector2(
			FRIDGE_FLIGHT_SPEED.x * fridge_player_flight_dir,
			FRIDGE_FLIGHT_SPEED.y) * delta
		var screen: Rect2 = _fridge_screen_world_rect()
		var left: float = screen.position.x
		var right: float = screen.position.x + screen.size.x
		var top: float = screen.position.y
		var bottom: float = screen.position.y + screen.size.y
		# 遇到屏幕上边界后，又从下方冒出来: only once he is COMPLETELY off one edge does he
		# re-enter at the opposite one - wrapping on mere overlap would bounce him back and
		# forth every frame (he would never be seen).
		if next_position.y + FRIDGE_FLIGHT_BOTTOM_OFFSET < top:
			next_position.y = bottom - FRIDGE_FLIGHT_TOP_OFFSET
		elif next_position.y + FRIDGE_FLIGHT_TOP_OFFSET > bottom:
			next_position.y = top - FRIDGE_FLIGHT_BOTTOM_OFFSET
		if next_position.x - FRIDGE_FLIGHT_HALF_WIDTH > right:
			next_position.x = left - FRIDGE_FLIGHT_HALF_WIDTH
		elif next_position.x + FRIDGE_FLIGHT_HALF_WIDTH < left:
			next_position.x = right + FRIDGE_FLIGHT_HALF_WIDTH
		fridge_player.global_position = next_position
	elif bool(fridge_player.call("is_cassette_dancing")):
		# 磁带机: boombox on his shoulder, the music playing - he paces side to side. Pure
		# horizontal motion (his y never changes), and rather than wrapping he TURNS AROUND
		# just inside each screen edge, so he stays fully visible for the whole countdown.
		if not fridge_player_flight_has_origin:
			fridge_player_flight_origin = fridge_player.global_position
			fridge_player_flight_has_origin = true
		var dance_position: Vector2 = fridge_player.global_position
		dance_position.x += FRIDGE_DANCE_SPEED * fridge_player_flight_dir * delta
		var dance_screen: Rect2 = _fridge_screen_world_rect()
		var dance_left: float = dance_screen.position.x
		var dance_right: float = dance_screen.position.x + dance_screen.size.x
		if dance_position.x + FRIDGE_FLIGHT_HALF_WIDTH > dance_right:
			dance_position.x = dance_right - FRIDGE_FLIGHT_HALF_WIDTH
			fridge_player_flight_dir = -1.0
		elif dance_position.x - FRIDGE_FLIGHT_HALF_WIDTH < dance_left:
			dance_position.x = dance_left + FRIDGE_FLIGHT_HALF_WIDTH
			fridge_player_flight_dir = 1.0
		fridge_player.global_position = dance_position
	elif bool(fridge_player.call("is_tv_fishing")):
		# 电视机: he is out on the 乌篷船 with his pole in the water, so the boat travels -
		# the boat sprite is a child of the player, so moving his node carries the whole
		# ensemble with it. It cruises at a slow, stately pace and, 划到屏幕边缘就会返回,
		# turns around just inside each edge (the left margin is wider because the mirrored
		# boat hangs off that side of him).
		if not fridge_player_flight_has_origin:
			fridge_player_flight_origin = fridge_player.global_position
			fridge_player_flight_has_origin = true
		var boat_position: Vector2 = fridge_player.global_position
		boat_position.x += FRIDGE_BOAT_SPEED * fridge_player_flight_dir * delta
		var boat_screen: Rect2 = _fridge_screen_world_rect()
		var boat_left: float = boat_screen.position.x
		var boat_right: float = boat_screen.position.x + boat_screen.size.x
		if boat_position.x + FRIDGE_BOAT_RIGHT_MARGIN > boat_right:
			boat_position.x = boat_right - FRIDGE_BOAT_RIGHT_MARGIN
			fridge_player_flight_dir = -1.0
		elif boat_position.x - FRIDGE_BOAT_LEFT_MARGIN < boat_left:
			boat_position.x = boat_left + FRIDGE_BOAT_LEFT_MARGIN
			fridge_player_flight_dir = 1.0
		fridge_player.global_position = boat_position
	elif fridge_player_flight_has_origin:
		# 回到地面: the levitation is over, so let him sink back to his take-off spot.
		var target: Vector2 = fridge_player_flight_origin
		var position2: Vector2 = fridge_player.global_position
		if position2.distance_to(target) < 1.5:
			fridge_player.global_position = target
			fridge_player_flight_has_origin = false
		else:
			fridge_player.global_position = position2.lerp(
				target, clampf(delta * FRIDGE_FLIGHT_RETURN_SPEED, 0.0, 1.0))


## 改变飞行方向: a click (a quick press that does not drag him) turns the flying fridge man
## around - and the 磁带机 dance the same way; a press-and-hold is the player taking the
## wheel instead.
func _flip_fridge_player_flight_dir() -> void:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	var pager_flying: bool = bool(fridge_player.call("is_pager_flying"))
	var dancing: bool = bool(fridge_player.call("is_cassette_dancing"))
	if not pager_flying and not dancing:
		return
	fridge_player_flight_dir = -fridge_player_flight_dir


## 打破第四面墙: the juggle's last tosses reached the camera - jolt the view and flash it.
func _on_fridge_player_screen_hit() -> void:
	fridge_screen_shake_time = FRIDGE_SCREEN_SHAKE_TIME
	fridge_screen_flash_time = FRIDGE_SCREEN_FLASH_TIME
	if fridge_screen_flash == null or not is_instance_valid(fridge_screen_flash):
		var layer := CanvasLayer.new()
		layer.name = "ScreenHitFlash"
		layer.layer = 90
		add_child(layer)
		fridge_screen_flash = ColorRect.new()
		fridge_screen_flash.name = "Flash"
		fridge_screen_flash.color = Color(1.0, 0.98, 0.9, 0.0)
		fridge_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fridge_screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fridge_screen_flash)


func _update_fridge_screen_shake(delta: float) -> void:
	if fridge_screen_shake_time > 0.0:
		fridge_screen_shake_time = maxf(fridge_screen_shake_time - delta, 0.0)
		var damp: float = fridge_screen_shake_time / FRIDGE_SCREEN_SHAKE_TIME
		if camera != null and is_instance_valid(camera):
			camera.offset = Vector2(
				sin(fridge_screen_shake_time * 74.0),
				cos(fridge_screen_shake_time * 63.0)) * FRIDGE_SCREEN_SHAKE_AMOUNT * damp
	elif camera != null and is_instance_valid(camera) and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
	if fridge_screen_flash != null and is_instance_valid(fridge_screen_flash):
		if fridge_screen_flash_time > 0.0:
			fridge_screen_flash_time = maxf(fridge_screen_flash_time - delta, 0.0)
			fridge_screen_flash.color = Color(
				1.0, 0.98, 0.9,
				0.85 * (fridge_screen_flash_time / FRIDGE_SCREEN_FLASH_TIME))
		elif fridge_screen_flash.color.a != 0.0:
			fridge_screen_flash.color = Color(1.0, 0.98, 0.9, 0.0)


func _is_ball_over_fridge_player(ball: Control) -> bool:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return false
	if ball == null or not is_instance_valid(ball):
		return false
	# The ball lives in the overlay CanvasLayer (screen space); map its center
	# back into world space and test it against the player's hit rectangle.
	var screen_center: Vector2 = ball.global_position + ball.size * 0.5
	var world_center: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_center
	return FRIDGE_PLAYER_DRAG_HIT_RECT.has_point(fridge_player.to_local(world_center))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		# Real mouse activity is the only thing that counts as "interacting" with
		# the pair, so the idle rotation stays out of the way while the player is
		# doing something - but a pointer merely parked on a character does not.
		fridge_idle_input_age = 0.0
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
	# 全部解锁: every item is owned from the start (see _ensure_all_fridge_items_owned).
	_ensure_all_fridge_items_owned()
	_spawn_fridge_player()
	_spawn_fridge_cat_pet()
	_spawn_fridge_gallery_stand()
	_spawn_fridge_box()
	_create_fridge_spray()
	_create_fridge_overlay()
	_refresh_fridge_ui()
	is_changing_scene = false


func _spawn_fridge_player() -> void:
	fridge_player = FridgePomodoroPlayerScript.new()
	fridge_player.name = "Player"
	fridge_player.global_position = Vector2(0.0, 170.0)
	fridge_player.performance_finished.connect(_on_fridge_performance_finished)
	# 打破第四面墙: the juggle's last tosses hit the CAMERA, so the view itself takes the blow.
	fridge_player.screen_hit.connect(_on_fridge_player_screen_hit)
	world.add_child(fridge_player)


func _spawn_fridge_cat_pet() -> void:
	fridge_cat_pet = FridgeCatPetScript.new()
	fridge_cat_pet.name = "FridgeCatPet"
	fridge_cat_pet.global_position = FRIDGE_CAT_POSITION
	fridge_cat_pet.clicked.connect(_on_fridge_cat_pet_clicked)
	fridge_cat_pet.close_requested.connect(_on_fridge_cat_pet_close_requested)
	world.add_child(fridge_cat_pet)


func _spawn_fridge_gallery_stand() -> void:
	fridge_gallery_stand = ActionSkeletonStandScript.new()
	fridge_gallery_stand.name = "ActionSkeletonStand"
	fridge_gallery_stand.art_texture_path = FRIDGE_GALLERY_STAND_TEXTURE
	# 缩小一倍: half the plugin's default art height (see FRIDGE_GALLERY_STAND_DISPLAY_HEIGHT).
	fridge_gallery_stand.call("set", "display_height", FRIDGE_GALLERY_STAND_DISPLAY_HEIGHT)
	fridge_gallery_stand.global_position = FRIDGE_GALLERY_STAND_POSITION
	fridge_gallery_stand.toggled.connect(_on_fridge_gallery_stand_toggled)
	world.add_child(fridge_gallery_stand)


func _spawn_fridge_box() -> void:
	fridge_box = FridgeChestScript.new()
	fridge_box.name = "PropBox"
	fridge_box.closed_art_path = FRIDGE_BOX_CLOSED_TEXTURE
	fridge_box.open_art_path = FRIDGE_BOX_OPEN_TEXTURE
	fridge_box.call("set", "display_height", FRIDGE_BOX_DISPLAY_HEIGHT)
	fridge_box.global_position = FRIDGE_BOX_POSITION
	fridge_box.toggled.connect(_on_fridge_box_toggled)
	world.add_child(fridge_box)


func _clear_world() -> void:
	if world == null:
		return
	for child in world.get_children():
		child.queue_free()
	fridge_player = null
	fridge_cat_pet = null
	fridge_gallery_stand = null
	fridge_box = null
	fridge_round_choice_root = null


func _on_return_door_clicked(_level_id: String) -> void:
	if is_changing_scene:
		return
	_save_fridge_progress()
	is_changing_scene = true
	call_deferred("_build_level")


func _on_fridge_cat_pet_clicked() -> void:
	_show_fridge_item_toolbar()


## Clicking the cat while its mouth is open closes the inventory again.
func _on_fridge_cat_pet_close_requested() -> void:
	_on_fridge_item_toolbar_close_pressed()


func _clear_overlay() -> void:
	if fridge_overlay != null and is_instance_valid(fridge_overlay):
		fridge_overlay.queue_free()
	fridge_overlay = null
	fridge_overlay_root = null
	fridge_item_panel = null
	fridge_settings_panel = null
	fridge_gallery_panel = null
	fridge_box_panel = null
	fridge_coin_label = null
	fridge_status_label = null
	fridge_timer_label = null
	fridge_reward_label = null
	fridge_reset_button = null
	_clear_fridge_round_choices()
	fridge_shop_list = null
	fridge_yarn_pile = null
	fridge_yarn_balls.clear()
	fridge_nose_button = null
	fridge_yarn_spawn.clear()
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
	fridge_item_panel_offset = Vector2.ZERO
	fridge_settings_panel_has_manual_position = false
	fridge_player_is_dragging = false
	fridge_player_drag_offset = Vector2.ZERO
	fridge_player_flight_dir = 1.0
	fridge_player_flight_origin = Vector2.ZERO
	fridge_player_flight_has_origin = false
	fridge_player_drag_moved = false
	fridge_player_press_msec = 0
	fridge_player_press_position = Vector2.ZERO
	fridge_player_juggling = false


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
	_create_fridge_gallery_panel()
	_create_fridge_box_panel()
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
	# Margins scale with the panel (500px) so the pile still sits inside the
	# cat mouth art, which is stretched to the full panel size.
	transparent_style.content_margin_left = 79.0
	transparent_style.content_margin_top = 145.0
	transparent_style.content_margin_right = 79.0
	transparent_style.content_margin_bottom = 66.0
	fridge_item_panel.add_theme_stylebox_override("panel", transparent_style)
	fridge_overlay_root.add_child(fridge_item_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	fridge_item_panel.add_child(content)

	# The mouth panel shows only the cat mouth art: no title, no coin readout and
	# no close button (clicking the cat again closes it). The header is kept as
	# an invisible strip so the panel can still be nudged by hand.
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, FRIDGE_ITEM_HEADER_DRAG_HEIGHT)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(Callable(self, "_on_fridge_panel_drag_handle_input").bind(fridge_item_panel, "item"))
	content.add_child(header)

	fridge_yarn_pile = Control.new()
	fridge_yarn_pile.name = "YarnPile"
	fridge_yarn_pile.custom_minimum_size = FRIDGE_YARN_PILE_SIZE
	fridge_yarn_pile.size = FRIDGE_YARN_PILE_SIZE
	fridge_yarn_pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fridge_yarn_pile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fridge_yarn_pile.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(fridge_yarn_pile)

	for i in FRIDGE_ITEMS.size():
		# 猫嘴里去掉: skip the items that are not mouth items - no ball for them.
		if not _is_fridge_mouth_item(str(FRIDGE_ITEMS[i].get("id", ""))):
			continue
		_create_fridge_yarn_ball(FRIDGE_ITEMS[i], i)

	# Over the painted nose: hover blushes it red; clicking re-deals the balls.
	fridge_nose_button = FridgeCatNoseScript.new()
	fridge_nose_button.name = "CatNose"
	fridge_nose_button.visible = false
	fridge_nose_button.pressed.connect(_on_fridge_cat_nose_pressed)
	fridge_overlay_root.add_child(fridge_nose_button)

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


## The wardrobe prop's action gallery panel (reusable addon component):
## shows the fridge man's animation performances; clicking an entry makes
## him perform it.
func _create_fridge_gallery_panel() -> void:
	fridge_gallery_panel = ActionGalleryPanelScript.new()
	fridge_gallery_panel.name = "ActionGalleryPanel"
	fridge_gallery_panel.visible = false
	fridge_overlay_root.add_child(fridge_gallery_panel)
	# 道具箱同款纸片 UI: the same style as the prop box - only the column count and the
	# pocket cell art are the gallery's own, everything else is the panel's default (cream
	# paper board + stars, 下拉查看更多). The 标题 is dropped, and the panel shows NO scroll
	# slider at all (the mouse wheel still pulls the list down).
	fridge_gallery_panel.call("setup", FRIDGE_GALLERY_TITLE, FRIDGE_GALLERY_ENTRIES, {
		# 摊开的书: the notebook's panel IS the book - the items print straight on its cream
		# pages (a 2-wide grid of big cells, no cell artwork), with the bookmark ribbons tucked
		# into the top right corner. The cell/icon sizes are picked so the panel lands on the
		# book art's own 4:3 aspect.
		"board": "book",
		# 去掉边框: the cells carry NO artwork - a framed slot looked unnatural, so the icons and
		# names print straight on the book's pages.
		"cell_texture": "none",
		"grid_columns": 2,
		"card_size": FRIDGE_GALLERY_BOOK_CARD_SIZE,
		"icon_size": FRIDGE_GALLERY_BOOK_ICON_SIZE,
		"card_gap": FRIDGE_GALLERY_BOOK_CARD_GAP,
		# 把文字说明去掉: the book's cells are ICON ONLY - a hover pops the paper 说明框 with the
		# entry's name and description instead.
		"cell_labels": false,
		# 文字说明: a tighter cell inset leaves room for the icon without growing the card (and with
		# it the whole book) any further.
		"cell_margin": 5.0,
		"show_title": false,
		# 底部那段提示: the 下拉查看更多 line is dropped (the wheel still pulls the list down).
		"show_hint": false,
		"scrollbar_style": "hidden",
		# 向下箭头: instead of that text line the page shows a small paper arrow on its right edge,
		# fading in and out (若隐若现) - and only while there is another page below.
		"scroll_arrow": true,
		"tabs": [
			{"id": FRIDGE_GALLERY_TAB_SKELETON, "name": "骨架", "labels": false, "entries": FRIDGE_GALLERY_ENTRIES},
			{"id": FRIDGE_GALLERY_TAB_ITEMS, "name": "猫嘴物品", "labels": false, "entries": _fridge_unlocked_item_entries()},
		],
	})
	fridge_gallery_panel.entry_pressed.connect(_on_fridge_gallery_entry_pressed)
	# 分页: a page can be a different height, so the panel is re-placed after every switch.
	fridge_gallery_panel.tab_changed.connect(_on_fridge_gallery_tab_changed)


## 猫嘴物品: every unlocked item as one card - the same 图标 the cat's own item badge uses
## (paper_icon_<id>.png). Ids are prefixed so a click on a card can never be mistaken for a
## performance entry.
func _fridge_unlocked_item_entries() -> Array:
	var entries: Array = []
	for item: Dictionary in FRIDGE_ITEMS:
		var item_id := str(item.get("id", ""))
		# 猫嘴里去掉: the walkman and the VHS tape are not mouth items any more.
		if item_id.is_empty() or not _is_fridge_mouth_item(item_id) or not fridge_owned_items.has(item_id):
			continue
		entries.append({
			"id": "item_%s" % item_id,
			# 悬停说明框: the name line is the item's own name and the description line carries its
			# 持续时间 - the 数字 badge is gone from this page, so the box is where the length is
			# read now ("基础待机动画 · 30 秒").
			"name": str(item.get("name", item_id)),
			"description": _fridge_item_description(item),
			"icon": "res://assets/generated/paper_icon_%s.png" % item_id,
		})
	return entries


## 悬停说明框: the item's own 描述 with its 持续时间 appended, so the hover box reads
## "名称" / "描述 · 30 秒" (or just the duration when the item has no description).
func _fridge_item_description(item: Dictionary) -> String:
	var item_id := str(item.get("id", ""))
	var description := str(item.get("description", ""))
	var duration_text := _format_fridge_duration(_get_fridge_item_duration(item_id))
	if description.is_empty():
		return duration_text
	return "%s · %s" % [description, duration_text]


func _on_fridge_gallery_tab_changed(_tab_id: String) -> void:
	if fridge_gallery_panel == null or not is_instance_valid(fridge_gallery_panel):
		return
	if fridge_gallery_panel.visible:
		fridge_gallery_panel.call("popup_at", _fridge_gallery_popup_position())


## 书的上方: the notebook's panel corner - pinned directly above the STAND's own art (see
## _fridge_prop_panel_position). Recomputed every frame while the panel is open, so a moved stand
## can never leave the opened book sitting over it.
func _fridge_gallery_popup_position() -> Vector2:
	if fridge_gallery_stand == null or not is_instance_valid(fridge_gallery_stand):
		return _clamp_panel_to_screen(Vector2.ZERO, fridge_gallery_panel.size)
	return _fridge_prop_panel_position(fridge_gallery_stand, fridge_gallery_panel, FRIDGE_GALLERY_STAND_GAP)


## 屏幕内: keeps a panel's auto position inside the viewport, so a host standing near an edge
## cannot push its panel off-screen.
func _clamp_panel_to_screen(top_left: Vector2, panel_size: Vector2) -> Vector2:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var lowest_x: float = maxf(FRIDGE_PANEL_SCREEN_MARGIN, screen.x - panel_size.x - FRIDGE_PANEL_SCREEN_MARGIN)
	var lowest_y: float = maxf(FRIDGE_PANEL_SCREEN_MARGIN, screen.y - panel_size.y - FRIDGE_PANEL_SCREEN_MARGIN)
	return Vector2(
		clampf(top_left.x, FRIDGE_PANEL_SCREEN_MARGIN, lowest_x),
		clampf(top_left.y, FRIDGE_PANEL_SCREEN_MARGIN, lowest_y)
	)


## 箱子上方: the briefcase's prop box panel corner - the same 正上方 rule as the book's, measured off
## the chest's own art (the open art's top sits well above the chest's origin, so the art itself is
## what the panel is pinned to).
func _fridge_box_popup_position() -> Vector2:
	if fridge_box == null or not is_instance_valid(fridge_box):
		return _clamp_panel_to_screen(Vector2.ZERO, fridge_box_panel.size)
	return _fridge_prop_panel_position(fridge_box, fridge_box_panel, FRIDGE_BOX_PANEL_GAP)


## 正上方: a prop's panel sits DIRECTLY ABOVE that prop - horizontally centred on the prop's own ART
## and with its bottom edge `gap` clear of the art's top - so a moved prop is never covered by the UI
## it opened. The art is MEASURED (the union of the prop's visible sprite children) because a prop's
## origin sits well below its picture. A panel can never rise above the screen's top margin, so when
## that clamp would push the panel down over the prop (the prop was dragged to the very top), the
## panel hangs BELOW the prop instead of covering it.
func _fridge_prop_panel_position(prop: Node, panel: Control, gap: float) -> Vector2:
	var panel_size: Vector2 = panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel.custom_minimum_size
	var art := _fridge_prop_art_rect(prop)
	if art.size == Vector2.ZERO:
		return _clamp_panel_to_screen(Vector2.ZERO, panel_size)
	var target := Vector2(art.get_center().x - panel_size.x * 0.5, art.position.y - gap - panel_size.y)
	if maxf(target.y, FRIDGE_PANEL_SCREEN_MARGIN) + panel_size.y > art.position.y + 0.5:
		var below: float = art.end.y + gap
		var screen: Vector2 = get_viewport().get_visible_rect().size
		if below + panel_size.y <= screen.y - FRIDGE_PANEL_SCREEN_MARGIN:
			target.y = below
	return _clamp_panel_to_screen(target, panel_size)


## The prop's ART rect in screen space: the union of its visible drawn children, mapped through the
## camera. The panel is pinned above the PICTURE rather than above the node's origin.
func _fridge_prop_art_rect(prop: Node) -> Rect2:
	var rect := Rect2()
	var found := false
	for node: Node in prop.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite == null or sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var sprite_rect := _fridge_sprite_art_rect(sprite, sprite.texture)
		rect = sprite_rect if not found else rect.merge(sprite_rect)
		found = true
	for node: Node in prop.find_children("*", "AnimatedSprite2D", true, false):
		var anim := node as AnimatedSprite2D
		if anim == null or anim.sprite_frames == null or not anim.is_visible_in_tree():
			continue
		var frame_texture: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		if frame_texture == null:
			continue
		var anim_rect := _fridge_sprite_art_rect(anim, frame_texture)
		rect = anim_rect if not found else rect.merge(anim_rect)
		found = true
	if not found:
		return Rect2()
	return Rect2(get_viewport().get_canvas_transform() * rect.position, rect.size)


## A sprite node's drawn rect in canvas space. **Sprite2D has NO get_global_rect()** (that is a Control
## method), so the rect is rebuilt from the global transform + the texture size and the node's own
## `offset` / `centered` flags. Rotation is ignored - the props never rotate.
func _fridge_sprite_art_rect(sprite: Node2D, texture: Texture2D) -> Rect2:
	# named `xform`, not `transform`: a local called `transform` shadows Node2D's own property.
	var xform := sprite.get_global_transform()
	var art_scale: Vector2 = xform.get_scale()
	var size: Vector2 = texture.get_size() * art_scale
	var top_left: Vector2 = xform.origin
	if sprite is Sprite2D:
		var plain := sprite as Sprite2D
		top_left -= plain.offset * art_scale
		if plain.centered:
			top_left -= size * 0.5
	elif sprite is AnimatedSprite2D:
		var anim := sprite as AnimatedSprite2D
		top_left -= anim.offset * art_scale
		if anim.centered:
			top_left -= size * 0.5
	return Rect2(top_left, size)


func _on_fridge_gallery_stand_toggled(open: bool) -> void:
	if fridge_gallery_panel == null:
		return
	# Only one of the two left-side panels is shown at a time.
	if open:
		_close_fridge_box(false)
	# 分页: the 猫嘴物品 page lists what is unlocked, so it is refreshed on every open (an
	# unlock while the panel was closed then shows up), and the panel is re-placed after the
	# rebuild in case the page's height changed.
	fridge_gallery_panel.call("update_tab_entries", FRIDGE_GALLERY_TAB_ITEMS, _fridge_unlocked_item_entries())
	fridge_gallery_panel.visible = open
	if open and fridge_gallery_stand != null and is_instance_valid(fridge_gallery_stand):
		fridge_gallery_panel.call("popup_at", _fridge_gallery_popup_position())


func _on_fridge_gallery_entry_pressed(entry_id: String) -> void:
	# 猫嘴物品: the second tab's cards only show what is unlocked in the cat's mouth - a click
	# on one is informational and must not disturb the idle rotation or start a performance.
	if entry_id.begins_with("item_"):
		return
	# Each gallery entry maps to an animation the fridge man or the cat performs.
	# A manual preview also keeps the idle rotation quiet for its whole length.
	# The two characters keep their own bits, so picking a cat entry does NOT cancel
	# what the fridge man is doing - but a performance preview does replace his own
	# idle business (see FridgePomodoroPlayer.play_juggle_preview).
	fridge_idle_suppress = FRIDGE_GALLERY_PREVIEW_DURATION + 1.0
	match entry_id:
		"juggle":
			if fridge_player != null and is_instance_valid(fridge_player):
				fridge_player.call("play_juggle_preview", FRIDGE_GALLERY_PREVIEW_DURATION)
		"man_rest_stand":
			_play_fridge_man_idle_action("rest_stand")
		"man_smoke":
			_play_fridge_man_idle_action("smoke")
		"man_pet_cat":
			_play_fridge_man_idle_action("pet_cat")
		"man_pager":
			fridge_idle_suppress = FRIDGE_PAGER_PREVIEW_DURATION + 1.0
			if fridge_player != null and is_instance_valid(fridge_player):
				fridge_player.call("play_pager_preview", FRIDGE_PAGER_PREVIEW_DURATION)
		"man_doze":
			fridge_idle_suppress = _fridge_idle_action_duration("doze") + 1.0
			_play_fridge_man_idle_action("doze")
		"man_cassette":
			# 磁带机: the boombox dance the cat's bag unlocks - the same performance its 2 分钟 round
			# plays (see FridgePomodoroPlayer.play_cassette_preview).
			if fridge_player != null and is_instance_valid(fridge_player):
				fridge_player.call("play_cassette_preview", FRIDGE_GALLERY_PREVIEW_DURATION)
		"man_tv":
			# 电视机: the fisherman poling his 乌篷船 (see play_tv_preview).
			if fridge_player != null and is_instance_valid(fridge_player):
				fridge_player.call("play_tv_preview", FRIDGE_GALLERY_PREVIEW_DURATION)
		"cat_rest_stand":
			_play_fridge_cat_idle_action("rest_stand")
		"cat_doze":
			fridge_idle_suppress = _fridge_idle_action_duration("doze") + 1.0
			_play_fridge_cat_idle_action("doze")
		"cat_play_ball":
			_play_fridge_cat_idle_action("play_ball")
		"cat_run_circle":
			_start_fridge_cat_orbit(FRIDGE_CAT_ORBIT_DURATION)
		_:
			pass


## Plays one of the fridge man's idle ("待机") animations. 摸摸小猫 is special: the
## cat has to come over and sit under his hand first.
func _play_fridge_man_idle_action(action_id: String) -> void:
	if action_id == "pet_cat":
		_start_fridge_pet_cat()
		return
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	fridge_player.call("play_idle_action", action_id, _fridge_idle_action_duration(action_id))


## Plays one of the cat's idle ("待机") animations in place.
func _play_fridge_cat_idle_action(action_id: String) -> void:
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		return
	fridge_cat_pet.call("play_idle_action", action_id, _fridge_idle_action_duration(action_id))


## (吐毛球's random prop-box item picker was removed with the 吐毛球 action.)


func _fridge_idle_action_duration(action_id: String) -> float:
	return float(FRIDGE_IDLE_ACTION_DURATIONS.get(action_id, FRIDGE_IDLE_ACTION_DURATION))


## The orbit ellipse's point at fraction `t` of the trip round him: t = 0 is the FRONT,
## t = 0.5 the LEFT side, t = 1 BEHIND. The approach aims at t = 0 and the return leaves
## from t = 1, so both hand offs stay continuous.
func _fridge_cat_orbit_point(t: float) -> Vector2:
	var angle: float = PI * 0.5 + t * PI
	return Vector2(
		fridge_cat_orbit_center.x + cos(angle) * FRIDGE_CAT_ORBIT_RADIUS,
		fridge_cat_orbit_base_y + sin(angle) * FRIDGE_CAT_ORBIT_DEPTH - FRIDGE_CAT_ORBIT_DEPTH
	)


## 小猫绕着冰箱人跑圈: the cat circles the fridge man on a flattened ellipse while playing
## 玩球's animation (without the mouse), then trots back to where it was standing.
func _start_fridge_cat_orbit(duration: float) -> void:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		return
	if fridge_cat_motion != "" or bool(fridge_cat_pet.get("is_bag_open")) or bool(fridge_cat_pet.get("is_dragging")):
		return
	fridge_cat_home = fridge_cat_pet.global_position
	fridge_cat_last_position = fridge_cat_home
	fridge_cat_orbit_center = fridge_player.global_position
	fridge_cat_orbit_base_y = fridge_cat_home.y
	fridge_cat_orbit_start = _fridge_cat_orbit_point(0.0)
	# 从站立的位置开始移动: the trip OPENS with an approach from where the cat is standing,
	# not with a jump onto the ellipse.
	fridge_cat_motion = "approach"
	fridge_cat_motion_time = 0.0
	fridge_cat_motion_total = FRIDGE_CAT_ORBIT_APPROACH_TIME
	fridge_cat_hop_clock = 0.0
	fridge_cat_choreo_time = 0.0
	fridge_cat_choreo_total = FRIDGE_CAT_ORBIT_APPROACH_TIME + maxf(duration, 0.5) + FRIDGE_CAT_RETURN_TIME
	# One action for the whole trip (hop out, circle, hop home), so no phase boundary can
	# swap the art or reset the flags midway.
	fridge_cat_pet.call("play_idle_action", "play_ball", fridge_cat_choreo_total + 1.0)
	fridge_cat_pet.call("set_play_toy_hidden", true)
	fridge_cat_pet.call("set_idle_action_fps_scale", FRIDGE_CAT_ORBIT_FPS_SCALE)


## 前后遮挡: while the cat circles the fridge man it must pass behind him on the far
## half of the circle and in front of him on the near half.
func _set_fridge_cat_orbit_depth(behind: bool) -> void:
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		return
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	var offset: int = FRIDGE_CAT_BACK_Z_OFFSET if behind else FRIDGE_CAT_FRONT_Z_OFFSET
	fridge_cat_pet.z_index = fridge_player.z_index + offset


## 摸摸小猫: the cat sits under the fridge man's hand while he strokes it, then
## trots home again.
func _start_fridge_pet_cat() -> void:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		return
	if fridge_cat_motion != "" or bool(fridge_cat_pet.get("is_bag_open")) or bool(fridge_cat_pet.get("is_dragging")):
		return
	var duration: float = _fridge_idle_action_duration("pet_cat")
	fridge_cat_home = fridge_cat_pet.global_position
	fridge_cat_pet.global_position = fridge_player.global_position + FRIDGE_PET_CAT_OFFSET
	fridge_cat_last_position = fridge_cat_pet.global_position
	fridge_cat_motion = "wait"
	fridge_cat_motion_time = 0.0
	fridge_cat_motion_total = duration
	fridge_player.call("play_idle_action", "pet_cat", duration + 1.4)
	fridge_cat_pet.call("play_idle_action", "rest_stand", duration + 1.4)


func _start_fridge_cat_return(run_cycle_time: float) -> void:
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		return
	fridge_cat_return_from = fridge_cat_pet.global_position
	fridge_cat_last_position = fridge_cat_return_from
	# 前后遮挡 follows the same line as the other two phases instead of assuming the cat
	# starts the trip home on the ground: it starts at the man's BACK, still high up behind
	# him, and only comes in front as it drops down to its own ground line. Forcing "in
	# front" here drew it in front for exactly one frame, then snapped it back behind.
	_set_fridge_cat_orbit_depth(fridge_cat_return_from.y < fridge_cat_orbit_base_y + FRIDGE_CAT_BEHIND_LINE)
	fridge_cat_motion = "return"
	fridge_cat_motion_time = 0.0
	fridge_cat_motion_total = maxf(run_cycle_time, 0.2)
	# No new action here: the 玩球 clip that started with the approach keeps playing, so
	# the trip home bounces exactly like the trip out instead of switching to 跑.


## Drives the cat while one of the two "together" idle bits is playing.
func _update_fridge_cat_motion(delta: float) -> void:
	if fridge_cat_motion == "":
		return
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		fridge_cat_motion = ""
		return
	# A drag by the player always wins over the idle choreography.
	if bool(fridge_cat_pet.get("is_dragging")):
		fridge_cat_motion = ""
		fridge_cat_pet.call("stop_idle_action")
		return
	# 面朝方向: read off where the cat actually moved and hand the direction to the pet,
	# which decides for itself whether its current art needs mirroring at all - only the
	# side-view run does (see FridgeCatPet.set_facing).
	var travel: float = fridge_cat_pet.global_position.x - fridge_cat_last_position.x
	if absf(travel) > 0.05:
		fridge_cat_pet.call("set_facing", signf(travel))
	fridge_cat_last_position = fridge_cat_pet.global_position
	fridge_cat_motion_time += delta
	fridge_cat_hop_clock += delta
	fridge_cat_choreo_time += delta
	var t: float = fridge_cat_motion_time / maxf(fridge_cat_motion_total, 0.001)
	# 一蹦一跳: ONE continuous bounce clock for the whole trip, its amplitude faded in and
	# out at the ends, so the cat neither takes off on the first frame nor lands mid air.
	var hop_ramp: float = clampf(fridge_cat_choreo_time / FRIDGE_CAT_HOP_RAMP, 0.0, 1.0) \
			* clampf((fridge_cat_choreo_total - fridge_cat_choreo_time) / FRIDGE_CAT_HOP_RAMP, 0.0, 1.0)
	var hop: float = absf(sin(fridge_cat_hop_clock * TAU * FRIDGE_CAT_ORBIT_HOP_RATE)) \
			* FRIDGE_CAT_ORBIT_HOP * hop_ramp
	match fridge_cat_motion:
		"approach":
			if t >= 1.0:
				fridge_cat_motion = "orbit"
				fridge_cat_motion_time = 0.0
				return
			var onward: Vector2 = fridge_cat_home.lerp(fridge_cat_orbit_start, t)
			fridge_cat_pet.global_position = Vector2(onward.x, onward.y - hop)
			_set_fridge_cat_orbit_depth(onward.y < fridge_cat_orbit_base_y + FRIDGE_CAT_BEHIND_LINE)
		"orbit":
			if t >= 1.0:
				_start_fridge_cat_return(FRIDGE_CAT_RETURN_TIME)
				return
			var point: Vector2 = _fridge_cat_orbit_point(t)
			fridge_cat_pet.global_position = Vector2(point.x, point.y - hop)
			_set_fridge_cat_orbit_depth(point.y < fridge_cat_orbit_base_y + FRIDGE_CAT_BEHIND_LINE)
		"wait":
			if t >= 1.0:
				_start_fridge_cat_return(FRIDGE_CAT_RETURN_TIME)
		"return":
			if t >= 1.0:
				fridge_cat_pet.global_position = fridge_cat_home
				fridge_cat_motion = ""
				fridge_cat_pet.call("stop_idle_action")
				fridge_cat_pet.call("set_play_toy_hidden", false)
				fridge_cat_pet.call("set_idle_action_fps_scale", 1.0)
				return
			var back: Vector2 = fridge_cat_return_from.lerp(fridge_cat_home, t)
			fridge_cat_pet.global_position = Vector2(back.x, back.y - hop)
			_set_fridge_cat_orbit_depth(back.y < fridge_cat_orbit_base_y + FRIDGE_CAT_BEHIND_LINE)


## The idle rotation: ten seconds after the last interaction, one of the two
## characters plays one of its idle animations by itself. Moving the mouse onto
## either of them cancels what is playing and restarts the wait.
func _update_fridge_idle(delta: float) -> void:
	fridge_idle_input_age += delta
	if fridge_idle_suppress > 0.0:
		fridge_idle_suppress = maxf(fridge_idle_suppress - delta, 0.0)
	_update_fridge_cat_motion(delta)
	if not fridge_idle_rotation_enabled:
		return
	# The pointer being moved onto one of the two characters: they drop back into
	# their default idle pose and the pause starts over, so it does not fire again
	# the moment the pointer leaves. Only RECENT mouse activity counts, though -
	# a pointer left resting on a character must not suppress the rotation for
	# good, or the player watching the fridge man would never see him idle. A
	# manual gallery pick is deliberate either way, so it plays out regardless.
	if fridge_idle_suppress <= 0.0 \
			and fridge_idle_input_age <= FRIDGE_IDLE_INPUT_GRACE \
			and _is_fridge_idle_pointer_interacting():
		_stop_fridge_idle_actions()
		fridge_idle_timer = FRIDGE_IDLE_DELAY
		return
	if not _can_play_fridge_idle():
		# Busy (or a manual preview is playing): hold the countdown where it is,
		# and restart one only if the pause had already run out.
		fridge_idle_timer = maxf(fridge_idle_timer, 0.0)
		if fridge_idle_timer <= 0.0:
			fridge_idle_timer = FRIDGE_IDLE_DELAY
		return
	if fridge_idle_timer > 0.0:
		fridge_idle_timer -= delta
		return
	# The pause is over: play the next animation out of the shuffled bag, then wait
	# out a fresh pause. Every idle animation is played once before any repeats.
	fridge_idle_timer = FRIDGE_IDLE_DELAY
	if fridge_idle_bag.is_empty():
		fridge_idle_bag = _build_fridge_idle_bag()
	var pick: Dictionary = fridge_idle_bag.pop_front()
	if str(pick["who"]) == "man":
		_play_fridge_man_idle_action(str(pick["action"]))
	elif str(pick["action"]) == "run":
		_start_fridge_cat_orbit(FRIDGE_CAT_ORBIT_DURATION)
	else:
		_play_fridge_cat_idle_action(str(pick["action"]))


## One shuffled bag holding every idle animation of both characters: each one is
## played once before any of them comes round again. The two take turns and the
## fridge man leads, so the animation the player sees right after the pause is his.
func _build_fridge_idle_bag() -> Array:
	var man_group: Array = []
	for action_id: String in FRIDGE_IDLE_MAN_ACTIONS:
		man_group.append({"who": "man", "action": action_id})
	var cat_group: Array = []
	for action_id: String in FRIDGE_IDLE_CAT_ACTIONS:
		cat_group.append({"who": "cat", "action": action_id})
	man_group = _order_fridge_idle_group(man_group)
	cat_group = _order_fridge_idle_group(cat_group)
	# 冰箱人先来: alternate the two, the fridge man first, so a rotation turn is
	# never "nobody visibly moved" straight after the pause.
	var bag: Array = []
	while not man_group.is_empty() or not cat_group.is_empty():
		if not man_group.is_empty():
			bag.append(man_group.pop_front())
		if not cat_group.is_empty():
			bag.append(cat_group.pop_front())
	return bag


## Shuffles one character's animations, but keeps its "stand still" pose last:
## 站立歇息 only replays the character's default idle pose, so as a first pick it
## would look like the rotation had done nothing at all.
func _order_fridge_idle_group(entries: Array) -> Array:
	var performing: Array = []
	var stand_still: Array = []
	for entry: Dictionary in entries:
		if str(entry["action"]) == "rest_stand":
			stand_still.append(entry)
		else:
			performing.append(entry)
	performing.shuffle()
	return performing + stand_still


## True while the pointer rests on the fridge man or the cat.
func _is_fridge_idle_pointer_interacting() -> bool:
	if _is_mouse_over_fridge_player():
		return true
	if fridge_cat_pet != null and is_instance_valid(fridge_cat_pet):
		# The cat owns an Area2D, so the engine already tracks its hover for us.
		return float(fridge_cat_pet.get("hover_amount")) > 0.0
	return false


## Idle animations only play while nothing else needs the characters: no running
## pomodoro round, no round-end choice buttons, no manual gallery preview, no
## half-finished walk, bag shut and neither character being dragged.
func _can_play_fridge_idle() -> bool:
	if fridge_phase != "idle" or fridge_round_choices_pending or fridge_round_ending_in_flight:
		return false
	if fridge_idle_suppress > 0.0 or fridge_cat_motion != "":
		return false
	if fridge_player_is_dragging:
		return false
	if fridge_player != null and is_instance_valid(fridge_player) and bool(fridge_player.call("is_idle_action_active")):
		return false
	if fridge_cat_pet == null or not is_instance_valid(fridge_cat_pet):
		return false
	if bool(fridge_cat_pet.get("is_bag_open")) or bool(fridge_cat_pet.get("is_dragging")):
		return false
	return true


## Cancels any idle work in progress so a session or a round-end preview starts
## from a clean, idle pair.
func _stop_fridge_idle_actions() -> void:
	fridge_idle_timer = 0.0
	if fridge_player != null and is_instance_valid(fridge_player):
		fridge_player.call("stop_idle_action")
	if fridge_cat_pet != null and is_instance_valid(fridge_cat_pet):
		# Any choreography (orbit, petting, walk home) ends with the cat back on
		# its home spot, so the pair is clean again.
		if fridge_cat_motion != "":
			fridge_cat_pet.global_position = fridge_cat_home
		_set_fridge_cat_orbit_depth(false)
		fridge_cat_pet.call("stop_idle_action")
	fridge_cat_motion = ""
	fridge_cat_motion_time = 0.0


## 喷射: the node that throws the spray pieces. It sits in the world just in front
## of the fridge man (z 13 against his 12), so the glyphs burst out over him.
func _create_fridge_spray() -> void:
	fridge_spray = FridgeGlyphSprayScript.new()
	fridge_spray.name = "GlyphSpray"
	fridge_spray.z_index = 13
	fridge_spray.set("ground_y", FRIDGE_SPRAY_GROUND_Y)
	world.add_child(fridge_spray)
	set_fridge_spray_payload(FRIDGE_SPRAY_PAYLOAD)


## Swaps what the spray throws (see FRIDGE_SPRAY_PAYLOADS): the 字体 shower can
## become any other prop by pointing this at another entry.
func set_fridge_spray_payload(payload_id: String) -> void:
	if not FRIDGE_SPRAY_PAYLOADS.has(payload_id):
		return
	fridge_spray_payload_id = payload_id
	if fridge_spray == null or not is_instance_valid(fridge_spray):
		return
	fridge_spray.call("set_payload", FRIDGE_SPRAY_PAYLOADS[payload_id])


## Drives the spray: while the pager reaction has him levitating with the device,
## the pieces squirt out from underneath it. He stops emitting the moment the
## levitation ends - whatever is already in the air falls on and vanishes where it
## lands, so the shower never snaps away mid-flight.
func _update_fridge_spray() -> void:
	if fridge_spray == null or not is_instance_valid(fridge_spray):
		return
	var levitating := false
	if fridge_player != null and is_instance_valid(fridge_player):
		levitating = bool(fridge_player.call("is_pager_levitating"))
		if levitating:
			var device: Vector2 = fridge_player.call("get_pager_device_global_position")
			fridge_spray.set("origin", device + FRIDGE_SPRAY_OFFSET)
	fridge_spray.set("emitting", levitating)


## The prop box (reuses the chest art): picking an object swaps what the
## fridge man juggles — live, even mid-performance.
func _create_fridge_box_panel() -> void:
	fridge_box_panel = ActionGalleryPanelScript.new()
	fridge_box_panel.name = "PropBoxPanel"
	fridge_box_panel.visible = false
	fridge_overlay_root.add_child(fridge_box_panel)
	fridge_box_panel.call("setup", FRIDGE_BOX_TITLE, FRIDGE_BOX_ENTRIES, {
		# 公文包: the board IS the opened case (its lid paints the title, its lining holds the page).
		"board": "case",
		"cell_texture": FRIDGE_BOX_CELL_TEXTURE,
		"icon_size": FRIDGE_BOX_ICON_SIZE,
		"action_icon_size": FRIDGE_BOX_ACTION_ICON_SIZE,
		"action_header_width": FRIDGE_BOX_ACTION_HEADER_WIDTH,
		"card_size": FRIDGE_BOX_CARD_SIZE,
		"cell_margin": FRIDGE_BOX_CELL_MARGIN,
		"grid_columns": FRIDGE_BOX_GRID_COLUMNS,
		# 固定托盘: pad the tray to 3x3, so the opened case shows its empty compartments too.
		"grid_min_rows": FRIDGE_BOX_GRID_ROWS,
		"visible_rows": FRIDGE_BOX_VISIBLE_ROWS,
		# 去掉标题: the opened case carries no word on its lid any more.
		"show_title": false,
		# 只留图标: the cells are their icons alone - and 不弹提示框, so hovering one shows nothing at all.
		"cell_labels": false,
		"hover_tooltip": false,
		# No 下拉查看更多 hint either - the opened case is a fixed tray and says nothing else.
		"show_hint": false,
		# 左侧改成按钮: the briefcase's left side is a column of action buttons; clicking one shows
		# that action's own items in the cells on the right (and a dropdown once there are more
		# actions than ACTION_BUTTON_MAX - which is how the actions added later get picked).
		"action_selector": true,
		# 从左到右: while the row holds another page of action logos a right-pointing paper arrow sits at
		# its end and pulses 若隐若现; a CLICK on it turns the row to that page, exactly like a wheel
		# notch over the panel.
		"action_arrow": true,
	})
	fridge_box_panel.call("set_selected", fridge_box_selected_id)
	fridge_box_panel.entry_pressed.connect(_on_fridge_box_entry_pressed)


func _on_fridge_box_toggled(open: bool) -> void:
	if fridge_box_panel == null:
		return
	# Only one of the two left-side panels is shown at a time.
	if open:
		_close_fridge_gallery(false)
	fridge_box_panel.visible = open
	if open and fridge_box != null and is_instance_valid(fridge_box):
		fridge_box_panel.call("popup_at", _fridge_box_popup_position())


func _on_fridge_box_entry_pressed(entry_id: String) -> void:
	match entry_id:
		"ball", "tomato":
			if fridge_player != null and is_instance_valid(fridge_player):
				fridge_player.call("set_juggle_projectile", entry_id)
		"spray_text":
			# 字体: the BB机's own item - the shower of paper glyphs.
			set_fridge_spray_payload("text")
		"spray_bubble":
			# 泡泡: the same BB机, squirting bubbles instead of the glyphs.
			set_fridge_spray_payload("bubble")
		"cassette_note", "tv_boat":
			# 只选不演: these two cards only mark the item in hand. They are what the two later cat-mouth
			# items UNLOCK (磁带机 -> 音乐符号, 电视机 -> 乌篷船); the items themselves are not cards, since
			# 不要显示自己的图标 - the action logo on the lid already IS that item's picture. Unlike 球 /
			# 番茄 / 字体 / 泡泡 (which swap a projectile or a payload) picking one starts NO performance.
			pass
		_:
			return
	fridge_box_selected_id = entry_id
	if fridge_box_panel != null and is_instance_valid(fridge_box_panel):
		fridge_box_panel.call("set_selected", entry_id)


## Closes the wardrobe prop's gallery panel (and syncs the prop's art state)
## without emitting its toggle signal.
func _close_fridge_gallery(animate_stand: bool) -> void:
	if fridge_gallery_panel != null:
		fridge_gallery_panel.visible = false
	if fridge_gallery_stand != null and is_instance_valid(fridge_gallery_stand):
		fridge_gallery_stand.call("set_open", false, animate_stand)


## Closes the prop box panel (and syncs the chest art state) without
## emitting its toggle signal.
func _close_fridge_box(animate_box: bool) -> void:
	if fridge_box_panel != null:
		fridge_box_panel.visible = false
	if fridge_box != null and is_instance_valid(fridge_box):
		fridge_box.call("set_open", false, animate_box)


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
		Vector2(37.0, 58.0),
		Vector2(90.0, 39.0),
		Vector2(142.0, 59.0),
		Vector2(197.0, 41.0),
		Vector2(250.0, 62.0),
		Vector2(118.0, 118.0),
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
	duration_label.text = "倒计时：%s" % _format_fridge_duration(_get_fridge_item_duration(item_id))
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
	# 猫嘴里去掉: an old save may still hold the walkman / vhs as the item in the cat's mouth - fall
	# back to the default so the mouth never carries an item it no longer lists.
	if not _is_fridge_mouth_item(fridge_active_item_id):
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
		# 猫嘴里去掉: these two have no mouth widgets at all, so there is nothing to refresh.
		if not _is_fridge_mouth_item(item_id):
			continue
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
			# 立即切换: an UNLOCKED ball stays clickable even while a session is running, so
			# clicking another unlocked item mid-round switches to its countdown animation at
			# once (FridgeYarnBall._gui_input swallows the press when it is not interactable,
			# which is what used to make the second click do nothing). A locked ball still
			# only becomes clickable in 待机 - clicking it is what asks to buy it.
			ball.call("set_state", unlocked, is_active, unlocked or fridge_phase == "idle", reward)
			# 数字: the mouth items carry NO hover tooltip - each ball floats how many whole minutes
			# one focused run takes ABOVE it (1 = 1 分钟, 2 = 2 分钟).
			ball.tooltip_text = ""
			ball.call("set_minutes", _fridge_item_minutes(item_id))
		if icon != null:
			icon.call("set_state", unlocked, is_active)
		if price_button != null:
			price_button.call("setup_price", reward, unlocked, fridge_phase == "idle" and price <= fridge_coin_count)
		if name_label != null:
			name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90) if unlocked else Color(0.62, 0.62, 0.62))
		if duration_label != null:
			duration_label.text = "倒计时：%s" % _format_fridge_duration(_get_fridge_item_duration(item_id))
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
				# If he was juggling, play the comic ball-to-the-face ending
				# first; the round choices appear once it finishes.
				var was_juggling := fridge_player_juggling
				fridge_player_juggling = false
				_update_fridge_player_form()
				# A pager reaction levitates until the countdown it was started in
				# runs out, so it ends here with the round - and the 磁带机 dance ends
				# with it the same way.
				if fridge_player != null and is_instance_valid(fridge_player):
					fridge_player.call("stop_pager_reaction")
					fridge_player.call("stop_cassette_reaction")
					fridge_player.call("stop_tv_reaction")
				if was_juggling and fridge_player != null and is_instance_valid(fridge_player):
					fridge_round_ending_in_flight = true
					# 打破第四面墙: instead of dropping one object on his face, the last
					# tosses rush the player's screen and the view takes the hit.
					fridge_player.call("play_screen_toss_ending")
				else:
					_show_fridge_round_choices()
			elif fridge_phase == "break":
				fridge_phase = "idle"
				fridge_time_left = 0.0
				if fridge_player != null and is_instance_valid(fridge_player):
					fridge_player.call("stop_pager_reaction")
					fridge_player.call("stop_cassette_reaction")
					fridge_player.call("stop_tv_reaction")
				_save_fridge_progress()

	fridge_pulse += delta
	_refresh_fridge_ui()


func _start_fridge_session() -> void:
	if fridge_phase != "idle":
		return
	fridge_round_choices_pending = false
	fridge_round_choice_in_flight = ""
	fridge_round_ending_in_flight = false
	_clear_fridge_round_choices()
	_stop_fridge_idle_actions()
	if fridge_player != null and is_instance_valid(fridge_player):
		fridge_player.call("stop_performances")
	fridge_phase = "work"
	# Each item runs for its OWN length, not the settings default: 番茄钟 30 s, BB机 60 s.
	fridge_time_left = _get_fridge_item_duration(fridge_active_item_id)
	_refresh_fridge_ui()


func _show_fridge_round_choices() -> void:
	_clear_fridge_round_choices()
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	# A completed round keeps offering the two buttons: every replay
	# performance ends with them popping up again (see
	# _on_fridge_performance_finished), until a new round starts.
	fridge_round_choices_pending = true

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
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	fridge_round_choice_in_flight = choice_id
	match choice_id:
		"devil":
			# Left button: keep the pomodoro sequence going by running one more
			# round with the item that was just played, so THAT item's own
			# animation runs for the whole countdown - the pager presents itself,
			# buzzes and levitates, the tomato juggles. Nothing is in flight as a
			# preview, so the buttons come back when that countdown ends.
			fridge_round_choice_in_flight = ""
			_take_fridge_item_out_of_mouth(fridge_active_item_id)
		"angel":
			# Right button: play the exhausted, panting rest animation. When it
			# ends the fridge man is back to his standing idle pose and the
			# choice sequence is over (see _on_fridge_performance_finished).
			fridge_player.call("play_rest_preview", FRIDGE_REST_PREVIEW_DURATION)
		_:
			fridge_round_choice_in_flight = ""


## Called when a choice performance (juggle or rest) runs out its timer.
##
## The two head buttons are a post-round choice: the LEFT (devil) option runs one
## more round with the same item, so it never reaches here (its countdown end
## brings the buttons back). The RIGHT (angel) option ENDS the sequence: the
## preview timer has already returned the fridge man to his standing idle pose, so
## we just drop the buttons and clear the pending flag until a new round starts.
func _on_fridge_performance_finished() -> void:
	# The 打破第四面墙 screen-toss ending just finished: now offer the round choices.
	if fridge_round_ending_in_flight:
		fridge_round_ending_in_flight = false
		_show_fridge_round_choices()
		return
	if not fridge_round_choices_pending:
		return
	var finished_choice := fridge_round_choice_in_flight
	fridge_round_choice_in_flight = ""
	if finished_choice == "angel":
		fridge_round_choices_pending = false
		_clear_fridge_round_choices()
		if fridge_player != null and is_instance_valid(fridge_player):
			fridge_player.call("stop_performances")
		return
	_show_fridge_round_choices()


func _reset_fridge_session() -> void:
	_reset_fridge_runtime()
	_refresh_fridge_ui()


func _reset_fridge_runtime() -> void:
	fridge_phase = "idle"
	fridge_time_left = 0.0
	fridge_round_choices_pending = false
	fridge_round_choice_in_flight = ""
	fridge_round_ending_in_flight = false
	_clear_fridge_round_choices()
	if fridge_player != null and is_instance_valid(fridge_player):
		fridge_player.call("stop_performances")


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
	fridge_yarn_spawn.clear()
	for ball in fridge_yarn_balls:
		if ball != null and is_instance_valid(ball):
			ball.scale = Vector2.ONE
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
	_finish_fridge_yarn_spawn()
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
	# 立即切换: tapping the item's icon starts that item's countdown straight away - the
	# same thing as taking its ball out of the mouth, including replacing a round in flight.
	_take_fridge_item_out_of_mouth(item_id)


func _start_fridge_item_from_inventory(item_id: String) -> void:
	if not fridge_owned_items.has(item_id):
		return
	# 立即切换对应物品的倒计时动画: choosing an item while a round is ALREADY running
	# replaces that round instead of the click being swallowed until its timer runs out.
	if fridge_phase != "idle":
		_cancel_fridge_session()
	fridge_active_item_id = item_id
	_save_fridge_progress()
	_refresh_fridge_ui()
	_start_fridge_session()


## Ends whatever round is in flight and puts the level back to idle, so a different item's
## session can be started immediately. Deliberately silent: no reward, no end-of-round
## fanfare, and no `performance_finished` (that is what pops the round-choice buttons).
func _cancel_fridge_session() -> void:
	if fridge_phase == "idle":
		return
	fridge_phase = "idle"
	fridge_time_left = 0.0
	fridge_round_choices_pending = false
	fridge_round_choice_in_flight = ""
	fridge_round_ending_in_flight = false
	_clear_fridge_round_choices()
	fridge_player_juggling = false
	_update_fridge_player_form()
	if fridge_player != null and is_instance_valid(fridge_player):
		fridge_player.call("stop_performances")
	if fridge_cat_pet != null and is_instance_valid(fridge_cat_pet):
		fridge_cat_motion = ""
		fridge_cat_pet.call("stop_idle_action")
	_save_fridge_progress()


## Taking a ball out of the cat's mouth immediately plays that item's animation
## — no dragging it onto the fridge man is required any more. Works during a running
## round too: that round is replaced, so the animation switches at once.
func _on_fridge_yarn_ball_pressed(ball: Control, _pointer_offset: Vector2) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	var item_id := str(ball.call("get_item_id"))
	if not fridge_owned_items.has(item_id):
		return
	_take_fridge_item_out_of_mouth(item_id)


## Starts the given item's session, which plays its countdown animation at once, and leaves
## the mouth OPEN - so while that animation is running the player can click another unlocked
## item in the mouth and switch to it immediately (倒计时重头开始). The tomato makes the
## fridge man juggle tomatoes, the pager makes him present it, buzz with it and float off
## the ground with it.
func _take_fridge_item_out_of_mouth(item_id: String) -> void:
	if not fridge_owned_items.has(item_id):
		return
	# 立即切换: the panel deliberately stays open, and the cat's bag with it, so the next
	# click lands on a live item grid. The session below cancels whatever round was in
	# flight, which is what makes the switch instant and restarts the countdown.
	if fridge_item_panel != null:
		fridge_item_panel.scale = Vector2.ONE
	if item_id == "tomato" and fridge_player != null and is_instance_valid(fridge_player):
		fridge_player.call("set_juggle_projectile", "tomato")
	# Start the session first: it cancels any round already in flight, so the item's own
	# countdown animation begins right away. Its performance is kicked off AFTERWARDS,
	# because starting a session clears whatever was performing.
	_start_fridge_item_from_inventory(item_id)
	if item_id == "tomato":
		fridge_player_juggling = true
		_update_fridge_player_form()
	elif item_id == "pager" and fridge_player != null and is_instance_valid(fridge_player):
		fridge_player.call("play_pager_reaction")
	elif item_id == "cassette" and fridge_player != null and is_instance_valid(fridge_player):
		# 磁带机: he yanks out a boombox, hoists it, shoulders it and dances with it for
		# the whole countdown (see FridgePomodoroPlayer.play_cassette_reaction).
		fridge_player.call("play_cassette_reaction")
	elif item_id == "crt" and fridge_player != null and is_instance_valid(fridge_player):
		# 电视机: he is turned into a fisherman and poles his 乌篷船 (白娘子 and 许仙 sitting
		# at the far end, backs to the player) for the whole countdown.
		fridge_player.call("play_tv_reaction")


func _handle_fridge_yarn_drag(event: InputEvent) -> bool:
	if fridge_dragged_yarn_ball == null or not is_instance_valid(fridge_dragged_yarn_ball):
		fridge_dragged_yarn_ball = null
		return false

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		# Follow the pointer via `relative` rather than absolute mouse position:
		# it is always accurate, including for synthetic/warped motion events
		# whose position field can lag behind the actual cursor.
		fridge_dragged_yarn_ball.global_position += mouse_motion.relative
		fridge_yarn_drag_release_velocity = mouse_motion.relative * 8.0
		return true

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			var dragged_ball := fridge_dragged_yarn_ball
			var item_id := str(dragged_ball.call("get_item_id"))
			var dropped_outside := not (_get_fridge_yarn_mouth_global_rect().has_point(dragged_ball.global_position + dragged_ball.size * 0.5))
			# Capture the "placed onto the fridge person" state NOW: returning
			# the ball to the pile below would reset its position first.
			var dropped_on_player := dropped_outside and _is_ball_over_fridge_player(dragged_ball)
			_return_fridge_yarn_ball_to_pile(dragged_ball, not dropped_outside)
			fridge_dragged_yarn_ball = null

			if dropped_outside and fridge_owned_items.has(item_id) and fridge_phase == "idle":
				if fridge_item_panel != null:
					fridge_item_panel.visible = false
					fridge_item_panel.scale = Vector2.ONE
				if fridge_cat_pet != null and is_instance_valid(fridge_cat_pet):
					fridge_cat_pet.call("set_bag_open", false)
				# Placing the tomato directly onto the fridge person starts the
				# pomodoro juggle performance (open door -> reveal tomatoes ->
				# take out -> juggle) for this session.
				if item_id == "tomato" and dropped_on_player:
					fridge_player_juggling = true
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

	var pointer: Vector2 = _get_fridge_yarn_pointer_local()
	for i in fridge_yarn_balls.size():
		var ball := fridge_yarn_balls[i]
		if ball == null or not is_instance_valid(ball):
			continue
		if ball == fridge_dragged_yarn_ball or ball.get_parent() != fridge_yarn_pile:
			continue
		if fridge_yarn_spawn.has(ball):
			continue

		var center: Vector2 = ball.call("get_center_position")
		var velocity: Vector2 = ball.call("get_velocity")
		var radius := float(ball.call("get_radius"))
		var idle_force := Vector2(sin(fridge_pulse * 2.0 + float(i) * 1.4), cos(fridge_pulse * 1.7 + float(i))) * 2.2
		velocity += idle_force * delta
		if fridge_dragged_yarn_ball == null:
			velocity += _get_fridge_yarn_pointer_push(center, pointer, delta)
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
		if first == null or not is_instance_valid(first) or first.get_parent() != fridge_yarn_pile or fridge_yarn_spawn.has(first):
			continue
		for j in range(i + 1, fridge_yarn_balls.size()):
			var second := fridge_yarn_balls[j]
			if second == null or not is_instance_valid(second) or second.get_parent() != fridge_yarn_pile or fridge_yarn_spawn.has(second):
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


## Clicking the cat's nose re-deals the balls: each one drops into the throat and
## then gushes back out, one after another, to a fresh spot in the mouth.
func _on_fridge_cat_nose_pressed() -> void:
	_refresh_fridge_yarn_balls()


func _refresh_fridge_yarn_balls() -> void:
	if fridge_yarn_pile == null or not is_instance_valid(fridge_yarn_pile):
		return
	if fridge_item_panel == null or not fridge_item_panel.visible:
		return
	var count := fridge_yarn_balls.size()
	if count <= 0:
		return
	if fridge_yarn_pile.size.x <= 8.0 or fridge_yarn_pile.size.y <= 8.0:
		return

	fridge_dragged_yarn_ball = null
	fridge_yarn_spawn.clear()

	# Evenly spread landing spots, then shuffled, so every refresh re-deals the
	# items to different places around the mouth.
	var columns := 3
	var rows := int(ceil(float(count) / float(columns)))
	var cell := Vector2(fridge_yarn_pile.size.x / float(columns), fridge_yarn_pile.size.y / float(rows))
	var targets: Array[Vector2] = []
	for slot in count:
		var column := slot % columns
		var row := floori(float(slot) / float(columns))
		targets.append(Vector2((float(column) + 0.5) * cell.x, (float(row) + 0.5) * cell.y))
	targets.shuffle()

	var origin := Vector2(
		fridge_yarn_pile.size.x * FRIDGE_REFILL_ORIGIN_FRAC.x,
		fridge_yarn_pile.size.y * FRIDGE_REFILL_ORIGIN_FRAC.y
	)
	for slot in count:
		var ball: Control = fridge_yarn_balls[slot]
		if ball == null or not is_instance_valid(ball) or ball.get_parent() != fridge_yarn_pile:
			continue
		var start := origin + Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0))
		var angle := -PI * 0.5 + randf_range(-0.9, 0.9)
		# Jitter the landing spot, then keep it clear of the mouth wall.
		var margin := float(ball.call("get_radius")) + 8.0
		var target: Vector2 = targets[slot] + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		target.x = clampf(target.x, margin, fridge_yarn_pile.size.x - margin)
		target.y = clampf(target.y, margin, fridge_yarn_pile.size.y - margin)
		fridge_yarn_spawn[ball] = {
			"time": 0.0,
			"delay": float(slot) * FRIDGE_REFILL_STAGGER,
			"origin": start,
			"target": target,
			"burst": Vector2(cos(angle), sin(angle)) * randf_range(40.0, 90.0),
		}
		ball.pivot_offset = ball.size * 0.5
		ball.scale = Vector2.ZERO
		ball.call("set_center_position", start)
		ball.call("set_velocity", Vector2.ZERO)


## Drives the pour-out: each ball waits its turn hidden in the throat, then grows
## and flies to its landing spot, hopping slightly as it comes out. Once it lands
## it hands back to the normal pile physics with a small residual velocity.
func _update_fridge_yarn_spawn(delta: float) -> void:
	if fridge_yarn_spawn.is_empty():
		return
	var finished: Array = []
	for key in fridge_yarn_spawn.keys():
		var ball := key as Control
		if ball == null or not is_instance_valid(ball) or ball.get_parent() != fridge_yarn_pile:
			finished.append(key)
			continue
		var state: Dictionary = fridge_yarn_spawn[key]
		state["time"] = float(state["time"]) + delta
		var elapsed: float = float(state["time"]) - float(state["delay"])
		if elapsed < 0.0:
			continue
		var progress: float = clamp(elapsed / FRIDGE_REFILL_EMERGE_TIME, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		var origin: Vector2 = state["origin"]
		var target: Vector2 = state["target"]
		var center: Vector2 = origin.lerp(target, eased)
		center.y -= sin(PI * progress) * FRIDGE_REFILL_HOP
		ball.call("set_center_position", center)
		var grow: float = FRIDGE_REFILL_START_SCALE + (1.0 - FRIDGE_REFILL_START_SCALE) * eased
		ball.scale = Vector2(grow, grow)
		if progress >= 1.0:
			ball.scale = Vector2.ONE
			ball.call("set_center_position", target)
			ball.call("set_velocity", state["burst"])
			finished.append(key)
	for key in finished:
		fridge_yarn_spawn.erase(key)


## Snaps any ball still pouring out straight to its landing spot (used when the
## mouth closes, so nothing is left invisible at the throat).
func _finish_fridge_yarn_spawn() -> void:
	if fridge_yarn_spawn.is_empty():
		return
	for key in fridge_yarn_spawn.keys():
		var ball := key as Control
		if ball == null or not is_instance_valid(ball):
			continue
		var state: Dictionary = fridge_yarn_spawn[key]
		ball.scale = Vector2.ONE
		ball.call("set_center_position", state.get("target", ball.call("get_center_position")))
		ball.call("set_velocity", state.get("burst", Vector2.ZERO))
	fridge_yarn_spawn.clear()


## Cursor position in the pile's local space, or FRIDGE_POINTER_NONE when the
## cursor is outside the mouth (so an outside cursor never disturbs the pile).
func _get_fridge_yarn_pointer_local() -> Vector2:
	if fridge_yarn_pile == null or not is_instance_valid(fridge_yarn_pile):
		return FRIDGE_POINTER_NONE
	if not fridge_yarn_pile.get_global_rect().has_point(fridge_yarn_pile.get_global_mouse_position()):
		return FRIDGE_POINTER_NONE
	return fridge_yarn_pile.get_local_mouse_position()


## Velocity nudge that shoves a ball away from the cursor, stronger the closer it
## is, so the pile scatters naturally as the pointer sweeps through the mouth.
func _get_fridge_yarn_pointer_push(center: Vector2, pointer: Vector2, delta: float) -> Vector2:
	if pointer == FRIDGE_POINTER_NONE:
		return Vector2.ZERO
	var offset := center - pointer
	var distance := offset.length()
	if distance >= FRIDGE_POINTER_PUSH_RADIUS:
		return Vector2.ZERO
	var falloff := 1.0 - distance / FRIDGE_POINTER_PUSH_RADIUS
	var direction := Vector2.RIGHT if distance <= 0.001 else offset / distance
	return direction * FRIDGE_POINTER_PUSH_FORCE * falloff * falloff * delta


func _position_fridge_popups() -> void:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return
	var screen_position: Vector2 = _get_fridge_player_screen_position()
	var item_position: Vector2 = _get_fridge_mouth_inventory_position()

	if fridge_item_panel != null and fridge_dragged_panel != fridge_item_panel:
		# The mouth inventory always follows the cat; a manual panel drag only
		# shifts the offset relative to the cat's mouth.
		fridge_item_panel.position = _clamp_fridge_panel_follow(fridge_item_panel, item_position + fridge_item_panel_offset)
		fridge_item_panel.size = FRIDGE_TOOLBAR_SIZE

	# The nose hotspot tracks the panel (and its open pop-in scale) every frame.
	if fridge_nose_button != null and is_instance_valid(fridge_nose_button):
		if fridge_item_panel != null and fridge_item_panel.visible:
			var panel_rect: Rect2 = fridge_item_panel.get_global_rect()
			var nose_size: Vector2 = panel_rect.size * FRIDGE_NOSE_SIZE_FRAC
			fridge_nose_button.size = nose_size
			fridge_nose_button.global_position = panel_rect.position + panel_rect.size * FRIDGE_NOSE_CENTER_FRAC - nose_size * 0.5
			fridge_nose_button.visible = true
		else:
			fridge_nose_button.visible = false

	if fridge_settings_panel != null and not fridge_settings_panel_has_manual_position and fridge_dragged_panel != fridge_settings_panel:
		var settings_position: Vector2 = _clamp_fridge_panel_position(fridge_settings_panel, screen_position + Vector2(300.0, -252.0))
		fridge_settings_panel.position = settings_position
		fridge_settings_panel.size = FRIDGE_SETTINGS_SIZE

	# The left-side panels stay anchored to their (draggable) props, so they
	# follow along when the wardrobe prop or the briefcase gets moved.
	if fridge_gallery_panel != null and fridge_gallery_panel.visible \
			and fridge_gallery_stand != null and is_instance_valid(fridge_gallery_stand):
		fridge_gallery_panel.call("popup_at", _fridge_gallery_popup_position())

	if fridge_box_panel != null and fridge_box_panel.visible \
			and fridge_box != null and is_instance_valid(fridge_box):
		fridge_box_panel.call("popup_at", _fridge_box_popup_position())


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
			if fridge_dragged_panel == fridge_item_panel:
				fridge_item_panel_offset = fridge_item_panel.position - _get_fridge_mouth_inventory_position()
			fridge_dragged_panel = null
			return true

	return false


func _handle_fridge_player_drag(event: InputEvent) -> bool:
	if fridge_player_is_dragging:
		if event is InputEventMouseMotion:
			var mouse_position: Vector2 = get_global_mouse_position()
			# 控制住冰箱人: once the player actually moves the cursor he takes the wheel,
			# and a press that never moves stays a CLICK (see the release below).
			if not fridge_player_drag_moved \
					and mouse_position.distance_to(fridge_player_press_position) > FRIDGE_PLAYER_CLICK_MOVE_LIMIT:
				fridge_player_drag_moved = true
			if fridge_player_drag_moved:
				fridge_player.global_position = mouse_position + fridge_player_drag_offset
			return true

		if event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
				var held_ms: int = Time.get_ticks_msec() - fridge_player_press_msec
				if not fridge_player_drag_moved \
						and held_ms < int(FRIDGE_PLAYER_CLICK_TIME_LIMIT * 1000.0):
					# 点击冰箱人: while he is idle a plain click hides the cat, the notebook
					# prop and the briefcase - a second click brings them back. While a
					# performance owns him the same click still turns him around.
					if _is_fridge_player_performing():
						_flip_fridge_player_flight_dir()
					elif not _is_any_fridge_panel_open():
						# 面板打开时不隐藏: the book / briefcase / cat-bag panels are opened FROM these
						# very props, so a click that lands on him while one of them is on screen must
						# leave everything alone instead of hiding the prop (and closing its panel).
						_set_fridge_props_hidden(not fridge_props_hidden)
				fridge_player_is_dragging = false
				fridge_player_drag_offset = Vector2.ZERO
				fridge_player_drag_moved = false
				return true

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if _is_mouse_over_fridge_player():
				fridge_player_is_dragging = true
				fridge_player_drag_moved = false
				fridge_player_press_msec = Time.get_ticks_msec()
				fridge_player_press_position = get_global_mouse_position()
				fridge_player_drag_offset = fridge_player.global_position - get_global_mouse_position()
				return true

	return false


func _is_mouse_over_fridge_player() -> bool:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return false
	var local_mouse := fridge_player.to_local(get_global_mouse_position())
	return FRIDGE_PLAYER_DRAG_HIT_RECT.has_point(local_mouse)


## True while a performance (or the ball-to-the-face ending) owns him; a click then means
## 改变飞行方向 rather than the hide/show toggle.
func _is_fridge_player_performing() -> bool:
	if fridge_player == null or not is_instance_valid(fridge_player):
		return false
	return bool(fridge_player.call("is_performing"))


## 面板打开时不隐藏: true while any panel one of the props owns is on screen - the notebook's book
## (fridge_gallery_panel), the briefcase (fridge_box_panel), the cat's bag (fridge_item_panel) and the
## settings list. A click that lands on the fridge man must leave them (and their props) alone then.
func _is_any_fridge_panel_open() -> bool:
	var panels: Array = [fridge_gallery_panel, fridge_box_panel, fridge_item_panel, fridge_settings_panel]
	for panel: Variant in panels:
		var control := panel as Control
		if control != null and is_instance_valid(control) and control.visible:
			return true
	return false


## 全部解锁: every item in FRIDGE_ITEMS is owned from the start, so the cat's bag lists them all with
## nothing locked and the shop has nothing left to sell. Applied AFTER the save is read, so an older
## save - which only listed whatever had been bought then - is topped up as well.
func _ensure_all_fridge_items_owned() -> void:
	for item: Dictionary in FRIDGE_ITEMS:
		var item_id := str(item.get("id", ""))
		if not item_id.is_empty() and not fridge_owned_items.has(item_id):
			fridge_owned_items.append(item_id)


## 点击冰箱人: hides (or brings back) the notebook prop and the briefcase. The cat is NEVER
## hidden. A hidden host cannot be clicked, so any panel it owns is closed with it. (The
## parameter is not called `hidden`: that name shadows CanvasItem's own `hidden` signal.)
func _set_fridge_props_hidden(should_hide: bool) -> void:
	fridge_props_hidden = should_hide
	if should_hide:
		_close_fridge_gallery(false)
		_close_fridge_box(false)
	if fridge_gallery_stand != null and is_instance_valid(fridge_gallery_stand):
		fridge_gallery_stand.visible = not should_hide
	if fridge_box != null and is_instance_valid(fridge_box):
		fridge_box.visible = not should_hide


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
	return _clamp_fridge_panel_follow(fridge_item_panel, target)


# The mouth inventory is anchored to the cat, so it may hang off screen while the
# cat is dragged to a corner: the bound only keeps a grabbable sliver visible.
func _clamp_fridge_panel_follow(panel: Control, target_position: Vector2) -> Vector2:
	if panel == null:
		return target_position
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel.custom_minimum_size
	var min_x: float = FRIDGE_PANEL_FOLLOW_MARGIN - panel_size.x
	var max_x: float = viewport_size.x - FRIDGE_PANEL_FOLLOW_MARGIN
	var min_y: float = FRIDGE_PANEL_FOLLOW_MARGIN - panel_size.y
	var max_y: float = viewport_size.y - FRIDGE_PANEL_FOLLOW_MARGIN
	return Vector2(
		clamp(target_position.x, min_x, max_x),
		clamp(target_position.y, min_y, max_y)
	)


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


## Hover text for a mouth ball: only the item's name and how long one focused run
## takes. FridgeYarnBall lays these two lines out as a paper-craft card.
func _get_fridge_item_tooltip(item_id: String, _price: int, _unlocked: bool) -> String:
	var record := _get_fridge_item_record(item_id)
	var item_name := str(record.get("name", item_id))
	return "%s\n%s" % [item_name, _format_fridge_duration(_get_fridge_item_duration(item_id))]


## How long one focused run of this item lasts. An item may set its own "duration"
## in seconds (番茄钟 30, BB机 60); anything without one follows 专注秒数 from the
## settings panel.
func _get_fridge_item_duration(item_id: String) -> float:
	var fallback := clampf(fridge_work_duration, 5.0, 3600.0)
	var record := _get_fridge_item_record(item_id)
	if record.is_empty():
		return fallback
	return clampf(float(record.get("duration", fallback)), 5.0, 3600.0)


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
			return 1.0 - clamp(fridge_time_left / _get_fridge_item_duration(fridge_active_item_id), 0.0, 1.0)
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
	if seconds == 0:
		return "%d 分钟" % minutes
	return "%d 分 %02d 秒" % [minutes, seconds]
