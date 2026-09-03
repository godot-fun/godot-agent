class_name OSUtils
extends Object

## Subprocess execution. Sync `execute` uses OS.execute; async `async_execute`
## uses OS.execute_with_pipe on a worker thread. Output chunks append to
## ExecResult.output. Pass `log=false` to silence command/output/result logs.

static var process_pids: RingIntList = RingIntList.new(32)


static func is_windows() -> bool:
	return OS.get_name().strip_edges().to_lower() == "windows"


static func godot_version() -> String:
	var version_info := Engine.get_version_info()
	var version_text := str(version_info.get("string", ""))
	if StringUtils.is_not_blank(version_text):
		return version_text
	return StringUtils.format("{}.{}.{}", version_info.get("major", 0), version_info.get("minor", 0), version_info.get("patch", 0))


class ExecResult:
	var exit_code: int = -1
	var output: StringBuilder = StringBuilder.new()


static func stop_current() -> void:
	var pid := process_pids.latest()
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	pass


static func stop_all() -> void:
	for pid in process_pids.to_array():
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	process_pids.clear()
	pass


static func execute(argv: PackedStringArray, log: bool = true) -> ExecResult:
	var result := ExecResult.new()
	if argv.is_empty():
		return result

	if log:
		Log.info("command:[{}]", format_command_line(argv))

	var lines: Array = []
	result.exit_code = OS.execute(argv[0], argv.slice(1), lines, true)
	var builder := StringBuilder.new()
	for line in lines:
		builder.append(str(line))
	append_output(result, builder.build_joined(StringUtils.LS))
	log_result(argv, result, log)
	return result


static func async_execute(argv: PackedStringArray, log: bool = true) -> ExecResult:
	var result := ExecResult.new()
	if argv.is_empty():
		return result

	if log:
		Log.info("command:[{}]", format_command_line(argv))

	var thread := Thread.new()
	thread.start(_run_process_async.bind(argv, result))
	while thread.is_alive():
		await Engine.get_main_loop().process_frame
	thread.wait_to_finish()
	log_result(argv, result, log)
	return result


static func _run_process_async(argv: PackedStringArray, result: ExecResult) -> void:
	var proc := OS.execute_with_pipe(argv[0], argv.slice(1), false)
	if proc.is_empty():
		result.exit_code = -1
		return

	var pid: int = int(proc.get("pid", -1))
	if pid > 0:
		process_pids.add(pid)
	var stdio: FileAccess = proc.get("stdio")
	var stderr_pipe: FileAccess = proc.get("stderr")

	while pid > 0 and OS.is_process_running(pid):
		drain_pipe(result, stdio)
		drain_pipe(result, stderr_pipe)
		OS.delay_msec(16)

	drain_pipe(result, stdio, true)
	drain_pipe(result, stderr_pipe, true)
	close_pipe(stdio)
	close_pipe(stderr_pipe)

	result.exit_code = OS.get_process_exit_code(pid) if pid > 0 else -1
	if pid > 0:
		process_pids.remove_value(pid)
	pass


static func drain_pipe(result: ExecResult, pipe: FileAccess, final: bool = false) -> void:
	if pipe == null or not pipe.is_open():
		return

	while true:
		var chunk := pipe.get_buffer(4096)
		var err := pipe.get_error()
		if chunk.is_empty():
			if final or err != OK:
				break
			return

		if is_windows():
			append_output(result, chunk.get_string_from_multibyte_char(""))
		else:
			append_output(result, chunk.get_string_from_utf8())
		if err != OK:
			break
	pass


static func append_output(result: ExecResult, text: String) -> void:
	if StringUtils.is_empty(text):
		return
	result.output.append(text)
	pass


static func close_pipe(pipe: FileAccess) -> void:
	if pipe != null and pipe.is_open():
		pipe.close()
	pass


static func format_command_line(argv: PackedStringArray) -> String:
	var builder := StringBuilder.new()
	for arg in argv:
		if arg.is_empty():
			builder.append("\"\"")
		elif arg.find(" ") >= 0 or arg.find("\t") >= 0:
			builder.append(StringUtils.format("\"{}\"", arg.replace("\"", "\\\"")))
		else:
			builder.append(arg)
	return builder.build_joined(StringUtils.SPACE)


static func log_result(argv: PackedStringArray, result: ExecResult, log: bool) -> void:
	if not log or argv.is_empty():
		return
	var output := result.output.build_string()
	if not output.is_empty():
		Log.info("process output:[{}]", output)
	if result.exit_code == 0:
		Log.info("process finished exit:[{}]", result.exit_code)
		return
	Log.error("process failed exit:[{}] command:[{}]", result.exit_code, format_command_line(argv))
	if result.exit_code < 0:
		Log.error("failed to start process; check runtime exists:[{}]", argv[0])
		return
	if output.is_empty():
		Log.error("no process output")
	pass
