class_name AgentLoop
extends RefCounted

const MAX_TURNS := 32

## Core agent loop: LLM call → tool execution → repeat until done.
static func run(session: AgentSession) -> void:
	var turn := 0
	AgentEvents.events.agent_start.emit(session.id)
	while turn < MAX_TURNS:
		turn += 1
		var session_index := AgentSessionManager.get_index(session.id)
		if session_index != null and session_index.is_stop_requested():
			AgentEvents.events.agent_end.emit(session.id, "Stop.")
			return
		
		AgentEvents.events.turn_start.emit(session.id)
		var on_chunk := func(chunk: String, stream_kind: String) -> void: AgentEvents.events.message_update.emit(session.id, chunk, stream_kind)
		var completion := await OpenAiClient.async_chat_messages_stream(session.messages, AgentToolRegistry.schemas, on_chunk)
		AgentEvents.events.message_complete.emit(session.id, completion.usage)
		if completion.has_error():
			AgentEvents.events.agent_end.emit(session.id, completion.error)
			return

		var content := completion.content
		var tool_calls := completion.tool_calls

		if tool_calls.is_empty() and StringUtils.is_not_blank(content):
			session.messages.append(ChatMessage.assistant(content))
			AgentEvents.events.agent_end.emit(session.id, StringUtils.EMPTY)
			return

		session.messages.append(ChatMessage.assistant_tool_calls(tool_calls, content))
		for tool_call: OpenAiToolCall in tool_calls:
			session_index = AgentSessionManager.get_index(session.id)
			if session_index != null and session_index.is_stop_requested():
				AgentEvents.events.agent_end.emit(session.id, "Stop...")
				return
			var tool_name := tool_call.function.name
			if tool_name.is_empty():
				continue
			var tool_call_id := tool_call.id if StringUtils.is_not_blank(tool_call.id) else tool_name
			var tool: AgentTool = AgentToolRegistry.tools.get(tool_name)
			if tool == null:
				AgentEvents.events.agent_end.emit(session.id, StringUtils.format("unknown tool '{}'", tool_name))
				return
			var args := tool.parse_args(tool_call.function.arguments)
			AgentEvents.events.tool_execution_start.emit(session.id, tool_call_id, tool_name, args)
			var tool_result := await tool.async_execute(args)
			AgentEvents.events.tool_execution_end.emit(session.id, tool_call_id, tool_name, tool_result)
			session.messages.append(ChatMessage.tool_result(tool_call.id, tool_result))
		AgentEvents.events.turn_end.emit(session.id)
	AgentEvents.events.agent_end.emit(session.id, "max turns exceeded")
	pass