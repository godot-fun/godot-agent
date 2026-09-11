class_name JarvisOrbCharOverlay
extends Node3D

## Character-level particle stream rendered as Label3D billboards.

const POOL_SIZE := 520
const KEYWORD_POOL := 48

var neuron_net: JarvisOrbNeuronNet
var char_queue: Array[String] = []
var active_particles: Array[CharParticle] = []
var free_labels: Array[Label3D] = []
var keyword_labels: Array[Label3D] = []
var current_phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var current_path_style: OrbPhase.PathStyle = OrbPhase.PathStyle.TRANSVERSE
var current_color: Color = Color(0.0, 0.92, 1.0)
var current_tool_name: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var stream_char_total: int = 0
var max_active: int = OrbGrowth.PARTICLE_CAP_MIN
var spawn_per_frame: int = OrbGrowth.SPAWN_FRAME_MIN
var recent_phrases: Array[String] = []


func setup(net: JarvisOrbNeuronNet) -> void:
	neuron_net = net
	rng.randomize()
	build_label_pool()
	build_keyword_pool()
	pass


func _process(delta: float) -> void:
	spawn_from_queue()
	update_particles(delta)
	update_keywords(delta)
	pass


func enqueue_chars(chars: Array[String]) -> void:
	for ch in chars:
		char_queue.append(ch)
	pass


func apply_growth(char_total: int) -> void:
	stream_char_total = char_total
	max_active = OrbGrowth.particle_cap(char_total)
	spawn_per_frame = OrbGrowth.spawn_per_frame(char_total)
	pass


func reset_growth() -> void:
	stream_char_total = 0
	max_active = OrbGrowth.PARTICLE_CAP_MIN
	spawn_per_frame = OrbGrowth.SPAWN_FRAME_MIN
	recent_phrases.clear()
	clear_queue()
	pass


func set_phase(phase: OrbPhase.Phase, tool_name: String = "") -> void:
	current_phase = phase
	current_path_style = OrbPhase.path_style_for(phase)
	current_color = OrbPhase.color_for(phase)
	if not tool_name.is_empty():
		current_tool_name = tool_name
	pass


func spawn_step_phrases(text: String) -> void:
	if text.is_empty():
		return
	var cap := OrbGrowth.stream_keyword_cap(stream_char_total)
	cap = maxi(cap, OrbGrowth.keyword_burst(stream_char_total))
	var phrases := CharStreamUtils.extract_step_phrases(text, cap)
	if phrases.is_empty():
		return
	spawn_keywords(phrases, phrases.size())
	pass


func clear_queue() -> void:
	char_queue.clear()
	pass


func build_label_pool() -> void:
	for _i in POOL_SIZE:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 20
		label.outline_size = 5
		label.pixel_size = 0.0018
		label.outline_modulate = Color(0.0, 0.15, 0.25, 0.85)
		label.modulate = Color(1, 1, 1, 0)
		label.visible = false
		add_child(label)
		free_labels.append(label)
	pass


func build_keyword_pool() -> void:
	for _i in KEYWORD_POOL:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 36
		label.outline_size = 8
		label.pixel_size = 0.0022
		label.outline_modulate = Color(0.0, 0.2, 0.35, 0.9)
		label.modulate = Color(1, 1, 1, 0)
		label.visible = false
		add_child(label)
		keyword_labels.append(label)
	pass


func spawn_from_queue() -> void:
	var spawned: int = 0
	while not char_queue.is_empty() and spawned < spawn_per_frame and active_particles.size() < max_active:
		if free_labels.is_empty():
			break
		var ch: String = char_queue.pop_front()
		spawn_char(ch)
		spawned += 1
	pass


func spawn_char(ch: String) -> void:
	if neuron_net == null or free_labels.is_empty():
		return
	var label: Label3D = free_labels.pop_back()
	var neurons := neuron_net.get_positions()
	var curve := CharStreamUtils.build_curve(current_path_style, neurons, rng)
	var near_index := rng.randi_range(0, maxi(neurons.size() - 1, 0))
	var particle := CharParticle.new()
	var speed: float = rng.randf_range(0.28, 0.48)
	if current_path_style == OrbPhase.PathStyle.CHAOTIC:
		speed *= 1.35
	particle.reset(label, curve, ch, current_color, speed, near_index)
	active_particles.append(particle)
	neuron_net.pulse_neuron(near_index, 0.55)
	pass


func update_particles(delta: float) -> void:
	var i: int = 0
	while i < active_particles.size():
		var particle := active_particles[i]
		if particle.update(delta):
			if particle.progress > 0.35 and particle.progress < 0.55 and neuron_net != null:
				neuron_net.pulse_neuron(particle.near_neuron_index, 0.25)
			i += 1
			continue
		free_labels.append(particle.label)
		active_particles.remove_at(i)
	pass


func spawn_keywords(words: Array[String], max_count: int = 3) -> void:
	var available: Array[Label3D] = []
	for label in keyword_labels:
		if not label.visible:
			available.append(label)
	if available.is_empty():
		return
	var spawned: int = 0
	for word in words:
		if available.is_empty() or spawned >= max_count:
			break
		if recent_phrases.has(word):
			continue
		var label: Label3D = available.pop_back()
		recent_phrases.append(word)
		while recent_phrases.size() > 48:
			recent_phrases.pop_front()
		label.text = word
		label.font_size = 22 if word.length() > 14 else 34
		label.pixel_size = 0.0016 if word.length() > 14 else 0.0022
		label.modulate = Color(current_color.r, current_color.g, current_color.b, 0.0)
		label.visible = true
		label.set_meta("life", rng.randf_range(2.2, 4.2))
		label.set_meta("age", 0.0)
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(1.15, 1.72)
		label.position = Vector3(
			cos(angle) * radius,
			rng.randf_range(-0.45, 0.55),
			sin(angle) * radius * 0.55
		)
		label.rotation.y = angle
		spawned += 1
	pass


func update_keywords(delta: float) -> void:
	for label in keyword_labels:
		if not label.visible:
			continue
		var age: float = float(label.get_meta("age", 0.0)) + delta
		var life: float = float(label.get_meta("life", 2.5))
		label.set_meta("age", age)
		var t: float = age / life
		var alpha: float = sin(clampf(t, 0.0, 1.0) * PI) * 0.75
		label.modulate = Color(current_color.r, current_color.g, current_color.b, alpha)
		label.position += Vector3(0.0, delta * 0.06, 0.0)
		if age >= life:
			label.visible = false
	pass
