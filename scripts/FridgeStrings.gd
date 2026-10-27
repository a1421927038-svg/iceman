class_name FridgeStrings
extends RefCounted

## 中英文切换: the game's TEXT lives in ONE table so the whole game can be flipped between 中文 and
## English from the two cards on the notebook's first page (see FridgeLevel._on_fridge_gallery_entry_pressed).
##
## HOW THE SWITCH WORKS - and why this file is so small:
## Godot translates a Control's own `text` / `tooltip_text` for us, live, every time the locale changes
## (a Control re-translates itself on NOTIFICATION_TRANSLATION_CHANGED). So `label.text = "番茄钟"` needs
## NO code change: installing the table below and calling set_language("en") is enough, and it works on
## labels/buttons that were built long before the switch, in both directions. Verified in a probe: a
## Label's minimum width went 96 px (中文) -> 217 px (Tomato Timer) -> 96 px again, and a Label created
## AFTER the switch picked it up too.
##
## ⚠ THE EXCEPTIONS - these do NOT pass through a Control's text, so they must be wrapped in `t()` by
## hand (see FridgeLevel):
##   * FORMATTED strings: "说明：基础待机动画 · 30 秒" is not a key. Translate the FORMAT and each PIECE,
##     then join - `t("说明：%s") % [t(item_name)]`.
##   * strings DRAWN with draw_string instead of living in a Label (the prop box's lid title).
##   * the OS-level tray-icon tooltip (DesktopPetWindow).
##
## ⚠ The identity entry in `install()` matters: the project's fallback locale is "en", so without a real
## zh_CN translation a Chinese lookup would fall through to the English message.
##
## Keys are the ORIGINAL Chinese strings - never translate a key, and never key off an already-formatted
## string.

const LANGUAGE_ZH := "zh"
const LANGUAGE_EN := "en"
const ZH_LOCALE := "zh_CN"
const EN_LOCALE := "en"

## The one and only 中文 -> English table.
const TRANSLATIONS := {
	# --- panel titles, labels, buttons ---
	"番茄钟设置": "Pomodoro Settings",
	"番茄钟": "Tomato Timer",
	"专注秒数": "Focus seconds",
	"休息秒数": "Break seconds",
	"开始专注": "Start Focus",
	"重置": "Reset",
	"关闭": "Close",
	"取消": "Cancel",
	"退出": "Quit",
	"要退出游戏吗？": "Quit the game?",
	"道具箱": "Prop Box",
	"动作选项": "Actions",
	"冰箱人": "Fridge Man",
	"基础待机动画": "Basic idle animation",
	"点击解锁": "Click to unlock",
	"已解锁": "Unlocked",
	"免费": "Free",
	"金币不足": "Not enough coins",
	# --- notebook tabs ---
	"骨架": "Animations",
	"猫嘴物品": "Mouth Items",
	"公文包物品": "Briefcase Items",
	"进度": "Slots",
	# ---公文包物品说明---
	"抛球杂耍时使用的番茄道具": "Tomato prop used during ball juggling",
	"抛球杂耍时可切换的彩球道具": "Colorful ball prop for ball juggling",
	"BB机悬浮时向下喷洒的纸片文字": "Paper glyphs sprayed while levitating with the pager",
	"BB机悬浮时可切换的漫天泡泡": "Floating bubbles sprayed while levitating with the pager",
	"磁带机蹦迪时飞出的纸片音符": "Paper music notes flying out during the boombox dance",
	"显像管电视专注时乘坐的江南乌篷船": "Traditional awning boat poled during the CRT TV focus",
	"炉石": "Hearthstone",
	"复古电脑专注结束时兽人用来回到电脑里的炉石传送石": "Hearthstone used by the Orc to teleport back into the PC at the end of the 90s PC focus",
	"复古电脑专注时从电脑人身上不断掉落的炉石石头": "Hearthstone rocks continuously dropped from the Computer Man during the 90s PC focus",
	"超级玛丽奥卡带": "Super Mario Cartridge",
	"游戏机手柄专注时插入学习机的超级玛丽奥卡带": "Super Mario cartridge plugged into the console during the gamepad focus",
	"传送门": "Portal",
	"斧子": "Battle Axe",
	"复古电脑专注时在爷爷两侧开启的旋涡传送门": "Swirling portal that opens beside Grandpa during the 90s PC focus",
	"复古电脑专注时从地上捡起并挥舞的斧子": "Battle axe picked up from the ground and swung during the 90s PC focus",
	"兽人护甲": "Orc Armor",
	"双持板斧": "Dual Battle Axes",
	"变大蘑菇": "Super Mushroom",
	"复古电脑专注时穿戴的兽人皮甲与骨刺护肩": "Orc leather armor and bone pauldrons worn during the 90s PC focus",
	"复古电脑专注时双手挥舞的兽人板斧": "Dual orc battle axes wielded during the 90s PC focus",
	"游戏机手柄专注时在平台上不断变大的神奇蘑菇": "Magic mushroom that grows on the platform during the gamepad focus",
	# --- notebook entry names / descriptions ---
	"抛球杂耍": "Ball Juggling",
	"连续抛接小球": "Juggles balls non-stop",
	"站立歇息": "Stand and Rest",
	"靠墙站一会儿": "Stands a while",
	"抽烟吐圈": "Smoke Rings",
	"吐出一个个烟圈": "Blows smoke rings",
	"摸摸小猫": "Petting the Cat",
	"弯腰抚摸小猫": "Bends down to pet the cat",
	"BB机来讯": "Pager Message",
	"腰间BB机响起": "The pager buzzes",
	"冰箱人打盹": "Fridge Man Dozes",
	"站着打起了瞌睡": "Dozes off standing",
	"小猫歇息": "Cat Rests",
	"原地伸展身体": "Stretches in place",
	"小猫打盹": "Cat Dozes",
	"眯眼慢慢睡着": "Slowly falls asleep",
	"小猫玩球": "Cat Plays Ball",
	"追着毛线球打转": "Chases the yarn ball",
	"小猫绕圈跑": "Cat Runs in Circles",
	"绕着冰箱人跑圈": "Runs circles around him",
	# --- the four mouth items + the two that are not in the mouth ---
	"番茄": "Tomato",
	"磁带机": "Boombox",
	"寻呼机": "Pager",
	"显像管电视": "CRT TV",
	"随身听": "Walkman",
	"录像带": "VHS Tape",
	"90年代电脑": "90s Computer",
	"游戏机手柄": "Game Controller",
	"复古电脑待机": "Retro PC idle",
	"手柄按键待机": "Gamepad idle",
	"喝茶缸": "Mug of Tea",
	"端出90年代的搪瓷缸喝口水": "Takes out his 90s enamel mug for a sip",
	"解锁新物品：%s": "New item unlocked: %s",
	# --- the 公文包 items found in the cat's mouth ---
	"该物品未解锁": "Not unlocked yet",
	"磁带转动待机": "Tape-spin idle",
	"屏幕闪烁待机": "Screen-flicker idle",
	"扫描线待机": "Scanline idle",
	"耳机律动待机": "Headphone-beat idle",
	"胶带循环待机": "Tape-loop idle",
	# --- the prop box's items and their action names ---
	"球": "Ball",
	"字体": "Glyphs",
	"泡泡": "Bubbles",
	"音乐符号": "Music Note",
	"电视机": "Television",
	"乌篷船": "Awning Boat",
	"喷射番茄": "Tomato Spray",
	"喷射字体": "Glyph Spray",
	"喷射泡泡": "Bubble Spray",
	# --- the save slots ---
	"读取": "Load",
	"存档 %d": "Slot %d",
	"空存档 · 点一下保存": "Empty · click to save",
	"存档无法读取": "Slot cannot be read",
	"存档 %d 是空的": "Slot %d is empty",
	"已保存到存档 %d": "Saved to slot %d",
	"已读取存档 %d": "Loaded slot %d",
	"%s · 猫嘴物品 %d 个 · %s": "%s · %d mouth items · %s",
	"番茄钟动画 %d 个 · 可交互物品 %d 个 · 待机动画 %d 个": "Pomodoro animations: %d · Interactive items: %d · Idle animations: %d",
	# --- 中英文切换 ---
	"中文": "Chinese",
	"英文": "English",
	"中文界面": "Switch to Chinese",
	"英文界面": "Switch to English",
	"语言已切换为中文": "Language: Chinese",
	"语言已切换为英文": "Language: English",
	"存档已删除，进度已重置": "Save deleted - progress reset",
	"已重置存档 %d，游戏已重置": "Slot %d reset - game reset",
	# --- HUD / status text ---
	"专注中": "Focusing",
	"休息中": "On a break",
	"倒计时：%s": "Countdown: %s",
	"说明：%s": "Note: %s",
	"待机：%s": "Idle: %s",
	"当前道具：%s。%s": "Current item: %s. %s",
	"完成一次专注奖励 %d 金币。": "Finishing a focus awards %d coins.",
	"专注结束后会发放金币，并询问是否继续下一轮。": "Coins are awarded when the focus ends, then you are asked whether to run another round.",
	"先休息一下，再继续下一轮。": "Take a break first, then run the next round.",
	"在道具栏里点击物品图标开始一轮番茄钟。": "Click an item icon in the tray to start a pomodoro round.",
	"%d 金币": "%d coins",
	"+%d 金币": "+%d coins",
	"%d 分钟": "%d min",
	"%d 秒": "%d sec",
	"%d 分 %02d 秒": "%d min %02d sec",
	# --- the desktop pet's tray icon ---
	"冰箱爷爷桌面宠物：左键显示/隐藏，右键退出": "Fridge Grandpa desktop pet - left click to show/hide, right click to quit",
	# --- the addon's scroll hint (a Control's text, so it needs no wrapping) ---
	"▼ 下拉查看更多": "▼ Scroll for more",
}

static var _installed := false
static var _zh_translation: Translation = null
static var _en_translation: Translation = null


## Registers both translations. Safe to call any number of times, so both the level's _ready and the
## desktop-pet window can make sure the table exists before they build any text.
static func install() -> void:
	if _installed:
		return
	_installed = true
	_zh_translation = Translation.new()
	_zh_translation.locale = ZH_LOCALE
	_en_translation = Translation.new()
	_en_translation.locale = EN_LOCALE
	for key: String in TRANSLATIONS:
		# ⚠ The identity message is what keeps 中文 working: without it a zh_CN lookup would fall
		# through to the project's "en" fallback and return the English text.
		_zh_translation.add_message(key, key)
		_en_translation.add_message(key, str(TRANSLATIONS[key]))
	TranslationServer.add_translation(_zh_translation)
	TranslationServer.add_translation(_en_translation)


## Switches the whole game. Every Control that was ever built re-translates itself from here on.
static func set_language(code: String) -> void:
	install()
	TranslationServer.set_locale(EN_LOCALE if code == LANGUAGE_EN else ZH_LOCALE)


static func language() -> String:
	return LANGUAGE_EN if TranslationServer.get_locale().begins_with("en") else LANGUAGE_ZH


static func is_english() -> bool:
	return language() == LANGUAGE_EN


## ⚠ For the strings a Control does NOT translate for us: format strings, text that was concatenated,
## text that is drawn with draw_string, and OS-level strings. Composite strings are not keys - translate
## the format AND its pieces.
static func t(zh: String) -> String:
	return TranslationServer.translate(zh)