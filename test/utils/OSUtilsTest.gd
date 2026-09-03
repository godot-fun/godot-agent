static func OSUtils_is_windows_test() -> void:
	assert(OSUtils.is_windows() == (OS.get_name().strip_edges().to_lower() == "windows"))
	pass


static func OSUtils_godot_version_test() -> void:
	assert(StringUtils.is_not_blank(OSUtils.godot_version()))
	pass


static func OSUtils_empty_argv_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(PackedStringArray(), false)
	assert(result.exit_code == -1)
	assert(result.output.is_empty())
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_execute_test() -> void:
	OSUtils.stop_all()
	var result := OSUtils.execute(echo_argv("OSUtilsSyncHello"), false)
	assert(result.exit_code == 0)
	assert(result.output.build_string().contains("OSUtilsSyncHello"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_echo_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(echo_argv("OSUtilsTestHello"), false)
	assert(result.exit_code == 0)
	assert(result.output.build_string().contains("OSUtilsTestHello"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_chinese_async_output_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(chinese_echo_argv(), false)
	assert(result.exit_code == 0)
	var output := result.output.build_string()
	assert(output.contains("OSUtils中文测试"))
	assert(not output.contains("\uFFFD"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_chinese_sync_output_test() -> void:
	OSUtils.stop_all()
	var result := OSUtils.execute(chinese_echo_argv(), false)
	assert(result.exit_code == 0)
	var output := result.output.build_string()
	assert(output.contains("OSUtils中文测试"))
	assert(not output.contains("\uFFFD"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_multiline_output_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(multiline_argv(), false)
	assert(result.exit_code == 0)
	var text := FileUtils.normalize_line_endings_to_lf(result.output.build_string())
	var lines := text.split("\n", false)
	assert(lines.size() >= 3)
	assert(text.contains("OSUtilsLine1"))
	assert(text.contains("OSUtilsLine2"))
	assert(text.contains("OSUtilsLine3"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_command_not_found_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(command_not_found_argv(), false)
	assert(result.exit_code != 0)
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_stop_all_empty_test() -> void:
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_stop_current_test() -> void:
	OSUtils.stop_all()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false))
	await ThreadUtils.async_sleep(800)
	assert(OSUtils.process_pids.size() > 0)
	OSUtils.stop_current()
	await ThreadUtils.async_sleep(1500)
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_concurrent_pid_tracking_test() -> void:
	OSUtils.stop_all()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false))
	await ThreadUtils.async_sleep(800)
	assert(OSUtils.process_pids.size() == 1)
	var result := await OSUtils.async_execute(echo_argv("OSUtilsConcurrentEcho"), false)
	assert(result.exit_code == 0)
	assert(result.output.build_string().contains("OSUtilsConcurrentEcho"))
	assert(OSUtils.process_pids.size() == 1)
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_stop_all_test() -> void:
	OSUtils.stop_all()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false))
	await ThreadUtils.async_sleep(800)
	assert(OSUtils.process_pids.size() > 0)
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	await ThreadUtils.async_sleep(500)
	pass


static func chinese_echo_argv() -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "echo OSUtils中文测试"])
	return PackedStringArray(["sh", "-c", "printf '%s\\n' 'OSUtils中文测试'"])


static func command_not_found_argv() -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "__godot_osutils_missing_executable__"])
	return PackedStringArray(["sh", "-c", "__godot_osutils_missing_executable__"])


static func multiline_argv() -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "echo OSUtilsLine1& echo OSUtilsLine2& echo OSUtilsLine3"])
	return PackedStringArray(["sh", "-c", "echo OSUtilsLine1; echo OSUtilsLine2; echo OSUtilsLine3"])


static func echo_argv(text: String) -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "echo " + text])
	return PackedStringArray(["sh", "-c", "echo " + text])


static func sleep_argv(seconds: int) -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "ping -n " + str(seconds + 1) + " 127.0.0.1 > nul"])
	return PackedStringArray(["sleep", str(seconds)])
