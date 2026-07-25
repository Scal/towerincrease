
extends AudioStreamPlayer

@export var default_track: AudioStream
@export var default_fade_time: float = 1.0

var _tween: Tween


func _ready() -> void:
	if default_track:
		play_track(default_track, 0.0) 



func play_track(new_stream: AudioStream, fade_time: float = -1.0) -> void:
	var duration: float = fade_time if fade_time >= 0.0 else default_fade_time

	if stream == new_stream and playing:
		return

	if _tween and _tween.is_running():
		_tween.kill()

	
	if duration <= 0.0 or not playing:
		stream = new_stream
		if stream:
			volume_db = 0.0
			play()
		else:
			stop()
		return

	
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", -80.0, duration)
	_tween.tween_callback(
		func():
			stream = new_stream
			if stream:
				play()
			else:
				stop()
	)
	if new_stream:
		_tween.tween_property(self, "volume_db", 0.0, duration)


func stop_music(fade_time: float = -1.0) -> void:
	play_track(null, fade_time)
