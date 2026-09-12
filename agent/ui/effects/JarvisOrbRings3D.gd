class_name JarvisOrbRings3D
extends Node3D

## Rotating holographic rings around the neural core.

const RING_SEGMENTS := 160
const RING_BAND_WIDTH := 0.006

var ring_nodes: Array[MeshInstance3D] = []
var ring_materials: Array[StandardMaterial3D] = []
var spin_speeds: PackedFloat32Array = PackedFloat32Array([0.32, -0.48, 0.26, -0.38, 0.42, -0.22])
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


func apply_theme() -> void:
	pass


func apply_display_color(color: Color) -> void:
	var alpha_base: float = 0.15 if OrbTheme.is_dark() else 0.1
	var emission_mul: float = 1.08 if OrbTheme.is_dark() else 0.86
	for i in ring_materials.size():
		var mat := ring_materials[i]
		mat.albedo_color = Color(color.r, color.g, color.b, maxf(alpha_base - i * 0.012, 0.04))
		mat.emission = Color(color.r * emission_mul, color.g * emission_mul, color.b * emission_mul)
	pass


func build_rings() -> void:
	var radii: PackedFloat32Array = PackedFloat32Array([1.06, 1.18, 1.30, 1.42, 1.54, 1.68])
	for i in radii.size():
		var radius: float = radii[i]
		var ring_mesh := build_smooth_ring_mesh(radius, RING_BAND_WIDTH, RING_SEGMENTS)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.0, 0.85, 1.0, maxf(0.13 - i * 0.012, 0.05))
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.75, 1.0)
		mat.emission_energy_multiplier = maxf(0.34 - i * 0.04, 0.12)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_materials.append(mat)

		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = mat
		var tilt_x: float = 58.0 + float(i) * 11.0
		var tilt_z: float = 12.0 + float(i) * 9.0
		var yaw: float = float(i) * 23.0
		ring.rotation_degrees = Vector3(tilt_x, yaw, tilt_z)
		add_child(ring)
		ring_nodes.append(ring)
	pass


func build_smooth_ring_mesh(radius: float, band_width: float, segments: int) -> ArrayMesh:
	var half_band: float = band_width * 0.5
	var inner_radius: float = maxf(radius - half_band, 0.02)
	var outer_radius: float = radius + half_band
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment in segments:
		var t0: float = float(segment) / float(segments) * TAU
		var t1: float = float(segment + 1) / float(segments) * TAU
		var cos0: float = cos(t0)
		var sin0: float = sin(t0)
		var cos1: float = cos(t1)
		var sin1: float = sin(t1)
		var base: int = verts.size()
		verts.append(Vector3(cos0 * inner_radius, sin0 * inner_radius, 0.0))
		verts.append(Vector3(cos0 * outer_radius, sin0 * outer_radius, 0.0))
		verts.append(Vector3(cos1 * outer_radius, sin1 * outer_radius, 0.0))
		verts.append(Vector3(cos1 * inner_radius, sin1 * inner_radius, 0.0))
		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(0.0, 1.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(1.0, 0.0))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
