class_name ReadTool
extends AgentTool

const NAME := "read"
const ARG_PATH := "path"


func _init() -> void:
	name = NAME
	description = "Read a text file from the project workspace. Returns file contents or an error."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.object().string_prop(ARG_PATH, "Absolute or project-relative file path", true)


func async_execute(args: Dictionary[String, String]) -> String:
	var path := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if StringUtils.is_blank(path):
		return "error: path is required"
	if not FileAccess.file_exists(path):
		return StringUtils.format("error: file not found: {}", path)
	var content := FileUtils.read_file_to_string(path)
	if content.length() > 100_000:
		return content.substr(0, 100_000) + "\n... (truncated)"
	return content
# AgentTool-Interface-Implement-End
