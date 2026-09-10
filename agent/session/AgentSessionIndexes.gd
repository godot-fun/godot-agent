class_name AgentSessionIndexes
extends RefCounted

## Persists the session list as `index.json` under the workspace `.agent/sessions/` folder.

const INDEX_FILE := "index.json"


class RunState:
	var stop_requested: bool = false
	var step_thinking_entry: ChatEntry = null
	var step_agent_entry: ChatEntry = null


class SessionIndex:
	var id: int = -1
	var title: String = ""
	## Active run state; null when idle. Not persisted to index.json.
	var run: RunState = null


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


	func is_stop_requested() -> bool:
		return run != null and run.stop_requested


var indexes: Array[SessionIndex] = []


static func get_index_path() -> String:
	return AgentSessionStore.get_chats_dir().path_join(INDEX_FILE)


static func load_index() -> AgentSessionIndexes:
	var text := FileUtils.read_file_to_string(get_index_path())
	if StringUtils.is_not_blank(text):
		var session_indexes: AgentSessionIndexes = JsonUtils.json_to_object(text, AgentSessionIndexes)
		if session_indexes != null:
			for session_index: SessionIndex in session_indexes.indexes:
				session_index.run = null
			return session_indexes
	return AgentSessionIndexes.new()


static func save_index(session_indexes: AgentSessionIndexes) -> void:
	var json := JsonUtils.object_to_json(session_indexes)
	FileUtils.write_string_to_file(get_index_path(), json)
	pass
