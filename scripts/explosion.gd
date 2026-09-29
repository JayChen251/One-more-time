class_name Explosion
extends Node2D
## A pixel-style blast: a white-hot flash, a fireball, a shockwave ring,
## flying square debris and a puff of smoke, with a generated boom.
## Use Explosion.spawn(parent, global_position, size).

const DURATION := 1.2
const DEBRIS_COLORS := [Color(1.0, 0.95, 0.5), Color(1.0, 0.6, 0.2), Color(0.95, 0.25, 0.2)]

var size := 1.0
var _t := 0.0
var _debris: Array = []          # [position, velocity, colour, side]
var _smoke: Array = []           # [offset, radius]

static var _boom_stream: AudioStreamWAV


static func spawn(parent: Node, at: Vector2, blast_size := 1.0, loudness_db := -6.0) -> Explosion:
	var e := Explosion.new()
	e.size = blast_size
	e.z_index = 20
	parent.add_child(e)
	e.global_position = at
	var sound := AudioStreamPlayer.new()
	sound.stream = _boom()
	sound.volume_db = loudness_db
	sound.pitch_scale = randf_range(0.8, 1.2) / sqrt(blast_size)
	e.add_child(sound)
	sound.play()
	return e


func _ready() -> void:
	for i in int(16 * size):
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		_debris.append([Vector2.ZERO, dir * randf_range(150.0, 480.0) * size,
				DEBRIS_COLORS[randi() % DEBRIS_COLORS.size()], (4.0 if randf() < 0.6 else 8.0) * ceilf(size)])
	for i in 6:
		_smoke.append([Vector2(randf_range(-35, 35), randf_range(-35, 35)) * size,
				randf_range(18.0, 36.0) * size])


func _process(delta: float) -> void:
	_t += delta
	for d in _debris:
		var v: Vector2 = d[1]
		v.y += 700.0 * delta
		v *= 0.985
		d[1] = v
		d[0] = d[0] + v * delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := _t / DURATION
	for s in _smoke:
		draw_circle(s[0] + Vector2(0, -50.0 * p * size), s[1] * (0.6 + p),
				Color(0.22, 0.2, 0.28, 0.55 * (1.0 - p)))
	var r := 75.0 * size * ease(minf(p * 3.0, 1.0), 0.4)
	if p < 0.35:
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.2, 1.0 - p / 0.35))
	if p < 0.18:
		draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 1.0, 0.85, 1.0 - p / 0.18))
	draw_arc(Vector2.ZERO, 30.0 * size + 170.0 * size * p, 0.0, TAU, 48,
			Color(1.0, 0.85, 0.5, 0.8 * (1.0 - p)), 4.0 * size * (1.0 - p) + 1.0)
	for d in _debris:
		var side: float = d[3]
		draw_rect(Rect2(d[0] - Vector2.ONE * side / 2.0, Vector2.ONE * side), Color(d[2], 1.0 - p))


# A low rumbling noise burst, generated once (no sound file to import).
static func _boom() -> AudioStreamWAV:
	if _boom_stream:
		return _boom_stream
	var rate := 22050
	var length := int(rate * 0.7)
	var data := PackedByteArray()
	data.resize(length * 2)
	var low := 0.0
	for i in length:
		var envelope := pow(1.0 - float(i) / length, 2.0)
		low = lerpf(low, randf_range(-1.0, 1.0), 0.08)      # muffle the noise
		data.encode_s16(i * 2, int(clampf(low * 3.0 * envelope, -1.0, 1.0) * 32767))
	_boom_stream = AudioStreamWAV.new()
	_boom_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_boom_stream.mix_rate = rate
	_boom_stream.data = data
	return _boom_stream
