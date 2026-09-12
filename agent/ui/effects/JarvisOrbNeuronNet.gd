class_name JarvisOrbNeuronNet
extends Node3D

## Brain-shaped neuron point cloud + synapse filaments — grows incrementally with stream volume.

const NEIGHBORS := 3
const MAX_EDGE_DIST := 0.62
const FILAMENT_SAMPLE_STRIDE := 2
const FILAMENT_WIDTH := 0.016

var neuron_rest_positions: PackedVector3Array = PackedVector3Array()
var neuron_positions: PackedVector3Array = PackedVector3Array()
var motion_phase: PackedFloat32Array = PackedFloat32Array()
var motion_speed: PackedFloat32Array = PackedFloat32Array()
var motion_amount: PackedFloat32Array = PackedFloat32Array()
var motion_axis_a: PackedVector3Array = PackedVector3Array()
var motion_axis_b: PackedVector3Array = PackedVector3Array()
var wobble_phase: PackedFloat32Array = PackedFloat32Array()
var wobble_speed: PackedFloat32Array = PackedFloat32Array()
var base_scales: PackedFloat32Array = PackedFloat32Array()
var filament_edges: Array[Vector2i] = []
var motion_time: float = 0.0
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

	motion_time += delta
	rotation.y = sin(motion_time * 0.19) * 0.07
	rotation.x = cos(motion_time * 0.23) * 0.045
	update_neuron_motion()
	update_filament_mesh()

	if neuron_shader != null:
		var avg_pulse: float = 0.65 + _average_pulse() * 0.55
		neuron_shader.set_shader_parameter("pulse", avg_pulse)
	if filament_shader != null:
		filament_shader.set_shader_parameter("pulse", 0.55 + _average_pulse() * 0.45)
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


func apply_display_color(neuron_color: Color, filament_color: Color) -> void:
	var render := OrbTheme.render_settings()
	if neuron_shader != null:
		neuron_shader.set_shader_parameter("base_color", neuron_color)
		neuron_shader.set_shader_parameter("emission_scale", render.neuron_emission_scale)
	if filament_shader != null:
		filament_shader.set_shader_parameter("line_color", filament_color)
		filament_shader.set_shader_parameter("emission_scale", render.filament_emission_scale)
	pass


func rebuild_neurons(count: int) -> void:
	clear_meshes()
	current_neuron_count = count
	neuron_rest_positions = generate_brain_points(count)
	neuron_positions = neuron_rest_positions.duplicate()
	init_motion_params(current_neuron_count)
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
	for point in new_points:
		neuron_rest_positions.append(point)
		neuron_positions.append(point)
	current_neuron_count = neuron_rest_positions.size()
	init_motion_params(current_neuron_count, current_neuron_count - add_count)
	pulse_levels.resize(current_neuron_count)
	for i in range(current_neuron_count - add_count, current_neuron_count):
		pulse_levels[i] = 0.0
	rebuild_multimesh()
	if rebuild_cooldown <= 0.0:
		build_filaments()
		filament_dirty = false
	else:
		filament_dirty = true
	pass


func clear_meshes() -> void:
	filament_edges.clear()
	if multimesh_instance != null:
		multimesh_instance.queue_free()
		multimesh_instance = null
	if filament_mesh != null:
		filament_mesh.queue_free()
		filament_mesh = null
	pass


func rebuild_multimesh() -> void:
	if neuron_shader == null:
		neuron_shader = ShaderMaterial.new()
		neuron_shader.shader = load("res://agent/ui/effects/shaders/jarvis_neuron.gdshader") as Shader
	neuron_shader.set_shader_parameter("base_color", Color(0.0, 0.9, 1.0, 0.85))

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = false
	multi.use_custom_data = true
	multi.mesh = sphere_mesh
	multi.instance_count = neuron_rest_positions.size()

	if multimesh_instance == null:
		multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.material_override = neuron_shader
		add_child(multimesh_instance)
	multimesh_instance.multimesh = multi
	update_neuron_motion()
	pass


func init_motion_params(count: int, start_index: int = 0) -> void:
	motion_phase.resize(count)
	motion_speed.resize(count)
	motion_amount.resize(count)
	motion_axis_a.resize(count)
	motion_axis_b.resize(count)
	wobble_phase.resize(count)
	wobble_speed.resize(count)
	base_scales.resize(count)
	for i in range(start_index, count):
		motion_phase[i] = rng.randf() * TAU
		motion_speed[i] = rng.randf_range(0.26, 1.08)
		motion_amount[i] = rng.randf_range(0.016, 0.074)
		motion_axis_a[i] = random_unit_vector()
		motion_axis_b[i] = random_unit_vector()
		wobble_phase[i] = rng.randf() * TAU
		wobble_speed[i] = rng.randf_range(0.48, 1.72)
		base_scales[i] = rng.randf_range(0.8, 1.02)
	pass


func random_unit_vector() -> Vector3:
	var theta := rng.randf() * TAU
	var phi := acos(rng.randf_range(-1.0, 1.0))
	return Vector3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi)).normalized()


func update_neuron_motion() -> void:
	if multimesh_instance == null or multimesh_instance.multimesh == null:
		return
	if neuron_rest_positions.is_empty():
		return
	var multi := multimesh_instance.multimesh
	var count := neuron_rest_positions.size()
	if neuron_positions.size() != count:
		neuron_positions = neuron_rest_positions.duplicate()
	for i in range(count):
		var t: float = motion_time * motion_speed[i] + motion_phase[i]
		var wt: float = motion_time * wobble_speed[i] + wobble_phase[i]
		var offset := motion_axis_a[i] * sin(t) * motion_amount[i]
		offset += motion_axis_b[i] * cos(wt) * motion_amount[i] * 0.44
		var swirl_axis := motion_axis_a[i].cross(motion_axis_b[i])
		if swirl_axis.length_squared() > 0.0001:
			offset += swirl_axis.normalized() * sin(t * 0.53 + wt * 0.71) * motion_amount[i] * 0.3
		neuron_positions[i] = neuron_rest_positions[i] + offset
		var breathe: float = 1.0 + sin(t * 1.12) * 0.065
		var pulse_scale: float = 1.0 + pulse_levels[i] * 0.24
		var scale: float = base_scales[i] * breathe * pulse_scale
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), neuron_positions[i]))
		multi.set_instance_custom_data(
			i,
			Color(motion_phase[i] / TAU, motion_speed[i] / 1.5, pulse_levels[i], motion_amount[i] / 0.08),
		)
	pass


func build_neurons() -> void:
	rebuild_multimesh()
	pass


func build_filaments() -> void:
	filament_edges.clear()
	var grid := build_spatial_grid(MAX_EDGE_DIST)
	var stride := 1 if neuron_rest_positions.size() <= 650 else FILAMENT_SAMPLE_STRIDE
	for i in range(0, neuron_rest_positions.size(), stride):
		var neighbors := find_neighbors_spatial(i, grid)
		for neighbor_index in neighbors:
			if neighbor_index <= i:
				continue
			filament_edges.append(Vector2i(i, neighbor_index))

	if filament_shader == null:
		filament_shader = ShaderMaterial.new()
		filament_shader.shader = load("res://agent/ui/effects/shaders/jarvis_filament.gdshader") as Shader
		filament_shader.render_priority = 1
	filament_shader.set_shader_parameter("line_color", Color(0.82, 0.38, 1.0, 0.55))

	if filament_mesh == null:
		filament_mesh = MeshInstance3D.new()
		filament_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		filament_mesh.material_override = filament_shader
		add_child(filament_mesh)
	update_filament_mesh()
	pass


func update_filament_mesh() -> void:
	if filament_mesh == null or filament_edges.is_empty():
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for edge: Vector2i in filament_edges:
		if edge.x >= neuron_positions.size() or edge.y >= neuron_positions.size():
			continue
		append_filament_segment(verts, uvs, indices, neuron_positions[edge.x], neuron_positions[edge.y])
	if verts.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := filament_mesh.mesh as ArrayMesh
	if mesh == null:
		mesh = ArrayMesh.new()
		filament_mesh.mesh = mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	pass


func append_filament_segment(
	verts: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
) -> void:
	var dir := b - a
	var length_sq := dir.length_squared()
	if length_sq < 0.000001:
		return
	var tangent := dir / sqrt(length_sq)
	var side := tangent.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = tangent.cross(Vector3.FORWARD)
	side = side.normalized() * FILAMENT_WIDTH * 0.5
	var base: int = verts.size()
	verts.append(a - side)
	verts.append(a + side)
	verts.append(b + side)
	verts.append(b - side)
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
	for i in neuron_rest_positions.size():
		var cell := cell_key(neuron_rest_positions[i], cell_size)
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
	var origin := neuron_rest_positions[index]
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
					var dist := origin.distance_to(neuron_rest_positions[j])
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
