class_name AgentSessionManager
extends RefCounted

## Manages multiple agent sessions and the active selection.

const INVALID_SESSION_ID := -1
const NEXT_SESSION_ID_KEY := "agent_next_session_id"

static var sessions: Dictionary[int, AgentSession] = {}
static var active_session_id: int = INVALID_SESSION_ID


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

static func _static_init() -> void:
	AgentEvents.events.session_title_changed.connect(on_persist_session)
	AgentEvents.events.agent_end.connect(on_agent_end)
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	AgentEvents.events.session_resume.connect(on_session_resume)
	AgentEvents.events.message_update.connect(on_message_update)
	pass


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

static func load_from_disk() -> void:
	sessions.clear()
	active_session_id = INVALID_SESSION_ID

	var all_sessions := AgentSessionStore.load_all_sessions()
	for session: AgentSession in all_sessions:
		register_session(session, false)
	select_first_or_create()
	pass


static func persist_session(session_id: int) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	AgentSessionStore.save_session(session)
	pass


static func on_persist_session(session_id: int, _arg: Variant = null) -> void:
	persist_session(session_id)
	pass


static func on_agent_end(session_id: int, error_message: String) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	if StringUtils.is_not_blank(error_message):
		session.add_chat_entry(ChatEntry.KIND_ERROR, ChatEntry.TITLE_ERROR, error_message)
	persist_session(session_id)
	
	session.stop_running()
	AgentEvents.events.session_stop.emit(session_id)
	pass


# ---------------------------------------------------------------------------
# Agent lifecycle
# ---------------------------------------------------------------------------

static func on_turn_start(session_id: int) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	session.clear_run_state()
	pass

static func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	var entry := session.append_chat_entry_stream(stream_kind, chunk)
	AgentEvents.events.chat_entry_update.emit(session_id, entry, stream_kind)
	pass

static func on_tool_execution_start(session_id: int, _tool_call_id: String, tool_name: String, args: Dictionary[String, String]) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	session.add_chat_entry(ChatEntry.KIND_TOOL, tool_name, format_tool_body(tool_name, args))
	pass


static func on_tool_execution_end(session_id: int, _tool_call_id: String, tool_name: String, result: String) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	var preview := result
	if preview.length() > 600:
		preview = preview.substr(0, 600) + "\n…"
	session.add_chat_entry(ChatEntry.KIND_RESULT, ChatEntry.TITLE_RESULT, StringUtils.format("{}:\n{}", tool_name, preview))
	pass


static func format_tool_body(tool_name: String, args: Dictionary[String, String]) -> String:
	match tool_name:
		ReadTool.NAME, WriteTool.NAME, EditTool.NAME:
			return str(args.get(ReadTool.ARG_PATH, ""))
		BashTool.NAME:
			return str(args.get(BashTool.ARG_COMMAND, ""))
		WebSearchTool.NAME:
			return str(args.get(WebSearchTool.ARG_QUERY, ""))
		_:
			for key: Variant in args.keys():
				var value := str(args[key])
				if StringUtils.is_not_blank(value):
					return value
			return ""


# ---------------------------------------------------------------------------
# Send / stop
# ---------------------------------------------------------------------------

static func send_message(session_id: int, text: String) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	await session.async_send(text)
	pass


static func request_stop(session_id: int) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	session.request_stop()
	pass


static func on_session_resume(session_id: int) -> void:
	var session := get_session(session_id)
	if session == null or session.is_running():
		return
	await session.async_resume()
	pass


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

static func create_session() -> AgentSession:
	var session_id := next_session_id()
	var session := AgentSession.new(session_id, StringUtils.format("New Chat {}", session_id))
	register_session(session, true)
	if active_session_id == INVALID_SESSION_ID:
		select_session(session.id)
	return session


static func register_session(session: AgentSession, emit_added: bool) -> void:
	sessions[session.id] = session
	if emit_added:
		AgentEvents.events.session_added.emit(session.id, session.title)
		persist_session(session.id)
	pass


static func delete_session(session_id: int) -> void:
	if not sessions.has(session_id):
		return
	var session: AgentSession = sessions[session_id]
	if session.is_running():
		session.request_stop()

	sessions.erase(session_id)
	AgentSessionStore.delete_session_file(session_id)
	AgentEvents.events.session_removed.emit(session_id)

	if active_session_id == session_id:
		active_session_id = INVALID_SESSION_ID
		select_first_or_create()
	pass


static func next_session_id() -> int:
	var session_id := Setting.get_int(NEXT_SESSION_ID_KEY, 0)
	Setting.set_int(NEXT_SESSION_ID_KEY, session_id + 1)
	Setting.save()
	return session_id


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

static func get_session(session_id: int) -> AgentSession:
	return sessions.get(session_id)


static func get_active() -> AgentSession:
	return get_session(active_session_id)


static func is_active(session_id: int) -> bool:
	return active_session_id == session_id


static func is_running(session_id: int) -> bool:
	var session := get_session(session_id)
	return session != null and session.is_running()


static func get_session_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(sessions.keys())
	ids.sort()
	ids.reverse()
	return ids


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

static func select_session(session_id: int) -> void:
	if not sessions.has(session_id):
		return
	active_session_id = session_id
	AgentEvents.events.session_selected.emit(session_id)


static func select_first_or_create() -> void:
	var session_ids := get_session_ids()
	if session_ids.is_empty():
		create_session()
	else:
		select_session(session_ids[0])
	pass
