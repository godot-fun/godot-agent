class_name AgentSessionManager
extends RefCounted

## Manages multiple agent sessions and the active selection.

const INVALID_SESSION_ID := -1
## Sidebar title cap for the first user prompt.
const TITLE_MAX := 32

static var session_indexes := AgentSessionIndexes.new()
static var active_session_id: int = INVALID_SESSION_ID


# ---------------------------------------------------------------------------
# Init — event wiring
# ---------------------------------------------------------------------------

static func _static_init() -> void:
	# Session persistence — auto-save when title changes
	AgentEvents.events.session_title_changed.connect(on_persist_session)

	# Agent run lifecycle
	AgentEvents.events.agent_end.connect(on_agent_end)
	AgentEvents.events.session_resume.connect(on_session_resume)

	# Turn & streaming
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.message_update.connect(on_message_update)

	# Tool execution
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	pass


# ---------------------------------------------------------------------------
# Persistence — load / save
# ---------------------------------------------------------------------------

## Boot: reload the index, then select the first session (create one if the list is empty).
static func load_from_disk() -> void:
	active_session_id = INVALID_SESSION_ID
	session_indexes = AgentSessionIndexes.load_index()
	select_session()
	pass


static func persist_session(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	if session.messages.is_empty():
		return
	update_index_title(session_id, session.title)
	AgentSessionStore.save_session(session_id)
	AgentSessionIndexes.save_index(session_indexes)
	pass

static func on_persist_session(session_id: int, _arg: Variant = null) -> void:
	persist_session(session_id)
	pass


# ---------------------------------------------------------------------------
# Session registry — create, delete
# ---------------------------------------------------------------------------

## New session is prepended to the index. Selects it only when nothing is active.
static func create_session() -> AgentSession:
	var session := AgentSessionStore.create_session()
	add_index(session)
	setup_new_chat(session.id)
	AgentEvents.events.session_added.emit(session.id, session.title)
	persist_session(session.id)
	if active_session_id == INVALID_SESSION_ID:
		select_session(session.id)
	return session


## Deleting the active session clears the selection, then falls back via select_session().
static func delete_session(session_id: int) -> void:
	if not has_index(session_id):
		return
	var session_index := get_index(session_id)
	if session_index != null and session_index.is_running():
		request_stop(session_id)

	AgentSessionStore.delete_session(session_id)
	remove_index(session_id)
	AgentSessionIndexes.save_index(session_indexes)
	AgentEvents.events.session_removed.emit(session_id)

	if active_session_id == session_id:
		active_session_id = INVALID_SESSION_ID
		select_session()
	pass


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## Omit session_id (or pass INVALID) to pick indexes[0], or create a session when the list is empty.
static func select_session(session_id: int = INVALID_SESSION_ID) -> void:
	if session_id == INVALID_SESSION_ID:
		if session_indexes.indexes.is_empty():
			create_session()
			return
		session_id = session_indexes.indexes[0].id
	if not has_index(session_id):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		session = AgentSession.new(session_id, get_title(session_id))
		AgentSessionStore.sessions[session_id] = session
	active_session_id = session_id
	AgentEvents.events.session_selected.emit(session_id)


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

static func get_index(session_id: int) -> AgentSessionIndexes.SessionIndex:
	for session_index: AgentSessionIndexes.SessionIndex in session_indexes.indexes:
		if session_index.id == session_id:
			return session_index
	return null


static func has_index(session_id: int) -> bool:
	return get_index(session_id) != null


static func get_title(session_id: int) -> String:
	var session_index := get_index(session_id)
	if session_index == null:
		return ""
	return session_index.title


static func add_index(session: AgentSession) -> void:
	var session_index := AgentSessionIndexes.SessionIndex.new()
	session_index.id = session.id
	session_index.title = session.title
	session_indexes.indexes.insert(0, session_index)
	pass


static func remove_index(session_id: int) -> void:
	for i in session_indexes.indexes.size():
		if session_indexes.indexes[i].id == session_id:
			session_indexes.indexes.remove_at(i)
			return
	pass


static func move_index(session_id: int, to_index: int) -> void:
	for i in session_indexes.indexes.size():
		if session_indexes.indexes[i].id != session_id:
			continue
		var session_index := session_indexes.indexes[i]
		session_indexes.indexes.remove_at(i)
		session_indexes.indexes.insert(clampi(to_index, 0, session_indexes.indexes.size()), session_index)
		AgentSessionIndexes.save_index(session_indexes)
		return
	pass


static func update_index_title(session_id: int, title: String) -> void:
	var session_index := get_index(session_id)
	if session_index == null:
		return
	session_index.title = title
	pass


static func is_active(session_id: int) -> bool:
	return active_session_id == session_id


static func is_running(session_id: int) -> bool:
	var session_index := get_index(session_id)
	return session_index != null and session_index.is_running()

# ---------------------------------------------------------------------------
# Session setup
# ---------------------------------------------------------------------------

static func setup_new_chat(session_id: int) -> void:
	var system_text := SystemPrompt.build()
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	session.messages.append(ChatMessage.system(system_text))
	add_chat_entry(session_id, ChatEntry.KIND_SYSTEM, ChatEntry.TITLE_SYSTEM, system_text)
	if SkillBubble.is_enabled():
		append_skill_context(session_id, session)
	pass


static func append_skill_context(session_id: int, session: AgentSession) -> void:
	var readme_text := SkillBubble.load_readme_text()
	if StringUtils.is_blank(readme_text):
		return
	var skill_message := SkillBubble.build_llm_message(readme_text)
	session.messages.append(ChatMessage.system(skill_message))
	add_chat_entry(session_id, ChatEntry.KIND_SKILL, ChatEntry.TITLE_SKILL, readme_text)
	pass


static func has_chat_history(session_id: int) -> bool:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return false
	for entry in session.chat_entries:
		if entry.kind != ChatEntry.KIND_SYSTEM and entry.kind != ChatEntry.KIND_SKILL:
			return true
	return false


# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------

## First user prompt becomes the sidebar title; later turns leave it unchanged.
static func set_title_from_prompt(session_id: int, prompt: String) -> void:
	if has_chat_history(session_id):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	session.title = StringUtils.truncate(prompt.strip_edges().replace("\n", " "), TITLE_MAX)
	AgentEvents.events.session_title_changed.emit(session_id, session.title)
	pass


# ---------------------------------------------------------------------------
# User actions — send, stop
# ---------------------------------------------------------------------------

static func async_send(session_id: int, user_text: String) -> void:
	var session_index := get_index(session_id)
	if session_index == null:
		return
	if session_index.is_running():
		Alert.alert("session is busy", Colors.error)
		return
	if StringUtils.is_blank(user_text):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var trimmed := user_text.strip_edges()
	set_title_from_prompt(session_id, trimmed)
	session.messages.append(ChatMessage.user(trimmed))
	add_chat_entry(session_id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, trimmed)
	await run_agent(session)
	pass


static func async_resume(session_id: int) -> void:
	var session_index := get_index(session_id)
	if session_index == null:
		return
	if session_index.is_running():
		Alert.alert("session is busy", Colors.error)
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	await run_agent(session)
	pass


static func run_agent(session: AgentSession) -> void:
	var session_index := get_index(session.id)
	if session_index == null:
		return
	session_index.run = AgentSessionIndexes.RunState.new()
	await AgentLoop.run(session)
	pass


static func on_session_resume(session_id: int) -> void:
	await async_resume(session_id)
	pass

static func request_stop(session_id: int) -> void:
	var session_index := get_index(session_id)
	if session_index == null:
		return
	if not session_index.is_running() or session_index.is_stop_requested():
		return
	session_index.run.stop_requested = true
	OSUtils.stop_current()
	pass


# ---------------------------------------------------------------------------
# Chat Entry
# ---------------------------------------------------------------------------

static func append_chat_entry_stream(session_id: int, stream_kind: String, chunk: String) -> ChatEntry:
	var session_index := get_index(session_id)
	if session_index == null or session_index.run == null:
		return null
	var run := session_index.run
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		if run.step_thinking_entry == null:
			run.step_thinking_entry = add_chat_entry(session_id, ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, chunk, false)
		else:
			run.step_thinking_entry.body += chunk
		return run.step_thinking_entry
	if run.step_agent_entry == null:
		run.step_agent_entry = add_chat_entry(session_id, ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, chunk, false)
	else:
		run.step_agent_entry.body += chunk
	return run.step_agent_entry


static func add_chat_entry(session_id: int, kind: String, entry_title: String, body: String, _emit_end: bool = true) -> ChatEntry:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return null
	var entry := ChatEntry.new(kind, entry_title, body)
	session.chat_entries.append(entry)
	AgentEvents.events.chat_entry_add.emit(session_id, entry)
	return entry

# ---------------------------------------------------------------------------
# Event handlers — agent run
# ---------------------------------------------------------------------------

static func on_agent_end(session_id: int, error_message: String) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	if StringUtils.is_not_blank(error_message):
		add_chat_entry(session_id, ChatEntry.KIND_ERROR, ChatEntry.TITLE_ERROR, error_message)
	persist_session(session_id)

	var session_index := get_index(session_id)
	if session_index != null:
		session_index.stop_running()
	AgentEvents.events.session_stop.emit(session_id)
	pass


# ---------------------------------------------------------------------------
# Event handlers — turn & streaming
# ---------------------------------------------------------------------------

static func on_turn_start(session_id: int) -> void:
	var session_index := get_index(session_id)
	if session_index == null:
		return
	session_index.clear_run_state()
	pass


static func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	var entry := append_chat_entry_stream(session_id, stream_kind, chunk)
	if entry == null:
		return
	AgentEvents.events.chat_entry_update.emit(session_id, entry, stream_kind)
	pass


# ---------------------------------------------------------------------------
# Event handlers — tool execution
# ---------------------------------------------------------------------------

static func on_tool_execution_start(session_id: int, _tool_call_id: String, tool_name: String, args: Dictionary[String, String]) -> void:
	add_chat_entry(session_id, ChatEntry.KIND_TOOL, tool_name, format_tool_body(tool_name, args))
	pass


static func on_tool_execution_end(session_id: int, _tool_call_id: String, tool_name: String, result: String) -> void:
	if tool_name == ReadTool.NAME && StringUtils.is_not_empty(result):
		return

	var title := ChatEntry.TITLE_RESULT
	var body := result
	if tool_name == BashTool.NAME:
		title = StringUtils.first_lines(result, 1)
		body = StringUtils.first_lines_after(result, 1)
		
	add_chat_entry(session_id, ChatEntry.KIND_RESULT, title, body)
	pass


static func format_tool_body(tool_name: String, args: Dictionary[String, String]) -> String:
	match tool_name:
		ReadTool.NAME, WriteTool.NAME, EditTool.NAME:
			return str(args.get(ReadTool.ARG_PATH, ""))
		BashTool.NAME:
			return str(args.get(BashTool.ARG_COMMAND, ""))
		WebSearchToolProxy.NAME, WebSearchToolBing.NAME:
			return str(args.get(WebSearchToolProxy.ARG_QUERY, ""))
		_:
			for key: Variant in args.keys():
				var value := str(args[key])
				if StringUtils.is_not_blank(value):
					return value
			return ""
