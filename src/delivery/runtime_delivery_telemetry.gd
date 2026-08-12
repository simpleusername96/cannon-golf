class_name RuntimeDeliveryTelemetry
extends RefCounted

## Local JSON-line markers for delivery captures and explicit profiling runs.
## They never leave the process and stay silent during ordinary play.
static func enabled() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--delivery-telemetry" or argument.begins_with("--capture-screen="):
			return true
	return false


static func emit_marker(marker: StringName, details: Dictionary = {}) -> void:
	if not enabled():
		return
	var payload := {
		"paint_mountain_marker": String(marker),
		"time_usec": Time.get_ticks_usec(),
		"memory_static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"render_video_memory": int(
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}
	payload.merge(details, true)
	print(JSON.stringify(payload))
