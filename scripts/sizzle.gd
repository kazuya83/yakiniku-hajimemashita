class_name Sizzle
extends AudioStreamPlayer3D
## ジュージュー音をその場で合成する（ノイズ＋パチパチ＋炎のボッ）

var intensity := 0.0
var _pb: AudioStreamGeneratorPlayback
var _prev := 0.0
var _crack := 0.0
var _pop := 0.0
var _lp := 0.0
var _rate := 22050.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _rate
	gen.buffer_length = 0.12
	stream = gen
	unit_size = 1.6
	max_distance = 12.0
	volume_db = -4.0
	play()
	_pb = get_stream_playback()


func pop(v: float) -> void:
	_pop = maxf(_pop, v)


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	var amp := clampf(intensity, 0.0, 1.3)
	for i in n:
		var w := randf() * 2.0 - 1.0
		var hp := (w - _prev) * 0.5
		_prev = w
		if randf() < amp * 0.0025:
			_crack = randf_range(0.4, 1.0) * amp
		_crack *= 0.985
		_lp += (w - _lp) * 0.05
		_pop *= 0.99985
		var s := hp * amp * 0.22 + w * _crack * 0.35 + _lp * _pop * 1.6
		_pb.push_frame(Vector2(s, s))
