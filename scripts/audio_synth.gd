extends RefCounted
class_name AudioSynth

const SAMPLE_RATE = 44100


static func create_sfx_library() -> Dictionary:
	return {
		"start": make_sweep_stream(180.0, 620.0, 0.18, "square", 0.44, 0.05),
		"slice": make_sweep_stream(820.0, 340.0, 0.08, "square", 0.28, 0.03),
		"capture": make_jingle_stream([72, 76, 79, 84, 88], 0.08, "triangle", 0.34),
		"pickup_good": make_sweep_stream(540.0, 1320.0, 0.22, "triangle", 0.44, 0.02),
		"pickup_bad": make_sweep_stream(320.0, 90.0, 0.21, "saw", 0.42, 0.05),
		"shield": make_sweep_stream(460.0, 980.0, 0.24, "triangle", 0.38, 0.01),
		"spark": make_sweep_stream(1180.0, 540.0, 0.06, "square", 0.22, 0.08),
		"hit": make_sweep_stream(260.0, 60.0, 0.28, "noise", 0.74, 0.44),
		"level_clear": make_jingle_stream([74, 79, 83, 86, 91], 0.11, "triangle", 0.33),
		"game_over": make_jingle_stream([74, 71, 67, 62], 0.18, "saw", 0.28)
	}


static func create_music_stream(theme: String = "random", danger: bool = false) -> AudioStreamWAV:
	var theme_data := _music_theme(theme)
	var step_duration := float(theme_data["tempo"]) * 0.5 * (0.84 if danger else 1.0)
	var total_steps := 64
	var total_seconds := step_duration * total_steps
	var sample_count := int(total_seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var bass: Array = theme_data["bass"]
	var lead: Array = theme_data["lead"]
	var accent: float = float(theme_data["accent"])

	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var step := int(floor(t / step_duration))
		var local_time := fmod(t, step_duration)
		var sample := 0.0
		var lane := step % 8
		var bass_frequency: float = float(bass[lane % bass.size()])
		var lead_frequency: float = float(lead[lane % lead.size()])
		var menace_frequency := lead_frequency * pow(2.0, -3.0 / 12.0)

		if step % 2 == 0:
			sample += voice_note(local_time, step_duration * 0.9, bass_frequency, 0.18 if danger else 0.13, "saw", 0.0)
			sample += voice_note(local_time, step_duration * 0.82, bass_frequency * 0.5, 0.08 if danger else 0.06, "triangle", 0.0)
			sample += voice_note(local_time, step_duration * 0.72, lead_frequency, 0.1 if danger else 0.08, "triangle", 0.01)
			sample += voice_note(local_time, step_duration * 0.46, lead_frequency * 2.0, 0.028 if danger else 0.018, "sine", 0.0)
			sample += drum_kick(local_time, 0.09, 0.34 if danger else 0.26)
		else:
			sample += drum_tick(local_time, 0.04, 0.07 if danger else 0.045)
		if step % 4 == 2:
			sample += drum_noise(local_time, 0.11, 0.16 if danger else 0.1)
		if danger and step % 4 == 1:
			sample += voice_note(local_time, step_duration * 0.56, menace_frequency, 0.06, "square", 0.0)
		if step % 8 == 7:
			sample += voice_note(local_time, step_duration * 0.32, accent if not danger else accent * pow(2.0, -5.0 / 12.0), 0.06 if danger else 0.04, "square", 0.0)

		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


static func _music_theme(theme: String) -> Dictionary:
	match theme:
		"aww":
			return {
				"tempo": 0.165,
				"bass": [87.31, 87.31, 98.0, 116.54, 130.81, 116.54, 98.0, 87.31],
				"lead": [523.25, 659.25, 783.99, 659.25, 587.33, 659.25, 880.0, 659.25],
				"accent": 987.77
			}
		"funny":
			return {
				"tempo": 0.15,
				"bass": [98.0, 98.0, 110.0, 123.47, 146.83, 123.47, 110.0, 98.0],
				"lead": [659.25, 587.33, 783.99, 698.46, 880.0, 783.99, 987.77, 880.0],
				"accent": 1174.66
			}
		"pinup":
			return {
				"tempo": 0.172,
				"bass": [82.41, 82.41, 98.0, 110.0, 123.47, 110.0, 98.0, 92.5],
				"lead": [493.88, 587.33, 659.25, 739.99, 659.25, 783.99, 880.0, 739.99],
				"accent": 1046.5
			}
		_:
			return {
				"tempo": 0.158,
				"bass": [87.31, 98.0, 110.0, 130.81, 146.83, 130.81, 110.0, 98.0],
				"lead": [523.25, 783.99, 659.25, 880.0, 698.46, 987.77, 783.99, 1174.66],
				"accent": 1318.51
			}


static func make_sweep_stream(freq_start: float, freq_end: float, duration: float, wave: String, volume: float, noise: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq_start * 13.0 + freq_end * 17.0 + duration * 997.0)
	var phase := 0.0

	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var mix: float = t / max(duration, 0.001)
		var freq: float = lerpf(freq_start, freq_end, mix)
		phase += TAU * freq / SAMPLE_RATE
		var env: float = min(t / 0.01, 1.0) * pow(max(0.0, 1.0 - mix), 1.8)
		var sample: float = wave_value(phase, wave) * env * volume
		sample += rng.randf_range(-1.0, 1.0) * noise * env
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	return stream


static func make_jingle_stream(notes: Array, note_length: float, wave: String, volume: float) -> AudioStreamWAV:
	var total_seconds := notes.size() * note_length
	var sample_count := int(total_seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var note_index: int = clamp(int(floor(t / note_length)), 0, notes.size() - 1)
		var local_time := fmod(t, note_length)
		var sample := voice_note(local_time, note_length * 0.94, midi_to_hz(notes[note_index]), volume, wave, 0.0)
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	return stream


static func voice_note(local_time: float, duration: float, frequency: float, volume: float, wave: String, vibrato_depth: float) -> float:
	if local_time >= duration:
		return 0.0
	var attack: float = min(local_time / 0.01, 1.0)
	var release := pow(max(0.0, 1.0 - local_time / max(duration, 0.001)), 1.7)
	var env: float = attack * release
	var vibrato := sin(local_time * TAU * 5.0) * vibrato_depth
	var phase := TAU * (frequency + frequency * vibrato) * local_time
	return wave_value(phase, wave) * env * volume


static func drum_kick(local_time: float, duration: float, volume: float) -> float:
	if local_time >= duration:
		return 0.0
	var env := pow(max(0.0, 1.0 - local_time / duration), 3.2)
	var phase := TAU * (120.0 - local_time * 540.0) * local_time
	return sin(phase) * env * volume


static func drum_noise(local_time: float, duration: float, volume: float) -> float:
	if local_time >= duration:
		return 0.0
	var env := pow(max(0.0, 1.0 - local_time / duration), 2.2)
	var noise := sin(local_time * 8940.0) * sin(local_time * 7310.0)
	return noise * env * volume


static func drum_tick(local_time: float, duration: float, volume: float) -> float:
	if local_time >= duration:
		return 0.0
	var env := pow(max(0.0, 1.0 - local_time / duration), 4.0)
	return wave_value(local_time * 8800.0, "square") * env * volume


static func wave_value(phase: float, wave: String) -> float:
	var unit := fmod(phase / TAU, 1.0)
	match wave:
		"sine":
			return sin(phase)
		"triangle":
			return 1.0 - 4.0 * abs(unit - 0.5)
		"saw":
			return unit * 2.0 - 1.0
		"noise":
			return sin(phase * 1.37) * sin(phase * 0.73)
		_:
			return 1.0 if unit < 0.5 else -1.0


static func midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)
