class_name JarvisOrbNeuronNet
extends Node3D

## Brain-shaped neuron point cloud + synapse filaments.

const NEURON_COUNT := 900
const NEIGHBORS := 3
const MAX_EDGE_DIST := 0.55

var neuron_positions: PackedVector3Array = PackedVector3Array()
var pulse_levels: PackedFloat32Array = PackedFloat32Array()

var multimesh_instance: MultiMeshInstance3D
var filament_mesh: MeshInstance3D
var neuron_shader: ShaderMaterial
var filament_shader: ShaderMaterial


func _ready() -> void:
	neuron_positions = generate_brain_points(NEURON_COUNT)
	pulse_levels.resize(neuron_positions.size())
	pulse_levels.fill(0.0)
	build_neurons()
	build_filaments()
	pass


func _process(delta: float) -> void:
	for i in pulse_levels.size():
		if pulse_levels[i] > 0.0:
			pulse_levels[i] = maxf(0.0, pulse_levels[i] - delta * 1.8)
	if neuron_shader != null:
		var avg_pulse: float = 0.65 + _average_pulse() * 0.55
		neuron_shader.set_shader_parameter("pulse", avg_pulse)
	if filament_shader != null:
		filament_shader.set_shader_parameter("pulse", 0.55 + _average_pulse() * 0.45)
	pass


func get_positions() -> PackedVector3Array:
	return neuron_positions


func pulse_neuron(index: int, strength: float = 1.0) -> void:
	if index < 0 or index >= pulse_levels.size():
		return
	pulse_levels[index] = clampf(pulse_levels[index] + strength, 0.0, 1.0)
	pass


func pulse_random(strength: float = 0.8) -> void:
	if neuron_positions.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	pulse_neuron(rng.randi_range(0, neuron_positions.size() - 1), strength)
	pass


func set_phase_color(color: Color) -> void:
	if neuron_shader != null:
		neuron_shader.set_shader_parameter("base_color", Color(color.r, color.g, color.b, 0.85))
	if filament_shader != null:
		filament_shader.set_shader_parameter("line_color", Color(color.r, color.g, color.b, 0.42))
	pass


func build_neurons() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.018
	sphere.height = 0.036
	sphere.radial_segments = 6
	sphere.rings = 4

	neuron_shader = ShaderMaterial.new()
	neuron_shader.shader = load("res://agent/ui/effects/shaders/jarvis_neuron.gdshader") as Shader
	neuron_shader.set_shader_parameter("base_color", Color(0.0, 0.9, 1.0, 0.85))

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = false
	multi.mesh = sphere
	multi.instance_count = neuron_positions.size()

	for i in neuron_positions.size():
		var pos := neuron_positions[i]
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * (0.85 + float(i % 5) * 0.04))
		multi.set_instance_transform(i, Transform3D(basis, pos))

	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.multimesh = multi
	multimesh_instance.material_override = neuron_shader
	add_child(multimesh_instance)
	pass


func build_filaments() -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var edge_index := 0
	for i in neuron_positions.size():
		var neighbors := find_neighbors(i)
		for neighbor_index in neighbors:
			if neighbor_index <= i:
				continue
			var a := neuron_positions[i]
			var b := neuron_positions[neighbor_index]
			var base: int = verts.size()
			verts.append(a)
			verts.append(b)
			uvs.append(Vector2(0.0, 0.0))
			uvs.append(Vector2(1.0, 0.0))
			indices.append(base)
			indices.append(base + 1)
			edge_index += 1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	filament_shader = ShaderMaterial.new()
	filament_shader.shader = load("res://agent/ui/effects/shaders/jarvis_filament.gdshader") as Shader
	filament_shader.set_shader_parameter("line_color", Color(0.0, 1.0, 1.0, 0.42))

	filament_mesh = MeshInstance3D.new()
	filament_mesh.mesh = mesh
	filament_mesh.material_override = filament_shader
	add_child(filament_mesh)
	pass


func generate_brain_points(count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in count:
		var u := rng.randf()
		var v := rng.randf()
		var theta := TAU * u
		var phi := acos(2.0 * v - 1.0)
		var x := sin(phi) * cos(theta)
		var y := sin(phi) * sin(theta) * 0.92
		var z := cos(phi) * 0.78
		if x >= 0.0:
			x += 0.07
		else:
			x -= 0.07
		x *= 0.88
		y *= 1.05
		z *= 0.82
		x += rng.randf_range(-0.04, 0.04)
		y += rng.randf_range(-0.04, 0.04)
		z += rng.randf_range(-0.04, 0.04)
		points.append(Vector3(x, y, z))
	return points


func find_neighbors(index: int) -> Array[int]:
	var origin := neuron_positions[index]
	var scored: Array[Vector2i] = []
	for j in neuron_positions.size():
		if j == index:
			continue
		var dist := origin.distance_to(neuron_positions[j])
		if dist <= MAX_EDGE_DIST:
			scored.append(Vector2i(j, int(dist * 1000.0)))
	scored.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	var result: Array[int] = []
	for entry in scored:
		result.append(entry.x)
		if result.size() >= NEIGHBORS:
			break
	return result


func _average_pulse() -> float:
	if pulse_levels.is_empty():
		return 0.0
	var total := 0.0
	for level in pulse_levels:
		total += level
	return total / float(pulse_levels.size())
