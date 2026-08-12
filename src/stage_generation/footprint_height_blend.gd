class_name FootprintHeightBlend
extends RefCounted

## Builds the shared sample-grid falloff from the generated footprint boundary.
## Side and cannon-facing contours descend into the apron. The rear contour
## stays raised where the mountain physically enters the enclosing backstop.

# The generated footprint reserves a 24 m support band outside each route. Use
# that whole band for the visible non-target taper so the closed mass approaches
# the apron as a broad hillside instead of ending in a near-vertical contour.
const FALLOFF_DISTANCE := 24.0
const UNREACHED := 1_000_000
const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]


static func build(
		cell_count: Vector2i,
		bounds: Rect2,
		footprint: PackedByteArray
) -> PackedFloat32Array:
	assert(cell_count.x > 0 and cell_count.y > 0, "Footprint falloff requires a sample grid.")
	assert(
		footprint.size() == cell_count.x * cell_count.y,
		"Footprint falloff requires one occupancy value per terrain cell."
	)
	var sample_size := cell_count + Vector2i.ONE
	var distances := PackedInt32Array()
	distances.resize(sample_size.x * sample_size.y)
	distances.fill(UNREACHED)
	var queue := PackedInt32Array()
	for sample_z in range(sample_size.y):
		for sample_x in range(sample_size.x):
			if not _is_visible_boundary_sample(
				Vector2i(sample_x, sample_z), cell_count, footprint
			):
				continue
			var index := sample_z * sample_size.x + sample_x
			distances[index] = 0
			queue.append(index)

	var read_index := 0
	while read_index < queue.size():
		var current_index := queue[read_index]
		read_index += 1
		var current := Vector2i(
			current_index % sample_size.x,
			current_index / sample_size.x
		)
		for offset: Vector2i in CARDINAL_OFFSETS:
			var neighbor: Vector2i = current + offset
			if neighbor.x < 0 or neighbor.y < 0 \
					or neighbor.x >= sample_size.x or neighbor.y >= sample_size.y:
				continue
			var neighbor_index: int = neighbor.y * sample_size.x + neighbor.x
			if distances[neighbor_index] <= distances[current_index] + 1:
				continue
			distances[neighbor_index] = distances[current_index] + 1
			queue.append(neighbor_index)

	var cell_size := bounds.size / Vector2(cell_count)
	var distance_per_step := minf(cell_size.x, cell_size.y)
	var blends := PackedFloat32Array()
	blends.resize(distances.size())
	for index in range(distances.size()):
		var normalized := clampf(
			float(distances[index]) * distance_per_step / FALLOFF_DISTANCE,
			0.0,
			1.0
		)
		blends[index] = normalized * normalized * (3.0 - 2.0 * normalized)
	return blends


static func _is_visible_boundary_sample(
		sample: Vector2i,
		cell_count: Vector2i,
		footprint: PackedByteArray
) -> bool:
	if sample.x == 0 or sample.x == cell_count.x or sample.y == cell_count.y:
		return true
	var touches_active := false
	for cell_z in range(sample.y - 1, sample.y + 1):
		for cell_x in range(sample.x - 1, sample.x + 1):
			if cell_x < 0 or cell_z < 0 or cell_x >= cell_count.x or cell_z >= cell_count.y:
				continue
			if footprint[cell_z * cell_count.x + cell_x] == 0:
				return true
			touches_active = true
	return not touches_active
