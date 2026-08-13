class_name CannonGolfLongitudinalGenerationContract
extends StageGenerationContract

## Cannon Golf-only depth contract. The retained shared contract stays unchanged.

const REQUIRED_LONGITUDINAL_CELL_COUNT := Vector2i(84, 128)
const REQUIRED_LONGITUDINAL_LOCAL_BOUNDS := Rect2(Vector2(-105.0, -160.0), Vector2(210.0, 320.0))
const REQUIRED_LONGITUDINAL_TRIANGLE_COUNT := 21504
const REQUIRED_LONGITUDINAL_STATIONS := 18


func is_valid() -> bool:
	if generation_version != CONTRACT_VERSION or profile_version != CONTRACT_VERSION \
			or layout_version != CONTRACT_VERSION:
		return false
	if cell_count != REQUIRED_LONGITUDINAL_CELL_COUNT \
			or local_bounds != REQUIRED_LONGITUDINAL_LOCAL_BOUNDS \
			or maximum_top_triangle_count != REQUIRED_LONGITUDINAL_TRIANGLE_COUNT \
			or route_station_z.size() != REQUIRED_LONGITUDINAL_STATIONS:
		return false
	if not is_equal_approx(local_bounds.size.x / float(cell_count.x), 2.5) \
			or not is_equal_approx(local_bounds.size.y / float(cell_count.y), 2.5):
		return false
	if not is_equal_approx(route_station_z[0], -140.0) \
			or not is_equal_approx(route_station_z[-1], 140.0):
		return false
	for index in range(route_station_z.size() - 1):
		if not is_finite(route_station_z[index]) or not is_finite(route_station_z[index + 1]) \
				or route_station_z[index + 1] - route_station_z[index] < 8.0:
			return false
	return cell_diagonal == CellDiagonal.P01_TO_P10 and mask_size == REQUIRED_MASK_SIZE \
			and is_equal_approx(maximum_station_x_delta, 18.0) \
			and is_equal_approx(outer_band_width, 12.0) \
			and is_equal_approx(terrace_step, 4.0) \
			and is_equal_approx(terrace_blend, 0.24) \
			and is_equal_approx(bank_blend_distance, 8.0) \
			and is_equal_approx(target_shoulder_distance, 12.0) \
			and is_equal_approx(support_distance, 24.0) \
			and is_equal_approx(noise_frequency, 0.035) and noise_octaves == 2 \
			and is_equal_approx(noise_lacunarity, 2.0) \
			and is_equal_approx(noise_gain, 0.45) and is_equal_approx(noise_amplitude, 0.5)
