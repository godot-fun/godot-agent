class_name AgentTool
extends RefCounted

## Base tool definition. Each tool exposes an OpenAI function schema and async_execute().

var name: String = ""
var description: String = ""


func get_schema() -> OpenAiToolDef:
	var def := OpenAiToolDef.new()
	def.function.name = name
	def.function.description = description
	def.function.parameters = get_parameters()
	return def


func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.new()


func async_execute(args: Dictionary[String, String]) -> String:
	return "not implemented"


func parse_args(raw: String) -> Dictionary[String, String]:
	var parsed: Dictionary[String, String] = {}
	if StringUtils.is_blank(raw):
		return parsed
	var data = JSON.parse_string(raw.strip_edges())
	if typeof(data) != TYPE_DICTIONARY:
		return parsed
	var dict: Dictionary = data
	for key: Variant in dict.keys():
		var value: Variant = dict[key]
		parsed[str(key)] = "" if value == null else str(value)
	return parsed
