class_name FridgeGlyphSpray
extends Node2D

## 喷射: the shower of paper pieces that squirts out from underneath the
## levitating BB机 while the fridge man floats up with it. Every piece is tossed
## on a random cone pointing down, falls under gravity, and vanishes the instant
## it reaches the ground line instead of bouncing.
##
## What comes out is a swappable PAYLOAD, so the 字体 spray can later become some
## other prop (跑跑, 泡泡, ...) without touching this file: set_payload() takes one
## entry of FRIDGE_SPRAY_PAYLOADS from the level - either a single "texture", or an
## "atlas" sheet plus the "regions" of the glyphs inside it.

const EMIT_INTERVAL := 0.045
const EMIT_MIN := 1
const EMIT_MAX := 3
## Hard cap so a long levitation stays cheap no matter how long it holds.
const MAX_LIVE := 160
## How long a piece takes to shrink and fade away where it landed.
const VANISH_TIME := 0.14
const SPAWN_JITTER := Vector2(18.0, 10.0)

## Where the pieces squirt from - the level sets this to the levitating device's
## world position plus its own offset, every frame.
var origin := Vector2.ZERO
var emitting := false
## The actors' baseline in world units: anything that reaches it has landed.
var ground_y := 184.0
var gravity := 640.0
var speed_min := 150.0
var speed_max := 330.0
## Half-angle of the downward cone the pieces are thrown on.
var spread := deg_to_rad(62.0)
## On-screen height every piece is normalised to, so a sheet of mixed glyph sizes
## still throws a visually even spray.
var piece_height := 46.0
var spin_speed := 3.4
## Name of the payload currently loaded (for debugging and tests).
var payload_name := ""

var _textures: Array[Texture2D] = []
## On-screen scale per texture, so one spray can mix pieces of different sizes
## (the glyphs and the smaller 五彩泡泡 share the same payload).
var _scales: PackedFloat32Array = PackedFloat32Array()
var _emit_cooldown := 0.0
var _pieces: Array[Sprite2D] = []
var _velocities: PackedVector2Array = PackedVector2Array()
var _spins: PackedFloat32Array = PackedFloat32Array()
var _vanish: PackedFloat32Array = PackedFloat32Array()
var _base_scale: PackedFloat32Array = PackedFloat32Array()


func _process(delta: float) -> void:
	step(delta)


## Swaps what this spray throws. `payload` is one entry of FRIDGE_SPRAY_PAYLOADS:
##   { "name": "喷射字体", "height": 46.0, "atlas": "res://...png",
##     "regions": [Rect2i(0, 0, 64, 64), ...],
##     "extra": [ {"atlas": "res://...png", "regions": [...], "height": 34.0} ] }
##   { "name": "喷射番茄", "height": 40.0, "texture": "res://...png" }
## "regions" cut a sheet into individual pieces; "extra" adds further sheets or
## single textures to the SAME spray (its own "height" each), which is how the font
## shower also throws 五彩泡泡. Anything an entry does not set keeps its tuning.
func set_payload(payload: Dictionary) -> void:
	clear_pieces()
	_textures.clear()
	_scales.clear()
	payload_name = str(payload.get("name", ""))
	piece_height = float(payload.get("height", piece_height))
	gravity = float(payload.get("gravity", gravity))
	speed_min = float(payload.get("speed_min", speed_min))
	speed_max = float(payload.get("speed_max", speed_max))
	spin_speed = float(payload.get("spin_speed", spin_speed))
	if payload.has("spread_deg"):
		spread = deg_to_rad(float(payload["spread_deg"]))
	_load_entry_textures(payload, piece_height)
	for extra: Dictionary in payload.get("extra", []):
		_load_entry_textures(extra, float(extra.get("height", piece_height)))


## Loads one payload entry's pieces: a single "texture", or an "atlas" sheet plus
## the "regions" of the pieces inside it (the whole sheet when there are none).
func _load_entry_textures(entry: Dictionary, fallback_height: float) -> void:
	var height: float = float(entry.get("height", fallback_height))
	var single_path := str(entry.get("texture", ""))
	if not single_path.is_empty():
		_append_texture(_load_texture(single_path), height)
		return
	var sheet_path := str(entry.get("atlas", ""))
	if sheet_path.is_empty():
		return
	var sheet := _load_texture(sheet_path)
	if sheet == null:
		return
	var regions: Array = entry.get("regions", [])
	if regions.is_empty():
		_append_texture(sheet, height)
		return
	for region: Rect2i in regions:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(region)
		_append_texture(atlas, height)


func _append_texture(texture: Texture2D, height: float) -> void:
	if texture == null:
		return
	_textures.append(texture)
	_scales.append(height / maxf(float(texture.get_height()), 1.0))


## Advances the spray one step: emits from `origin` while emitting is on, then
## moves everything and retires whatever has landed.
func step(delta: float) -> void:
	if emitting:
		_emit_cooldown -= delta
		var guard := 0
		while _emit_cooldown <= 0.0 and guard < 60:
			guard += 1
			_emit_cooldown += EMIT_INTERVAL
			if _pieces.size() >= MAX_LIVE:
				continue
			var count := randi_range(EMIT_MIN, EMIT_MAX)
			for _i in range(count):
				_spawn_piece()
	else:
		_emit_cooldown = 0.0
	var index := _pieces.size() - 1
	while index >= 0:
		var piece: Sprite2D = _pieces[index]
		if not is_instance_valid(piece):
			_drop_piece(index)
			index -= 1
			continue
		if _vanish[index] > 0.0:
			# 落地消失: it shrinks and fades away right where it hit the ground.
			_vanish[index] = maxf(_vanish[index] - delta, 0.0)
			var fade: float = _vanish[index] / VANISH_TIME
			piece.scale = Vector2.ONE * _base_scale[index] * fade
			piece.modulate.a = fade
			if _vanish[index] <= 0.0:
				piece.queue_free()
				_drop_piece(index)
			index -= 1
			continue
		_velocities[index] = _velocities[index] + Vector2(0.0, gravity * delta)
		piece.position += _velocities[index] * delta
		piece.rotation += _spins[index] * delta
		# Land ON the ground, not half sunk into it: the piece settles with its
		# bottom edge on the actors' baseline, then shrinks away from there.
		var landing_y := ground_y - float(piece.texture.get_height()) * _base_scale[index] * 0.5
		if piece.position.y >= landing_y:
			piece.position.y = landing_y
			_velocities[index] = Vector2.ZERO
			_spins[index] = 0.0
			_vanish[index] = VANISH_TIME
		index -= 1


## Pieces still in the air or still shrinking away.
func live_count() -> int:
	var count := 0
	for piece: Sprite2D in _pieces:
		if is_instance_valid(piece):
			count += 1
	return count


## World positions of the live pieces (tests and probing).
func get_piece_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for piece: Sprite2D in _pieces:
		if is_instance_valid(piece):
			positions.append(piece.global_position)
	return positions


## Lowest live piece, or -INF when the spray is empty.
func lowest_y() -> float:
	var lowest := -INF
	for piece: Sprite2D in _pieces:
		if is_instance_valid(piece):
			lowest = maxf(lowest, piece.global_position.y)
	return lowest


## How many distinct pieces the loaded payload can throw (glyphs in the sheet).
func texture_count() -> int:
	return _textures.size()


## Drops every piece at once (swapping payloads, leaving the level).
func clear_pieces() -> void:
	for piece: Sprite2D in _pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	_pieces.clear()
	_velocities.clear()
	_spins.clear()
	_vanish.clear()
	_base_scale.clear()
	_emit_cooldown = 0.0


func _drop_piece(index: int) -> void:
	_pieces.remove_at(index)
	_velocities.remove_at(index)
	_spins.remove_at(index)
	_vanish.remove_at(index)
	_base_scale.remove_at(index)


func _spawn_piece() -> void:
	if _textures.is_empty():
		return
	var texture: Texture2D = _textures[randi() % _textures.size()]
	if texture == null:
		return
	var piece := Sprite2D.new()
	piece.name = "SprayPiece"
	piece.texture = texture
	piece.z_index = z_index
	var piece_scale: float = _scales[randi() % _scales.size()] if _scales.size() == _textures.size() else piece_height / maxf(float(texture.get_height()), 1.0)
	piece.scale = Vector2.ONE * piece_scale
	piece.rotation = randf_range(-PI, PI) * 0.06
	piece.position = origin + Vector2(
		randf_range(-SPAWN_JITTER.x, SPAWN_JITTER.x),
		randf_range(-SPAWN_JITTER.y, SPAWN_JITTER.y))
	add_child(piece)
	_pieces.append(piece)
	var angle := randf_range(-spread, spread)
	var speed := randf_range(speed_min, speed_max)
	_velocities.append(Vector2(sin(angle), cos(angle)) * speed)
	_spins.append(randf_range(-spin_speed, spin_speed))
	_vanish.append(0.0)
	_base_scale.append(piece_scale)


## The project's art has to be read from the PNG on disk: overwriting a file does
## not refresh the editor's import cache, so the cache can serve stale art.
func _load_texture(texture_path: String) -> Texture2D:
	if FileAccess.file_exists(texture_path):
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(texture_path)) == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D
	return null