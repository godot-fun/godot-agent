class_name TokenHelper
extends RefCounted

## Heuristic token estimate for [ChatMessage] history.
##
## Not a tokenizer — use for context-window budgeting and session stats only.
## Latin text ≈ 4 chars/token; non-ASCII (e.g. CJK) ≈ 1 char/token; each message
## adds a small role/format overhead ([constant MESSAGE_OVERHEAD]).
##
## ```gdscript
## var tokens := TokenHelper.count(session.messages)
## var one := TokenHelper.estimate_message(ChatMessage.user("hello"))
## ```

## Per-message JSON/role overhead (OpenAI-style wire shape).
const MESSAGE_OVERHEAD := 4
## Average Latin characters per token for the heuristic.
const ASCII_CHARS_PER_TOKEN := 4.0


## Total estimated tokens for a full conversation history.
static func count(messages: Array[ChatMessage]) -> int:
	var total := 0
	for message: ChatMessage in messages:
		total += estimate_message(message)
	return total


## Estimate tokens for plain text (content, tool args, ids, …).
static func estimate_text(text: String) -> int:
	if StringUtils.is_blank(text):
		return 0
	var ascii_chars := 0
	var non_ascii_tokens := 0
	for i in text.length():
		var code := text.unicode_at(i)
		if code <= 0x7F:
			ascii_chars += 1
		else:
			non_ascii_tokens += 1
	return non_ascii_tokens + maxi(0, ceili(float(ascii_chars) / ASCII_CHARS_PER_TOKEN))


## Estimate tokens for one message, including [member ChatMessage.tool_calls] and [member ChatMessage.tool_call_id].
static func estimate_message(message: ChatMessage) -> int:
	if message == null:
		return 0
	var tokens := MESSAGE_OVERHEAD
	tokens += estimate_text(message.content)
	if StringUtils.is_not_blank(message.tool_call_id):
		tokens += estimate_text(message.tool_call_id)
	for tool_call: OpenAiToolCall in message.tool_calls:
		tokens += estimate_text(tool_call.id)
		tokens += estimate_text(tool_call.function.name)
		tokens += estimate_text(tool_call.function.arguments)
	return tokens
