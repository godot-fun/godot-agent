class_name AgentEvents
extends RefCounted

## Pi agent-core event names. Multi-session: agent/turn signals include session_id.

# prompt("...")
# ├─ agent_start              # whole run begins
# │   ├─ turn_start           # one LLM round + tools
# │   │   ├─ message_update   (assistant streaming)
# │   │   ├─ tool_execution_start
# │   │   └─ tool_execution_end
# │   └─ turn_end
# └─ agent_end                # whole run ends


static var events := Events.new()


class Events:
	# Agent lifecycle
	signal agent_start(session_id: int)
	signal agent_end(session_id: int, error_message: String)

	# Turn lifecycle — one LLM call + tool executions
	signal turn_start(session_id: int)
	signal turn_end(session_id: int)

	# Message lifecycle
	signal message_update(session_id: int, chunk: String, stream_kind: String)

	# Tool execution lifecycle
	signal tool_execution_start(session_id: int, tool_call_id: String, tool_name: String, args: Dictionary[String, String])
	signal tool_execution_end(session_id: int, tool_call_id: String, tool_name: String, result: String, is_error: bool)

	# Session management
	signal session_added(session_id: int, title: String)
	signal session_removed(session_id: int)
	signal session_selected(session_id: int)
	signal session_title_changed(session_id: int, title: String)
	signal session_resume(session_id: int)
	signal session_stop(session_id: int)

	# UI configuration
	signal chat_entry_add(session_id: int, entry: ChatEntry)
	signal chat_entry_update(session_id: int, entry: ChatEntry, stream_kind: String)
	## Emitted after ChatBubbleFlusher applies a pending batch (every ~100 ms while streaming).
	signal chat_bubble_flushed
	signal markdown_changed(enabled: bool)
	signal skill_context_changed(session_id: int)
	signal theme_changed(is_dark: bool)
	pass
