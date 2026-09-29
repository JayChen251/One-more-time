@tool
class_name Decor
extends Node2D
## Background dressing that makes the level look like the inside of a ship:
## pipes, lamps, portholes, consoles, fans, alarm screens, signs, support
## ribs, cables, damage and crates; the escape tube's chase lights; and on
## the outside, antennas, a dish, navigation lights and the engines.
## Nothing here collides; it's all drawn
## behind the platforms in the Industrial tileset's palette (see Pal).
## tools/build_level.py places the items. Each item is
## [kind, x, y, w, h] (+ text for signs), in world units: top-left and size.
## Static parts are drawn once; lights, screens and fans animate.

@export var items: Array = []:
	set(value):
		items = value
		if _static:
			_static.queue_redraw()

const PX := Pal.PX
const ANIMATED := ["lamp", "window", "console", "fan", "screen", "damage", "antenna", "engine",
		"chase", "navlight"]
const SPACE := Color8(4, 6, 18)
const SCREEN := Color8(4, 14, 20)
const LAMP_LIGHT := Color(1.0, 0.93, 0.75)
const CABLE := Color8(12, 10, 18)

var _static: Node2D
var _t := 0.0


func _ready() -> void:
	z_index = -12
	_static = Node2D.new()
	_static.show_behind_parent = true
	add_child(_static)
	_static.draw.connect(_draw_static)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not Engine.is_editor_hint():
		_spark_damage()


# ------------------------------------------------------------------ helpers
func _r(c: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	c.draw_rect(Rect2(x, y, w, h), color)


# Bands of colour, one pixel each, running horizontally (or vertically).
func _bands(c: CanvasItem, x: float, y: float, length: float, colors: Array, vertical := false) -> void:
	for i in colors.size():
		if vertical:
			_r(c, x + i * PX, y, PX, length, colors[i])
		else:
			_r(c, x, y + i * PX, length, PX, colors[i])


func _text(c: CanvasItem, text: String, x: float, y: float, color: Color) -> void:
	for ch in text:
		var rows: Array = PixelText.GLYPHS.get(ch, [])
		for gy in rows.size():
			var row: String = rows[gy]
			for gx in row.length():
				if row[gx] == "1":
					_r(c, x + gx * PX, y + gy * PX, PX, PX, color)
		x += 6 * PX


func _view() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if Engine.is_editor_hint() or not camera:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size).grow(64)


# A stable pseudo-random number in [0, 1) per item.
func _hash(item: Array, salt := 0) -> float:
	return fposmod(sin(float(item[1]) * 12.9898 + float(item[2]) * 78.233 + salt * 37.719) * 43758.5453, 1.0)


# ------------------------------------------------------------------ static
func _draw_static() -> void:
	var c := _static
	for item in items:
		var x: float = item[1]
		var y: float = item[2]
		var w: float = item[3]
		var h: float = item[4]
		match item[0]:
			"pipes":
				_pipes(c, x, y, w)
			"vpipes":
				_vpipes(c, x, y, w, h)
			"rib":
				_rib(c, x, y, h)
			"cable":
				_cable(c, x, y, w, h)
			"lamp":
				Pal.plate(c, Rect2(x, y, w, 3 * PX))
				_r(c, x + PX, y + 3 * PX, w - 2 * PX, PX, Pal.OUTLINE)
			"window":
				_window(c, x, y, w)
			"console":
				_console(c, x, y, w, h)
			"fan":
				_fan_frame(c, x, y, w)
			"screen":
				Pal.plate(c, Rect2(x, y, w, h), Pal.MID)
				_r(c, x + 2 * PX, y + 2 * PX, w - 4 * PX, h - 4 * PX, SCREEN)
			"sign":
				_sign(c, x, y, w, h, item[5] if item.size() > 5 else "")
			"damage":
				_damage(c, x, y, w, h)
			"crates":
				_crates(c, x, y, w, h, item)
			"antenna":
				_antenna(c, x, y, h)
			"dish":
				_dish(c, x, y, w, h)
			"engine":
				_engine(c, x, y, w, h)
			"chase":
				var sx := x + 3 * PX if w > 0 else x - 10 * PX
				_r(c, sx, y, 7 * PX, h, Pal.OUTLINE)
				_r(c, sx + PX, y, 5 * PX, h, Pal.DARK)
			"tubering":
				# A structural hoop across the tube's back wall.
				# Kept dark with no bright rim so it can't pass for a ledge.
				_r(c, x, y, w, h, Pal.OUTLINE)
				_r(c, x, y + PX, w, h - 2 * PX, Pal.DARK)
				var bx := x + 8 * PX
				while bx < x + w - 4 * PX:
					_r(c, bx, y + h / 2.0 - PX, PX, PX, Pal.STEEL)
					bx += 16 * PX
			"vent":
				Pal.plate(c, Rect2(x, y, w, h))
				var sy := y + 2 * PX
				while sy < y + h - 2 * PX:
					_r(c, x + 2 * PX, sy, w - 4 * PX, PX, Pal.OUTLINE)
					sy += 2 * PX


func _pipes(c: CanvasItem, x: float, y: float, w: float) -> void:
	# Straps from the ceiling.
	var bx := x + 24.0
	while bx < x + w - 8.0:
		_r(c, bx, y, 2 * PX, 13 * PX, Pal.DARK)
		bx += 64.0
	_bands(c, x, y + 2 * PX, w, [Pal.OUTLINE, Pal.STEEL, Pal.MID, Pal.MID, Pal.BODY, Pal.OUTLINE])
	_bands(c, x, y + 9 * PX, w, [Pal.OUTLINE, Pal.TEAL, Pal.TEAL_DARK, Pal.OUTLINE])
	# Flanges, and a red valve on every third one.
	var fx := x + 56.0
	var n := 0
	while fx < x + w - 16.0:
		_r(c, fx, y + PX, 2 * PX, 8 * PX, Pal.OUTLINE)
		_r(c, fx, y + 2 * PX, PX, 6 * PX, Pal.STEEL)
		if n % 3 == 1:
			_r(c, fx - 2 * PX, y + 13 * PX, 6 * PX, PX, Pal.RED)
			_r(c, fx - 2 * PX, y + 14 * PX, 6 * PX, PX, Pal.RED_DARK)
			_r(c, fx, y + 12 * PX, PX, PX, Pal.STEEL)
		fx += 96.0
		n += 1


func _vpipes(c: CanvasItem, x: float, y: float, dir: float, h: float) -> void:
	# `x` is the wall's face; the pipes run down it on the open side.
	var x0 := x + 2 * PX if dir > 0 else x - 13 * PX
	var by := y + 24.0
	while by < y + h - 8.0:
		_r(c, x if dir > 0 else x - 13 * PX, by, 13 * PX, 2 * PX, Pal.DARK)
		by += 64.0
	_bands(c, x0, y, h, [Pal.OUTLINE, Pal.STEEL, Pal.MID, Pal.MID, Pal.BODY, Pal.OUTLINE], true)
	_bands(c, x0 + 7 * PX, y, h, [Pal.OUTLINE, Pal.AMBER, Pal.RED_DARK, Pal.OUTLINE], true)
	var fy := y + 48.0
	while fy < y + h - 16.0:
		_r(c, x0 - PX, fy, 8 * PX, 2 * PX, Pal.OUTLINE)
		_r(c, x0, fy, 6 * PX, PX, Pal.STEEL)
		fy += 112.0


func _rib(c: CanvasItem, x: float, y: float, h: float) -> void:
	_bands(c, x, y, h, [Pal.OUTLINE, Pal.MID, Pal.BODY, Pal.BODY, Pal.BODY, Pal.BODY, Pal.DARK, Pal.OUTLINE], true)
	var ry := y + 16.0
	while ry < y + h - 8.0:
		_r(c, x + 2 * PX, ry, PX, PX, Pal.STEEL)
		_r(c, x + 5 * PX, ry, PX, PX, Pal.STEEL)
		ry += 32.0
	var py := y + 96.0
	while py < y + h - 32.0:
		Pal.plate(c, Rect2(x - 2 * PX, py, 12 * PX, 5 * PX), Pal.MID)
		py += 192.0


func _cable(c: CanvasItem, x: float, y: float, w: float, sag: float) -> void:
	var i := 0.0
	while i < w:
		var u := i / w * 2.0 - 1.0
		var cy := snappedf(y + sag * (1.0 - u * u), PX)
		_r(c, x + i, cy, PX, 2 * PX, CABLE)
		i += PX


func _window(c: CanvasItem, x: float, y: float, w: float) -> void:
	var r := w / 2.0
	var ctr := Vector2(x + r, y + r)
	Pal.circle(c, ctr, r, Pal.OUTLINE)
	Pal.circle(c, ctr, r - PX, Pal.MID)
	Pal.ring(c, ctr + Vector2(-PX, -PX), r - 2 * PX, Pal.STEEL)
	Pal.circle(c, ctr, r - 5 * PX, Pal.OUTLINE)
	Pal.circle(c, ctr, r - 6 * PX, SPACE)
	for i in 8:
		var a := TAU * i / 8.0 + 0.4
		var p := ctr + Vector2(cos(a), sin(a)) * (r - 3 * PX)
		_r(c, snappedf(p.x, PX) - PX, snappedf(p.y, PX) - PX, PX, PX, Pal.RIM)
	# Glass glint.
	for i in 3:
		_r(c, ctr.x - 6 * PX + i * PX, ctr.y - 3 * PX - i * PX, PX, PX, Color(Pal.TEAL_GLOW, 0.5))


func _console(c: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	Pal.plate(c, Rect2(x, y + h * 0.45, w, h * 0.55))
	_r(c, x + 3 * PX, y + h * 0.45 + 3 * PX, w - 6 * PX, PX, Pal.DARK)
	Pal.plate(c, Rect2(x + 4 * PX, y, w - 8 * PX, h * 0.45 + PX), Pal.MID)
	_r(c, x + 6 * PX, y + 2 * PX, w - 12 * PX, h * 0.45 - 4 * PX, SCREEN)


func _fan_frame(c: CanvasItem, x: float, y: float, w: float) -> void:
	Pal.plate(c, Rect2(x, y, w, w))
	for corner in [Vector2(2, 2), Vector2(w / PX - 3, 2), Vector2(2, w / PX - 3), Vector2(w / PX - 3, w / PX - 3)]:
		_r(c, x + corner.x * PX, y + corner.y * PX, PX, PX, Pal.STEEL)
	Pal.circle(c, Vector2(x, y) + Vector2(w, w) / 2.0, w / 2.0 - 4 * PX, Pal.OUTLINE)


func _sign(c: CanvasItem, x: float, y: float, w: float, h: float, text: String) -> void:
	Pal.plate(c, Rect2(x, y, w, h), Pal.DARK)
	Pal.hazard(c, Rect2(x + 2 * PX, y + 2 * PX, 4 * PX, h - 4 * PX))
	Pal.hazard(c, Rect2(x + w - 6 * PX, y + 2 * PX, 4 * PX, h - 4 * PX))
	_text(c, text, x + 9 * PX, y + (h - 7 * PX) / 2.0, Pal.HAZARD)


func _damage(c: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	# A wall panel with a hole torn in it and wires spilling out.
	Pal.plate(c, Rect2(x, y, w, h), Pal.MID)
	for corner in [Vector2(2, 2), Vector2(w / PX - 3, 2), Vector2(2, h / PX - 3), Vector2(w / PX - 3, h / PX - 3)]:
		_r(c, x + corner.x * PX, y + corner.y * PX, PX, PX, Pal.STEEL)
	var cx := x + w / 2.0
	var cy := y + h / 2.0
	var top := y + 5 * PX
	var rows := int((h - 10 * PX) / PX)
	for i in rows:
		var half := snappedf((w / 2.0 - 6 * PX) * sin(PI * (i + 0.5) / rows) * (0.7 + 0.3 * absf(sin(i * 1.7))), PX)
		_r(c, cx - half - PX, top + i * PX, 2 * half + 2 * PX, PX, Pal.RIM)
		_r(c, cx - half, top + i * PX, 2 * half, PX, Pal.OUTLINE)
	var colors := [Pal.RED, Pal.HAZARD, Pal.TEAL_LIGHT]
	for k in 3:
		var wx := cx + (k - 1) * 3 * PX
		for i in 10 + k * 3:
			_r(c, snappedf(wx + sin(i * 0.6 + k) * 2.0 * PX, PX), cy - 4 * PX + i * PX, PX, PX, colors[k])


func _crates(c: CanvasItem, x: float, y: float, w: float, h: float, item: Array) -> void:
	# A stack of 32px crates filling w x h from the floor up.
	var size := 32.0
	var cols := int(w / size)
	var tall := int(h / size)
	for col in cols:
		var stack := 1 + int(_hash(item, col) * tall)
		for s in stack:
			var cx := x + col * size + (4.0 if s % 2 else 0.0)
			var cy := y + h - (s + 1) * size
			Pal.plate(c, Rect2(cx, cy, size, size), Pal.MID if (col + s) % 2 else Pal.BODY)
			for i in int(size / PX) - 4:
				_r(c, cx + (2 + i) * PX, cy + (2 + i) * PX, PX, PX, Pal.DARK)
			_r(c, cx + 2 * PX, cy + size / 2.0 - PX, size - 4 * PX, 2 * PX, Pal.AMBER if col % 2 else Pal.TEAL)


# A mast standing on the hull; `y` is its foot, `h` its height.
func _antenna(c: CanvasItem, x: float, y: float, h: float) -> void:
	Pal.plate(c, Rect2(x - 4 * PX, y - 3 * PX, 9 * PX, 3 * PX))
	_r(c, x, y - h, PX, h, Pal.STEEL)
	_r(c, x + PX, y - h, PX, h, Pal.DARK)
	var bar := y - 24.0
	var n := 0
	while bar > y - h + 16.0:
		var half := (4 - n % 3) * PX
		_r(c, x - half, bar, 2 * half + 2 * PX, PX, Pal.MID)
		bar -= 24.0
		n += 1


# A radar dish on a stand, bowl facing up.
func _dish(c: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	var cx := snappedf(x + w / 2.0, PX)
	_r(c, cx - PX, y + h * 0.4, 2 * PX, h * 0.6, Pal.MID)
	Pal.plate(c, Rect2(cx - 6 * PX, y + h - 3 * PX, 12 * PX, 3 * PX))
	var rows := int(h * 0.45 / PX)
	for j in rows:
		var half := snappedf(w / 2.0 * sqrt(1.0 - pow(float(j) / rows, 2.0)), PX)
		var color: Color = Pal.RIM if j == 0 else (Pal.STEEL if j < rows / 2 else Pal.MID)
		_r(c, cx - half, y + j * PX, 2 * half, PX, color)
		_r(c, cx - half - PX, y + j * PX, PX, PX, Pal.OUTLINE)
		_r(c, cx + half, y + j * PX, PX, PX, Pal.OUTLINE)
	# Feed arm and receiver above the bowl.
	_r(c, cx, y - 10 * PX, PX, 10 * PX, Pal.STEEL)
	_r(c, cx - PX, y - 12 * PX, 3 * PX, 2 * PX, Pal.RIM)


# An engine bell sticking out of the ship's back; `x` is the hull's face.
func _engine(c: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	Pal.plate(c, Rect2(x, y + h * 0.2, 16 * PX, h * 0.6), Pal.MID)
	var start := x + 16 * PX
	var length := w - 16 * PX
	var i := 0.0
	while i < length:
		var u := i / length
		var half := snappedf(h * (0.22 + 0.28 * u * u), PX)
		var cy := snappedf(y + h / 2.0, PX)
		_r(c, start + i, cy - half - PX, PX, 2 * half + 2 * PX, Pal.OUTLINE)
		_r(c, start + i, cy - half, PX, 2 * half, Pal.STEEL if u < 0.85 else Pal.RIM)
		_r(c, start + i, cy - half + 2 * PX, PX, 2 * half - 4 * PX, Pal.MID)
		_r(c, start + i, cy - half * 0.4, PX, half * 0.8, Pal.DARK)
		i += PX


# ------------------------------------------------------------------ animated
func _draw() -> void:
	var view := _view()
	for item in items:
		if not (item[0] in ANIMATED):
			continue
		var x: float = item[1]
		var y: float = item[2]
		var w: float = item[3]
		var h: float = item[4]
		if not view.intersects(Rect2(x - 64, y - 16, w + 128, h + 200)):
			continue
		match item[0]:
			"lamp":
				_lamp_light(x, y, w, item)
			"window":
				_stars(x, y, w, item)
			"console":
				_console_screen(x, y, w, h, item)
			"fan":
				_fan_blades(x, y, w)
			"screen":
				_alarm_screen(x, y, w, h)
			"antenna":
				if fposmod(_t + _hash(item), 1.2) < 0.25:
					Pal.circle(self, Vector2(x + PX, y - h), 2 * PX, Pal.RED)
					Pal.circle(self, Vector2(x + PX, y - h), 5 * PX, Color(Pal.RED, 0.2))
			"navlight":
				var color: Color = Pal.GREEN if int(x) % 3 == 0 else Pal.RED
				if fposmod(_t * 0.9 + _hash(item), 1.0) < 0.3:
					_r(self, x - PX, y - PX, 3 * PX, 3 * PX, color)
					Pal.circle(self, Vector2(x, y), 6 * PX, Color(color, 0.2))
			"engine":
				_flame(x + w, y + h / 2.0, h, item)
			"chase":
				_chase(x, y, w, h)
			"damage":
				var on := fposmod(_t * 7.0 + _hash(item) * 10.0, 3.0) < 0.4
				if on:
					Pal.circle(self, Vector2(x + w / 2.0, y + h / 2.0 + 8 * PX), 3 * PX, Color(Pal.HAZARD, 0.5))


func _lamp_light(x: float, y: float, w: float, item: Array) -> void:
	# Mostly steady, with the odd flicker as the ship falls apart.
	var flick := sin(_t * 23.0 + _hash(item) * 40.0) + sin(_t * 7.3 + _hash(item, 1) * 9.0)
	var on := flick > -1.6
	_r(self, x + PX, y + 3 * PX, w - 2 * PX, PX, LAMP_LIGHT if on else Pal.MID)
	if not on:
		return
	var reach := 18
	for i in reach:
		var spread := snappedf(w / 2.0 + i * 2.0 * PX, PX)
		var a := 0.1 * (1.0 - float(i) / reach)
		_r(self, x + w / 2.0 - spread, y + (4 + i * 2) * PX, 2 * spread, 2 * PX, Color(LAMP_LIGHT, a))


func _stars(x: float, y: float, w: float, item: Array) -> void:
	var r := w / 2.0 - 7 * PX
	var ctr := Vector2(x + w / 2.0, y + w / 2.0)
	for i in 6:
		var a := _hash(item, i) * TAU
		var d := sqrt(_hash(item, i + 10)) * r
		var p := ctr + Vector2(cos(a), sin(a)) * d
		var b := 0.5 + 0.5 * sin(_t * (1.5 + i) + i)
		_r(self, snappedf(p.x, PX), snappedf(p.y, PX), PX, PX, Color(1, 1, 1, b))
	# A small planet drifting past.
	var drift := fposmod(_t * 3.0 + _hash(item, 20) * 100.0, 2.0 * r + 12 * PX) - r - 6 * PX
	var planet := ctr + Vector2(drift, r * 0.35)
	if planet.distance_to(ctr) < r - 3 * PX:
		Pal.circle(self, planet, 3 * PX, Pal.TEAL)
		_r(self, snappedf(planet.x, PX) - PX, snappedf(planet.y, PX) - 2 * PX, PX, PX, Pal.TEAL_GLOW)


func _console_screen(x: float, y: float, w: float, h: float, item: Array) -> void:
	var sx := x + 7 * PX
	var sy := y + 3 * PX
	var sw := w - 14 * PX
	var lines := int((h * 0.45 - 6 * PX) / (2 * PX))
	var scroll := int(_t * 6.0 + _hash(item) * 50.0)
	for i in lines:
		var n := scroll + i
		var length := snappedf(sw * (0.3 + 0.7 * fposmod(sin(n * 12.9898) * 43758.5453, 1.0)), PX)
		_r(self, sx, sy + i * 2 * PX, length, PX, Pal.GREEN if n % 5 else Pal.HAZARD)
	# Blinking buttons on the desk.
	var colors := [Pal.RED, Pal.GREEN, Pal.AMBER, Pal.TEAL_GLOW]
	for i in 4:
		if fposmod(_t * (1.0 + i * 0.7) + _hash(item, i), 1.0) < 0.6:
			_r(self, x + (4 + i * 4) * PX, y + h * 0.45 + 5 * PX, 2 * PX, PX, colors[i])


func _fan_blades(x: float, y: float, w: float) -> void:
	var ctr := Vector2(x + w / 2.0, y + w / 2.0)
	var r := w / 2.0 - 5 * PX
	var turn := _t * 5.0
	for k in 4:
		var a := turn + k * PI / 2.0
		for i in int(r / PX):
			for side in [0.0, 0.35]:
				var p := ctr + Vector2(cos(a + side), sin(a + side)) * i * PX
				_r(self, snappedf(p.x, PX), snappedf(p.y, PX), PX, PX, Pal.MID)
	_r(self, snappedf(ctr.x, PX) - PX, snappedf(ctr.y, PX) - PX, 2 * PX, 2 * PX, Pal.STEEL)


# The engines sputter as the ship fails: a flame that flares and dies.
func _flame(x: float, cy: float, h: float, item: Array) -> void:
	var power := clampf(0.55 + 0.45 * sin(_t * 9.0 + _hash(item) * 20.0) * sin(_t * 2.3 + _hash(item, 1) * 7.0), 0.0, 1.0)
	var length := snappedf(40.0 + 120.0 * power, PX)
	var i := 0.0
	while i < length:
		var u := i / length
		var half := snappedf(h * 0.4 * (1.0 - u) + PX, PX)
		var jitter := snappedf(sin(_t * 40.0 + i * 0.3) * PX, PX)
		var y0 := snappedf(cy, PX) - half + jitter
		_r(self, x + i, y0, PX, 2 * half, Color(Pal.AMBER, 0.75 * (1.0 - u)))
		_r(self, x + i, y0 + half * 0.4, PX, half * 1.2, Color(Pal.HAZARD, 0.9 * (1.0 - u)))
		if u < 0.35:
			_r(self, x + i, snappedf(cy, PX) - PX + jitter, PX, 2 * PX, Color(1, 1, 0.9, 1.0 - u / 0.35))
		i += PX


# Green chevrons running up the escape tube's wall, pointing the way out.
func _chase(x: float, y: float, dir: float, h: float) -> void:
	var sx := x + 4 * PX if dir > 0 else x - 9 * PX
	var n := int(h / 32.0)
	var head := fposmod(_t * 10.0, 12.0)
	for i in n:
		var from_bottom := float(n - 1 - i)
		var d := fposmod(head - from_bottom, 12.0)
		var a := 0.35 + 0.65 * clampf(1.0 - d / 4.0, 0.0, 1.0)
		var cy := y + i * 32.0 + 12.0
		for k in 5:
			_r(self, sx + k * PX, cy + absf(k - 2) * PX, PX, 2 * PX, Color(Pal.GREEN, a))
		if a > 0.9:
			Pal.circle(self, Vector2(sx + 2.5 * PX, cy + 2 * PX), 5 * PX, Color(Pal.GREEN, 0.12))


func _alarm_screen(x: float, y: float, w: float, h: float) -> void:
	var blink := fmod(_t, 0.8) < 0.5
	if blink:
		_text(self, "ALERT", x + (w - 29 * PX) / 2.0, y + 3 * PX, Pal.RED)
	# A bar that drains and refills: the self-destruct countdown.
	var bar := w - 8 * PX
	var fill := snappedf(bar * (1.0 - fposmod(_t / 25.0, 1.0)), PX)
	_r(self, x + 4 * PX, y + h - 5 * PX, bar, PX, Pal.RED_DARK)
	_r(self, x + 4 * PX, y + h - 5 * PX, fill, PX, Pal.RED)


# Now and then a burst of real sparks from a damaged panel on screen.
func _spark_damage() -> void:
	if randf() > 0.02:
		return
	var view := _view()
	for item in items:
		if item[0] == "damage" and randf() < 0.5:
			var at := Vector2(item[1] + item[3] / 2.0, item[2] + item[4] / 2.0 + 8 * PX)
			if view.has_point(at):
				Sparks.spawn(get_parent(), global_position + at, Pal.HAZARD, 6, true, 0.4)
				return
