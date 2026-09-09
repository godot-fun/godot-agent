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

static func save_session(session: AgentSession) -> void:
	if session == null or session.id < 0:
		return
	if not ensure_chats_dir():
		Log.error("agent chat save failed, cannot create dir:[{}]", get_chats_dir())
		return
	var json := JsonUtils.object_to_json(session)
	FileUtils.write_string_to_file(get_session_path(session.id), json)
	upsert_index(session.id, session.title)
	pass


static func delete_session_file(session_id: int) -> void:
	if session_id < 0:
		return
	var path := get_session_path(session_id)
	FileUtils.delete_file(path)
	remove_index(session_id)
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
# Session Index
# ---------------------------------------------------------------------------
class SessionIndex:
	var index: Array[SessionTitle] = []

class SessionTitle:
	var id: int = -1
	var title: String = ""


static func load_index() -> SessionIndex:
	var session_index := read_index_file()
	if session_index != null:
		return session_index
	return rebuild_index()


static func read_index_file() -> SessionIndex:
	var text := FileUtils.read_file_to_string(get_index_path())
	if StringUtils.is_blank(text):
		return null
	var session_index: SessionIndex = JsonUtils.json_to_object(text, SessionIndex)
	if session_index == null:
		Log.error("agent chat index load failed, invalid json:[{}]", get_index_path())
		return null
	return session_index


static func save_index(session_index: SessionIndex) -> void:
	if session_index == null:
		return
	if not ensure_chats_dir():
		Log.error("agent chat save failed, cannot create dir:[{}]", get_chats_dir())
		return
	var json := JsonUtils.object_to_json(session_index)
	FileUtils.write_string_to_file(get_index_path(), json)
	pass


static func upsert_index(session_id: int, title: String) -> void:
	var session_index := read_index_file()
	var found := false
	for session_title: SessionTitle in session_index.index:
		if session_title.id == session_id:
			session_title.title = title
			found = true
			break
	if not found:
		var session_title := SessionTitle.new()
		session_title.id = session_id
		session_title.title = title
		session_index.index.insert(0, session_title)
	save_index(session_index)
	pass


static func remove_index(session_id: int) -> void:
	var session_index := read_index_file()
	if session_index == null:
		return
	for i in range(session_index.index.size() - 1, -1, -1):
		if session_index.index[i].id == session_id:
			session_index.index.remove_at(i)
	save_index(session_index)
	pass


static func rebuild_index() -> SessionIndex:
	var session_index := SessionIndex.new()
	for session: AgentSession in load_all_sessions():
		var session_title := SessionTitle.new()
		session_title.id = session.id
		session_title.title = session.title
		session_index.index.append(session_title)
	save_index(session_index)
	return session_index
