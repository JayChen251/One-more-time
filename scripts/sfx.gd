class_name Sfx
## Small generated sound effects (no audio files to import): each sound is
## synthesised once, cached, and played with Sfx.play(node, "name").
## Sounds: step, land, jump, double_jump, teleport, grapple, grapple_arrive,
## unlock, hatch.

const RATE := 22050

## Default loudness per sound (dB).
const VOLUME := {
	"step": -20.0, "land": -14.0, "jump": -16.0, "double_jump": -15.0,
	"teleport": -13.0, "grapple": -16.0, "grapple_arrive": -17.0,
	"unlock": -10.0, "hatch": -12.0,
}

static var _cache := {}


## Plays `sound` once from a throwaway player attached to `parent`.
static func play(parent: Node, sound: String, pitch := 1.0, volume_offset_db := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _stream_for(sound)
	player.volume_db = VOLUME.get(sound, -12.0) + volume_offset_db
	player.pitch_scale = pitch
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _stream_for(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _synth(sound)
	return _cache[sound]


const DURATION := {
	"step": 0.05, "land": 0.14, "jump": 0.12, "double_jump": 0.16,
	"teleport": 0.16, "grapple": 0.07, "grapple_arrive": 0.12,
	"unlock": 0.5, "hatch": 0.35,
}
const UNLOCK_NOTES := [523.25, 659.25, 783.99, 1046.5]


static func _synth(sound: String) -> AudioStreamWAV:
	var seconds: float = DURATION.get(sound, 0.05)
	var length := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(length * 2)
	var state := {"lp": 0.0, "sq": 0.0, "ph": 0.0}
	for i in length:
		var t := float(i) / length                     # 0 -> 1 over the sound
		var sample := _sample(sound, t, t * seconds, randf_range(-1.0, 1.0), state)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav


# One sample of `sound`. t: 0..1 progress, sec: seconds in, n: white noise.
static func _sample(sound: String, t: float, sec: float, n: float, s: Dictionary) -> float:
	match sound:
		"step":             # soft tick
			return n * pow(1.0 - t, 6.0) * 0.8
		"land":             # low thud
			s["lp"] = lerpf(s["lp"], n, 0.15)
			return (s["lp"] * 2.0 + sin(TAU * 90.0 * sec) * 0.6) * pow(1.0 - t, 3.0)
		"jump":             # square blip sweeping up
			return _square(s, lerpf(260.0, 560.0, t)) * 0.35 * (1.0 - t)
		"double_jump":      # higher sweep with a shimmer
			var f := lerpf(420.0, 980.0, sqrt(t))
			return (_square(s, f) * 0.25 + sin(TAU * f * 2.0 * sec) * 0.15) * (1.0 - t)
		"teleport":         # zip down with a little hiss
			s["ph"] += TAU * lerpf(1400.0, 250.0, t) / RATE
			return (sin(s["ph"]) * 0.45 + n * 0.15) * (1.0 - t)
		"grapple":          # short high blip
			return _square(s, lerpf(900.0, 1500.0, t)) * 0.25 * (1.0 - t)
		"grapple_arrive":   # soft whoosh
			s["lp"] = lerpf(s["lp"], n, 0.3)
			return s["lp"] * 1.6 * sin(PI * t)
		"unlock":           # rising arpeggio chime
			var idx := mini(int(t * 4.0), 3)
			var within := t * 4.0 - idx
			return _square(s, UNLOCK_NOTES[idx]) * 0.22 * (1.0 - within * 0.6) * (1.0 - t * 0.5)
		"hatch":            # heavy metal clank
			s["lp"] = lerpf(s["lp"], n, 0.12)
			return (_square(s, 70.0) * 0.3 + s["lp"] * 1.5 + sin(TAU * 310.0 * sec) * 0.2) \
					* pow(1.0 - t, 2.0)
	return 0.0


# Square wave with its own running phase kept in `s`.
static func _square(s: Dictionary, freq: float) -> float:
	s["sq"] = fmod(s["sq"] + freq / RATE, 1.0)
	return 1.0 if s["sq"] < 0.5 else -1.0
