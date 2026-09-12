class_name JarvisOrbCharOverlay
extends Node3D

## Character-level particle stream rendered as Label3D billboards.

const POOL_SIZE := 320
const KEYWORD_POOL := 48
const SHARED_CURVE_COUNT := 20
const CHAR_QUEUE_CAP := 900

var neuron_net: JarvisOrbNeuronNet
var char_queue: Array[String] = []
var active_particles: Array[CharParticle] = []
var free_labels: Array[Label3D] = []
var keyword_labels: Array[Label3D] = []
var shared_curves: Array[Curve3D] = []

var current_phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var current_path_style: OrbPhase.PathStyle = OrbPhase.PathStyle.TRANSVERSE
var display_color: Color = OrbPhase.theme_rgb()
var current_tool_name: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var stream_char_total: int = 0
var max_active: int = OrbGrowth.PARTICLE_CAP_MIN
var spawn_per_frame: int = OrbGrowth.SPAWN_FRAME_MIN
var recent_phrases: Array[String] = []

var pending_phrase_text := ""
var phrase_batch_timer: float = 0.0


func setup(net: JarvisOrbNeuronNet) -> void:
	neuron_net = net
	rng.randomize()
	build_label_pool()
	build_keyword_pool()
	refresh_shared_curves()
	pass


func _process(delta: float) -> void:
	spawn_from_queue()
	update_particles(delta)
	update_keywords(delta)
	if phrase_batch_timer > 0.0:
		phrase_batch_timer = maxf(0.0, phrase_batch_timer - delta)
		if phrase_batch_timer <= 0.0:
			flush_phrase_batch()
	pass


func enqueue_chars(chars: Array[String]) -> void:
	for ch in chars:
		if char_queue.size() >= CHAR_QUEUE_CAP:
			char_queue.pop_front()
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
	pending_phrase_text = ""
	phrase_batch_timer = 0.0
	clear_queue()
	refresh_shared_curves()
	pass


func set_phase(phase: OrbPhase.Phase, tool_name: String = "") -> void:
	current_phase = phase
	current_path_style = OrbPhase.path_style_for(phase)
	if not tool_name.is_empty():
		current_tool_name = tool_name
	refresh_shared_curves()
	pass


func sync_display_color(color: Color) -> void:
	display_color = color
	pass


func queue_step_phrases(text: String) -> void:
	if text.is_empty():
		return
	pending_phrase_text += text
	phrase_batch_timer = OrbGrowth.TEXT_BATCH_INTERVAL_S
	pass


func flush_phrase_batch() -> void:
	if pending_phrase_text.is_empty():
		return
	var cap := OrbGrowth.stream_keyword_cap(stream_char_total)
	cap = maxi(cap, OrbGrowth.keyword_burst(stream_char_total))
	var phrases := CharStreamUtils.extract_step_phrases(pending_phrase_text, cap)
	pending_phrase_text = ""
	if phrases.is_empty():
		return
	spawn_keywords(phrases, phrases.size())
	pass


func clear_queue() -> void:
	char_queue.clear()
	pass


func apply_orb_font(label: Label3D) -> void:
	label.font = Fonts.light()
	pass


func refresh_shared_curves() -> void:
	shared_curves.clear()
	if neuron_net == null:
		return
	var neurons := neuron_net.get_positions()
	var styles: Array[OrbPhase.PathStyle] = [
		OrbPhase.PathStyle.TRANSVERSE,
		OrbPhase.PathStyle.SPIRAL_IN,
		OrbPhase.PathStyle.ORBIT,
		OrbPhase.PathStyle.CHAOTIC,
	]
	for _i in SHARED_CURVE_COUNT:
		var style: OrbPhase.PathStyle = styles[rng.randi_range(0, styles.size() - 1)]
		shared_curves.append(CharStreamUtils.build_curve(style, neurons, rng))
	pass


func build_label_pool() -> void:
	for _i in POOL_SIZE:
		var label := Label3D.new()
		apply_orb_font(label)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 20
		label.outline_size = 0
		label.pixel_size = 0.0018
		label.modulate = Color(1, 1, 1, 0)
		label.visible = false
		add_child(label)
		free_labels.append(label)
	pass


func build_keyword_pool() -> void:
	for _i in KEYWORD_POOL:
		var label := Label3D.new()
		apply_orb_font(label)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 36
		label.outline_size = 0
		label.pixel_size = 0.0022
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


func acquire_curve() -> Curve3D:
	if shared_curves.is_empty():
		refresh_shared_curves()
	if shared_curves.is_empty():
		return CharStreamUtils.build_curve(current_path_style, neuron_net.get_positions(), rng)
	return shared_curves[rng.randi_range(0, shared_curves.size() - 1)]


func spawn_char(ch: String) -> void:
	if neuron_net == null or free_labels.is_empty():
		return
	var label: Label3D = free_labels.pop_back()
	var token_len := ch.length()
	if token_len > 1:
		label.font_size = 16 if token_len > 10 else 18
		label.pixel_size = 0.00135 if token_len > 10 else 0.00155
	else:
		label.font_size = 20
		label.pixel_size = 0.0018
	var near_index := rng.randi_range(0, maxi(neuron_net.get_positions().size() - 1, 0))
	var particle := CharParticle.new()
	var speed: float = rng.randf_range(OrbVisualScale.PARTICLE_SPEED_MIN, OrbVisualScale.PARTICLE_SPEED_MAX)
	if current_path_style == OrbPhase.PathStyle.CHAOTIC:
		speed *= 1.25
	particle.reset(label, acquire_curve(), ch, display_color, speed, near_index)
	active_particles.append(particle)
	pass


func update_particles(delta: float) -> void:
	var i: int = 0
	while i < active_particles.size():
		var particle := active_particles[i]
		if particle.update(delta):
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
		label.set_meta("birth_color", display_color)
		label.font_size = 22 if word.length() > 14 else 34
		label.pixel_size = 0.0016 if word.length() > 14 else 0.0022
		label.modulate = Color(display_color.r, display_color.g, display_color.b, 0.0)
		label.visible = true
		label.set_meta("life", rng.randf_range(OrbVisualScale.KEYWORD_LIFE_MIN, OrbVisualScale.KEYWORD_LIFE_MAX))
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
		var birth: Color = label.get_meta("birth_color", display_color)
		label.modulate = Color(birth.r, birth.g, birth.b, alpha)
		label.position += Vector3(0.0, delta * OrbVisualScale.KEYWORD_DRIFT_SPEED, 0.0)
		if age >= life:
			label.visible = false
	pass
