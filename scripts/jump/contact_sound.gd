extends RefCounted
## Short damped metal contacts, generated once at startup, not per landing.
## Mono PCM avoids runtime generators/threads and adds no downloaded assets.

static func make_contact(quality: int) -> AudioStreamWAV:
	var durations := [0.09, 0.14, 0.19]
	var frequencies := [160.0, 290.0, 430.0]
	var duration: float = durations[quality]
	var frequency: float = frequencies[quality]
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var t := float(index) / sample_rate
		var progress := t / duration
		var envelope := minf(t / 0.003, 1.0) * pow(1.0 - progress, 2.0)
		var metal := sin(TAU * frequency * t) * 0.65 + sin(TAU * frequency * 2.71 * t) * 0.22
		data.encode_s16(index * 2, int(metal * envelope * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream
