class_name ChatEntry
extends RefCounted

const KIND_SYSTEM := "system"
const KIND_USER := "user"
const KIND_AGENT := "agent"
const KIND_THINKING := "thinking"
const KIND_TOOL := "tool"
const KIND_RESULT := "result"
const KIND_ERROR := "error"

const TITLE_SYSTEM := "System"
const TITLE_USER := "You"
const TITLE_AGENT := "Agent"
const TITLE_THINKING := "Thinking"
const TITLE_RESULT := "Result"
const TITLE_ERROR := "Error"

var kind: String = ""
var title: String = ""
var body: String = ""


func _init(_kind: String = "", _title: String = "", _body: String = "") -> void:
	kind = _kind
	title = _title
	body = _body
	pass
