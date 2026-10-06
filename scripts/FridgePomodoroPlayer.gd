class_name FridgePomodoroPlayer
extends CharacterBody2D

## The plain standing idle: three 512px frames of a relaxed breathing loop
## (neutral, inhale, exhale) assembled from art normalised onto the old
## idle's frame geometry, so his size and ground line never change.
@export var sprite_sheet_path := "res://assets/generated/paper_fridge_idle_relaxed.png"
@export var frame_count := 3
@export var frame_size := Vector2i(512, 512)
## Slow on purpose: a relaxed idle breathes over about two seconds, not one.
@export var animation_fps := 2.0
@export var display_height := 320.0

## Emitted when a performance preview (juggle replay or rest) ends naturally
## after its timer runs out. The host level uses this to bring the post-round
## choice buttons back, so the player can pick again. Not emitted when a
## performance is replaced or stopped (new session, reset, mutual swap).
signal performance_finished
## 打破第四面墙: emitted at the instant the last tosses hit the camera, so the host level can
## jolt the view itself.
signal screen_hit

# Pomodoro juggle sequence, triggered by placing the tomato item from the cat
# mouth onto the player: the fridge man simply starts juggling in place. There
# is NO separate intro any more (the old door-opening keyframes were removed).
const JUGGLE_ANIMATION_NAME := "tomato_juggle"
# The juggle phase is a four-frame ARM animation built from the IDLE character
# itself: the whole body, face, colors, proportions and paper-craft style are
# identical to the idle animation — ONLY the arms move (a windmill toss). The
# frames are laid out exactly like the idle frame (same size, same foot line),
# so the juggle uses the same sprite scale and position as idle and the swap is
# seamless. Frames play in the order [0, 2, 1, 3] so the raised hand alternates
# left/right, ending on both hands up. The flying tomatoes stay SEPARATE
# code-animated, swappable sprites (see _create_juggle_objects).
const JUGGLE_ATLAS_PATH := "res://assets/generated/paper_fridge_juggle_idle_v2.png"
# Four poses of a deliberately over-the-top juggle, and the atlas columns are ALREADY in play
# order: throw with the picture-left hand -> the mirrored throw with the picture-right hand ->
# a comic ducking crouch with both arms swept low and crossed -> both arms flung up in a
# triumphant V. The body leans into each throw and the pupils stay rolled up tracking the
# objects, so the cycle reads as frantic fun rather than a metronome.
const JUGGLE_ATLAS_FRAME_INDICES := [0, 1, 2, 3]
# Deliberately unhurried: one toss per 1.25 s (was a hurried 0.67 s). This is also what the
# flying objects are timed to - see JUGGLE_CYCLE_TIME - so a tomato meets a raised hand
# instead of a hand that has already swung away.
const JUGGLE_ANIMATION_FPS := 3.2

# Rest performance: after a work round finishes, the right button plays this
# Gemini-generated exhausted-panting loop (bent over, hands on knees, sweat
# drops flying). The atlas holds three 512px frames; they are ping-ponged
# (1-2-3-2) at load time so the breathing heave eases instead of snapping.
const REST_ANIMATION_NAME := "pomodoro_rest"
const REST_ATLAS_PATH := "res://assets/generated/paper_fridge_rest_pant.png"
const REST_FRAME_SIZE := Vector2i(512, 512)
const REST_ANIMATION_FPS := 5.5

# Comic ending: after a juggle countdown runs out, one tossed object falls out
# of the loop and bonks the fridge man on the face. He reels (hit face + body
# shake), then settles back to idle. The falling object is the same swappable
# projectile sprite he was juggling.
const BALL_DROP_ANIMATION_NAME := "face_hit"
const BALL_DROP_ATLAS_PATH := "res://assets/generated/paper_fridge_hit_face_aligned.png"
const BALL_DROP_FRAME_SIZE := Vector2i(512, 512)
const BALL_DROP_TOTAL_TIME := 1.45

# 打破第四面墙: the juggle's REAL ending. Instead of dropping one object on his face, the
# tossed objects turn and rush the CAMERA - flying at the player's screen, growing until they
# fill it, and then jolting the whole view. `SCREEN_TOSS_FLIGHT_TIME` is the rush, the rest is
# the impact and the man's startled reaction (STARTLE_ANIMATION_NAME deliberately: the new man's
# art, not the retired ball-to-the-face sheet, which still belongs to the old ending).
const SCREEN_TOSS_FLIGHT_TIME := 0.85
const SCREEN_TOSS_HOLD_TIME := 0.5
const SCREEN_TOSS_TOTAL_TIME := SCREEN_TOSS_FLIGHT_TIME + SCREEN_TOSS_HOLD_TIME
const SCREEN_TOSS_MAX_SCALE := 7.0
const BALL_DROP_FALL_TIME := 0.6
const BALL_DROP_HIT_TIME := 0.55
const BALL_DROP_BOUNCE_TIME := 0.22
const BALL_DROP_SHAKE_TIME := 0.5
const BALL_DROP_START_Y := -640.0
const BALL_DROP_HIT_Y := -228.0

# Pager (BB机) reaction: clicking the pager item in the cat's mouth plays this
# four-keyframe sequence taken from the reference chart — present the pager,
# the pager buzzes in his hand, the whole man buzzes with it, then he floats off
# the ground while the device levitates in front of his chest, bobbing up and
# down. The device is painted into the first three keyframes (so his grip matches
# the art); the fourth is drawn empty-handed and the detached device is a
# separate sprite that floats and bobs.
const PAGER_ANIMATION_NAME := "pager_react"
const PAGER_ATLAS_PATH := "res://assets/generated/paper_fridge_pager_react.png"
const PAGER_FRAME_SIZE := Vector2i(512, 512)
const PAGER_DEVICE_PATH := "res://assets/generated/paper_pager_device.png"
# Seconds per keyframe: present, pager buzz, body buzz, reach up, grab, float (5.2 s total).
const PAGER_BEATS := [0.7, 1.0, 1.1, 0.4, 0.4, 1.6]
const PAGER_TOTAL_TIME := 5.2
# Buzz shake amplitudes: a light tremble while only the device rattles, a big one once the
# whole body joins in (夸张 enough that the panic beats really read).
const PAGER_BUZZ_LIGHT := 5.0
const PAGER_BUZZ_STRONG := 13.0
# Float beat: he lifts off the ground and keeps drifting up and down, while the
# device levitates in front of his chest and bobs further than he does.
const PAGER_FLOAT_LIFT := 30.0
const PAGER_FLOAT_MAN_BOB := 9.0
# 抓住BB机: the fourth keyframe has both hands clutching the device, so the device
# must NOT bob on its own any more - it rides exactly with his body (whose own bob
# still carries the whole pair up and down) or the grip would come apart.
const PAGER_FLOAT_DEVICE_BOB := 0.0
const PAGER_FLOAT_BOB_SPEED := 3.2
const PAGER_FLOAT_RISE_TIME := 0.4
# 抓住BB机: right between the fists of the float keyframe. Measured from the art the
# way the art is placed on screen: the frame is drawn at 0.625 (320/512) with its
# centre at SPRITE_BASE_POSITION, and the float pose now raises BOTH ARMS OVER HIS
# HEAD with the two clenched fists meeting on frame row ~30, so
# -145 + (30 - 256) * 0.625 = -286.3 holds the device up in the raised fists.
const PAGER_FLOAT_POSITION := Vector2(0.0, -286.3)
## 逐渐向上悬浮 / 抓住BB机: the detached device is driven through PAGER_RISE_KEYS on the
## float-local clock, so it leaves his shaking hand, passes between his reaching hands and
## settles inside the fists he closes over his head.
const PAGER_REACH_TIME := 0.4
const PAGER_GRAB_TIME := 0.4
const PAGER_RISE_KEYS := [
	Vector2(-105.0, -221.0),   # still in the shaking hand (the buzz keyframe's device)
	Vector2(0.0, -242.5),      # between his reaching hands, just above the fingertips
	Vector2(0.0, -276.9),      # caught: sitting in the two clenched fists
	Vector2(0.0, -286.3),      # held high overhead (matches PAGER_FLOAT_POSITION)
]
const PAGER_RISE_KEY_TIMES := [
	0.0, PAGER_REACH_TIME, PAGER_REACH_TIME + PAGER_GRAB_TIME, PAGER_FLOAT_RISE_TIME + 0.8,
]
## 随着BB机向上移动: once the levitation has been held for this long the whole man starts
## drifting upward with the pager. The LEVEL drives that flight (see
## FridgeLevel._update_fridge_player_flight) because it owns his node position and the
## screen bounds. Measured on the held float's own clock.
const PAGER_FLIGHT_DELAY := 1.6
const PAGER_DEVICE_SCALE := 0.175

# 磁带机 (cassette) countdown performance: he yanks a boombox out of nowhere, hoists it
# over his head, slams it onto his shoulder and dances with it while music notes fly out
# of its speakers. Five 512px frames with beat-length durations; the boombox is PAINTED
# INTO the art in every frame (so hoisting and shouldering it read as one continuous,
# deliberately over-the-top action) and the 音乐符号 are separate pooled sprites emitted
# from a fixed point on its speaker grille. Sunglasses, gold chain and sneakers are in
# the art, so the outfit is part of the performance.
const CASSETTE_ANIMATION_NAME := "cassette_party"
const CASSETTE_ATLAS_PATH := "res://assets/generated/paper_fridge_boombox_party.png"
const CASSETTE_FRAME_SIZE := Vector2i(512, 512)
const CASSETTE_BEATS := [0.5, 0.35, 0.45, 0.6, 0.6]
const CASSETTE_TOTAL_TIME := 2.5
# The held version loops the last two beats (a left-right bop) at this rate.
const CASSETTE_GROOVE_FPS := 2.6
const CASSETTE_GROOVE_FIRST_FRAME := 3
# 音乐符号: they leave the boombox once it is on his shoulder - the shoulder beat starts
# when the first three beats are done - and rise while they fade.
const CASSETTE_NOTE_START := 1.3
const CASSETTE_NOTE_ATLAS_PATH := "res://assets/generated/paper_music_notes.png"
const CASSETTE_NOTE_FRAMES := 4
const CASSETTE_NOTE_SOURCE_SIZE := Vector2i(128, 128)
const CASSETTE_NOTE_SCALE := 0.44
# Art-local point on the boombox's speaker grille (the frames draw it on his left
# shoulder, i.e. the picture-left side). Converted with the sprite's own scale.
const CASSETTE_NOTE_ART_ORIGIN := Vector2(126.0, 78.0)
const CASSETTE_NOTE_INTERVAL := 0.3
const CASSETTE_NOTE_LIFE := 1.5
const CASSETTE_NOTE_RISE := 70.0
const CASSETTE_NOTE_SPREAD := 58.0
const CASSETTE_NOTE_POOL := 10
# The whole-body motion: a shake while he hoists the thing, then an exaggerated bop.
const CASSETTE_HOIST_SHAKE := 7.0
const CASSETTE_BOP := 6.0

# 电视机 (CRT) countdown performance: the fridge man is turned into a Chinese fisherman
# poling a 乌篷船. Five 512px frames - startled -> a comic transformation poof -> the
# fisherman with his bamboo pole up -> pushing it down -> lifting it back - which then
# loop the pole stroke. The boat itself (a dark arched woven canopy with 白娘子 and 许仙
# sitting at the FAR end with their BACKS to the player) is a separate sprite, placed so
# his feet rest on its open deck, and it bobs on the water with him.
const TV_ANIMATION_NAME := "tv_fisherman"
const TV_ATLAS_PATH := "res://assets/generated/paper_fridge_tv_fisherman.png"
const TV_FRAME_SIZE := Vector2i(512, 512)
# 整体缩小 (asked for after the first look: 「电视机的动画太大了需要整体缩小」, then halved
# again: 「整体再缩小一半」): the whole fisherman + boat scene is drawn smaller than the idle
# body, because the boat alone is a wide prop and the pair read as oversized on screen. This
# ONE knob scales the man, the boat, its x offset and the performance's motion together; his
# feet stay on the idle's ground line regardless, because _set_sprite_scale_for slides the
# sprite down by 512 * 0.5 * (base_scale - scaled) to compensate.
const TV_PERFORMANCE_SCALE := 0.39
const TV_BEATS := [0.5, 0.5, 0.5, 0.6, 0.6]
const TV_TOTAL_TIME := 2.7
# The held version loops the stroke (pole up -> push -> lift) at this rate.
const TV_POLE_FPS := 1.8
const TV_POLE_FIRST_FRAME := 2
# The man's feet art row - all five frames are fitted to the idle's ground line.
const TV_FOOT_ROW := 510.0
# 船重新生成: the boat was generated whole rather than patched - no water band and a clean
# deck. The layout is deliberately the same as the old art (open deck on the left half,
# canopy right of centre, the two passengers at the far end), so only this path and the
# deck row below had to move.
const TV_BOAT_PATH := "res://assets/generated/wupeng_boat_v2.png"
const TV_BOAT_SCALE := 0.74
# 站在船头: the boat is placed to his LEFT and drawn MIRRORED, so the bow faces him and he
# stands on the flat deck's front section (measured: the deck plateau is art row 283 and the
# flat deck starts at art x ~268; he stands at ~310). His world offset is therefore NEGATIVE:
# -(512 - 310) * 0.74 art units, i.e. the boat's centre sits (512-310) boat-art px to his
# left. Mirroring also keeps the canopy and the two fridge-shaped passengers - 白娘子 in
# ivory robes and 许仙 in the blue-green scholar's robe, both seen from BEHIND - on his FAR
# side, away from the cat, which idles at his picture-right.
const TV_BOAT_CENTER_X := -149.5
# The deck plank line inside the boat art (measured off its row profile: the plateau is row
# 295 over most of the open half); it is placed under his feet, so he reads as standing IN
# the boat. ⚠ Re-measure it with the art whenever the boat is regenerated: the new art's
# deck sits 12px lower in its own canvas than the old art's did.
const TV_BOAT_DECK_ROW := 295.0
const TV_BOAT_POP_TIME := 0.35
const TV_BOAT_BOB := 5.0
const TV_BOAT_BOB_SPEED := 1.7
const TV_BOAT_TILT := 0.02
# 竹竿: the pole is a SEPARATE sprite (never baked into the frames), which is the only way it
# can reach DOWN past the boat's hull into the water. The frames 2/3/4 are drawn
# empty-handed; the pole pivots on his grip and sweeps through the stroke's three angles.
const TV_POLE_PATH := "res://assets/generated/bamboo_pole.png"
const TV_POLE_ART_SIZE := Vector2(96.0, 1024.0)
# Where his hands hold the pole, measured down its own art.
const TV_POLE_GRIP_ART_Y := 560.0
# 1024 * 0.24 = 246px of pole, ~2x his own 125px drawn height, so the tip hangs well below
# the hull (his feet are ~50px below the grip, the tip ~111px).
const TV_POLE_SCALE := 0.24
# His grip point in HIS frames, converted with his own sprite scale (like the notes' origin).
# ⚠ The pole's ORIGIN is pinned here, so this point must lie ON the line through his two fists -
# otherwise the pole hangs beside his hands instead of in them. A least-squares fit to the three
# measured fist lines ((196,242)-(222,308), (118,182)-(218,299), (142,159)-(182,259)) lands on
# (200,279), which is at most 9.7px (2.4 drawn px) off any of them; the old (252,306) was 21-48px
# off, i.e. the pole was drawn a whole pole-width to the side of his grip.
const TV_POLE_GRIP_ART := Vector2(200.0, 279.0)
# The stroke's pole angle per frame, in radians; in Godot +y is DOWN, so a NEGATIVE angle turns
# the tip toward the picture-RIGHT. ⚠ These are measured off his own fists: a distance transform
# on frames 2/3/4 puts the two gripping fists at (196,242)/(222,308), (118,182)/(218,299) and
# (142,159)/(182,259), i.e. the pole runs from an upper-LEFT fist down to a lower-RIGHT one in
# EVERY frame - atan2(-dx, dy) gives -0.38, -0.71 and -0.38. The old values (-0.10, +0.60, -0.02)
# had the push swinging the tip the WRONG way, so the pole crossed his hands instead of lying in
# them (「竹竿的摆动方向好像反了和手握住的方向不一致」).
const TV_POLE_ANGLES := [-0.38, -0.71, -0.38]
# 一圈水花: the paper splash ring that bursts where the pole's tip bites the water on the push.
const TV_SPLASH_PATH := "res://assets/generated/water_splash_ring.png"
const TV_SPLASH_SCALE := 0.38
const TV_SPLASH_LIFE := 0.66
const TV_SPLASH_RISE := 10.0
# The whole-body motion: a shake through the transformation, then a gentle standing sway.
const TV_POOF_SHAKE := 8.0
const TV_POLE_SWAY := 2.0

# Idle ("待机") bits of business the fridge man plays by himself while nothing
# else is going on (see play_idle_action). Every atlas is generated from the
# IDLE art itself, so his body, face, colours and proportions are identical to
# idle — only the arms and stance move. Three 512px frames each, laid out like
# the rest atlas, so they all share one sprite scale and position.
const IDLE_ACTION_FRAME_SIZE := Vector2i(512, 512)
const IDLE_ACTIONS := {
	# 站立歇息 IS the default idle pose: the entry has no atlas and plays the plain
	# idle animation, so picking it shows the calm stance the character always has.
	"rest_stand": {
		"animation": "idle",
		"atlas": "",
		"fps": 3.5,
		"ping_pong": true,
	},
	# 打瞌睡 is its own action, NOT the default stance: he has to be asked to nod
	# off. The poses and timing come from FridgeDozeCycle, so this entry only names
	# the pose animation to start on.
	"doze": {
		"animation": "idle_doze",
		"atlas": "",
		"fps": 1.0,
		"ping_pong": false,
	},
	"smoke": {
		"animation": "idle_smoke",
		# Regenerated at the idle's own scale: the man is 503px of his 512px frame
		# with his feet on the same ground line (the old atlas drew him at 396px, so
		# he used to shrink during this animation).
		"atlas": "res://assets/generated/paper_fridge_idle_smoke.png",
		# EIGHT poses - a full, unhurried puff: the cigarette hangs at his hip, the
		# hand lifts it, it goes to his mouth, he lets go and his hand falls as he
		# inhales with his eyes shut, his head tips back and the smoke ring floats
		# away while he lifts his hand for the next drag. The in-between poses are
		# half-steps (arm mid-lift, ring just leaving the lips) so nothing snaps from
		# one extreme to the other, and 2.2fps keeps the whole 8-frame cycle at 3.6s.
		"frames": 8,
		"fps": 2.2,
		"ping_pong": false,
	},
	# 扔鞋子: the throw that opens 小猫睡觉 - he winds his arm back, swings it past his hip and
	# follows through. Three poses generated from his own idle frame, so his body, colours and
	# proportions stay identical to idle and only the arm moves. The slipper he lobs with it is
	# a separate sprite the level drives, so no object is baked into these frames.
	"throw_shoe": {
		"animation": "idle_throw_shoe",
		"atlas": "res://assets/generated/fridge_man_throw_shoe.png",
		"frames": 3,
		"fps": 4.5,
		"ping_pong": false,
	},
	"pet_cat": {
		"animation": "idle_pet_cat",
		# TEN poses making a real 撸猫 loop, played straight through: he stands, reaches
		# out to his RIGHT (the cat always sits on his right), lays his hand on the cat's
		# head, then strokes twice - down over its back with his eyes shut in bliss, arm
		# lifting back up between strokes. Half-step poses bridge every change so the arm
		# travels instead of snapping. His hand lands where the level parks the cat
		# (FRIDGE_PET_CAT_OFFSET is (96, -12), the cat's head sits right under his palm).
		"atlas": "res://assets/generated/paper_fridge_pet_cat_right.png",
		"frames": 10,
		"fps": 2.2,
		"ping_pong": false,
	},
}

# 打瞌睡 (doze): an idle ACTION, not the default stance (站立待机). He stands
# there for a while, nods off on his feet, sleep bubbles rise above his head, the
# bubble pops and he snaps awake with a start before settling back down and
# starting over. Both poses are single 512px frames laid out exactly like the
# idle frame (same size, feet on the same ground line) and their outlines match
# it, so the doze neither changes his size nor looks like a different art style.
const DOZE_ACTION_ID := "doze"
const DOZE_ANIMATION_NAME := "idle_doze"
const STARTLE_ANIMATION_NAME := "idle_startle"
const DOZE_FRAME_PATH := "res://assets/generated/paper_fridge_doze_v2.png"
const STARTLE_FRAME_PATH := "res://assets/generated/paper_fridge_startle_v2.png"
# The sleep bubble floats above his head (local offset); his body sags this far
# while he is asleep (see FridgeDozeCycle.get_body_offset).
const DOZE_BUBBLE_OFFSET := Vector2(78.0, -330.0)
const DOZE_BUBBLE_SCALE := 0.5
const DOZE_BODY_SINK := 7.0

const JUGGLE_FRAME_SIZE := Vector2i(512, 512)
const JUGGLE_OBJECT_SCALE := 0.62
# Where each hand catches / releases a tossed object, measured from the regenerated
# juggle art's raised-arm poses: the thrown-up hand's palm sits at frame x 78 and the other
# at frame x 421, palm rows ~25 / ~48. Those are SPRITE-local pixels, and the flying objects
# are siblings of the sprite (children of this node), not children of it - so the sprite's own
# base position (0, -145) has to be added back before the objects can actually meet the hands.
# At the 0.625 sprite scale that gives (-111.2, -289.2) and (102.9, -275.0). The two are
# deliberately asymmetric because the art is: each object arcs from one hand up over the
# head and down into the other hand - a crossing cascade that really lands in the hands.
const JUGGLE_HAND_LEFT := Vector2(-111.2, -289.2)
const JUGGLE_HAND_RIGHT := Vector2(102.9, -275.0)
# How high the arc peaks above the catching hands. Smaller than before only because the hands
# now sit higher (thrown up hard), keeping the same head-clearing peak as the old art.
const JUGGLE_ARC_LIFT := 80.0
# The objects' flight is LOCKED to the arm animation: the cycle is exactly the animation's own
# 4-frame cycle (4 / JUGGLE_ANIMATION_FPS = 1.25 s), so the hands and the tomatoes move on the
# same clock. A flight leg lasts half of that, which is exactly how long the art takes to swing
# from the raised right hand to the raised left hand, so the catch lands in the hand that is up.
const JUGGLE_CYCLE_TIME := 4.0 / JUGGLE_ANIMATION_FPS
const JUGGLE_LAUNCH_TIME := JUGGLE_CYCLE_TIME * 0.5
# Per-object flight: cycle offset plus a small height variation so the arc peaks are not
# identical. The offsets sit inside the 0.05-0.25 window, the only part of the arm animation's
# cycle where a catch always lands on a pose with that hand actually raised: the arms are up in
# three of the four frames, and a quarter of the cycle is the both-arms-crossing pose, which a
# tomato must never be scheduled to arrive in. The window is narrow, so the three tomatoes fly
# as a small train - each with its own arc height so their paths stay distinct.
# Toss patterns, rotated one after another for as long as the countdown runs (轮番播放):
# each lasts JUGGLE_PATTERN_TIME, so a 30 s 番茄钟 sees a full lap of all five. Every pattern
# keeps the objects' endpoints EXACTLY on the raised palms - the phases and the cycle time are
# untouched - and only changes the shape of the flight between them, so a pattern can never
# break the hand contact. Parameters:
#   lift     - overall arc height for the throw leg
#   back     - the RETURN leg as a fraction of that (a low pass makes a shower)
#   bulge    - how far the arc bows out sideways from the straight hand-to-hand line
#   swirl    - an extra circular wobble around the arc
#   spread   - widens the per-object height difference (1.0 = the shipped heights, 2.2 = two
#              clear tiers of balls)
const JUGGLE_PATTERNS := [
	{"name": "cascade", "lift": 1.0, "back": 1.0, "bulge": 0.0, "swirl": 0.0, "spread": 1.0},
	{"name": "shower", "lift": 1.0, "back": 0.32, "bulge": 0.0, "swirl": 0.0, "spread": 1.0},
	{"name": "wide_arcs", "lift": 0.82, "back": 0.9, "bulge": 118.0, "swirl": 0.0, "spread": 1.0},
	{"name": "two_tiers", "lift": 1.22, "back": 0.72, "bulge": 0.0, "swirl": 0.0, "spread": 2.6},
	{"name": "rosette", "lift": 0.92, "back": 0.85, "bulge": 58.0, "swirl": 52.0, "spread": 1.0},
]
## How long one pattern plays before the next takes over, and how long they cross-fade.
const JUGGLE_PATTERN_TIME := 6.0
const JUGGLE_PATTERN_BLEND := 0.6
# Per-object flight: cycle offset plus a small height variation so the arc peaks are not
# identical. The offsets sit inside the 0.05-0.25 window, the only part of the arm animation's
# cycle where a catch always lands on a pose with that hand actually raised: the arms are up in
# three of the four frames, and a quarter of the cycle is the both-arms-crossing pose, which a
# tomato must never be scheduled to arrive in. The window is narrow, so the three tomatoes fly
# as a small train - each with its own arc height so their paths stay distinct.
const JUGGLE_FLIGHTS := [
	{"phase": 0.07, "lift_scale": 1.0},
	{"phase": 0.15, "lift_scale": 0.9},
	{"phase": 0.23, "lift_scale": 0.82},
]
# Tossable objects: the base animation is pure motion with EMPTY hands, so the
# flying object is a separate, swappable layer (tomato by default — the tomato
# pomodoro item juggles tomatoes; the prop box in the level swaps it live; more
# objects can be registered here later).
const JUGGLE_PROJECTILES := [
	{"id": "ball", "path": "res://assets/generated/paper_juggle_ball.png"},
	{"id": "tomato", "path": "res://assets/generated/paper_tomato_projectile.png"},
]
const SPRITE_BASE_POSITION := Vector2(0.0, -145.0)

const IDLE_ANIMATION_NAME := "idle"

var phase := "idle"
var progress := 0.0
var time_text := "00:00"
var active_item_id := "tomato"
var item_elapsed := 0.0
# Juggle performance state: driven by the work session (dragging the tomato
# onto the fridge person) and by short chest-panel previews.
var session_juggling := false
var juggle_preview_timer := 0.0
var juggling := false
var juggle_motion := 0.0
var juggle_projectile_id := "tomato"
var juggle_objects: Array[Sprite2D] = []
# 打破第四面墙 state: the last tosses rushing the player's screen (see play_screen_toss_ending).
var screen_toss_active := false
var screen_toss_timer := 0.0
var screen_toss_from: Array[Vector2] = []
var screen_toss_target := Vector2.ZERO
var screen_toss_impacted := false
var animated_sprite: AnimatedSprite2D
# Rest performance state: a timed preview of the panting animation.
var resting := false
var rest_preview_timer := 0.0

# Ball-to-the-face ending state.
var ball_drop_active := false
var ball_drop_timer := 0.0
var ball_drop_sprite: Sprite2D

# Pager reaction state (see play_pager_reaction).
var pager_reaction_active := false
var pager_reaction_timer := 0.0
var pager_device_sprite: Sprite2D
# Once the four beats are over the levitation is held (not dropped) so he keeps
# floating with the device until the countdown he was started in runs out.
var pager_hold_active := false
var pager_hold_time := 0.0
# Gallery previews (骨架背包) run the reaction on a clock instead of waiting for a
# countdown: > 0 while such a preview is playing, and it stops itself at zero.
var pager_preview_timer := 0.0

# 磁带机 (cassette) dance state (see play_cassette_reaction): the five beats play once,
# then the dance is HELD until the countdown ends, with the notes still coming.
var cassette_reaction_active := false
var cassette_reaction_timer := 0.0
var cassette_hold_active := false
var cassette_hold_time := 0.0
var cassette_preview_timer := 0.0
# Pooled 音乐符号 sprites flying out of the boombox's speakers.
var cassette_notes: Array = []
var cassette_note_texture: Texture2D
var cassette_note_timer := 0.0
var cassette_note_serial := 0

# 电视机 (CRT) fisherman state (see play_tv_reaction): the transformation plays once and
# then the fishing stroke is HELD until the countdown ends.
var tv_reaction_active := false
var tv_reaction_timer := 0.0
var tv_hold_active := false
var tv_hold_time := 0.0
var tv_preview_timer := 0.0
# His ground shadow: the Polygon2D built by _create_shadow. Hidden for the whole 电视机
# performance, because he stands ON the boat there and the shadow would otherwise smear an
# olive patch across the deck planks.
var shadow_polygon: Polygon2D
var tv_boat_sprite: Sprite2D
var tv_pole_sprite: Sprite2D
var tv_splash_sprite: Sprite2D
var tv_splash_time := 0.0
var tv_last_pole_frame := -1
var tv_boat_pop := 0.0

# Idle action state (see play_idle_action): "" while he is not doing a bit of
# idle business.
var idle_action_id := ""
var idle_action_timer := 0.0
# Extra y offset applied while an idle action is drawn at a different size than
# the idle itself, so its feet stay planted on the ground line.
var sprite_scale_drop := 0.0

## How long he stands before nodding off when 打瞌睡 is REQUESTED by name (the
## skeleton gallery, or the idle rotation picking it). FridgeDozeCycle's own stand
## time is for the ambient stance, where a slow drift into sleep is the point.
const DOZE_REQUESTED_STAND_TIME := 0.25

# 打瞌睡 (the default idle) state.
var doze: FridgeDozeCycle
# How far the body sags / jolts this frame while dozing (see _update_doze).
var doze_body_offset := Vector2.ZERO


func _ready() -> void:
	z_index = 12
	set_process(true)
	_create_shadow()
	_create_animation()
	_create_doze_cycle()
	queue_redraw()


func _process(delta: float) -> void:
	item_elapsed += delta
	# The pager reaction and the ball-to-the-face ending own the character while
	# they play.
	if pager_reaction_active or pager_hold_active:
		_update_pager_reaction(delta)
	elif cassette_reaction_active or cassette_hold_active:
		_update_cassette_reaction(delta)
	elif tv_reaction_active or tv_hold_active:
		_update_tv_reaction(delta)
	elif screen_toss_active:
		_update_screen_toss(delta)
	elif ball_drop_active:
		_update_ball_drop(delta)
	else:
		if idle_action_id != "":
			idle_action_timer -= delta
			if idle_action_timer <= 0.0:
				stop_idle_action()
		if juggle_preview_timer > 0.0:
			juggle_preview_timer -= delta
			if juggle_preview_timer <= 0.0:
				juggle_preview_timer = 0.0
				_update_juggle_state()
				performance_finished.emit()
		if rest_preview_timer > 0.0:
			rest_preview_timer -= delta
			if rest_preview_timer <= 0.0:
				rest_preview_timer = 0.0
				_update_rest_state()
				performance_finished.emit()
		if juggling:
			juggle_motion += delta
			_update_juggle_motion()
	# 打瞌睡: the plain idle's own bit of business, always evaluated last so the
	# default stance wins whenever nothing else owns him.
	_update_doze(delta)
	_update_shadow_visibility()
	# The juggle frames are laid out exactly like the idle frame, so idle, juggle
	# and rest all share the same sprite scale and position — the ARMS do the
	# performing, the body stays put. Resting adds a slow breathing bob; the hit
	# ending shakes the whole body; juggling stays planted (no crouch).
	if animated_sprite != null and is_instance_valid(animated_sprite):
		# 整体缩小: this per-frame pass must NOT undo a performance's own scale multiplier.
		# It used to hard-set display_height/frame_size.y every frame, which silently
		# overwrote _set_sprite_scale_for(TV_FRAME_SIZE, TV_PERFORMANCE_SCALE) - the 电视机
		# scene was therefore drawn at full body size in the game while every test (which
		# parks _process) saw the scaled version. That is why shaving the const twice still
		# looked oversized, and why he towered over the boat's passengers.
		var scale_multiplier: float = TV_PERFORMANCE_SCALE if (tv_reaction_active or tv_hold_active) else 1.0
		var base_scale: float = display_height / float(frame_size.y) * scale_multiplier
		animated_sprite.scale = Vector2(base_scale, base_scale)
		var offset := Vector2.ZERO
		if resting:
			offset.y = sin(item_elapsed * 3.0) * 2.0
		if pager_reaction_active or pager_hold_active:
			offset += _get_pager_reaction_offset()
		if cassette_reaction_active or cassette_hold_active:
			offset += _get_cassette_offset()
		if tv_reaction_active or tv_hold_active:
			offset += _get_tv_offset()
		if ball_drop_active:
			offset += _get_ball_drop_shake()
		animated_sprite.position = SPRITE_BASE_POSITION + offset + doze_body_offset + Vector2(0.0, sprite_scale_drop)
	queue_redraw()


func set_pomodoro_state(new_phase: String, new_progress: float, new_time_text: String) -> void:
	phase = new_phase
	progress = clamp(new_progress, 0.0, 1.0)
	time_text = new_time_text
	queue_redraw()


func set_active_item(item_id: String) -> void:
	if active_item_id == item_id:
		return
	active_item_id = item_id
	item_elapsed = 0.0
	queue_redraw()


## Toggle the pomodoro juggle performance tied to a running work session:
## the fridge man starts (and loops) the arm-juggling animation in place. While
## performing, the countdown ring is replaced by the animation.
func set_pomodoro_juggle(enabled: bool) -> void:
	if session_juggling == enabled:
		return
	session_juggling = enabled
	_update_juggle_state()


## Short preview performance (e.g. from the chest collection panel): juggle
## for `duration` seconds even outside a session, then return to idle.
func play_juggle_preview(duration: float) -> void:
	if duration <= 0.0:
		return
	# 立即播放: the juggle replaces whatever he was doing - a running rest
	# performance AND any idle bit of business (smoking, dozing, petting). Without
	# this the clicked performance plays "behind" the idle action still owning the
	# sprite, which reads as the click having done nothing.
	stop_idle_action()
	# The juggle replaces a running rest performance.
	if rest_preview_timer > 0.0:
		rest_preview_timer = 0.0
		_update_rest_state()
	if juggle_preview_timer <= 0.0:
		juggle_preview_timer = duration
		_update_juggle_state()
	else:
		juggle_preview_timer = maxf(juggle_preview_timer, duration)


## Timed preview of the Gemini-generated exhausted rest animation (bent over,
## hands on knees, heavy panting). Replaces a running juggle performance.
func play_rest_preview(duration: float) -> void:
	if duration <= 0.0:
		return
	if juggle_preview_timer > 0.0:
		juggle_preview_timer = 0.0
		_update_juggle_state()
	if rest_preview_timer <= 0.0:
		rest_preview_timer = duration
		_update_rest_state()
	else:
		rest_preview_timer = maxf(rest_preview_timer, duration)


## Plays one of the idle ("待机") bits of business for `duration` seconds, then
## hands the sprite back to plain idle. Used both by the level's idle rotation
## and by the skeleton stand's action gallery.
func play_idle_action(action_id: String, duration: float) -> void:
	if not IDLE_ACTIONS.has(action_id) or duration <= 0.0:
		return
	# A bit of idle business replaces whatever he was doing.
	stop_performances()
	_start_doze_if_requested(action_id)
	idle_action_id = action_id
	idle_action_timer = duration
	_play_current_animation()


## 打瞌睡 asked for BY NAME (the skeleton gallery, or the idle rotation picking it)
## has to nod off promptly. The long stand-up in FridgeDozeCycle exists for the days
## when the doze was the ambient stance; as an explicitly requested action it just
## reads as "the click did nothing" for three seconds.
func _start_doze_if_requested(action_id: String) -> void:
	if action_id != DOZE_ACTION_ID:
		return
	if doze == null or not is_instance_valid(doze):
		return
	doze.stand_time = DOZE_REQUESTED_STAND_TIME
	doze.reset()


## Ends the current idle action (if any) and returns to plain idle.
func stop_idle_action() -> void:
	if idle_action_id == "":
		return
	idle_action_id = ""
	idle_action_timer = 0.0
	_play_current_animation()


func is_idle_action_active() -> bool:
	return idle_action_id != ""


## Stop any timed performance preview (rest, juggle, ball drop or pager
## reaction); used when a new pomodoro session starts so the character snaps
## back to idle.
func stop_performances() -> void:
	juggle_preview_timer = 0.0
	rest_preview_timer = 0.0
	ball_drop_active = false
	ball_drop_timer = 0.0
	if ball_drop_sprite != null and is_instance_valid(ball_drop_sprite):
		ball_drop_sprite.visible = false
	# 打破第四面墙: a stopped screen toss puts the tossed objects back to a sane size.
	screen_toss_active = false
	screen_toss_timer = 0.0
	screen_toss_impacted = false
	screen_toss_from.clear()
	for tossed: Sprite2D in juggle_objects:
		if tossed != null and is_instance_valid(tossed):
			tossed.visible = false
			tossed.scale = Vector2(JUGGLE_OBJECT_SCALE, JUGGLE_OBJECT_SCALE)
			tossed.rotation = 0.0
	pager_reaction_active = false
	pager_reaction_timer = 0.0
	pager_hold_active = false
	pager_hold_time = 0.0
	pager_preview_timer = 0.0
	if pager_device_sprite != null and is_instance_valid(pager_device_sprite):
		pager_device_sprite.visible = false
	cassette_reaction_active = false
	cassette_reaction_timer = 0.0
	cassette_hold_active = false
	cassette_hold_time = 0.0
	cassette_preview_timer = 0.0
	cassette_note_timer = 0.0
	_hide_cassette_notes()
	tv_reaction_active = false
	tv_reaction_timer = 0.0
	tv_hold_active = false
	tv_hold_time = 0.0
	tv_preview_timer = 0.0
	tv_boat_pop = 0.0
	if tv_boat_sprite != null and is_instance_valid(tv_boat_sprite):
		tv_boat_sprite.visible = false
	if tv_pole_sprite != null and is_instance_valid(tv_pole_sprite):
		tv_pole_sprite.visible = false
	if tv_splash_sprite != null and is_instance_valid(tv_splash_sprite):
		tv_splash_sprite.visible = false
	tv_splash_time = 0.0
	tv_last_pole_frame = -1
	idle_action_id = ""
	idle_action_timer = 0.0
	_update_juggle_state()
	_update_rest_state()
	# Those two only re-play when their own flag flips, so make sure a stopped
	# performance really hands the sprite back to idle.
	_play_current_animation()


## Plays the comic ball-to-the-face ending: a tossed object falls out of the
## juggle loop, bonks the fridge man, and he reels before settling to idle.
## Emits `performance_finished` when it is done (see _update_ball_drop).
func play_ball_drop_ending() -> void:
	juggle_preview_timer = 0.0
	rest_preview_timer = 0.0
	_update_juggle_state()
	_update_rest_state()
	_ensure_ball_drop_sprite()
	ball_drop_active = true
	ball_drop_timer = BALL_DROP_TOTAL_TIME
	if animated_sprite != null and is_instance_valid(animated_sprite):
		_set_sprite_scale_for(frame_size)
		animated_sprite.animation = IDLE_ANIMATION_NAME
		animated_sprite.play()


func _ensure_ball_drop_sprite() -> void:
	if ball_drop_sprite != null and is_instance_valid(ball_drop_sprite):
		return
	var texture: Texture2D = _load_projectile_texture(juggle_projectile_id)
	if texture == null:
		texture = _load_texture("res://assets/generated/paper_tomato_projectile.png")
	if texture == null:
		return
	ball_drop_sprite = Sprite2D.new()
	ball_drop_sprite.name = "BallDropSprite"
	ball_drop_sprite.texture = texture
	ball_drop_sprite.scale = Vector2(JUGGLE_OBJECT_SCALE, JUGGLE_OBJECT_SCALE)
	ball_drop_sprite.z_index = 6
	ball_drop_sprite.visible = false
	add_child(ball_drop_sprite)


func _update_ball_drop(delta: float) -> void:
	ball_drop_timer -= delta
	var elapsed: float = BALL_DROP_TOTAL_TIME - ball_drop_timer
	# Character pose: idle while the object falls, hit face during the impact.
	var in_hit: bool = elapsed >= BALL_DROP_FALL_TIME and elapsed < BALL_DROP_FALL_TIME + BALL_DROP_HIT_TIME
	if animated_sprite != null and is_instance_valid(animated_sprite):
		var desired: String = BALL_DROP_ANIMATION_NAME if in_hit else IDLE_ANIMATION_NAME
		if animated_sprite.animation != desired:
			animated_sprite.animation = desired
			animated_sprite.play()
	# Falling object: drops onto the face, then bounces away.
	if ball_drop_sprite != null and is_instance_valid(ball_drop_sprite):
		if elapsed < BALL_DROP_FALL_TIME:
			var fall_t: float = elapsed / BALL_DROP_FALL_TIME
			ball_drop_sprite.visible = true
			ball_drop_sprite.position = Vector2(0.0, lerp(BALL_DROP_START_Y, BALL_DROP_HIT_Y, fall_t * fall_t))
			ball_drop_sprite.rotation = fall_t * 2.2
		elif elapsed < BALL_DROP_FALL_TIME + BALL_DROP_BOUNCE_TIME:
			var bounce_t: float = (elapsed - BALL_DROP_FALL_TIME) / BALL_DROP_BOUNCE_TIME
			ball_drop_sprite.visible = true
			ball_drop_sprite.position = Vector2(120.0 * bounce_t, BALL_DROP_HIT_Y - 54.0 * sin(PI * bounce_t))
			ball_drop_sprite.rotation = bounce_t * 6.0
		else:
			ball_drop_sprite.visible = false
	if ball_drop_timer <= 0.0:
		ball_drop_timer = 0.0
		ball_drop_active = false
		if ball_drop_sprite != null and is_instance_valid(ball_drop_sprite):
			ball_drop_sprite.visible = false
		_play_current_animation()
		performance_finished.emit()


func _get_ball_drop_shake() -> Vector2:
	var elapsed: float = BALL_DROP_TOTAL_TIME - ball_drop_timer
	var shake_t: float = elapsed - BALL_DROP_FALL_TIME
	if shake_t < 0.0 or shake_t > BALL_DROP_SHAKE_TIME:
		return Vector2.ZERO
	var damp: float = 1.0 - shake_t / BALL_DROP_SHAKE_TIME
	return Vector2(sin(shake_t * 58.0) * 7.0, cos(shake_t * 50.0) * 4.0) * damp


## 打破第四面墙: the juggle's real ending. The tossed objects stop juggling and rush the
## CAMERA - they keep wherever the last toss left them, fly straight at the player's screen
## and grow until they blot it out. At the moment of impact `screen_hit` fires (the level
## jolts the view) and the fridge man flinches (STARTLE_ANIMATION_NAME - the current man's art,
## not the retired ball-to-the-face sheet the old ending used). Emits `performance_finished`
## when the beat is done, exactly like the other endings.
func play_screen_toss_ending() -> void:
	juggle_preview_timer = 0.0
	rest_preview_timer = 0.0
	ball_drop_active = false
	screen_toss_active = true
	screen_toss_timer = 0.0
	screen_toss_impacted = false
	# Aim at whatever the camera is looking at, expressed in THIS node's own space: the tossed
	# objects are children of the node, not of the sprite.
	var view_centre: Vector2 = global_position
	if is_inside_tree() and get_viewport().get_camera_2d() != null:
		view_centre = get_viewport().get_camera_2d().global_position
	screen_toss_target = to_local(view_centre)
	screen_toss_from.clear()
	for object_sprite: Sprite2D in juggle_objects:
		if object_sprite == null or not is_instance_valid(object_sprite):
			continue
		screen_toss_from.append(object_sprite.position)
		object_sprite.visible = true
		object_sprite.z_index = 40
		object_sprite.rotation = 0.0
	if animated_sprite != null and is_instance_valid(animated_sprite):
		animated_sprite.animation = IDLE_ANIMATION_NAME
		animated_sprite.play()


func _update_screen_toss(delta: float) -> void:
	screen_toss_timer += delta
	var flight_t: float = clamp(screen_toss_timer / SCREEN_TOSS_FLIGHT_TIME, 0.0, 1.0)
	# An accelerating rush: it hangs for a beat, then comes straight at the viewer.
	var eased: float = pow(flight_t, 2.2)
	for i in screen_toss_from.size():
		if i >= juggle_objects.size():
			break
		var object_sprite: Sprite2D = juggle_objects[i]
		if object_sprite == null or not is_instance_valid(object_sprite):
			continue
		if screen_toss_impacted:
			object_sprite.visible = false
			continue
		object_sprite.position = screen_toss_from[i].lerp(screen_toss_target, eased)
		# The size leads the position: it swells into your face well before the lunge lands,
		# so the last frame that is actually drawn is already huge (the impact frame hides it).
		var grow_t: float = sqrt(flight_t)
		var grown: float = JUGGLE_OBJECT_SCALE * lerpf(1.0, SCREEN_TOSS_MAX_SCALE, grow_t)
		object_sprite.scale = Vector2(grown, grown)
		object_sprite.rotation = eased * 6.0
	if not screen_toss_impacted and screen_toss_timer >= SCREEN_TOSS_FLIGHT_TIME:
		screen_toss_impacted = true
		for hit_object: Sprite2D in juggle_objects:
			if hit_object != null and is_instance_valid(hit_object):
				hit_object.visible = false
		screen_hit.emit()
		if animated_sprite != null and is_instance_valid(animated_sprite) \
				and animated_sprite.sprite_frames.has_animation(STARTLE_ANIMATION_NAME):
			animated_sprite.animation = STARTLE_ANIMATION_NAME
			animated_sprite.play()
	if screen_toss_timer >= SCREEN_TOSS_TOTAL_TIME:
		screen_toss_timer = 0.0
		screen_toss_active = false
		for rest_object: Sprite2D in juggle_objects:
			if rest_object != null and is_instance_valid(rest_object):
				rest_object.visible = false
				rest_object.scale = Vector2(JUGGLE_OBJECT_SCALE, JUGGLE_OBJECT_SCALE)
				rest_object.rotation = 0.0
		_play_current_animation()
		performance_finished.emit()


## Swap the object being juggled (ball <-> tomato <-> future objects).
## Applies live: flying sprites switch texture immediately, so it can be
## called mid-performance.
func set_juggle_projectile(id: String) -> void:
	var texture: Texture2D = _load_projectile_texture(id)
	if texture == null:
		return
	juggle_projectile_id = id
	for object_sprite: Sprite2D in juggle_objects:
		if object_sprite != null and is_instance_valid(object_sprite):
			object_sprite.texture = texture


## Single source of truth for the visual juggling state.
func _update_juggle_state() -> void:
	var should_juggle := session_juggling or juggle_preview_timer > 0.0
	if juggling == should_juggle:
		return
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if should_juggle and not animated_sprite.sprite_frames.has_animation(JUGGLE_ANIMATION_NAME):
		return
	if should_juggle and resting:
		resting = false

	juggling = should_juggle
	if juggling:
		juggle_motion = 0.0
	for object_sprite: Sprite2D in juggle_objects:
		if object_sprite != null and is_instance_valid(object_sprite):
			object_sprite.visible = juggling
	_play_current_animation()


## Single source of truth for the visual rest (panting) state.
func _update_rest_state() -> void:
	var should_rest := rest_preview_timer > 0.0
	if resting == should_rest:
		return
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if should_rest and not animated_sprite.sprite_frames.has_animation(REST_ANIMATION_NAME):
		return
	if should_rest and juggling:
		juggling = false
		for object_sprite: Sprite2D in juggle_objects:
			if object_sprite != null and is_instance_valid(object_sprite):
				object_sprite.visible = false

	resting = should_rest
	_play_current_animation()


## Where object `index` should be for a given motion time under `pattern`. The flight always
## runs from one RAISED palm to the other and back on the arm animation's own clock, so the
## catch still lands in a hand that is up; only the shape of the path between the palms changes
## (see JUGGLE_PATTERNS).
func _juggle_object_position(index: int, motion: float, pattern: Dictionary) -> Vector2:
	var flight: Dictionary = JUGGLE_FLIGHTS[index % JUGGLE_FLIGHTS.size()]
	var cycle: float = fposmod(motion / JUGGLE_CYCLE_TIME + float(flight["phase"]), 1.0)
	# First half of the cycle: the RAISED RIGHT hand (the art's frame 0) -> the RAISED
	# LEFT hand (frame 2); second half: back. Starting from the right hand is what ties
	# each leg to the pose that holds that hand up.
	var leg_t: float = cycle * 2.0
	var from: Vector2 = JUGGLE_HAND_RIGHT
	var to: Vector2 = JUGGLE_HAND_LEFT
	var leg_lift: float = float(pattern.get("lift", 1.0))
	if leg_t >= 1.0:
		leg_t -= 1.0
		from = JUGGLE_HAND_LEFT
		to = JUGGLE_HAND_RIGHT
		# The return leg can be a low pass (a shower) instead of a mirror of the throw.
		leg_lift *= float(pattern.get("back", 1.0))
	var target: Vector2 = from.lerp(to, leg_t)
	var arc: float = sin(PI * leg_t)
	# Widening the per-object height difference splits the balls into visible tiers.
	var spread: float = float(pattern.get("spread", 1.0))
	var lift_scale: float = 1.0 - (1.0 - float(flight.get("lift_scale", 1.0))) * spread
	target.y -= arc * JUGGLE_ARC_LIFT * maxf(lift_scale, 0.15) * leg_lift
	# Bow the arc out sideways from the straight hand-to-hand line...
	var bulge: float = float(pattern.get("bulge", 0.0))
	if bulge != 0.0:
		target.x += arc * bulge * (1.0 if to.x > from.x else -1.0)
	# ...and let a pattern add a circular wobble around the whole hop. Everything extra is
	# scaled by `arc`, which is exactly 0 at both palms - so no pattern can ever displace a
	# catch out of the hand it is supposed to land in.
	var swirl: float = float(pattern.get("swirl", 0.0))
	if swirl != 0.0:
		target.x += cos(TAU * leg_t) * swirl * 0.5 * arc
		target.y += cos(TAU * leg_t) * swirl * arc
	return target


## Drives the flying objects. The toss pattern ROTATES (轮番播放) every JUGGLE_PATTERN_TIME
## for as long as the juggle runs, cross-fading into the next one, so a long countdown shows a
## cascade, then a shower, then wide arcs, then two tiers of balls, then a rosette, and round
## again. Cycles are staggered so the objects are always spread between the hands and the air.
func _update_juggle_motion() -> void:
	var launch_t: float = clamp(juggle_motion / JUGGLE_LAUNCH_TIME, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - launch_t, 3.0)
	var start_point := Vector2(0.0, -160.0)
	var pattern_count: int = JUGGLE_PATTERNS.size()
	var index: int = int(juggle_motion / JUGGLE_PATTERN_TIME) % pattern_count
	var pattern: Dictionary = JUGGLE_PATTERNS[index]
	var next_pattern: Dictionary = JUGGLE_PATTERNS[(index + 1) % pattern_count]
	var into: float = fposmod(juggle_motion, JUGGLE_PATTERN_TIME)
	var blend: float = 0.0
	if into > JUGGLE_PATTERN_TIME - JUGGLE_PATTERN_BLEND:
		blend = clamp((into - (JUGGLE_PATTERN_TIME - JUGGLE_PATTERN_BLEND)) / JUGGLE_PATTERN_BLEND, 0.0, 1.0)
	for i in juggle_objects.size():
		var object_sprite := juggle_objects[i]
		if object_sprite == null or not is_instance_valid(object_sprite):
			continue
		var target: Vector2 = _juggle_object_position(i, juggle_motion, pattern)
		if blend > 0.0:
			# Cross-fade the two patterns' paths so the change of shape never snaps.
			target = target.lerp(_juggle_object_position(i, juggle_motion, next_pattern), blend)
		object_sprite.position = start_point.lerp(target, eased)
		var object_scale: float = JUGGLE_OBJECT_SCALE * (0.45 + 0.55 * eased)
		object_sprite.scale = Vector2(object_scale, object_scale)
		# Gentle airborne tilt, like the tilted objects in the reference.
		object_sprite.rotation = sin(juggle_motion * 2.2 + float(i) * 1.7) * 0.3
		# The toss happens in a vertical plane in front of the fridge man —
		# no weaving around the body.
		object_sprite.z_index = 2


## Ends the pager reaction/levitation and hands the character back to idle. The
## level calls this when the countdown the reaction belongs to runs out.
func stop_pager_reaction() -> void:
	if not pager_reaction_active and not pager_hold_active:
		return
	pager_reaction_active = false
	pager_reaction_timer = 0.0
	pager_hold_active = false
	pager_hold_time = 0.0
	pager_preview_timer = 0.0
	if pager_device_sprite != null and is_instance_valid(pager_device_sprite):
		pager_device_sprite.visible = false
	_play_current_animation()


## Plays the pager (BB机) reaction: the four keyframes from the reference chart,
## then - instead of dropping back to idle - he holds the levitation with the
## device until the countdown ends (stop_pager_reaction). Clears the other
## performances first so two never fight over the sprite.
## Timed preview of the pager (BB机) reaction for the skeleton stand's gallery: the
## same four beats and levitation, but the hold ends by itself after `duration`
## seconds instead of waiting for a countdown to finish.
func play_pager_preview(duration: float) -> void:
	if duration <= 0.0:
		return
	play_pager_reaction()
	pager_preview_timer = duration


func play_pager_reaction() -> void:
	# 立即播放: the reaction replaces whatever he was doing, an idle bit of business
	# included (see play_juggle_preview).
	stop_idle_action()
	pager_preview_timer = 0.0
	pager_hold_active = false
	pager_hold_time = 0.0
	juggle_preview_timer = 0.0
	rest_preview_timer = 0.0
	ball_drop_active = false
	ball_drop_timer = 0.0
	if ball_drop_sprite != null and is_instance_valid(ball_drop_sprite):
		ball_drop_sprite.visible = false
	_update_juggle_state()
	_update_rest_state()
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if not animated_sprite.sprite_frames.has_animation(PAGER_ANIMATION_NAME):
		return
	_ensure_pager_device_sprite()
	pager_reaction_active = true
	pager_reaction_timer = PAGER_TOTAL_TIME
	_set_sprite_scale_for(PAGER_FRAME_SIZE)
	animated_sprite.animation = PAGER_ANIMATION_NAME
	animated_sprite.frame = 0
	animated_sprite.play()


func _ensure_pager_device_sprite() -> void:
	if pager_device_sprite != null and is_instance_valid(pager_device_sprite):
		return
	var texture: Texture2D = _load_texture(PAGER_DEVICE_PATH)
	if texture == null:
		return
	pager_device_sprite = Sprite2D.new()
	pager_device_sprite.name = "PagerDeviceSprite"
	pager_device_sprite.texture = texture
	pager_device_sprite.scale = Vector2(PAGER_DEVICE_SCALE, PAGER_DEVICE_SCALE)
	pager_device_sprite.z_index = 6
	pager_device_sprite.visible = false
	add_child(pager_device_sprite)


## When the third keyframe ends: the device is no longer in his hands and the float-local
## clock starts (it runs through the reach / grab / float frames).
func _get_pager_float_start() -> float:
	return PAGER_BEATS[0] + PAGER_BEATS[1] + PAGER_BEATS[2]


## 抓住BB机: reaching up (float-local time 0..0.8) he is still on the ground and keeps a
## light tremble; from the moment his fists close he rises off the ground and drifts.
## `t` is float-local time and simply keeps growing while the float is held.
func _get_pager_float_offset(t: float) -> Vector2:
	var grab_done: float = PAGER_REACH_TIME + PAGER_GRAB_TIME
	if t <= grab_done:
		return Vector2(sin(t * 54.0), cos(t * 47.0)) * PAGER_BUZZ_LIGHT
	var lift_t: float = t - grab_done
	var rise: float = clampf(lift_t / PAGER_FLOAT_RISE_TIME, 0.0, 1.0)
	var lift: float = PAGER_FLOAT_LIFT * (1.0 - pow(1.0 - rise, 3.0))
	return Vector2(0.0, -lift + sin(lift_t * PAGER_FLOAT_BOB_SPEED) * PAGER_FLOAT_MAN_BOB)


## Whole-body motion for the pager reaction: a buzz during the shake beats, then
## a lift off the ground plus a slow up-and-down drift during the float beat.
func _get_pager_reaction_offset() -> Vector2:
	if pager_hold_active:
		return _get_pager_float_offset(pager_hold_time)
	var elapsed: float = PAGER_TOTAL_TIME - pager_reaction_timer
	if elapsed >= _get_pager_float_start():
		return _get_pager_float_offset(elapsed - _get_pager_float_start())
	var amplitude := 0.0
	if elapsed >= PAGER_BEATS[0] + PAGER_BEATS[1]:
		amplitude = PAGER_BUZZ_STRONG
	elif elapsed >= PAGER_BEATS[0]:
		amplitude = PAGER_BUZZ_LIGHT
	if amplitude <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(elapsed * 54.0), cos(elapsed * 47.0)) * amplitude


## Drives the pager reaction: once the device leaves his hands the separate device
## sprite pops out in front of his chest and keeps drifting up and down. When the
## four beats are done he does NOT drop back to idle - he holds the float
## (pager_hold_active) until stop_pager_reaction, so the levitation lasts for the
## whole rest of the countdown.
func _update_pager_reaction(delta: float) -> void:
	# A gallery preview is on a clock: once it runs out he drops back to idle.
	if pager_preview_timer > 0.0:
		pager_preview_timer = maxf(pager_preview_timer - delta, 0.0)
		if pager_preview_timer <= 0.0:
			stop_pager_reaction()
			return
	if pager_hold_active:
		pager_hold_time += delta
		_update_pager_device(pager_hold_time)
		return
	pager_reaction_timer -= delta
	var elapsed: float = PAGER_TOTAL_TIME - pager_reaction_timer
	if elapsed < _get_pager_float_start():
		if pager_device_sprite != null and is_instance_valid(pager_device_sprite):
			pager_device_sprite.visible = false
	else:
		_update_pager_device(elapsed - _get_pager_float_start())
	if pager_reaction_timer <= 0.0:
		pager_reaction_timer = 0.0
		pager_reaction_active = false
		pager_hold_active = true
		# The hold picks the float clock up exactly where the fourth keyframe left
		# it, so the levitation does not pop when the beats end. The atlas
		# animation is non-looping, so the sprite stays parked on the float frame.
		pager_hold_time = PAGER_TOTAL_TIME - _get_pager_float_start()
		_update_pager_device(pager_hold_time)
		performance_finished.emit()


## Places the levitating device for float-local time `t`: it pops out where his shaking
## hand left it, climbs through PAGER_RISE_KEYS (reaching hands -> fists -> overhead) and
## then rides his own drift.
func _update_pager_device(t: float) -> void:
	if pager_device_sprite == null or not is_instance_valid(pager_device_sprite):
		return
	var pop: float = clampf(t / 0.25, 0.0, 1.0)
	var device_scale: float = PAGER_DEVICE_SCALE * (0.55 + 0.45 * pop)
	pager_device_sprite.visible = true
	pager_device_sprite.scale = Vector2(device_scale, device_scale)
	# 抓住BB机: walk the key points; past the last one it simply sits in the raised fists.
	var base_position: Vector2 = PAGER_RISE_KEYS[PAGER_RISE_KEYS.size() - 1]
	for k in range(1, PAGER_RISE_KEYS.size()):
		if t < float(PAGER_RISE_KEY_TIMES[k]):
			var from_t: float = float(PAGER_RISE_KEY_TIMES[k - 1])
			var to_t: float = float(PAGER_RISE_KEY_TIMES[k])
			var local: float = clampf((t - from_t) / maxf(to_t - from_t, 0.001), 0.0, 1.0)
			var eased: float = local * local * (3.0 - 2.0 * local)
			base_position = (PAGER_RISE_KEYS[k - 1] as Vector2).lerp(PAGER_RISE_KEYS[k], eased)
			break
	pager_device_sprite.position = base_position + _get_pager_reaction_offset()
	# Held tight in both hands (or hanging in his reach): no tilt of its own.
	pager_device_sprite.rotation = 0.0


## True while the pager levitation is actually showing: he is floating and the
## detached device is on screen in front of his chest. The level uses this to run
## the glyph spray out from underneath the device.
func is_pager_levitating() -> bool:
	if not (pager_reaction_active or pager_hold_active):
		return false
	if pager_device_sprite == null or not is_instance_valid(pager_device_sprite):
		return false
	return pager_device_sprite.visible


## 随着BB机向上移动: true once the held levitation has settled AND the delay is up, i.e.
## the fridge man should now be travelling upward with the pager. The level asks this
## each frame and moves his node (and wraps him at the screen edges).
func is_pager_flying() -> bool:
	if not pager_hold_active:
		return false
	return pager_hold_time >= PAGER_FLOAT_RISE_TIME + PAGER_FLIGHT_DELAY


## 磁带机: true once the boombox dance has settled into its held loop, i.e. the music is
## playing with the boombox on his shoulder. The LEVEL asks this every frame and paces him
## SIDEWAYS (see FridgeLevel._update_fridge_player_flight) until the countdown ends.
func is_cassette_dancing() -> bool:
	return cassette_hold_active


## World position of the levitating device (falls back to his chest point while
## the device sprite does not exist yet).
func get_pager_device_global_position() -> Vector2:
	if pager_device_sprite != null and is_instance_valid(pager_device_sprite):
		return pager_device_sprite.global_position
	return global_position + PAGER_FLOAT_POSITION


## Plays the 磁带机 (cassette) countdown performance: he pulls a boombox out, hoists it
## over his head, shoulders it and dances with it while 音乐符号 fly out of it - and then
## HOLDS the dance until stop_cassette_reaction (the countdown's end), exactly like the
## pager holds its levitation.
func play_cassette_preview(duration: float) -> void:
	if duration <= 0.0:
		return
	play_cassette_reaction()
	cassette_preview_timer = duration


func play_cassette_reaction() -> void:
	# 立即播放: the dance replaces whatever he was doing - the pager's own performance
	# and any idle bit of business included.
	stop_idle_action()
	stop_pager_reaction()
	cassette_preview_timer = 0.0
	cassette_hold_active = false
	cassette_hold_time = 0.0
	cassette_note_timer = 0.0
	juggle_preview_timer = 0.0
	rest_preview_timer = 0.0
	ball_drop_active = false
	ball_drop_timer = 0.0
	if ball_drop_sprite != null and is_instance_valid(ball_drop_sprite):
		ball_drop_sprite.visible = false
	_update_juggle_state()
	_update_rest_state()
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if not animated_sprite.sprite_frames.has_animation(CASSETTE_ANIMATION_NAME):
		return
	_ensure_cassette_note_texture()
	cassette_reaction_active = true
	cassette_reaction_timer = CASSETTE_TOTAL_TIME
	_set_sprite_scale_for(CASSETTE_FRAME_SIZE)
	animated_sprite.animation = CASSETTE_ANIMATION_NAME
	animated_sprite.frame = 0
	animated_sprite.play()


## Ends the dance and hands the character back to idle. The level calls this when the
## countdown the performance belongs to runs out.
func stop_cassette_reaction() -> void:
	if not cassette_reaction_active and not cassette_hold_active:
		return
	cassette_reaction_active = false
	cassette_reaction_timer = 0.0
	cassette_hold_active = false
	cassette_hold_time = 0.0
	cassette_preview_timer = 0.0
	cassette_note_timer = 0.0
	_hide_cassette_notes()
	_play_current_animation()


## Whole-body motion for the dance: a shake while he hoists the boombox, then an
## exaggerated up-and-down bop with a small side-to-side sway while it is held.
func _get_cassette_offset() -> Vector2:
	if cassette_hold_active:
		return Vector2(sin(cassette_hold_time * 6.4) * 2.5, -absf(sin(cassette_hold_time * 5.2)) * CASSETTE_BOP)
	var elapsed: float = CASSETTE_TOTAL_TIME - cassette_reaction_timer
	if elapsed < 0.5:
		return Vector2.ZERO
	return Vector2(sin(elapsed * 46.0), cos(elapsed * 41.0)) * CASSETTE_HOIST_SHAKE * clampf((elapsed - 0.5) / 0.4, 0.0, 1.0)


## Drives the dance: the five beats play on their own clock, then it holds (with the
## notes still coming) until the countdown ends or a gallery preview timer runs out.
func _update_cassette_reaction(delta: float) -> void:
	if cassette_preview_timer > 0.0:
		cassette_preview_timer = maxf(cassette_preview_timer - delta, 0.0)
		_update_cassette_notes(delta)
		if cassette_preview_timer <= 0.0:
			stop_cassette_reaction()
			return
	if cassette_hold_active:
		cassette_hold_time += delta
		_spawn_cassette_notes(delta)
		_update_cassette_notes(delta)
		_update_cassette_groove()
		return
	cassette_reaction_timer -= delta
	_spawn_cassette_notes(delta)
	_update_cassette_notes(delta)
	if cassette_reaction_timer <= 0.0:
		cassette_reaction_timer = 0.0
		cassette_reaction_active = false
		cassette_hold_active = true
		cassette_hold_time = 0.0
		performance_finished.emit()


## The held dance: bop between the last two beats so the pose never freezes. The atlas
## animation is non-looping, so without this he would stand still on the last frame.
func _update_cassette_groove() -> void:
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if not animated_sprite.sprite_frames.has_animation(CASSETTE_ANIMATION_NAME):
		return
	var step: int = int(cassette_hold_time * CASSETTE_GROOVE_FPS)
	animated_sprite.frame = CASSETTE_GROOVE_FIRST_FRAME + (step % 2)


func _ensure_cassette_note_texture() -> void:
	if cassette_note_texture != null:
		return
	cassette_note_texture = _load_texture(CASSETTE_NOTE_ATLAS_PATH)


## True while a performance or the ball-to-the-face ending owns him. The level uses it to tell
## a 改变飞行方向 click apart from the idle click that toggles the room's props.
func is_performing() -> bool:
	return pager_reaction_active or pager_hold_active or cassette_reaction_active \
		or cassette_hold_active or tv_reaction_active or tv_hold_active or ball_drop_active


## Where the 音乐符号 are born, in the player's own space: a point on the boombox's
## speaker grille, converted from the art's 512px canvas through the sprite's scale.
func _get_cassette_note_origin() -> Vector2:
	var scale_factor: float = display_height / float(CASSETTE_FRAME_SIZE.y)
	return SPRITE_BASE_POSITION + Vector2(0.0, sprite_scale_drop) \
		+ (CASSETTE_NOTE_ART_ORIGIN - Vector2(256.0, 256.0)) * scale_factor


## 音乐符号: spawn one note every CASSETTE_NOTE_INTERVAL, but only once the boombox is on
## his shoulder. The sprites are pooled, so a long dance never allocates.
func _spawn_cassette_notes(delta: float) -> void:
	var elapsed: float = CASSETTE_TOTAL_TIME if cassette_hold_active else CASSETTE_TOTAL_TIME - cassette_reaction_timer
	if elapsed < CASSETTE_NOTE_START:
		return
	cassette_note_timer -= delta
	if cassette_note_timer > 0.0:
		return
	cassette_note_timer = CASSETTE_NOTE_INTERVAL
	_ensure_cassette_note_texture()
	if cassette_note_texture == null:
		return
	var note: Sprite2D = null
	for existing: Sprite2D in cassette_notes:
		if existing != null and is_instance_valid(existing) and not bool(existing.get_meta("flying", false)):
			note = existing
			break
	if note == null:
		if cassette_notes.size() >= CASSETTE_NOTE_POOL:
			return
		note = Sprite2D.new()
		note.name = "CassetteNote%d" % cassette_notes.size()
		note.z_index = 5
		add_child(note)
		cassette_notes.append(note)
	var index: int = cassette_note_serial % CASSETTE_NOTE_FRAMES
	cassette_note_serial += 1
	var note_texture := AtlasTexture.new()
	note_texture.atlas = cassette_note_texture
	note_texture.region = Rect2(
		index * CASSETTE_NOTE_SOURCE_SIZE.x,
		0,
		CASSETTE_NOTE_SOURCE_SIZE.x,
		CASSETTE_NOTE_SOURCE_SIZE.y
	)
	note.texture = note_texture
	note.scale = Vector2(CASSETTE_NOTE_SCALE, CASSETTE_NOTE_SCALE)
	note.modulate = Color(1.0, 1.0, 1.0, 1.0)
	note.rotation = 0.0
	# A deterministic spread (no randf, so a test sees the same thing every run).
	var wobble: float = float(cassette_note_serial % 5) * 0.45 - 0.9
	note.position = _get_cassette_note_origin() + Vector2(wobble * 12.0, 6.0)
	note.set_meta("flying", true)
	note.set_meta("life", CASSETTE_NOTE_LIFE)
	note.set_meta("drift", wobble * CASSETTE_NOTE_SPREAD)
	note.visible = true


## Floats the live 音乐符号 upward and fades them out, recycling the pooled sprites.
func _update_cassette_notes(delta: float) -> void:
	for note: Sprite2D in cassette_notes:
		if note == null or not is_instance_valid(note):
			continue
		if not bool(note.get_meta("flying", false)):
			continue
		var life: float = float(note.get_meta("life", 0.0)) - delta
		note.set_meta("life", life)
		if life <= 0.0:
			note.set_meta("flying", false)
			note.visible = false
			continue
		var step: float = delta / maxf(CASSETTE_NOTE_LIFE, 0.001)
		note.position.y -= CASSETTE_NOTE_RISE * step
		note.position.x += float(note.get_meta("drift", 0.0)) * step
		note.rotation = sin((CASSETTE_NOTE_LIFE - life) * 5.0) * 0.25
		note.modulate.a = clampf(life / (CASSETTE_NOTE_LIFE * 0.55), 0.0, 1.0)


func _hide_cassette_notes() -> void:
	for note: Sprite2D in cassette_notes:
		if note != null and is_instance_valid(note):
			note.set_meta("flying", false)
			note.visible = false


## Plays the 电视机 (CRT) countdown performance: the fridge man is startled, turns into a
## Chinese fisherman in a puff of paper smoke, and poles his 乌篷船 - with 白娘子 and 许仙
## sitting at the far end, their backs to the player - for the whole countdown.
func play_tv_preview(duration: float) -> void:
	if duration <= 0.0:
		return
	play_tv_reaction()
	tv_preview_timer = duration


func play_tv_reaction() -> void:
	# 立即播放: the transformation replaces whatever he was doing.
	stop_idle_action()
	stop_pager_reaction()
	stop_cassette_reaction()
	tv_preview_timer = 0.0
	tv_hold_active = false
	tv_hold_time = 0.0
	juggle_preview_timer = 0.0
	rest_preview_timer = 0.0
	ball_drop_active = false
	ball_drop_timer = 0.0
	if ball_drop_sprite != null and is_instance_valid(ball_drop_sprite):
		ball_drop_sprite.visible = false
	_update_juggle_state()
	_update_rest_state()
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if not animated_sprite.sprite_frames.has_animation(TV_ANIMATION_NAME):
		return
	_ensure_tv_boat_sprite()
	_ensure_tv_pole_sprite()
	_ensure_tv_splash_sprite()
	tv_splash_time = 0.0
	tv_last_pole_frame = -1
	tv_reaction_active = true
	tv_reaction_timer = TV_TOTAL_TIME
	tv_boat_pop = 0.0
	_set_sprite_scale_for(TV_FRAME_SIZE, TV_PERFORMANCE_SCALE)
	animated_sprite.animation = TV_ANIMATION_NAME
	animated_sprite.frame = 0
	animated_sprite.play()


## Ends the fishing trip and hands the character back to idle, boat and all. The level
## calls this when the countdown the performance belongs to runs out.
func stop_tv_reaction() -> void:
	if not tv_reaction_active and not tv_hold_active:
		return
	tv_reaction_active = false
	tv_reaction_timer = 0.0
	tv_hold_active = false
	tv_hold_time = 0.0
	tv_preview_timer = 0.0
	tv_boat_pop = 0.0
	if tv_boat_sprite != null and is_instance_valid(tv_boat_sprite):
		tv_boat_sprite.visible = false
	if tv_pole_sprite != null and is_instance_valid(tv_pole_sprite):
		tv_pole_sprite.visible = false
	if tv_splash_sprite != null and is_instance_valid(tv_splash_sprite):
		tv_splash_sprite.visible = false
	tv_splash_time = 0.0
	tv_last_pole_frame = -1
	_play_current_animation()


## 电视机: true while he is out on the boat - the boat is up and the stroke is running.
func is_tv_fishing() -> bool:
	if not tv_reaction_active and not tv_hold_active:
		return false
	return tv_boat_sprite != null and is_instance_valid(tv_boat_sprite) and tv_boat_sprite.visible


## Whole-body motion: a hard shake through the transformation (its first two beats), then
## a gentle standing sway while he works the pole.
func _get_tv_offset() -> Vector2:
	var elapsed: float = TV_TOTAL_TIME if tv_hold_active else TV_TOTAL_TIME - tv_reaction_timer
	# The motion scales with the performance, so the smaller scene shakes by less.
	if elapsed < 1.0:
		return Vector2(sin(elapsed * 52.0), cos(elapsed * 44.0)) * TV_POOF_SHAKE * TV_PERFORMANCE_SCALE
	return Vector2(0.0, sin(elapsed * 3.4) * TV_POLE_SWAY * TV_PERFORMANCE_SCALE)


func _update_tv_reaction(delta: float) -> void:
	if tv_preview_timer > 0.0:
		tv_preview_timer = maxf(tv_preview_timer - delta, 0.0)
		_update_tv_boat(delta)
		if tv_preview_timer <= 0.0:
			stop_tv_reaction()
			return
	if tv_hold_active:
		tv_hold_time += delta
		_update_tv_boat(delta)
		_update_tv_pole()
		_update_tv_pole_and_splash(delta)
		return
	tv_reaction_timer -= delta
	_update_tv_boat(delta)
	_update_tv_pole_and_splash(delta)
	if tv_reaction_timer <= 0.0:
		tv_reaction_timer = 0.0
		tv_reaction_active = false
		tv_hold_active = true
		tv_hold_time = 0.0
		performance_finished.emit()


## The held stroke: cycle the last three frames (pole up -> push -> lift) so he keeps
## working the pole instead of freezing on the atlas' last frame.
func _update_tv_pole() -> void:
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	if not animated_sprite.sprite_frames.has_animation(TV_ANIMATION_NAME):
		return
	var step: int = int(tv_hold_time * TV_POLE_FPS)
	animated_sprite.frame = TV_POLE_FIRST_FRAME + (step % 3)


## 竹竿 + 水花, driven every frame of the performance: the pole sprite is shown only while he
## is actually holding it (frames 2..4) and is rotated to that frame's stroke angle, and the
## splash ring fires once per stroke, the moment the PUSH frame comes up - that is when the
## tip is deepest, and it is aimed at the pole's real tip position rather than an offset guess.
func _update_tv_pole_and_splash(delta: float) -> void:
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return
	var holding: bool = animated_sprite.animation == TV_ANIMATION_NAME \
		and animated_sprite.frame >= TV_POLE_FIRST_FRAME
	if tv_pole_sprite != null and is_instance_valid(tv_pole_sprite):
		tv_pole_sprite.visible = holding
		if holding:
			var man_scale_p: float = display_height / float(TV_FRAME_SIZE.y) * TV_PERFORMANCE_SCALE
			var index: int = clampi(animated_sprite.frame - TV_POLE_FIRST_FRAME, 0, TV_POLE_ANGLES.size() - 1)
			tv_pole_sprite.scale = Vector2(TV_POLE_SCALE, TV_POLE_SCALE)
			tv_pole_sprite.rotation = float(TV_POLE_ANGLES[index])
			tv_pole_sprite.position = SPRITE_BASE_POSITION + Vector2(0.0, sprite_scale_drop) \
				+ (TV_POLE_GRIP_ART - Vector2(256.0, 256.0)) * man_scale_p + _get_tv_offset()
	# The splash is started AFTER the pole has been placed THIS frame: it has to aim at the
	# pole's current tip, and on the very first call the pole has not been positioned yet.
	if holding and animated_sprite.frame == TV_POLE_FIRST_FRAME + 1 \
			and tv_last_pole_frame != animated_sprite.frame:
		_start_tv_splash()
	tv_last_pole_frame = animated_sprite.frame if holding else -1
	_update_tv_splash(delta)


## World point of the pole's lower tip, so the splash bursts exactly where the pole meets the
## water: the pole's offset pins its grip row to the node, so the tip is half the art below
## that, rotated with the sprite.
func _get_tv_pole_tip() -> Vector2:
	if tv_pole_sprite == null or not is_instance_valid(tv_pole_sprite):
		return Vector2.ZERO
	var local: Vector2 = (Vector2(0.0, TV_POLE_ART_SIZE.y * 0.5) + tv_pole_sprite.offset) * TV_POLE_SCALE
	return tv_pole_sprite.position + local.rotated(tv_pole_sprite.rotation)


func _start_tv_splash() -> void:
	if tv_splash_sprite == null or not is_instance_valid(tv_splash_sprite):
		return
	tv_splash_time = TV_SPLASH_LIFE
	tv_splash_sprite.visible = true
	tv_splash_sprite.position = _get_tv_pole_tip()
	tv_splash_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tv_splash_sprite.scale = Vector2(TV_SPLASH_SCALE * 0.45, TV_SPLASH_SCALE * 0.45)


func _update_tv_splash(delta: float) -> void:
	if tv_splash_sprite == null or not is_instance_valid(tv_splash_sprite):
		return
	if tv_splash_time <= 0.0:
		tv_splash_sprite.visible = false
		return
	tv_splash_time = maxf(tv_splash_time - delta, 0.0)
	# NOT "progress": that name is already a member of this class (the pomodoro bar), and the
	# shadowing only shows up as a Session Error when the scene RUNS.
	var fade_frac: float = 1.0 - tv_splash_time / TV_SPLASH_LIFE
	var eased: float = fade_frac * fade_frac * (3.0 - 2.0 * fade_frac)
	var size: float = TV_SPLASH_SCALE * (0.45 + 0.55 * eased)
	tv_splash_sprite.scale = Vector2(size, size)
	tv_splash_sprite.modulate.a = clampf(1.0 - fade_frac * fade_frac, 0.0, 1.0)
	tv_splash_sprite.position.y -= TV_SPLASH_RISE * delta / maxf(TV_SPLASH_LIFE, 0.001)


## The boat: popped out of nothing as the transformation lands, then bobbing on the water
## under his feet for the rest of the performance.
func _ensure_tv_boat_sprite() -> void:
	if tv_boat_sprite != null and is_instance_valid(tv_boat_sprite):
		return
	var texture: Texture2D = _load_texture(TV_BOAT_PATH)
	if texture == null:
		return
	tv_boat_sprite = Sprite2D.new()
	tv_boat_sprite.name = "TvBoatSprite"
	tv_boat_sprite.texture = texture
	tv_boat_sprite.z_index = 11
	tv_boat_sprite.visible = false
	add_child(tv_boat_sprite)


## 竹竿: the long bamboo pole, a separate sprite pivoting on his grip. Its offset is set so
## the art's grip row lands on the node, which makes rotating the sprite swing the pole in
## water below the boat.
func _ensure_tv_pole_sprite() -> void:
	if tv_pole_sprite != null and is_instance_valid(tv_pole_sprite):
		return
	var texture: Texture2D = _load_texture(TV_POLE_PATH)
	if texture == null:
		return
	tv_pole_sprite = Sprite2D.new()
	tv_pole_sprite.name = "TvPoleSprite"
	tv_pole_sprite.texture = texture
	tv_pole_sprite.z_index = 12
	tv_pole_sprite.offset = Vector2(0.0, TV_POLE_ART_SIZE.y * 0.5 - TV_POLE_GRIP_ART_Y)
	tv_pole_sprite.visible = false
	add_child(tv_pole_sprite)


## 一圈水花: the paper splash ring that bursts where the pole's tip bites the water.
func _ensure_tv_splash_sprite() -> void:
	if tv_splash_sprite != null and is_instance_valid(tv_splash_sprite):
		return
	var texture: Texture2D = _load_texture(TV_SPLASH_PATH)
	if texture == null:
		return
	tv_splash_sprite = Sprite2D.new()
	tv_splash_sprite.name = "TvSplashSprite"
	tv_splash_sprite.texture = texture
	tv_splash_sprite.z_index = 13
	tv_splash_sprite.visible = false
	add_child(tv_splash_sprite)


func _update_tv_boat(delta: float) -> void:
	if tv_boat_sprite == null or not is_instance_valid(tv_boat_sprite):
		return
	var elapsed: float = TV_TOTAL_TIME if tv_hold_active else TV_TOTAL_TIME - tv_reaction_timer
	# The boat appears WITH the transformation poof - during the first (startled) beat there
	# is nothing but him and the television's glare.
	if elapsed < TV_BEATS[0]:
		tv_boat_sprite.visible = false
		return
	tv_boat_pop = minf(tv_boat_pop + delta / TV_BOAT_POP_TIME, 1.0)
	var pop_ease: float = tv_boat_pop * tv_boat_pop * (3.0 - 2.0 * tv_boat_pop)
	# 整体缩小: the boat shrinks with the man, so it stays in proportion to him.
	var boat_scale: float = TV_BOAT_SCALE * TV_PERFORMANCE_SCALE
	tv_boat_sprite.visible = true
	# Mirrored (negative x scale) so the bow points at him while the boat sits to his left.
	tv_boat_sprite.scale = Vector2(-boat_scale, boat_scale) * (0.6 + 0.4 * pop_ease)
	# His feet are the anchor: the boat's deck plank line is placed on the row he stands
	# on, so he reads as standing IN the boat whatever the boat art's own margins are.
	var man_scale: float = display_height / float(TV_FRAME_SIZE.y) * TV_PERFORMANCE_SCALE
	var feet_y: float = SPRITE_BASE_POSITION.y + sprite_scale_drop + (TV_FOOT_ROW - 256.0) * man_scale
	var deck_y: float = feet_y - (TV_BOAT_DECK_ROW - 256.0) * boat_scale
	tv_boat_sprite.position = Vector2(
		SPRITE_BASE_POSITION.x + TV_BOAT_CENTER_X * TV_PERFORMANCE_SCALE,
		deck_y + _get_tv_offset().y * 0.6 + sin(elapsed * TV_BOAT_BOB_SPEED) * TV_BOAT_BOB * TV_PERFORMANCE_SCALE)
	tv_boat_sprite.rotation = sin(elapsed * TV_BOAT_BOB_SPEED * 0.7) * TV_BOAT_TILT


func _play_current_animation() -> void:
	if pager_reaction_active or pager_hold_active:
		return
	if cassette_reaction_active or cassette_hold_active:
		return
	if tv_reaction_active or tv_hold_active:
		return
	if idle_action_id != "":
		var idle_entry: Dictionary = IDLE_ACTIONS[idle_action_id]
		_set_sprite_scale_for(IDLE_ACTION_FRAME_SIZE, float(idle_entry.get("scale", 1.0)))
		animated_sprite.animation = str(idle_entry["animation"])
	elif resting:
		_set_sprite_scale_for(REST_FRAME_SIZE)
		animated_sprite.animation = REST_ANIMATION_NAME
	elif juggling:
		_set_sprite_scale_for(JUGGLE_FRAME_SIZE)
		animated_sprite.animation = JUGGLE_ANIMATION_NAME
	else:
		_set_sprite_scale_for(frame_size)
		animated_sprite.animation = IDLE_ANIMATION_NAME
	animated_sprite.play()


func _set_sprite_scale_for(source_frame_size: Vector2i, size_multiplier: float = 1.0) -> void:
	var base_scale: float = display_height / float(source_frame_size.y)
	var scale_factor: float = base_scale * size_multiplier
	animated_sprite.scale = Vector2(scale_factor, scale_factor)
	# Scaling happens about the sprite's centre, so slide it down by half of what
	# it gained to keep the bottom edge of the frame - where his feet are - on the
	# same ground line as the idle.
	sprite_scale_drop = float(source_frame_size.y) * 0.5 * (base_scale - scale_factor)


## The circular countdown ring that used to be drawn behind the character is gone
## at the user's request - the performances no longer sit inside a timer circle.
func _draw() -> void:
	pass


func _draw_item_idle_effect() -> void:
	var bob: float = sin(item_elapsed * 4.0) * 4.0
	match active_item_id:
		"cassette":
			_draw_cassette(Vector2(94.0, -120.0 + bob))
		"pager":
			_draw_pager(Vector2(94.0, -142.0 + bob))
		"walkman":
			_draw_walkman(Vector2(0.0, -196.0 + bob * 0.4))
		"crt":
			_draw_crt(Vector2(104.0, -132.0 + bob))
		"vhs":
			_draw_vhs(Vector2(98.0, -118.0 + bob))
		_:
			pass


func _draw_cassette(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-34.0, -22.0), Vector2(68.0, 44.0))
	draw_rect(body, Color(0.15, 0.17, 0.20, 0.92), true)
	draw_rect(body, Color(0.88, 0.76, 0.52, 0.96), false, 3.0)
	draw_circle(center + Vector2(-18.0, 0.0), 10.0, Color(0.78, 0.80, 0.78, 0.95))
	draw_circle(center + Vector2(18.0, 0.0), 10.0, Color(0.78, 0.80, 0.78, 0.95))
	draw_line(center + Vector2(-18.0, -10.0).rotated(item_elapsed), center + Vector2(-18.0, 10.0).rotated(item_elapsed), Color(0.09, 0.10, 0.11), 2.0)
	draw_line(center + Vector2(18.0, -10.0).rotated(-item_elapsed), center + Vector2(18.0, 10.0).rotated(-item_elapsed), Color(0.09, 0.10, 0.11), 2.0)


func _draw_pager(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-28.0, -18.0), Vector2(56.0, 36.0))
	var blink: float = 0.45 + 0.35 * abs(sin(item_elapsed * 5.5))
	draw_rect(body, Color(0.12, 0.12, 0.14, 0.94), true)
	draw_rect(Rect2(center + Vector2(-20.0, -10.0), Vector2(28.0, 12.0)), Color(0.46, 0.78, 0.60, blink), true)
	draw_circle(center + Vector2(18.0, 8.0), 4.0, Color(0.95, 0.72, 0.25, 0.95))


func _draw_walkman(center: Vector2) -> void:
	draw_arc(center + Vector2(0.0, -18.0), 62.0, PI * 1.06, PI * 1.94, 36, Color(0.08, 0.09, 0.10, 0.86), 5.0, true)
	draw_circle(center + Vector2(-62.0, 0.0), 18.0, Color(0.18, 0.18, 0.20, 0.92))
	draw_circle(center + Vector2(62.0, 0.0), 18.0, Color(0.18, 0.18, 0.20, 0.92))


func _draw_crt(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-34.0, -28.0), Vector2(68.0, 52.0))
	var scan_y: float = fposmod(item_elapsed * 34.0, 34.0) - 17.0
	draw_rect(body, Color(0.22, 0.20, 0.18, 0.95), true)
	draw_rect(Rect2(center + Vector2(-25.0, -19.0), Vector2(42.0, 31.0)), Color(0.42, 0.74, 0.78, 0.88), true)
	draw_line(center + Vector2(-23.0, scan_y), center + Vector2(15.0, scan_y), Color(0.96, 1.0, 0.82, 0.72), 2.0)
	draw_circle(center + Vector2(25.0, 13.0), 4.0, Color(0.95, 0.72, 0.25, 0.95))


func _draw_vhs(center: Vector2) -> void:
	var body: Rect2 = Rect2(center + Vector2(-38.0, -18.0), Vector2(76.0, 36.0))
	draw_rect(body, Color(0.08, 0.08, 0.10, 0.94), true)
	draw_rect(Rect2(center + Vector2(-22.0, -9.0), Vector2(44.0, 18.0)), Color(0.78, 0.78, 0.74, 0.95), true)
	draw_circle(center + Vector2(-24.0, 0.0), 7.0, Color(0.18, 0.18, 0.19, 0.95))
	draw_circle(center + Vector2(24.0, 0.0), 7.0, Color(0.18, 0.18, 0.19, 0.95))


## 阴影去掉: standing on the boat's deck his own ground shadow read as a translucent olive
## patch smeared across the planks (the user circled exactly that in a screenshot). The
## 电视机 performance therefore owns the shadow's visibility, and it restores itself the
## moment the performance ends. Driven from _process, but callable on its own so the suite -
## which parks _process - can assert it.
func _update_shadow_visibility() -> void:
	if shadow_polygon == null or not is_instance_valid(shadow_polygon):
		return
	shadow_polygon.visible = not (tv_reaction_active or tv_hold_active)


func _create_shadow() -> void:
	# Subtle paper-drop shadow or none matching the flat paper craft style
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.28, 0.30, 0.18, 0.18)
	shadow_polygon = shadow
	shadow.polygon = PackedVector2Array([
		Vector2(-60.0, -8.0),
		Vector2(60.0, -8.0),
		Vector2(75.0, 4.0),
		Vector2(60.0, 16.0),
		Vector2(-60.0, 16.0),
		Vector2(-75.0, 4.0),
	])
	add_child(shadow)


func _create_animation() -> void:
	var texture: Texture2D = _load_texture(sprite_sheet_path)
	if texture == null:
		push_warning("Fridge player sprite sheet not found: %s" % sprite_sheet_path)
		return

	var frames := SpriteFrames.new()
	_add_sheet_animation(frames, IDLE_ANIMATION_NAME, texture, frame_count, frame_size, animation_fps, true)
	_add_juggle_animation(frames)
	_add_rest_animation(frames)
	_add_hit_animation(frames)
	_add_pager_animation(frames)
	_add_cassette_animation(frames)
	_add_tv_animation(frames)
	_add_idle_action_animations(frames)
	_add_doze_animations(frames)

	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "Sprite"
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = IDLE_ANIMATION_NAME
	animated_sprite.position = SPRITE_BASE_POSITION
	_set_sprite_scale_for(frame_size)
	animated_sprite.play()
	add_child(animated_sprite)


## Juggle: the four-frame arm atlas (windmill toss), looped. The flying objects
## are separate code-animated, swappable sprites (see _create_juggle_objects),
## so the character body itself never deforms.
func _add_juggle_animation(frames: SpriteFrames) -> void:
	var juggle_texture: Texture2D = _load_texture(JUGGLE_ATLAS_PATH)
	if juggle_texture == null:
		push_warning("Pomodoro juggle atlas not found: %s" % JUGGLE_ATLAS_PATH)
		return
	_add_atlas_animation(frames, JUGGLE_ANIMATION_NAME, juggle_texture, JUGGLE_ATLAS_FRAME_INDICES, JUGGLE_FRAME_SIZE, JUGGLE_ANIMATION_FPS, true)
	_create_juggle_objects()


## Builds an animation from selected frames of a horizontal atlas, using the
## given frame indices (so a strip can be ping-ponged, e.g. [0, 1, 2, 1]).
func _add_atlas_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, frame_indices: Array, source_frame_size: Vector2i, fps: float, loops: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for frame_index: int in frame_indices:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(
			frame_index * source_frame_size.x,
			0,
			source_frame_size.x,
			source_frame_size.y
		)
		frames.add_frame(animation_name, atlas_texture)


## Rest: the Gemini-generated exhausted-panting atlas (three 512px frames in
## one row). Frames are ping-ponged 1-2-3-2 so the breathing cycle eases back
## down instead of snapping to the first frame.
func _add_rest_animation(frames: SpriteFrames) -> void:
	var rest_texture: Texture2D = _load_texture(REST_ATLAS_PATH)
	if rest_texture == null:
		push_warning("Pomodoro rest atlas not found: %s" % REST_ATLAS_PATH)
		return
	frames.add_animation(REST_ANIMATION_NAME)
	frames.set_animation_speed(REST_ANIMATION_NAME, REST_ANIMATION_FPS)
	frames.set_animation_loop(REST_ANIMATION_NAME, true)
	for frame_index in [0, 1, 2, 1]:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = rest_texture
		atlas_texture.region = Rect2(
			int(frame_index) * REST_FRAME_SIZE.x,
			0,
			REST_FRAME_SIZE.x,
			REST_FRAME_SIZE.y
		)
		frames.add_frame(REST_ANIMATION_NAME, atlas_texture)


## Hit: the single Gemini-generated frame where the fridge man is bonked on the
## face (dizzy eyes, wincing mouth, limp arms) — held during the impact of the
## ball-to-the-face ending.
func _add_hit_animation(frames: SpriteFrames) -> void:
	var hit_texture: Texture2D = _load_texture(BALL_DROP_ATLAS_PATH)
	if hit_texture == null:
		push_warning("Pomodoro hit frame not found: %s" % BALL_DROP_ATLAS_PATH)
		return
	frames.add_animation(BALL_DROP_ANIMATION_NAME)
	frames.set_animation_speed(BALL_DROP_ANIMATION_NAME, 1.0)
	frames.set_animation_loop(BALL_DROP_ANIMATION_NAME, true)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = hit_texture
	atlas_texture.region = Rect2(0, 0, BALL_DROP_FRAME_SIZE.x, BALL_DROP_FRAME_SIZE.y)
	frames.add_frame(BALL_DROP_ANIMATION_NAME, atlas_texture)


## Pager reaction: the four-keyframe atlas from the reference chart, played once
## (no loop) with the chart's own beat lengths, so the poses line up with the buzz
## and the float motion.
func _add_pager_animation(frames: SpriteFrames) -> void:
	var pager_texture: Texture2D = _load_texture(PAGER_ATLAS_PATH)
	if pager_texture == null:
		push_warning("Pager reaction atlas not found: %s" % PAGER_ATLAS_PATH)
		return
	frames.add_animation(PAGER_ANIMATION_NAME)
	frames.set_animation_speed(PAGER_ANIMATION_NAME, 1.0)
	frames.set_animation_loop(PAGER_ANIMATION_NAME, false)
	for frame_index in range(PAGER_BEATS.size()):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = pager_texture
		atlas_texture.region = Rect2(
			frame_index * PAGER_FRAME_SIZE.x,
			0,
			PAGER_FRAME_SIZE.x,
			PAGER_FRAME_SIZE.y
		)
		frames.add_frame(PAGER_ANIMATION_NAME, atlas_texture, float(PAGER_BEATS[frame_index]))


## 磁带机 (cassette): the five-beat boombox dance, played once with its own beat lengths
## (the same construction as the pager's) and then held on the dance by the code.
func _add_cassette_animation(frames: SpriteFrames) -> void:
	var dance_texture: Texture2D = _load_texture(CASSETTE_ATLAS_PATH)
	if dance_texture == null:
		push_warning("Boombox dance atlas not found: %s" % CASSETTE_ATLAS_PATH)
		return
	frames.add_animation(CASSETTE_ANIMATION_NAME)
	frames.set_animation_speed(CASSETTE_ANIMATION_NAME, 1.0)
	frames.set_animation_loop(CASSETTE_ANIMATION_NAME, false)
	for frame_index in range(CASSETTE_BEATS.size()):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = dance_texture
		atlas_texture.region = Rect2(
			frame_index * CASSETTE_FRAME_SIZE.x,
			0,
			CASSETTE_FRAME_SIZE.x,
			CASSETTE_FRAME_SIZE.y
		)
		frames.add_frame(CASSETTE_ANIMATION_NAME, atlas_texture, float(CASSETTE_BEATS[frame_index]))


## 电视机 (CRT): the five-frame fisherman transformation, played once with its own beat
## lengths and then held on the fishing stroke by the code.
func _add_tv_animation(frames: SpriteFrames) -> void:
	var fisher_texture: Texture2D = _load_texture(TV_ATLAS_PATH)
	if fisher_texture == null:
		push_warning("Fisherman atlas not found: %s" % TV_ATLAS_PATH)
		return
	frames.add_animation(TV_ANIMATION_NAME)
	frames.set_animation_speed(TV_ANIMATION_NAME, 1.0)
	frames.set_animation_loop(TV_ANIMATION_NAME, false)
	for frame_index in range(TV_BEATS.size()):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = fisher_texture
		atlas_texture.region = Rect2(
			frame_index * TV_FRAME_SIZE.x,
			0,
			TV_FRAME_SIZE.x,
			TV_FRAME_SIZE.y
		)
		frames.add_frame(TV_ANIMATION_NAME, atlas_texture, float(TV_BEATS[frame_index]))


## Creates the swappable flying objects using the currently selected
## projectile texture (see set_juggle_projectile).
## Idle bits of business: three-frame atlases registered as looping animations.
## The breathing and stroking loops ping-pong (1-2-3-2) so they ease back instead
## of snapping; the smoke rings play straight through.
func _add_idle_action_animations(frames: SpriteFrames) -> void:
	for action_id: String in IDLE_ACTIONS:
		var entry: Dictionary = IDLE_ACTIONS[action_id]
		# An entry without an atlas plays an animation that already exists (the
		# plain idle), so there is nothing to build for it.
		if str(entry.get("atlas", "")).is_empty():
			continue
		var texture: Texture2D = _load_texture(str(entry["atlas"]))
		if texture == null:
			push_warning("Idle action atlas not found: %s" % str(entry["atlas"]))
			continue
		# An entry may hold more than the usual three poses; "frames" names how many
		# columns of the atlas to play (default 3), so a longer, slower cycle needs no
		# code change - just its own atlas and a smaller fps.
		var atlas_frames: int = int(entry.get("frames", 3))
		var indices: Array = []
		for i in range(atlas_frames):
			indices.append(i)
		if bool(entry.get("ping_pong", false)):
			for i in range(atlas_frames - 2, 0, -1):
				indices.append(i)
		_add_atlas_animation(frames, str(entry["animation"]), texture, indices, IDLE_ACTION_FRAME_SIZE, float(entry["fps"]), true)


## 打瞌睡: the two extra poses of the default idle - dozing off on his feet and
## jolting awake - as single 512px frames from their own files, so they use the
## idle's own frame geometry, scale and ground line.
func _add_doze_animations(frames: SpriteFrames) -> void:
	for entry: Array in [[DOZE_ANIMATION_NAME, DOZE_FRAME_PATH], [STARTLE_ANIMATION_NAME, STARTLE_FRAME_PATH]]:
		var animation_name := str(entry[0])
		var texture: Texture2D = _load_texture(str(entry[1]))
		if texture == null:
			push_warning("Doze frame not found: %s" % str(entry[1]))
			continue
		_add_atlas_animation(frames, animation_name, texture, [0], IDLE_ACTION_FRAME_SIZE, 1.0, true)


## Builds the shared doze cycle (see FridgeDozeCycle). It owns the timing and the
## sleep bubble / pop effect; this script owns the poses.
func _create_doze_cycle() -> void:
	doze = FridgeDozeCycle.new()
	doze.name = "DozeCycle"
	doze.configure(DOZE_BUBBLE_OFFSET, DOZE_BUBBLE_SCALE, DOZE_BODY_SINK)
	add_child(doze)


## True only while 打瞌睡 owns him. The doze is an idle action now, not the default
## stance, so the plain relaxed idle never nods off on its own - he has to be asked
## (the skeleton stand's gallery). Everything else - a work/break session, another
## idle action, the pager reaction or the ball-to-the-face ending - pauses the
## doze, so two animations never fight over the sprite.
func _is_doze_action() -> bool:
	return idle_action_id == DOZE_ACTION_ID and not (juggling or resting or ball_drop_active or pager_reaction_active or pager_hold_active)


## 打瞌睡: drives the default standing idle. He stands there for a while, nods off
## with sleep bubbles rising above his head, the bubble swells and pops and he
## snaps awake with a start before settling back down and starting over.
func _update_doze(delta: float) -> void:
	if doze == null or not is_instance_valid(doze):
		return
	doze.set_enabled(_is_doze_action())
	var doze_phase: String = doze.tick(delta)
	if not doze.is_enabled():
		doze_body_offset = Vector2.ZERO
		return
	var desired := IDLE_ANIMATION_NAME
	if doze_phase == FridgeDozeCycle.PHASE_NOD or doze_phase == FridgeDozeCycle.PHASE_DOZE:
		desired = DOZE_ANIMATION_NAME
	elif doze_phase == FridgeDozeCycle.PHASE_POP or doze_phase == FridgeDozeCycle.PHASE_STARTLE:
		desired = STARTLE_ANIMATION_NAME
	var frames: SpriteFrames = null
	if animated_sprite != null and is_instance_valid(animated_sprite):
		frames = animated_sprite.sprite_frames
	if frames != null and frames.has_animation(desired) and animated_sprite.animation != desired:
		animated_sprite.animation = desired
		animated_sprite.play()
	doze_body_offset = doze.get_body_offset()


func _create_juggle_objects() -> void:
	var object_texture: Texture2D = _load_projectile_texture(juggle_projectile_id)
	if object_texture == null:
		push_warning("Juggle projectile texture not found for id: %s" % juggle_projectile_id)
		return
	for i in JUGGLE_FLIGHTS.size():
		var object_sprite := Sprite2D.new()
		object_sprite.name = "JuggleObject%d" % i
		object_sprite.texture = object_texture
		object_sprite.scale = Vector2(JUGGLE_OBJECT_SCALE, JUGGLE_OBJECT_SCALE)
		object_sprite.visible = false
		object_sprite.z_index = 2
		add_child(object_sprite)
		juggle_objects.append(object_sprite)


func _load_projectile_texture(id: String) -> Texture2D:
	for entry: Dictionary in JUGGLE_PROJECTILES:
		if str(entry.get("id", "")) == id:
			return _load_texture(str(entry.get("path", "")))
	return null


## Robust texture loader. The PNG on disk wins over the editor's import cache:
## when art is rewritten in place the cache still serves the OLD texture, while
## the raw file is always current. The imported resource is the fallback (and the
## only path that works inside an export).
func _load_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null

	var file_path := texture_path
	if texture_path.begins_with("res://") or texture_path.begins_with("user://"):
		file_path = ProjectSettings.globalize_path(texture_path)

	if FileAccess.file_exists(file_path):
		var image := Image.new()
		var error := image.load(file_path)
		if error == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)

	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D

	return null


func _add_sheet_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, count: int, sheet_frame_size: Vector2i, fps: float, loops: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in range(count):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(
			frame_index * sheet_frame_size.x,
			0,
			sheet_frame_size.x,
			sheet_frame_size.y
		)
		frames.add_frame(animation_name, atlas_texture)
