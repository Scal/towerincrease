extends AudioStreamPlayer3D

@export var tracks: Array[AudioStream] = [
	preload("res://common/audio/industrial_SFX-001.ogg"),
	preload("res://common/audio/industrial_SFX-002.ogg"),
	preload("res://common/audio/industrial_SFX-003.ogg"),
	preload("res://common/audio/industrial_SFX-004.ogg"),
	preload("res://common/audio/industrial_SFX-005.ogg"),
	preload("res://common/audio/industrial_SFX-006.ogg"),
	preload("res://common/audio/industrial_SFX-007.ogg"),
	preload("res://common/audio/industrial_SFX-008.ogg"),
	preload("res://common/audio/industrial_SFX-010.ogg"),
	preload("res://common/audio/industrial_SFX-011.ogg"),
	preload("res://common/audio/industrial_SFX-012.ogg"),
	preload("res://common/audio/industrial_SFX-013.ogg"),
	preload("res://common/audio/industrial_SFX-014.ogg"),
]


func _ready() -> void:
	if tracks.is_empty():
		return

	var chosen_stream: AudioStream = tracks.pick_random()

	_enable_looping(chosen_stream)

	stream = chosen_stream
	play()


func _enable_looping(audio_stream: AudioStream) -> void:
	if audio_stream is AudioStreamMP3:
		audio_stream.loop = true
	elif audio_stream is AudioStreamOggVorbis:
		audio_stream.loop = true
	elif audio_stream is AudioStreamWAV:
		audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
