class_name BootstrapMountainMeshFactory
extends RefCounted

const WIDTH := 170.0
const DEPTH := 110.0
const X_SEGMENTS := 48
const Z_SEGMENTS := 32


static func build() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for z_index in range(Z_SEGMENTS + 1):
		var z_ratio := float(z_index) / float(Z_SEGMENTS)
		var local_z := lerpf(-DEPTH * 0.5, DEPTH * 0.5, z_ratio)
		for x_index in range(X_SEGMENTS + 1):
			var x_ratio := float(x_index) / float(X_SEGMENTS)
			var local_x := lerpf(-WIDTH * 0.5, WIDTH * 0.5, x_ratio)
			vertices.append(Vector3(local_x, _height(local_x, local_z), local_z))
			normals.append(_normal(local_x, local_z))
			uvs.append(Vector2(x_ratio, z_ratio))

	for z_index in range(Z_SEGMENTS):
		for x_index in range(X_SEGMENTS):
			var row_width := X_SEGMENTS + 1
			var top_left := z_index * row_width + x_index
			var top_right := top_left + 1
			var bottom_left := top_left + row_width
			var bottom_right := bottom_left + 1
			indices.append_array(PackedInt32Array([
				top_left, bottom_left, top_right,
				top_right, bottom_left, bottom_right,
			]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _height(x: float, z: float) -> float:
	var broad_peak := 66.0 * exp(
		-pow((x + 12.0) / 51.0, 2.0) - pow((z + 8.0) / 50.0, 2.0)
	)
	var right_ridge := 34.0 * exp(
		-pow((x - 43.0) / 27.0, 2.0) - pow((z - 5.0) / 45.0, 2.0)
	)
	var left_ridge := 25.0 * exp(
		-pow((x + 59.0) / 22.0, 2.0) - pow((z - 2.0) / 39.0, 2.0)
	)
	var central_valley := 17.0 * exp(
		-pow((x - 14.0) / 18.0, 2.0) - pow((z - 3.0) / 44.0, 2.0)
	)
	var facets := 1.5 * sin(x * 0.14) + 1.1 * cos((x + z) * 0.11)
	var x_falloff := clampf(1.0 - pow(absf(x) / (WIDTH * 0.54), 3.0), 0.0, 1.0)
	var z_falloff := clampf(1.0 - pow(absf(z) / (DEPTH * 0.5), 2.0), 0.0, 1.0)
	return maxf(
		0.0,
		(broad_peak + right_ridge + left_ridge - central_valley + facets) * x_falloff * z_falloff
	)


static func _normal(x: float, z: float) -> Vector3:
	const SAMPLE_OFFSET := 0.5
	var x_delta := _height(x - SAMPLE_OFFSET, z) - _height(x + SAMPLE_OFFSET, z)
	var z_delta := _height(x, z - SAMPLE_OFFSET) - _height(x, z + SAMPLE_OFFSET)
	return Vector3(x_delta, SAMPLE_OFFSET * 2.0, z_delta).normalized()
