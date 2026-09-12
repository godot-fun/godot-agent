class_name JarvisOrbNeuronNet
extends Node3D

## Brain-shaped neuron point cloud + synapse filaments — grows incrementally with stream volume.

const NEIGHBORS := 3
const MAX_EDGE_DIST := 0.55
const FILAMENT_SAMPLE_STRIDE := 2
## Slim quad width for synapse segments (PRIMITIVE_LINES is unreliable in 3D).
const FILAMENT_HALF_WIDTH := 0.0020
## White synapse lines (intensity via shader; not phase-tinted).
const SYNAPSE_LINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)

var neuron_anchors: PackedVector3Array = PackedVector3Array()
var neuron_positions: PackedVector3Array = PackedVector3Array()
var neuron_phases: PackedFloat32Array = PackedFloat32Array()
var neuron_speeds: PackedFloat32Array = PackedFloat32Array()
var neuron_amps: PackedFloat32Array = PackedFloat32Array()
var neuron_tangent_a: PackedVector3Array = PackedVector3Array()
var neuron_tangent_b: PackedVector3Array = PackedVector3Array()
var synapse_pairs: Array[Vector2i] = []
var motion_time: float = 0.0
var wander_speed_scale: float = 0.75
var pulse_levels: PackedFloat32Array = PackedFloat32Array()
var active_pulse_indices: Array[int] = []
var pulse_sum: float = 0.0

var current_neuron_count: int = 0
var pending_neuron_target: int = 0
var rebuild_cooldown: float = 0.0
var filament_dirty: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var sphere_mesh: SphereMesh

var multimesh_instance: MultiMeshInstance3D
var filament_mesh: MeshInstance3D
var filament_surface: ArrayMesh
var neuron_shader: ShaderMaterial
var filament_shader: ShaderMaterial


func _ready() -> void:
	rng.randomize()
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.018
	sphere_mesh.height = 0.036
	sphere_mesh.radial_segments = 6
	sphere_mesh.rings = 4
	rebuild_neurons(OrbGrowth.NEURON_MIN)
	pass


func _process(delta: float) -> void:
	rebuild_cooldown = maxf(0.0, rebuild_cooldown - delta)
	try_flush_neuron_growth()
	if filament_dirty and rebuild_cooldown <= 0.0:
		build_filaments()
		filament_dirty = false
		rebuild_cooldown = OrbGrowth.NEURON_REBUILD_COOLDOWN_S

	var pulse_index := 0
	while pulse_index < active_pulse_indices.size():
		var neuron_index: int = active_pulse_indices[pulse_index]
		if neuron_index >= pulse_levels.size():
			active_pulse_indices.remove_at(pulse_index)
			continue
		var level: float = pulse_levels[neuron_index]
		if level <= 0.0:
			active_pulse_indices.remove_at(pulse_index)
			continue
		var decayed: float = maxf(0.0, level - delta * 1.8)
		pulse_sum += decayed - level
		pulse_levels[neuron_index] = decayed
		if decayed <= 0.0:
			active_pulse_indices.remove_at(pulse_index)
			continue
		pulse_index += 1

	if neuron_shader != null:
		var avg_pulse: float = 0.65 + _average_pulse() * 0.55
		neuron_shader.set_shader_parameter("pulse", avg_pulse)

	motion_time += delta * wander_speed_scale
	update_neuron_motion()
	refresh_multimesh_transforms()
	refresh_filament_vertices()
	pass


func get_positions() -> PackedVector3Array:
	return neuron_positions


func apply_growth(char_count: int) -> void:
	var target := OrbGrowth.neuron_count(char_count)
	if target <= current_neuron_count:
		return
	pending_neuron_target = maxi(pending_neuron_target, target)
	try_flush_neuron_growth()
	pass


func try_flush_neuron_growth() -> void:
	if pending_neuron_target <= current_neuron_count:
		return
	if rebuild_cooldown > 0.0:
		return
	if current_neuron_count > 0 and pending_neuron_target < current_neuron_count + OrbGrowth.NEURON_REBUILD_STEP:
		return
	append_neurons(pending_neuron_target)
	pending_neuron_target = 0
	rebuild_cooldown = OrbGrowth.NEURON_REBUILD_COOLDOWN_S
	pass


func reset_growth() -> void:
	pending_neuron_target = 0
	rebuild_cooldown = 0.0
	filament_dirty = false
	motion_time = 0.0
	active_pulse_indices.clear()
	pulse_sum = 0.0
	rebuild_neurons(OrbGrowth.NEURON_MIN)
	pass


func pulse_neuron(index: int, strength: float = 1.0) -> void:
	if index < 0 or index >= pulse_levels.size():
		return
	var old_level: float = pulse_levels[index]
	var new_level: float = clampf(old_level + strength, 0.0, 1.0)
	if is_equal_approx(old_level, new_level):
		return
	pulse_levels[index] = new_level
	pulse_sum += new_level - old_level
	if old_level <= 0.0 and new_level > 0.0:
		active_pulse_indices.append(index)
	pass


func pulse_random(strength: float = 0.8) -> void:
	if neuron_positions.is_empty():
		return
	pulse_neuron(rng.randi_range(0, neuron_positions.size() - 1), strength)
	pass


func apply_display_color(color: Color) -> void:
	if neuron_shader != null:
		neuron_shader.set_shader_parameter("base_color", Color(color.r, color.g, color.b, 0.85))
	if filament_shader != null:
		sync_filament_theme()
	pass


func sync_filament_theme() -> void:
	if filament_shader == null:
		return
	filament_shader.set_shader_parameter("line_color", SYNAPSE_LINE_COLOR)
	filament_shader.set_shader_parameter(
		"line_strength",
		0.52 if AgentColors.is_dark() else 0.28
	)
	pass


func rebuild_neurons(count: int) -> void:
	clear_meshes()
	current_neuron_count = count
	neuron_anchors = generate_brain_points(count)
	neuron_positions = neuron_anchors.duplicate()
	init_motion_params(0, current_neuron_count)
	pulse_levels.resize(neuron_positions.size())
	pulse_levels.fill(0.0)
	pulse_sum = 0.0
	active_pulse_indices.clear()
	build_neurons()
	build_filaments()
	filament_dirty = false
	pass


func append_neurons(target_count: int) -> void:
	var add_count := target_count - current_neuron_count
	if add_count <= 0:
		return
	var new_points := generate_brain_points(add_count)
	var start_index := neuron_anchors.size()
	for point in new_points:
		neuron_anchors.append(point)
		neuron_positions.append(point)
	current_neuron_count = neuron_anchors.size()
	init_motion_params(start_index, current_neuron_count)
	pulse_levels.resize(current_neuron_count)
	for i in range(current_neuron_count - add_count, current_neuron_count):
		pulse_levels[i] = 0.0
	rebuild_multimesh()
	filament_dirty = true
	pass


func clear_meshes() -> void:
	if multimesh_instance != null:
		multimesh_instance.queue_free()
		multimesh_instance = null
	if filament_mesh != null:
		filament_mesh.queue_free()
		filament_mesh = null
	filament_surface = null
	synapse_pairs.clear()
	pass


func rebuild_multimesh() -> void:
	if neuron_shader == null:
		neuron_shader = ShaderMaterial.new()
		neuron_shader.shader = load("res://agent/ui/effects/shaders/jarvis_neuron.gdshader") as Shader
	neuron_shader.set_shader_parameter("base_color", Color(0.0, 0.9, 1.0, 0.85))

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = false
	multi.mesh = sphere_mesh
	multi.instance_count = neuron_positions.size()

	for i in neuron_positions.size():
		multi.set_instance_transform(i, neuron_instance_transform(i))

	if multimesh_instance == null:
		multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.material_override = neuron_shader
		add_child(multimesh_instance)
	multimesh_instance.multimesh = multi
	pass


func build_neurons() -> void:
	rebuild_multimesh()
	pass


func build_filaments() -> void:
	synapse_pairs.clear()
	var grid := build_spatial_grid(MAX_EDGE_DIST)
	var stride := 1 if neuron_anchors.size() <= 650 else FILAMENT_SAMPLE_STRIDE
	for i in range(0, neuron_anchors.size(), stride):
		var neighbors := find_neighbors_spatial(i, grid)
		for neighbor_index in neighbors:
			if neighbor_index <= i:
				continue
			synapse_pairs.append(Vector2i(i, neighbor_index))

	var arrays := build_filament_arrays()
	if arrays.is_empty():
		return
	if filament_surface == null:
		filament_surface = ArrayMesh.new()
	filament_surface.clear_surfaces()
	filament_surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if filament_shader == null:
		filament_shader = ShaderMaterial.new()
		filament_shader.shader = load("res://agent/ui/effects/shaders/jarvis_filament.gdshader") as Shader
		filament_shader.render_priority = 8
	sync_filament_theme()

	if filament_mesh == null:
		filament_mesh = MeshInstance3D.new()
		filament_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		filament_mesh.material_override = filament_shader
		add_child(filament_mesh)
	filament_mesh.mesh = filament_surface
	pass


func init_motion_params(from_index: int, to_index: int) -> void:
	neuron_phases.resize(to_index)
	neuron_speeds.resize(to_index)
	neuron_amps.resize(to_index)
	neuron_tangent_a.resize(to_index)
	neuron_tangent_b.resize(to_index)
	for i in range(from_index, to_index):
		var anchor := neuron_anchors[i]
		var normal := anchor.normalized() if anchor.length_squared() > 0.0001 else Vector3.UP
		var ref := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var tangent_a := normal.cross(ref).normalized()
		var tangent_b := normal.cross(tangent_a).normalized()
		neuron_tangent_a[i] = tangent_a
		neuron_tangent_b[i] = tangent_b
		neuron_phases[i] = rng.randf_range(0.0, TAU)
		neuron_speeds[i] = rng.randf_range(0.4, 1.05)
		neuron_amps[i] = rng.randf_range(0.02, 0.048)
	pass


func update_neuron_motion() -> void:
	for i in neuron_anchors.size():
		var anchor := neuron_anchors[i]
		var phase := neuron_phases[i]
		var speed := neuron_speeds[i]
		var amp := neuron_amps[i]
		var t := motion_time * speed + phase
		var offset := neuron_tangent_a[i] * (sin(t) * amp)
		offset += neuron_tangent_b[i] * (cos(t * 0.71) * amp * 0.88)
		offset += neuron_tangent_a[i].cross(neuron_tangent_b[i]).normalized() * (sin(t * 1.37 + phase) * amp * 0.35)
		neuron_positions[i] = anchor + offset
	pass


func neuron_instance_transform(index: int) -> Transform3D:
	var scale := Vector3.ONE * (0.85 + float(index % 5) * 0.04)
	var basis := Basis.IDENTITY.scaled(scale)
	return Transform3D(basis, neuron_positions[index])


func refresh_multimesh_transforms() -> void:
	if multimesh_instance == null or multimesh_instance.multimesh == null:
		return
	var multi := multimesh_instance.multimesh
	for i in neuron_positions.size():
		multi.set_instance_transform(i, neuron_instance_transform(i))
	pass


func build_filament_arrays() -> Array:
	if synapse_pairs.is_empty():
		return []
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for pair in synapse_pairs:
		append_filament_quad(
			verts,
			uvs,
			normals,
			indices,
			neuron_positions[pair.x],
			neuron_positions[pair.y]
		)
	if verts.is_empty():
		return []
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func refresh_filament_vertices() -> void:
	if filament_mesh == null or filament_surface == null or synapse_pairs.is_empty():
		return
	var arrays := build_filament_arrays()
	if arrays.is_empty():
		return
	filament_surface.clear_surfaces()
	filament_surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	pass


func append_filament_quad(
	verts: PackedVector3Array,
	uvs: PackedVector2Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3
) -> void:
	var ab := b - a
	var length := ab.length()
	if length < 0.0001:
		return
	var dir := ab / length
	var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.92 else Vector3.FORWARD
	var side := dir.cross(ref).normalized()
	var half := side * FILAMENT_HALF_WIDTH
	var base: int = verts.size()
	verts.append(a - half)
	verts.append(a + half)
	verts.append(b + half)
	verts.append(b - half)
	for _i in 4:
		normals.append(side)
	uvs.append(Vector2(0.0, 0.0))
	uvs.append(Vector2(0.0, 1.0))
	uvs.append(Vector2(1.0, 1.0))
	uvs.append(Vector2(1.0, 0.0))
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	pass


func generate_brain_points(count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
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


func build_spatial_grid(cell_size: float) -> Dictionary:
	var grid: Dictionary = {}
	for i in neuron_anchors.size():
		var cell := cell_key(neuron_anchors[i], cell_size)
		if not grid.has(cell):
			grid[cell] = [] as Array[int]
		(grid[cell] as Array[int]).append(i)
	return grid


func cell_key(point: Vector3, cell_size: float) -> Vector3i:
	return Vector3i(
		int(floor(point.x / cell_size)),
		int(floor(point.y / cell_size)),
		int(floor(point.z / cell_size))
	)


func find_neighbors_spatial(index: int, grid: Dictionary) -> Array[int]:
	var origin := neuron_anchors[index]
	var result: Array[int] = []
	var dists: Array[float] = []
	var origin_cell := cell_key(origin, MAX_EDGE_DIST)
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			for oz in range(-1, 2):
				var bucket: Variant = grid.get(origin_cell + Vector3i(ox, oy, oz))
				if bucket == null:
					continue
				for j: int in bucket as Array[int]:
					if j == index:
						continue
					var dist := origin.distance_to(neuron_anchors[j])
					if dist > MAX_EDGE_DIST:
						continue
					var insert_at := result.size()
					for k in result.size():
						if dist < dists[k]:
							insert_at = k
							break
					result.insert(insert_at, j)
					dists.insert(insert_at, dist)
					if result.size() > NEIGHBORS:
						result.pop_back()
						dists.pop_back()
	return result


func _average_pulse() -> float:
	if pulse_levels.is_empty():
		return 0.0
	return pulse_sum / float(pulse_levels.size())
