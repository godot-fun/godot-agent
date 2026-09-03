func consume_sse_buffer_tools_test() -> void:
	var text_build := StringBuilder.new()
	var tool_calls_acc: Array[OpenAiToolCall] = []
	var remainder := OpenAiClient.consume_sse_buffer_tools(
		"data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n",
		text_build,
		tool_calls_acc
	)
	assert(text_build.build_string() == "Hello")
	assert(remainder == StringUtils.EMPTY)
	pass


func consume_sse_buffer_tools_partial_line_test() -> void:
	var text_build := StringBuilder.new()
	var tool_calls_acc: Array[OpenAiToolCall] = []
	var remainder := OpenAiClient.consume_sse_buffer_tools(
		"data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}",
		text_build,
		tool_calls_acc
	)
	assert(text_build.is_empty())
	assert(remainder.begins_with("data:"))
	var remainder2 := OpenAiClient.consume_sse_buffer_tools(remainder + "\n", text_build, tool_calls_acc)
	assert(text_build.build_string() == "Hi")
	assert(remainder2 == StringUtils.EMPTY)
	pass


func consume_sse_buffer_tools_on_delta_test() -> void:
	var text_build := StringBuilder.new()
	var tool_calls_acc: Array[OpenAiToolCall] = []
	var deltas := StringBuilder.new()
	var on_delta := func(delta: String, stream_kind: String) -> void:
		deltas.append_if_not_empty(delta)
		pass
	OpenAiClient.consume_sse_buffer_tools(
		"data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n",
		text_build,
		tool_calls_acc,
		on_delta
	)
	assert(text_build.build_string() == "Hello")
	assert(deltas.build_string() == "Hello")
	pass


func consume_sse_buffer_tools_reasoning_on_delta_test() -> void:
	var text_build := StringBuilder.new()
	var tool_calls_acc: Array[OpenAiToolCall] = []
	var kinds: Array[String] = []
	var on_delta := func(delta: String, stream_kind: String) -> void:
		kinds.append(stream_kind)
		pass
	OpenAiClient.consume_sse_buffer_tools(
		"data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"think\"}}]}\n"
		+ "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n",
		text_build,
		tool_calls_acc,
		on_delta
	)
	assert(text_build.build_string() == "OK")
	assert(kinds.size() == 2)
	assert(kinds[0] == OpenAiClient.STREAM_KIND_REASONING)
	assert(kinds[1] == OpenAiClient.STREAM_KIND_CONTENT)
	pass


func extract_finish_reason_test() -> void:
	var body := "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\ndata: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n"
	assert(OpenAiClient.extract_finish_reason(body) == "stop")
	pass


func extract_stream_delta_test() -> void:
	var delta := OpenAiClient.extract_stream_delta("{\"choices\":[{\"delta\":{\"role\":\"assistant\",\"content\":\"OK\"}}]}")
	assert(delta == "OK")
	pass


func extract_stream_delta_reasoning_test() -> void:
	var delta := OpenAiClient.extract_stream_delta("{\"choices\":[{\"delta\":{\"role\":\"assistant\",\"content\":null,\"reasoning_content\":\"think\"}}]}")
	assert(delta == "think")
	pass


func extract_stream_delta_whitespace_test() -> void:
	var delta := OpenAiClient.extract_stream_delta("{\"choices\":[{\"delta\":{\"content\":\" \"}}]}")
	assert(delta == " ")
	pass


func extract_stream_delta_null_content_test() -> void:
	var delta := OpenAiClient.extract_stream_delta("{\"choices\":[{\"delta\":{\"role\":\"assistant\",\"content\":null}}]}")
	assert(delta == StringUtils.EMPTY)
	pass


func consume_sse_buffer_tools_multichunk_test() -> void:
	var pending_build := StringBuilder.new()
	var text_build := StringBuilder.new()
	var tool_calls_acc: Array[OpenAiToolCall] = []
	var append_chunk := func(chunk_text: String) -> void:
		var buffer := pending_build.build_string() + chunk_text
		pending_build.clear()
		var remaining := OpenAiClient.consume_sse_buffer_tools(buffer, text_build, tool_calls_acc)
		if StringUtils.is_not_empty(remaining):
			pending_build.append_if_not_empty(remaining)
		pass
	append_chunk.call("data: {\"choices\":[{\"delta\":{\"content\":\"Hel")
	append_chunk.call("lo\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"!\"}}]}\n")
	assert(text_build.build_string() == "Hello!")
	pass


func consume_sse_buffer_tools_tool_calls_test() -> void:
	var text_build := StringBuilder.new()
	var tool_calls_acc: Array[OpenAiToolCall] = []
	OpenAiClient.consume_sse_buffer_tools(
		"data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"type\":\"function\",\"function\":{\"name\":\"read\",\"arguments\":\"\"}}]}}]}\n"
		+ "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"path\\\":\\\"a.txt\\\"}\"}}]}}]}\n",
		text_build,
		tool_calls_acc
	)
	assert(text_build.is_empty())
	assert(tool_calls_acc.size() == 1)
	assert(tool_calls_acc[0].id == "call_1")
	assert(tool_calls_acc[0].function.name == "read")
	assert(tool_calls_acc[0].function.arguments == "{\"path\":\"a.txt\"}")
	pass


func build_request_json_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hello"))
	var request := OpenAiRequest.new("test-model", messages, true)
	request.max_tokens = 8192
	var tool := OpenAiToolDef.new()
	tool.function.name = "read"
	tool.function.description = "Read a file"
	tool.function.parameters.string_prop("path", "File path", true)
	request.tools.append(tool)
	var json := OpenAiClient.build_request_json(request)
	assert(json.contains("\"model\": \"test-model\""))
	assert(json.contains("\"stream\": true"))
	assert(json.contains("\"max_tokens\": 8192"))
	assert(json.contains("\"content\": \"hello\""))
	assert(json.contains("\"name\": \"read\""))
	pass


func build_request_json_escapes_control_characters_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.tool_result("call_1", "ansi" + char(0x1B) + "[0m"))
	var request := OpenAiRequest.new("test-model", messages, true)
	var json := OpenAiClient.build_request_json(request)
	assert(JSON.parse_string(json) != null)
	assert(json.contains("\\u001b"))
	assert(not json.contains(char(0x1B)))
	pass
