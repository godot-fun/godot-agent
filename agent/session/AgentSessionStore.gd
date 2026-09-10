class_name AgentSessionStore
extends RefCounted

## Persists agent chat sessions as JSON files under the workspace `.agent/sessions/` folder.

const CHATS_SUBDIR := ".agent/sessions"
const FILE_SUFFIX := ".json"
const NEXT_SESSION_ID_KEY := "agent_next_session_id"

static var sessions: Dictionary[int, AgentSession] = {}


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

static func get_chats_dir() -> String:
	return AgentWorkspace.get_root().path_join(CHATS_SUBDIR)


static func get_session_path(session_id: int) -> String:
	return get_chats_dir().path_join(str(session_id) + FILE_SUFFIX)


static func ensure_chats_dir() -> bool:
	var dir_path := get_chats_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	return err == OK


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------

static func create_session() -> AgentSession:
	var session_id := next_session_id()
	var session := AgentSession.new(session_id, StringUtils.format("New Chat {}", session_id))
	sessions[session.id] = session
	return session


static func next_session_id() -> int:
	var session_id := Setting.get_int(NEXT_SESSION_ID_KEY, 0)
	Setting.set_int(NEXT_SESSION_ID_KEY, session_id + 1)
	Setting.save()
	return session_id


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

static func save_session(session_id: int) -> void:
	var session: AgentSession = load_session(session_id)
	if session == null:
		return
	if not ensure_chats_dir():
		Log.error("agent chat save failed, cannot create dir:[{}]", get_chats_dir())
		return
	var json := JsonUtils.object_to_json(session)
	FileUtils.write_string_to_file(get_session_path(session.id), json)
	pass


static func delete_session(session_id: int) -> void:
	if session_id < 0:
		return
	sessions.erase(session_id)
	FileUtils.delete_file(get_session_path(session_id))
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
		if file_path.get_file() == AgentSessionIndexes.INDEX_FILE:
			continue
		if not file_path.ends_with(FILE_SUFFIX):
			continue
		var session := load_session_file(file_path)
		if session != null:
			result.append(session)
	return result


static func load_session(session_id: int) -> AgentSession:
	var session: AgentSession = sessions.get(session_id)
	if session != null:
		return session
	session = load_session_file(get_session_path(session_id))
	if session != null:
		sessions[session_id] = session
	return session


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
