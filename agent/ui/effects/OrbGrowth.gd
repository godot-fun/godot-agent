class_name OrbGrowth
extends RefCounted

## Maps cumulative streamed text volume to orb density (neurons, particles, keywords).

const NEURON_MIN := 260
const NEURON_MAX := 1700
const NEURON_REBUILD_STEP := 70

const PARTICLE_CAP_MIN := 90
const PARTICLE_CAP_MAX := 480
const SPAWN_FRAME_MIN := 6
const SPAWN_FRAME_MAX := 32
const CHUNK_CHARS_MIN := 4
const CHUNK_CHARS_MAX := 18

const KEYWORD_POOL_MIN := 12
const KEYWORD_POOL_MAX := 48

## Stream chars to reach maximum density (one long agent reply).
const CHARS_FOR_FULL := 7000.0


static func level(char_count: int) -> float:
	return clampf(float(char_count) / CHARS_FOR_FULL, 0.0, 1.0)


static func neuron_count(char_count: int) -> int:
	return int(lerpf(float(NEURON_MIN), float(NEURON_MAX), level(char_count)))


static func particle_cap(char_count: int) -> int:
	return int(lerpf(float(PARTICLE_CAP_MIN), float(PARTICLE_CAP_MAX), level(char_count)))


static func spawn_per_frame(char_count: int) -> int:
	return int(lerpf(float(SPAWN_FRAME_MIN), float(SPAWN_FRAME_MAX), level(char_count)))


static func chunk_char_cap(char_count: int) -> int:
	return int(lerpf(float(CHUNK_CHARS_MIN), float(CHUNK_CHARS_MAX), level(char_count)))


static func keyword_burst(char_count: int) -> int:
	var growth := level(char_count)
	return 1 + int(growth * 4.0)


static func stream_keyword_cap(char_count: int) -> int:
	return 1 + int(level(char_count) * 3.0)
