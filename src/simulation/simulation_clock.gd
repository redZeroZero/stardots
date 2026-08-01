class_name SimulationClock
extends RefCounted

const TICK_RATE: int = 20
const MAX_TICKS_PER_FRAME: int = 5
const TICK_DURATION: float = 1.0 / float(TICK_RATE)

var tick_index: int = 0
var time_scale: float = 1.0
var paused: bool = false
var _accumulator: float = 0.0


func advance(delta: float) -> int:
	if paused or time_scale <= 0.0:
		return 0

	_accumulator += delta * time_scale
	var processed_ticks: int = 0

	while _accumulator >= TICK_DURATION and processed_ticks < MAX_TICKS_PER_FRAME:
		_accumulator -= TICK_DURATION
		tick_index += 1
		processed_ticks += 1

	if processed_ticks == MAX_TICKS_PER_FRAME:
		_accumulator = minf(_accumulator, TICK_DURATION)

	return processed_ticks

