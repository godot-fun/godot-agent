class_name AgentSessionStore
extends RefCounted

## Persists agent chat sessions as JSON files under the workspace `.agent/sessions/` folder.

const CHATS_SUBDIR := ".agent/sessions"
const FILE_SUFFIX := ".json"
const INDEX_FILE := "index.json"


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

static func get_chats_dir() -> String:
	return AgentWorkspace.get_root().path_join(CHATS_SUBDIR)


static func get_session_path(session_id: int) -> String:
	return get_chats_dir().path_join(str(session_id) + FILE_SUFFIX)


static func get_index_path() -> String:
	return get_chats_dir().path_join(INDEX_FILE)


static func ensure_chats_dir() -> bool:
	var dir_path := get_chats_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	return err == OK


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

static func save_session(session_id: int, sessions: Dictionary[int, AgentSession]) -> void:
	var session: AgentSession = sessions.get(session_id)
	if not ensure_chats_dir():
		Log.error("agent chat save failed, cannot create dir:[{}]", get_chats_dir())
		return
	var json := JsonUtils.object_to_json(session)
	FileUtils.write_string_to_file(get_session_path(session.id), json)
	save_index(sessions)
	pass


static func delete_session_file(session_id: int, sessions: Dictionary[int, AgentSession]) -> void:
	if session_id < 0:
		return
	var path := get_session_path(session_id)
	FileUtils.delete_file(path)
	save_index(sessions)
	pass


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

static func load_all_sessions() -> Array[AgentSession]:
	var result: Array[AgentSession] = []
	var dir_path := get_chats_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		return result

	var file_paths := FileUtils.get_all_files_in_folder(dir_path, false)
	file_paths.sort_custom(func(a: String, b: String) -> bool:
		return a.get_file().to_lower() > b.get_file().to_lower()
	)
	for file_path in file_paths:
		if file_path.get_file() == INDEX_FILE:
			continue
		if not file_path.ends_with(FILE_SUFFIX):
			continue
		var session := load_session_file(file_path)
		if session != null:
			result.append(session)
	return result


static func load_session(session_id: int) -> AgentSession:
	return load_session_file(get_session_path(session_id))


static func load_session_file(file_path: String) -> AgentSession:
	var text := FileUtils.read_file_to_string(file_path)
	if StringUtils.is_blank(text):
		return null
	var session: AgentSession = JsonUtils.json_to_object(text, AgentSession)
	if session == null:
		Log.error("agent chat load failed, invalid json:[{}]", file_path)
		return null
	session.id = int(file_path.get_file().trim_suffix(FILE_SUFFIX))
	return session


# ---------------------------------------------------------------------------
# Session Indexes
# ---------------------------------------------------------------------------
class SessionIndexes:
	var indexes: Array[SessionIndex] = []

class SessionIndex:
	var id: int = -1
	var title: String = ""
	var order: int = 0


static func load_index() -> SessionIndexes:
	var text := FileUtils.read_file_to_string(get_index_path())
	if StringUtils.is_not_blank(text):
		var session_indexes: SessionIndexes = JsonUtils.json_to_object(text, SessionIndexes)
		if session_indexes != null:
			return session_indexes
	var sessions: Dictionary[int, AgentSession] = {}
	for session: AgentSession in load_all_sessions():
		sessions[session.id] = session
	return save_index(sessions)


static func save_index(sessions: Dictionary[int, AgentSession]) -> SessionIndexes:
	var session_indexes := SessionIndexes.new()
	for session_id: int in sessions:
		var session: AgentSession = sessions[session_id]
		if session == null:
			continue
		var session_index := SessionIndex.new()
		session_index.id = session.id
		session_index.title = session.title
		session_indexes.indexes.append(session_index)
	if not ensure_chats_dir():
		Log.error("agent chat save failed, cannot create dir:[{}]", get_chats_dir())
		return session_indexes
	var json := JsonUtils.object_to_json(session_indexes)
	FileUtils.write_string_to_file(get_index_path(), json)
	return session_indexes
