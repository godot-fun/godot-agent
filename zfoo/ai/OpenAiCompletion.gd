class_name OpenAiCompletion
extends RefCounted

## Result of a chat completion that may include tool calls.

var content: String = ""
var tool_calls: Array[OpenAiToolCall] = []
var finish_reason: String = ""
var error: String = ""


func has_error() -> bool:
	return StringUtils.is_not_blank(error)
