## Audio service (autoload "AudioService").
##
## All sound is synthesised at runtime into AudioStreamWAV buffers, so the repo
## ships zero audio files (see ASSETS_LICENSES). Short cues play on EventBus
## events (pickup, craft, level-up, warning); a soft wind bed loops underneath
## and swells with cold and storms. Master volume + mute come from balance.json.
extends Node

const SAMPLE_RATE := 22050
const LOW_NEED_FRACTION := 0.15  # play a warning when a need drops under this

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _wind: AudioStreamPlayer
var _cues: Dictionary = {}        # name -> AudioStreamWAV
var _master_volume := 1.0
var _prev_fractions: Dictionary = {}

func _ready() -> void:
	var acc: Dictionary = Balance.data.get("accessibility", {})
	_master_volume = float(acc.get("master_volume", 0.8))

	_cues["pickup"] = _tone([880.0], 0.07, 0.25)
	_cues["craft"] = _tone([523.0, 784.0], 0.18, 0.3)
	_cues["levelup"] = _tone([523.0, 659.0, 784.0], 0.28, 0.3)
	_cues["quest"] = _tone([659.0, 988.0], 0.3, 0.32)
	_cues["warning"] = _tone([196.0, 165.0], 0.4, 0.4, true)
	_cues["build"] = _tone([147.0], 0.12, 0.45)

	for _i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = linear_to_db(_master_volume)
		add_child(p)
		_sfx_players.append(p)

	_wind = AudioStreamPlayer.new()
	_wind.stream = _wind_loop()
	_wind.volume_db = -80.0
	add_child(_wind)
	if _master_volume > 0.0:
		_wind.play()

	EventBus.item_picked_up.connect(func(_i: String, _q: int) -> void: play("pickup"))
	EventBus.recipe_crafted.connect(func(_r: String, _q: String) -> void: play("craft"))
	EventBus.skill_leveled.connect(func(_s: String, _l: int) -> void: play("levelup"))
	EventBus.quest_completed.connect(func(_q: String) -> void: play("quest"))
	EventBus.structure_built.connect(func(_b: String) -> void: play("build"))
	EventBus.affliction_started.connect(func(_a: String) -> void: play("warning"))
	EventBus.vitals_changed.connect(_on_vitals_changed)

func play(cue: String) -> void:
	if _master_volume <= 0.0 or not _cues.has(cue):
		return
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = _cues[cue]
	player.play()

func _process(_delta: float) -> void:
	# Wind swells with darkness/storms; quiet on a clear day.
	if _wind != null and _master_volume > 0.0:
		var loudness := 0.12 + 0.6 * Env.darkness()
		_wind.volume_db = linear_to_db(clampf(loudness * _master_volume, 0.0001, 1.0))

## Warning cue the moment any need drops into the danger zone.
func _on_vitals_changed(state: RefCounted) -> void:
	var vitals := state as VitalsState
	var v: Dictionary = Balance.data["vitals"]
	var curr := {
		"calories": vitals.calories / float(v["calories_max"]),
		"hydration": vitals.hydration / float(v["hydration_max"]),
		"energy": vitals.energy / float(v["energy_max"]),
		"warmth": vitals.warmth / float(v["warmth_max"]),
		"condition": vitals.condition / float(v["condition_max"]),
	}
	if not _prev_fractions.is_empty():
		if not VitalAlert.newly_critical(_prev_fractions, curr, LOW_NEED_FRACTION).is_empty():
			play("warning")
	_prev_fractions = curr

## --- Synthesis ---

## A short note or arpeggio: `freqs` played in sequence over `duration` seconds,
## with a quick attack/decay envelope. `square` gives a harsher (warning) timbre.
func _tone(freqs: Array, duration: float, gain: float, square: bool = false) -> AudioStreamWAV:
	var total := int(SAMPLE_RATE * duration)
	var per := maxi(1, total / freqs.size())
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var freq := float(freqs[mini(i / per, freqs.size() - 1)])
		var t := float(i) / SAMPLE_RATE
		var phase := fmod(t * freq, 1.0)
		var wave := (1.0 if phase < 0.5 else -1.0) if square else sin(TAU * phase)
		var env := _envelope(float(i % per) / float(per))
		var sample := int(clampf(wave * env * gain, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	return _wav(data, false)

func _envelope(progress: float) -> float:
	return clampf(progress / 0.05, 0.0, 1.0) * clampf((1.0 - progress) / 0.4, 0.0, 1.0)

## A second of soft, low-passed noise for the wind bed (loops seamlessly).
func _wind_loop() -> AudioStreamWAV:
	var total := SAMPLE_RATE
	var data := PackedByteArray()
	data.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var smoothed := 0.0
	for i in total:
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.04)  # low-pass -> wind
		data.encode_s16(i * 2, int(clampf(smoothed * 0.5, -1.0, 1.0) * 32767.0))
	return _wav(data, true)

func _wav(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	return wav
