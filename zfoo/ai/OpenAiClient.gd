class_name OpenAiClient
extends Object

## Local-dev only. Replace with a backend proxy before shipping.
## Reads from env OPENAI_API_KEY by default; can still override at runtime.
const API_KEY_ENV := "OPENAI_API_KEY"
static var api_key: String = OS.get_environment(API_KEY_ENV)
static var base_url: String = "https://api.deepseek.com/chat/completions"
static var model: String = "deepseek-v4-flash"


static func build_messages(prompt: String, system_prompt: String = "") -> Array[ChatMessage]:
	var messages: Array[ChatMessage] = []
	if StringUtils.is_not_blank(system_prompt):
		messages.append(ChatMessage.new(ChatMessage.ROLE_SYSTEM, system_prompt))
	messages.append(ChatMessage.new(ChatMessage.ROLE_USER, prompt))
	return messages


static func build_headers(stream: bool = false) -> PackedStringArray:
	var headers := PackedStringArray([StringUtils.format("Authorization: Bearer {}", api_key)])
	if stream:
		headers.append("Accept: text/event-stream")
	return headers


static func validate_messages(messages: Array[ChatMessage]) -> bool:
	if StringUtils.is_blank(api_key):
		Log.error("OpenAI api_key is empty, set env {}", API_KEY_ENV)
		return false
	if messages.is_empty():
		Log.error("OpenAI messages is empty")
		return false
	return true


static func build_request_json(request: OpenAiRequest) -> String:
	return request.to_json()


# ----------------------------------------------------------------------------------------------------------------------
static func async_chat(prompt: String, system_prompt: String = "") -> String:
	return await async_chat_messages(build_messages(prompt, system_prompt))

static func async_chat_messages(messages: Array[ChatMessage]) -> String:
	if not validate_messages(messages):
		return StringUtils.EMPTY
	var request := OpenAiRequest.new(model, messages, false)
	var response := await HttpHelper.async_post(base_url, build_request_json(request), build_headers())
	var body := response.get_body_string()
	Log.info("OpenAI response body:[{}]", StringUtils.truncate(body, 512))
	if not response.success or response.code != 200:
		Log.error("OpenAI request failed code:[{}] body:[{}]", response.code, StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var chat_response: OpenAiResponse = JsonUtils.json_to_object(body, OpenAiResponse)
	if chat_response == null or chat_response.choices.is_empty():
		Log.error("OpenAI response parse failed body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var message := chat_response.choices[0].message
	if message == null or StringUtils.is_blank(message.content):
		Log.error("OpenAI response missing content body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	return message.content

# ----------------------------------------------------------------------------------------------------------------------
const REQUEST_TIMEOUT_MILLIS := 5 * TimeUtils.MILLIS_PER_MINUTE
# Example sse request:
# HTTP/1.1 200 OK
# Content-Type: text/event-stream
# Cache-Control: no-cache
# Connection: keep-alive

# Example response:
# data: {"content":"你"}
# data: {"content":"好"}
# data: {"content":"！"}
# data: [DONE]

## Streaming chat completion with optional tools.
## on_delta(delta, stream_kind) — stream_kind is STREAM_KIND_CONTENT or STREAM_KIND_REASONING.
static func async_chat_messages_stream(messages: Array[ChatMessage], tools: Array[OpenAiToolDef] = [], on_delta: Callable = Callable()) -> OpenAiCompletion:
	var result := OpenAiCompletion.new()
	if not validate_messages(messages):
		result.error = "invalid messages"
		return result
	var request := OpenAiRequest.new(model, messages, true)
	request.tools = tools
	request.max_tokens = 8192
	var tool_calls_acc: Array[OpenAiToolCall] = []
	var content_build := StringBuilder.new()
	var pending_build := StringBuilder.new()
	var utf8_decoder := Utf8StreamDecoder.new()
	var on_chunk := func(chunk: PackedByteArray) -> void:
		var buffer := pending_build.build_string() + utf8_decoder.push(chunk)
		pending_build.clear()
		var remaining := consume_sse_buffer_tools(buffer, content_build, tool_calls_acc, on_delta)
		pending_build.append_if_not_empty(remaining)
		pass
	var response := await HttpHelper.async_post(
		base_url, build_request_json(request), build_headers(true), REQUEST_TIMEOUT_MILLIS, "", on_chunk
	)
	if not response.success or response.code != 200:
		Log.error("OpenAI stream failed code:[{}] body:[{}]", response.code, StringUtils.truncate(response.get_body_string(), 512))
		result.error = response.get_body_string()
		return result
	var tail := pending_build.build_string() + utf8_decoder.flush()
	if StringUtils.is_not_empty(tail):
		consume_sse_buffer_tools(tail + "\n", content_build, tool_calls_acc, on_delta)
	result.content = content_build.build_string()
	result.tool_calls = filter_tool_calls(tool_calls_acc)
	result.finish_reason = extract_finish_reason(response.get_body_string())
	return result

static func filter_tool_calls(raw_calls: Variant) -> Array[OpenAiToolCall]:
	var tool_calls: Array[OpenAiToolCall] = []
	for call: OpenAiToolCall in OpenAiToolCall.parse_list(raw_calls):
		if StringUtils.is_not_blank(call.function.name):
			tool_calls.append(call)
	return tool_calls


static func extract_stream_delta(json_line: String) -> String:
	var chunk: OpenAiStreamChunk = JsonUtils.json_to_object(json_line, OpenAiStreamChunk)
	if chunk == null or chunk.choices.is_empty():
		return StringUtils.EMPTY
	return extract_stream_text(chunk.choices[0].delta)


static func extract_stream_text(delta: OpenAiStreamChunk.StreamDelta) -> String:
	if delta == null:
		return StringUtils.EMPTY
	if StringUtils.is_not_empty(delta.content):
		return delta.content
	if StringUtils.is_not_empty(delta.reasoning_content):
		return delta.reasoning_content
	return StringUtils.EMPTY

static func extract_finish_reason(body: String) -> String:
	if StringUtils.is_blank(body):
		return StringUtils.EMPTY
	var finish_reason := StringUtils.EMPTY
	for line: String in body.split("\n", false):
		line = line.strip_edges()
		if line.is_empty() or not line.begins_with("data:"):
			continue
		var payload := StringUtils.substring_after(line, "data:").strip_edges()
		if payload.to_upper() == "[DONE]":
			continue
		var chunk: OpenAiStreamChunk = JsonUtils.json_to_object(payload, OpenAiStreamChunk)
		if chunk == null or chunk.choices.is_empty():
			continue
		if StringUtils.is_not_empty(chunk.choices[0].finish_reason):
			finish_reason = chunk.choices[0].finish_reason
	return finish_reason

# ----------------------------------------------------------------------------------------------------------------------
const STREAM_KIND_CONTENT := "content"
const STREAM_KIND_REASONING := "reasoning"

static func consume_sse_buffer_tools(buffer: String, text_build: StringBuilder, tool_calls_acc: Array[OpenAiToolCall], on_delta: Callable = Callable()) -> String:
	if buffer.is_empty():
		return StringUtils.EMPTY
	var lines: PackedStringArray = buffer.split("\n", false)
	var remaining := StringUtils.EMPTY
	if not buffer.ends_with("\n"):
		remaining = lines[lines.size() - 1]
		lines = lines.slice(0, lines.size() - 1)
	for line: String in lines:
		line = line.strip_edges()
		if line.is_empty() or not line.begins_with("data:"):
			continue
		var payload := StringUtils.substring_after(line, "data:").strip_edges()
		if payload.to_upper() == "[DONE]":
			continue
		var chunk: OpenAiStreamChunk = JsonUtils.json_to_object(payload, OpenAiStreamChunk)
		if chunk == null or chunk.choices.is_empty():
			continue
		var choice := chunk.choices[0]
		if choice.delta != null:
			if StringUtils.is_not_empty(choice.delta.content):
				text_build.append(choice.delta.content)
				if on_delta.is_valid():
					on_delta.call(choice.delta.content, STREAM_KIND_CONTENT)
			if StringUtils.is_not_empty(choice.delta.reasoning_content):
				if on_delta.is_valid():
					on_delta.call(choice.delta.reasoning_content, STREAM_KIND_REASONING)
			OpenAiToolCall.merge_stream_deltas(tool_calls_acc, choice.delta.tool_calls)
	return remaining
