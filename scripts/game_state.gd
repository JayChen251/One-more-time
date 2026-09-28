extends Node
## Autoload (registered as "GameState"). Survives scene reloads, so it holds
## everything that carries over from one run to the next.

## Abilities in the order they are unlocked. Add new ones (e.g. "grapple") here.
const ABILITY_ORDER := ["jump", "teleport", "boost", "grapple"]

## Background music: drop a track (.ogg, .mp3 or .wav, any name) into this
## folder and it plays, looping, for the whole session. It lives here so it
## keeps playing across run restarts instead of starting over every run.
const MUSIC_DIR := "res://assets/audio/"
const MUSIC_VOLUME_DB := -14.0

var run_count := 1
var abilities := {}
var music: AudioStreamPlayer


func _ready() -> void:
	reset()
	_start_music()


func _start_music() -> void:
	var path := _find_music()
	if path == "":
		push_warning("No music found: put an .ogg/.mp3/.wav file in " + MUSIC_DIR)
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) \
				/ (2 if wav.stereo else 1)
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = MUSIC_VOLUME_DB
	add_child(music)
	music.play()
	print("Playing music: ", path)


# The first audio file in MUSIC_DIR. Exported games only list the ".import"
# / ".remap" stubs, so those suffixes are stripped before loading.
func _find_music() -> String:
	var dir := DirAccess.open(MUSIC_DIR)
	if not dir:
		return ""
	var files := dir.get_files()
	files.sort()
	for file in files:
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension().to_lower() in ["ogg", "mp3", "wav"] \
				and ResourceLoader.exists(MUSIC_DIR + name):
			return MUSIC_DIR + name
	return ""


## Fades the music to `volume_db` over `seconds` (no-op without music).
func fade_music(volume_db: float, seconds: float) -> void:
	if music:
		create_tween().tween_property(music, "volume_db", volume_db, seconds)


func reset() -> void:
	run_count = 1
	abilities.clear()
	for ability in ABILITY_ORDER:
		abilities[ability] = false


func has_ability(ability: String) -> bool:
	return abilities.get(ability, false)


func unlock(ability: String) -> void:
	abilities[ability] = true


## The next ability to unlock, or "" once everything is unlocked.
func next_ability() -> String:
	for ability in ABILITY_ORDER:
		if not has_ability(ability):
			return ability
	return ""
