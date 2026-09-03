class_name AgentSession
extends RefCounted

## Single conversation session — LLM history, UI transcript, and run lifecycle.

const TITLE_MAX := 32

var id: int = -1
var title: String = ""
var title_customized: bool = false
var messages: Array[ChatMessage] = []
var chat_entries: Array[ChatEntry] = []
## Active run state; null when idle.
var run: RunState = null


class RunState:
	var stop_requested: bool = false
	var step_thinking_entry: ChatEntry = null
	var step_agent_entry: ChatEntry = null


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _init(_id: int = -1, _title: String = "New Chat") -> void:
	id = _id
	title = _title
	var system_text := SystemPrompt.build()
	messages.append(ChatMessage.system(system_text))
	add_chat_entry(ChatEntry.KIND_SYSTEM, ChatEntry.TITLE_SYSTEM, system_text)
	pass


# ---------------------------------------------------------------------------
# Session state
# ---------------------------------------------------------------------------

func is_running() -> bool:
	return run != null

func stop_running() -> void:
	run = null
	pass

func clear_run_state() -> void:
	if run == null:
		return
	run.step_thinking_entry = null
	run.step_agent_entry = null
	pass

func has_chat_history() -> bool:
	for entry in chat_entries:
		if entry.kind != ChatEntry.KIND_SYSTEM:
			return true
	return false


func is_stop_requested() -> bool:
	return run != null and run.stop_requested

# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------

func set_title_from_prompt(prompt: String) -> void:
	if title_customized:
		return
	title_customized = true
	title = truncate_title(prompt)
	AgentEvents.events.session_title_changed.emit(id, title)
	pass


static func truncate_title(text: String) -> String:
	var trimmed := text.strip_edges().replace("\n", " ")
	if trimmed.length() <= TITLE_MAX:
		return trimmed
	return trimmed.substr(0, TITLE_MAX) + "…"


# ---------------------------------------------------------------------------
# Run lifecycle
# ---------------------------------------------------------------------------

func run_agent() -> void:
	run = RunState.new()
	await AgentLoop.run(self)
	pass


func async_send(user_text: String) -> void:
	if is_running():
		Alert.alert("session is busy", Colors.error)
		return
	if StringUtils.is_blank(user_text):
		return
	var trimmed := user_text.strip_edges()
	
	
	set_title_from_prompt(trimmed)
	messages.append(ChatMessage.user(trimmed))
	add_chat_entry(ChatEntry.KIND_USER, ChatEntry.TITLE_USER, trimmed)
	await run_agent()
	pass


func async_resume() -> void:
	if is_running():
		Alert.alert("session is busy", Colors.error)
		return
	await run_agent()
	pass


func request_stop() -> void:
	if not is_running() or is_stop_requested():
		return
	run.stop_requested = true
	OSUtils.stop_current()
	pass


# ---------------------------------------------------------------------------
# Chat Entry
# ---------------------------------------------------------------------------
func append_chat_entry_stream(stream_kind: String, chunk: String) -> ChatEntry:
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		if run.step_thinking_entry == null:
			run.step_thinking_entry = add_chat_entry(ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, chunk, false)
		else:
			run.step_thinking_entry.body += chunk
		return run.step_thinking_entry
	if run.step_agent_entry == null:
		run.step_agent_entry = add_chat_entry(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, chunk, false)
	else:
		run.step_agent_entry.body += chunk
	return run.step_agent_entry


func add_chat_entry(kind: String, entry_title: String, body: String, emit_end: bool = true) -> ChatEntry:
	var entry := ChatEntry.new(kind, entry_title, body)
	chat_entries.append(entry)
	AgentEvents.events.chat_entry_add.emit(id, entry)
	return entry
