extends Node
## Autoload (registered as "GameState"). Survives scene reloads, so it holds
## everything that carries over from one run to the next.

## Abilities in the order they are unlocked. Add new ones (e.g. "grapple") here.
const ABILITY_ORDER := ["jump", "teleport", "boost", "grapple"]

## Background music: drop a track at this path (e.g. an .ogg) and it plays,
## looping, for the whole session. It lives here so it keeps playing
## across run restarts instead of starting over every run.
const MUSIC_PATH := "res://assets/audio/music.ogg"
const MUSIC_VOLUME_DB := -14.0

var run_count := 1
var abilities := {}
var music: AudioStreamPlayer


func _ready() -> void:
	reset()
	_start_music()


func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream := load(MUSIC_PATH) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = MUSIC_VOLUME_DB
	add_child(music)
	music.play()


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
