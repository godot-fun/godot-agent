class_name ChatMessage
extends RefCounted

const ROLE_SYSTEM := "system"
const ROLE_USER := "user"
const ROLE_ASSISTANT := "assistant"
const ROLE_TOOL := "tool"

var role: String = ""
var content: String = ""
var tool_call_id: String = ""
var tool_calls: Array[OpenAiToolCall] = []


func _init(_role: String = "", _content: String = "") -> void:
	role = _role
	content = _content
	pass


static func system(text: String) -> ChatMessage:
	return ChatMessage.new(ROLE_SYSTEM, text)


static func user(text: String) -> ChatMessage:
	return ChatMessage.new(ROLE_USER, text)


static func assistant(text: String) -> ChatMessage:
	return ChatMessage.new(ROLE_ASSISTANT, text)


static func tool_result(call_id: String, text: String) -> ChatMessage:
	var msg := ChatMessage.new(ROLE_TOOL, text)
	msg.tool_call_id = call_id
	return msg


static func assistant_tool_calls(calls: Array[OpenAiToolCall], text: String = "") -> ChatMessage:
	var msg := ChatMessage.new(ROLE_ASSISTANT, text)
	msg.tool_calls = calls
	return msg


## OpenAI wire shape
func to_api_dict() -> Dictionary:
	if role == ROLE_TOOL:
		return {
			"role": role,
			"content": content,
			"tool_call_id": tool_call_id,
		}
	if not tool_calls.is_empty():
		return {
			"role": role,
			"content": content if StringUtils.is_not_blank(content) else null,
			"tool_calls": tool_calls,
		}
	return {
		"role": role,
		"content": content,
	}
