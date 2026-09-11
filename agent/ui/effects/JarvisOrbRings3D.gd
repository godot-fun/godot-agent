class_name JarvisOrbRings3D
extends Node3D

## Rotating holographic rings around the neural core.

var ring_nodes: Array[MeshInstance3D] = []
var spin_speeds: PackedFloat32Array = PackedFloat32Array([0.35, -0.55, 0.22])
var target_scale: float = 1.0


func _ready() -> void:
	build_rings()
	pass


func _process(delta: float) -> void:
	for i in ring_nodes.size():
		var ring := ring_nodes[i]
		var speed: float = spin_speeds[i] if i < spin_speeds.size() else 0.3
		ring.rotate_y(speed * delta)
		ring.rotate_x(speed * 0.35 * delta)
	var current: float = scale.x
	scale = Vector3.ONE * lerpf(current, target_scale, delta * 3.0)
	pass


func set_tool_mode(enabled: bool) -> void:
	target_scale = 0.82 if enabled else 1.0
	pass


func build_rings() -> void:
	var radii: PackedFloat32Array = PackedFloat32Array([1.22, 1.48, 1.72])
	for i in radii.size():
		var radius: float = radii[i]
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.012
		torus.outer_radius = radius
		torus.rings = 24
		torus.ring_segments = 48

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.0, 0.85, 1.0, 0.12 - i * 0.02)
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.75, 1.0)
		mat.emission_energy_multiplier = 0.35 - i * 0.06
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = mat
		ring.rotation_degrees = Vector3(72.0 + i * 14.0, 0.0, 18.0 + i * 8.0)
		add_child(ring)
		ring_nodes.append(ring)
	pass
