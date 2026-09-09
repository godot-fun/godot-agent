class_name BashTool
extends AgentTool

const NAME := "bash"
const ARG_COMMAND := "command"
const MAX_OUTPUT := 32_000


func _init() -> void:
	name = NAME
	description = "Run a shell command in the project root. Returns stdout/stderr and exit code."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.object().string_prop(ARG_COMMAND, "Shell command to execute", true)


func async_execute(args: Dictionary[String, String]) -> String:
	var argv := build_argv_from_args(args)
	if argv.is_empty():
		return "error: command is required"
	var result := await OSUtils.async_execute(argv, false)
	var build := StringBuilder.new()
	build.append_line(StringUtils.format("exit_code: {}", result.exit_code))
	build.append(StringUtils.truncate(result.output.build_string(), MAX_OUTPUT))
	return build.build_string()
# AgentTool-Interface-Implement-End

func build_argv_from_args(args: Dictionary[String, String]) -> PackedStringArray:
	var command := str(args.get(ARG_COMMAND, "")).strip_edges()
	if command.is_empty():
		return PackedStringArray()
	return build_argv(wrap_command(command))


static func build_argv(command: String) -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd.exe", "/c", command])
	return PackedStringArray(["/bin/sh", "-c", command])


static func wrap_command(command: String) -> String:
	var workspace_root := AgentWorkspace.get_root()
	if StringUtils.is_blank(workspace_root):
		return command
	if OSUtils.is_windows():
		return StringUtils.format('cd /d "{}" && {}', workspace_root, command)
	return StringUtils.format('cd "{}" && {}', workspace_root, command)
