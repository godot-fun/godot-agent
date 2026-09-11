class_name JarvisOrb
extends Node3D

## 3D Jarvis brain orb — neuron net, rings, and char overlay.

var neuron_net: JarvisOrbNeuronNet
var rings: JarvisOrbRings3D
var char_overlay: JarvisOrbCharOverlay

var phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var spin_speed: float = 0.7
var wobble: float = 0.0


func _ready() -> void:
	scale = Vector3.ONE * OrbVisualScale.WORLD_SCALE
	neuron_net = JarvisOrbNeuronNet.new()
	add_child(neuron_net)

	rings = JarvisOrbRings3D.new()
	add_child(rings)

	char_overlay = JarvisOrbCharOverlay.new()
	char_overlay.setup(neuron_net)
	add_child(char_overlay)
	pass


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(spin_speed) * delta)
	if phase == OrbPhase.Phase.REASONING:
		wobble = lerpf(wobble, 0.12, delta * 2.0)
	else:
		wobble = lerpf(wobble, 0.0, delta * 3.0)
	rotation.x = sin(Time.get_ticks_msec() * 0.0012) * wobble
	pass


func set_phase(new_phase: OrbPhase.Phase, tool_name: String = "") -> void:
	phase = new_phase
	var color: Color = OrbPhase.color_for(new_phase)
	neuron_net.set_phase_color(color)
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


func enqueue_stream_chars(chars: Array[String]) -> void:
	if char_overlay != null:
		char_overlay.enqueue_chars(chars)
	pass


func clear_stream_queue() -> void:
	if char_overlay != null:
		char_overlay.clear_queue()
	pass
