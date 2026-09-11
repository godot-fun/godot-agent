class_name AgentSession
extends RefCounted

## Single conversation session — LLM history and UI transcript.

var id: int = -1
var title: String = ""
var messages: Array[ChatMessage] = []
var chat_entries: Array[ChatEntry] = []
## Latest LLM request usage; prompt_tokens is the current context length.
var usage: OpenAiUsage = OpenAiUsage.new()


func _init(_id: int = -1, _title: String = "New Chat") -> void:
	id = _id
	title = _title
	pass
