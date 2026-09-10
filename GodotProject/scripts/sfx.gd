extends Node

# Audio drop-in system.
#
# Put your own .wav files in:
#   res://audio/sfx/
#
# Exact filenames:
#   projectile.wav
#   graze.wav
#   countdown.wav
#   go.wav
#   hit.wav
#   level_complete.wav
#
# If any file is missing, the old generated tone is used automatically.
# This means a missing/renamed sound cannot break gameplay.

const PROJECTILE_PATH := "res://audio/sfx/projectile.wav"
const GRAZE_PATH := "res://audio/sfx/graze.wav"
const COUNTDOWN_PATH := "res://audio/sfx/countdown.wav"
const GO_PATH := "res://audio/sfx/go.wav"
const HIT_PATH := "res://audio/sfx/hit.wav"
const LEVEL_COMPLETE_PATH := "res://audio/sfx/level_complete.wav"


static func play_projectile(parent: Node) -> void:
	if not _play_file(parent, PROJECTILE_PATH, -18.0):
		play_tone(parent, 260.0, 0.035, -29.0)


static func play_graze(parent: Node, combo: int = 1) -> void:
	# A tiny pitch increase keeps consecutive grazes satisfying.
	# Set pitch_scale to 1.0 below if you want every graze identical.
	var pitch := 1.0 + minf(float(maxi(combo - 1, 0)) * 0.035, 0.20)
	if not _play_file(parent, GRAZE_PATH, -10.0, pitch):
		play_tone(parent, 760.0 + combo * 35.0, 0.07, -18.0)


# countdown.wav may contain the ENTIRE spoken cue:
# "3, 2, 1, GO!"
#
# Older versions of game.gd call play_countdown() once per visual number.
# To make a full announcer WAV safe with BOTH old and new game.gd versions,
# we debounce the custom countdown file for 4 seconds.
const COUNTDOWN_SEQUENCE_DEBOUNCE_MS := 4000
const COUNTDOWN_SEQUENCE_META := "_cursorhell_countdown_sequence_started_ms"


static func _custom_countdown_is_available() -> bool:
	if not ResourceLoader.exists(COUNTDOWN_PATH):
		return false
	return (load(COUNTDOWN_PATH) as AudioStream) != null


static func _countdown_sequence_recently_started(parent: Node) -> bool:
	if parent == null or not is_instance_valid(parent):
		return false
	if not parent.has_meta(COUNTDOWN_SEQUENCE_META):
		return false

	var last_started := int(parent.get_meta(COUNTDOWN_SEQUENCE_META))
	return Time.get_ticks_msec() - last_started < COUNTDOWN_SEQUENCE_DEBOUNCE_MS


static func play_countdown(parent: Node, number: int = 3) -> void:
	# If countdown.wav exists, treat it as ONE complete announcer sequence.
	# Calls for 2 and 1 from older game scripts are ignored.
	if _custom_countdown_is_available():
		if _countdown_sequence_recently_started(parent):
			return

		parent.set_meta(COUNTDOWN_SEQUENCE_META, Time.get_ticks_msec())
		_play_file(parent, COUNTDOWN_PATH, -10.0, 1.0)
		return

	# If no custom countdown.wav exists, preserve the original generated
	# per-number countdown tones.
	var pitch := 1.0 + float(3 - clampi(number, 1, 3)) * 0.05
	play_tone(parent, 430.0 + (3 - number) * 35.0, 0.07, -16.0)


static func play_go(parent: Node) -> void:
	# A custom countdown.wav already contains "GO", so do not layer go.wav
	# or a generated GO beep on top of it.
	if _custom_countdown_is_available() and _countdown_sequence_recently_started(parent):
		return

	if not _play_file(parent, GO_PATH, -8.0):
		play_tone(parent, 760.0, 0.11, -13.0)


static func play_hit(parent: Node) -> void:
	if not _play_file(parent, HIT_PATH, -6.0):
		play_tone(parent, 118.0, 0.18, -10.0)


static func play_level_complete(parent: Node) -> void:
	if not _play_file(parent, LEVEL_COMPLETE_PATH, -8.0):
		play_tone(parent, 523.25, 0.22, -16.0)
		play_tone(parent, 659.25, 0.22, -17.0)
		play_tone(parent, 783.99, 0.28, -18.0)


static func _play_file(
	parent: Node,
	path: String,
	volume_db: float = -10.0,
	pitch_scale: float = 1.0
) -> bool:
	if parent == null or not is_instance_valid(parent):
		return false

	if not ResourceLoader.exists(path):
		return false

	var stream := load(path) as AudioStream
	if stream == null:
		return false

	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = volume_db
	audio.pitch_scale = pitch_scale
	parent.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
	return true


# Original generated-tone fallback from v0.7.
static func play_tone(
	parent: Node,
	frequency: float,
	duration: float,
	volume_db: float = -18.0
) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var sample_rate := 22050
	var frame_count := maxi(1, int(float(sample_rate) * duration))
	var data := PackedByteArray()
	data.resize(frame_count * 2)

	for i in range(frame_count):
		var t := float(i) / float(sample_rate)
		var normalized := float(i) / maxf(1.0, float(frame_count - 1))
		var envelope := sin(PI * normalized)
		var sample_float := sin(TAU * frequency * t) * envelope * 0.42
		var signed_value := int(clampf(sample_float, -1.0, 1.0) * 32767.0)
		var unsigned_value := signed_value
		if unsigned_value < 0:
			unsigned_value += 65536
		data[i * 2] = unsigned_value & 0xFF
		data[i * 2 + 1] = (unsigned_value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data

	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = volume_db
	parent.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
