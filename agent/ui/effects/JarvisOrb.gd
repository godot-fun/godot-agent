class_name JarvisOrb
extends Node3D

## 3D Jarvis brain orb — neuron net, rings, and char overlay.

var neuron_net: JarvisOrbNeuronNet
var rings: JarvisOrbRings3D
var char_overlay: JarvisOrbCharOverlay

var phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var spin_speed: float = 0.7
var wobble: float = 0.0
var stream_char_total: int = 0
var color_controller: OrbColorController = OrbColorController.new()
var filament_color_controller: OrbColorController = OrbColorController.new()

var pending_chars: Array[String] = []
var growth_dirty: bool = false
var growth_flush_timer: float = 0.0


func _ready() -> void:
	scale = Vector3.ONE * OrbVisualScale.WORLD_SCALE
	neuron_net = JarvisOrbNeuronNet.new()
	add_child(neuron_net)

	rings = JarvisOrbRings3D.new()
	add_child(rings)

	char_overlay = JarvisOrbCharOverlay.new()
	char_overlay.setup(neuron_net)
	add_child(char_overlay)
	apply_theme(false)
	pass


func _process(delta: float) -> void:
	var time_s: float = Time.get_ticks_msec() * 0.001
	rotate_y(deg_to_rad(spin_speed) * delta + sin(time_s * 0.31) * delta * 0.08)
	if phase == OrbPhase.Phase.REASONING:
		wobble = lerpf(wobble, 0.12, delta * 2.0)
	else:
		wobble = lerpf(wobble, 0.0, delta * 3.0)
	rotation.x = sin(time_s * 0.97) * wobble
	rotation.z = sin(time_s * 0.63) * wobble * 0.35

	color_controller.update(delta)
	filament_color_controller.update(delta)
	apply_display_color()

	if growth_flush_timer > 0.0:
		growth_flush_timer = maxf(0.0, growth_flush_timer - delta)
		if growth_flush_timer <= 0.0 and growth_dirty:
			flush_growth()
	pass


func set_phase(new_phase: OrbPhase.Phase, tool_name: String = "") -> void:
	phase = new_phase
	color_controller.set_target(OrbTheme.neuron_color_for(new_phase))
	filament_color_controller.set_target(OrbTheme.filament_color_for(new_phase))
	char_overlay.set_phase(new_phase, tool_name)
	rings.set_tool_mode(new_phase == OrbPhase.Phase.TOOL_EXEC)
	match new_phase:
		OrbPhase.Phase.REASONING:
			spin_speed = 0.45
		OrbPhase.Phase.TOOL_EXEC:
			spin_speed = 1.1
		OrbPhase.Phase.ERROR:
			spin_speed = 1.6
		_:
			spin_speed = 0.7
	if new_phase != OrbPhase.Phase.IDLE:
		neuron_net.pulse_random(0.9)
	pass


func add_step_text(text: String) -> void:
	if text.is_empty():
		return
	stream_char_total += text.length()
	var cap := OrbGrowth.chunk_char_cap(stream_char_total)
	for ch in CharStreamUtils.extract_spawn_chars(text, cap):
		pending_chars.append(ch)
	char_overlay.queue_step_phrases(text)
	growth_dirty = true
	growth_flush_timer = OrbGrowth.TEXT_BATCH_INTERVAL_S
	pass


func flush_growth() -> void:
	growth_dirty = false
	if not pending_chars.is_empty():
		char_overlay.enqueue_chars(pending_chars)
		pending_chars.clear()
	char_overlay.apply_growth(stream_char_total)
	neuron_net.apply_growth(stream_char_total)
	pass


func add_stream_chunk(chunk: String) -> void:
	add_step_text(chunk)
	pass


func apply_growth() -> void:
	char_overlay.apply_growth(stream_char_total)
	neuron_net.apply_growth(stream_char_total)
	pass


func apply_display_color() -> void:
	var color: Color = color_controller.display_color
	var filament_color: Color = filament_color_controller.display_color
	neuron_net.apply_display_color(color, filament_color)
	rings.apply_display_color(color)
	char_overlay.sync_display_color(OrbTheme.char_color_for(phase))
	pass


func apply_theme(smooth: bool = true) -> void:
	var neuron_color := OrbTheme.neuron_color_for(phase)
	var filament_color := OrbTheme.filament_color_for(phase)
	if phase == OrbPhase.Phase.IDLE:
		neuron_color = OrbTheme.neuron_color_for(OrbPhase.Phase.AWAKE)
		filament_color = OrbTheme.filament_color_for(OrbPhase.Phase.AWAKE)
	if smooth:
		color_controller.set_target(neuron_color)
		filament_color_controller.set_target(filament_color)
	else:
		color_controller.snap_to(neuron_color)
		filament_color_controller.snap_to(filament_color)
	char_overlay.apply_theme()
	rings.apply_theme()
	apply_display_color()
	pass


func reset_growth() -> void:
	if growth_dirty:
		flush_growth()
	apply_theme(false)
	stream_char_total = 0
	pending_chars.clear()
	growth_dirty = false
	growth_flush_timer = 0.0
	neuron_net.reset_growth()
	char_overlay.reset_growth()
	pass


func enqueue_stream_chars(chars: Array[String]) -> void:
	if char_overlay != null:
		char_overlay.enqueue_chars(chars)
	pass


func clear_stream_queue() -> void:
	pending_chars.clear()
	if char_overlay != null:
		char_overlay.clear_queue()
	pass
