extends Node
## 音效管理器（自动加载单例 Sfx）
## ------------------------------------------------------------
## 所有音效都在运行时用数学波形合成 AudioStreamWAV，不依赖任何外部音频文件。
## 落子声 = 正弦音 + 极短噪声（模拟棋子敲击），胜利用四音上行琶音。

## 音效总开关，UI 上可切换
var enabled := true

const MIX_RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

var _place_black: AudioStreamWAV
var _place_white: AudioStreamWAV
var _undo_sfx: AudioStreamWAV
var _win_sfx: AudioStreamWAV


func _ready() -> void:
	# 一组播放器轮转，允许快速连点时声音叠加
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	_place_black = _make_place(520.0, 0.09)
	_place_white = _make_place(720.0, 0.09)
	_undo_sfx = _make_sweep(820.0, 300.0, 0.14)
	_win_sfx = _make_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.10)


## 播放落子音：黑棋偏低沉，白棋偏清脆。
func play_place(color: int) -> void:
	_play(_place_black if color == 1 else _place_white)


## 悔棋音效（下滑音）。
func play_undo() -> void:
	_play(_undo_sfx)


## 获胜音效（上行琶音）。
func play_win() -> void:
	_play(_win_sfx)


func _play(stream) -> void:
	if not enabled or stream == null or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.play()


# ---------------------------------------------------------------- 波形合成

## 把 -1..1 的浮点采样打包成 16 位单声道 WAV。
func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampf(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(round(v * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


## 落子「嗒」声：短促衰减的正弦 + 首帧噪声。
func _make_place(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var envelope := exp(-t * 42.0)
		var tone := sin(TAU * freq * t) * 0.55
		var noise := rng.randf_range(-1.0, 1.0) * 0.45 * exp(-t * 320.0)
		samples[i] = (tone + noise) * envelope * 0.5
	return _to_wav(samples)


## 频率下滑音（悔棋）。
func _make_sweep(from_freq: float, to_freq: float, duration: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var freq := lerpf(from_freq, to_freq, t * t)
		phase += TAU * freq / float(MIX_RATE)
		samples[i] = sin(phase) * sin(PI * t) * 0.30
	return _to_wav(samples)


## 琶音（胜利）。
func _make_arpeggio(freqs: Array, note_duration: float) -> AudioStreamWAV:
	var tail := 0.30
	var total := int(MIX_RATE * (note_duration * freqs.size() + tail))
	var samples := PackedFloat32Array()
	samples.resize(total)
	for k in freqs.size():
		var start := int(MIX_RATE * note_duration * k)
		var freq: float = freqs[k]
		var n := int(MIX_RATE * (note_duration + tail))
		for i in n:
			var idx := start + i
			if idx >= total:
				break
			var t := float(i) / float(MIX_RATE)
			samples[idx] += sin(TAU * freq * t) * exp(-t * 6.5) * 0.26
	return _to_wav(samples)
