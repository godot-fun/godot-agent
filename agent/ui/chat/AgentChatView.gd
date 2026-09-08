class_name AgentChatView
extends RefCounted

## Chat transcript area — bubbles, streaming, scroll, error resume.
## One bubble list per session; switching shows the cached list.

const BUBBLE_BODY_MARGIN_H := 12
const LIST_SEPARATION := 10
const STREAM_FLUSH_SEC := 0.1
const META_BODY_LABEL := "body_label"


class StreamSlot:
	var entry: ChatEntry = null
	var label: RichTextLabel = null


class SessionStepStreams:
	var slots: Dictionary[String, StreamSlot] = {}


var chat_scroll: ScrollContainer
var chat_host: Control

var chat_list_caches: Dictionary[int, VBoxContainer] = {}
var step_streams: Dictionary[int, SessionStepStreams] = {}
var entry_labels: Dictionary[ChatEntry, RichTextLabel] = {}
var stick_to_bottom: bool = true
var stream_flush_scheduled: Dictionary[int, bool] = {}
var pending_stream_refreshes: Dictionary[int, Dictionary] = {}


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(
	p_chat_scroll: ScrollContainer,
	p_chat_host: Control
) -> void:
	chat_scroll = p_chat_scroll
	chat_host = p_chat_host
	chat_scroll.gui_input.connect(on_chat_scroll_gui_input)
	AgentEvents.events.markdown_changed.connect(on_markdown_changed)
	AgentEvents.events.theme_changed.connect(on_theme_changed)
	AgentEvents.events.session_selected.connect(on_session_selected)
	AgentEvents.events.session_removed.connect(on_session_removed)
	AgentEvents.events.agent_start.connect(on_agent_start)
	AgentEvents.events.session_stop.connect(on_session_stop)
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.chat_entry_add.connect(on_message_start)
	AgentEvents.events.chat_entry_update.connect(on_chat_entry_update)
	pass


func on_session_selected(session_id: int) -> void:
	show_session(session_id)
	refresh_error_resume_buttons()
	pass


func on_session_removed(session_id: int) -> void:
	drop_list(session_id)
	step_streams.erase(session_id)
	pass


func on_session_stop(session_id: int) -> void:
	if AgentSessionManager.is_active(session_id):
		refresh_error_resume_buttons()
	flush_stream_refreshes(session_id)
	step_streams.erase(session_id)
	var session := AgentSessionManager.get_session(session_id)
	if session != null:
		sync_new_entries(session)
	pass


func on_turn_start(session_id: int) -> void:
	step_streams.erase(session_id)
	pass


func on_agent_start(session_id: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	reset_stick_to_bottom()
	refresh_error_resume_buttons()
	pass


func refresh_error_resume_buttons() -> void:
	var active_chat_list := get_active_chat_list()
	if active_chat_list == null:
		return
	ErrorBubble.refresh_resume_buttons(active_chat_list, AgentSessionManager.is_running(AgentSessionManager.active_session_id))
	pass


## Re-render every bubble body after Markdown toggle changes.
func on_markdown_changed(_enabled: bool) -> void:
	var session := AgentSessionManager.get_active()
	if session == null:
		return
	for entry: ChatEntry in session.chat_entries:
		var body_label: RichTextLabel = entry_labels.get(entry)
		if body_label == null:
			continue
		match entry.kind:
			ChatEntry.KIND_THINKING:
				ThinkingBubble.refresh(body_label, entry)
			ChatEntry.KIND_ERROR:
				ErrorBubble.refresh(body_label, entry)
			_:
				refresh_body_label(body_label, entry)
	drop_inactive_lists()
	pass


func on_theme_changed(_is_dark: bool) -> void:
	if AgentSessionManager.active_session_id == AgentSessionManager.INVALID_SESSION_ID:
		return
	rebuild(AgentSessionManager.active_session_id)
	pass


func build_bubble_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	style.content_margin_left = BUBBLE_BODY_MARGIN_H
	style.content_margin_right = BUBBLE_BODY_MARGIN_H
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if AgentColors.is_dark():
		style.set_border_width_all(0)
	else:
		style.border_color = AgentColors.chat_bubble_border
		style.set_border_width_all(1)
		style.shadow_color = Color(0, 0, 0, 0.04)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 2)
	return style


# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------

func show_session(session_id: int) -> void:
	var session := AgentSessionManager.get_session(session_id)
	if session == null:
		return

	# One bubble list per session — create on first open, reuse on later switches.
	var is_first_open := not chat_list_caches.has(session_id)
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if list == null:
		list = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", LIST_SEPARATION)
		chat_host.add_child(list)
		chat_list_caches[session_id] = list

	for id: int in chat_list_caches:
		chat_list_caches[id].visible = id == session_id

	if list.get_child_count() == 0:
		fill_list(session)
	else:
		sync_new_entries(session)

	if is_first_open:
		stick_to_bottom = true
		queue_scroll_to_bottom_after_layout()
	pass


func rebuild(session_id: int) -> void:
	drop_all_lists()
	show_session(session_id)
	pass


func fill_list(session: AgentSession) -> void:
	step_streams.erase(session.id)
	for entry: ChatEntry in session.chat_entries:
		append_entry_bubble(entry, session.id)
	if AgentSessionManager.is_running(session.id):
		restore_step_streams(session.id, session)
	pass


func drop_list(session_id: int) -> void:
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if list == null:
		return
	flush_stream_refreshes(session_id)
	unregister_session_labels(session_id)
	chat_list_caches.erase(session_id)
	list.queue_free()
	pass


func drop_inactive_lists() -> void:
	var drop_ids: Array[int] = []
	for session_id: int in chat_list_caches:
		if session_id != AgentSessionManager.active_session_id:
			drop_ids.append(session_id)
	for session_id: int in drop_ids:
		drop_list(session_id)
	pass


func drop_all_lists() -> void:
	var drop_ids: Array[int] = []
	drop_ids.assign(chat_list_caches.keys())
	for session_id: int in drop_ids:
		drop_list(session_id)
	pass


func sync_new_entries(session: AgentSession) -> void:
	var list: VBoxContainer = chat_list_caches.get(session.id)
	if list == null:
		return
	for index in range(list.get_child_count(), session.chat_entries.size()):
		append_entry_bubble(session.chat_entries[index], session.id)
	pass


# ---------------------------------------------------------------------------
# Agent events
# ---------------------------------------------------------------------------

func on_message_start(session_id: int, entry: ChatEntry) -> void:
	if entry_labels.has(entry):
		return
	if chat_list_caches.get(session_id) == null:
		return
	append_entry_bubble(entry, session_id)
	pass


func on_chat_entry_update(session_id: int, entry: ChatEntry, channel: String) -> void:
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if list == null:
		return

	if not step_streams.has(session_id):
		step_streams[session_id] = SessionStepStreams.new()
	var container: SessionStepStreams = step_streams[session_id]

	var slot: StreamSlot = container.slots.get(channel)
	if slot == null or slot.entry != entry:
		slot = StreamSlot.new()
		slot.entry = entry
		slot.label = entry_labels.get(entry)
		if slot.label == null:
			slot.label = append_entry_bubble(entry, session_id)
		container.slots[channel] = slot
	elif slot.label != null:
		queue_stream_refresh(session_id, slot.entry, slot.label, channel)
	pass


func queue_stream_refresh(session_id: int, entry: ChatEntry, label: RichTextLabel, channel: String) -> void:
	if not pending_stream_refreshes.has(session_id):
		pending_stream_refreshes[session_id] = {}
	pending_stream_refreshes[session_id][channel] = {
		"entry": entry,
		"label": label,
	}
	if stream_flush_scheduled.get(session_id, false):
		return
	stream_flush_scheduled[session_id] = true
	var tree := chat_scroll.get_tree()
	if tree == null:
		flush_stream_refreshes(session_id)
		return
	tree.create_timer(STREAM_FLUSH_SEC).timeout.connect(func() -> void:
		flush_stream_refreshes(session_id)
	, CONNECT_ONE_SHOT)
	pass


func flush_stream_refreshes(session_id: int) -> void:
	stream_flush_scheduled[session_id] = false
	var pending: Dictionary = pending_stream_refreshes.get(session_id, {})
	pending_stream_refreshes.erase(session_id)
	for channel: String in pending:
		var item: Dictionary = pending[channel]
		var entry: ChatEntry = item.get("entry")
		var label: RichTextLabel = item.get("label")
		if entry == null or label == null or not is_instance_valid(label):
			continue
		if channel == OpenAiClient.STREAM_KIND_REASONING:
			ThinkingBubble.on_stream_delta(label, entry)
		else:
			refresh_body_label(label, entry, true)
	if AgentSessionManager.is_active(session_id):
		queue_scroll_to_bottom()
	pass


# ---------------------------------------------------------------------------
# Streaming restore
# ---------------------------------------------------------------------------

func restore_step_streams(session_id: int, session: AgentSession) -> void:
	if session.run == null:
		return
	var container := SessionStepStreams.new()
	if session.run.step_thinking_entry != null:
		var thinking_slot := StreamSlot.new()
		thinking_slot.entry = session.run.step_thinking_entry
		thinking_slot.label = entry_labels.get(session.run.step_thinking_entry)
		container.slots["reasoning"] = thinking_slot
	if session.run.step_agent_entry != null:
		var agent_slot := StreamSlot.new()
		agent_slot.entry = session.run.step_agent_entry
		agent_slot.label = entry_labels.get(session.run.step_agent_entry)
		container.slots["content"] = agent_slot
	if not container.slots.is_empty():
		step_streams[session_id] = container
	pass


# ---------------------------------------------------------------------------
# Bubbles
# ---------------------------------------------------------------------------

func append_entry_bubble(entry: ChatEntry, session_id: int) -> RichTextLabel:
	var chat_list: VBoxContainer = chat_list_caches.get(session_id)
	if chat_list == null:
		return null
	var body_label: RichTextLabel = null
	match entry.kind:
		ChatEntry.KIND_SYSTEM:
			body_label = append_bubble(chat_list, entry, AgentColors.chat_text_muted, AgentColors.system_bubble, AgentColors.system_title)
		ChatEntry.KIND_USER:
			body_label = append_bubble(chat_list, entry, AgentColors.chat_text, AgentColors.user_bubble)
		ChatEntry.KIND_THINKING:
			body_label = ThinkingBubble.append(
					chat_list,
					entry,
					build_bubble_style(AgentColors.thinking_bubble)
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_AGENT:
			body_label = append_bubble(chat_list, entry, AgentColors.chat_text, AgentColors.assistant_bubble)
		ChatEntry.KIND_TOOL:
			body_label = append_bubble(chat_list, entry, AgentColors.success, AgentColors.tool_bubble)
		ChatEntry.KIND_RESULT:
			body_label = append_bubble(chat_list, entry, AgentColors.chat_text_muted, AgentColors.result_bubble)
		ChatEntry.KIND_ERROR:
			body_label = ErrorBubble.append(
					chat_list,
					entry,
					build_bubble_style(AgentColors.panel),
					session_id,
					AgentSessionManager.is_running(session_id)
			)
			queue_scroll_to_bottom()
		_:
			body_label = append_bubble(chat_list, entry, AgentColors.chat_text_muted, AgentColors.panel)
	if body_label != null:
		entry_labels[entry] = body_label
	return body_label


func append_bubble(chat_list: VBoxContainer, entry: ChatEntry, text_color: Color, bg_color: Color, title_color: Color = AgentColors.chat_text_muted) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", build_bubble_style(bg_color))

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	wrapper.add_child(vbox)

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_label)

	var body_label := MarkdownUtils.create_body_label(
		text_color,
		entry.body,
		markdown_enabled_for_entry(entry),
		0.0,
		AgentColors.code_block_bg_html()
	)
	vbox.add_child(body_label)
	wrapper.set_meta(META_BODY_LABEL, body_label)

	chat_list.add_child(wrapper)
	queue_scroll_to_bottom()
	return body_label


func refresh_body_label(body_label: RichTextLabel, entry: ChatEntry, incremental: bool = false) -> void:
	var markdown_enabled := markdown_enabled_for_entry(entry)
	if incremental and not markdown_enabled:
		var cached := MarkdownUtils.get_raw_body(body_label)
		if entry.body.length() > cached.length() and entry.body.begins_with(cached):
			if body_label.bbcode_enabled:
				body_label.bbcode_enabled = false
			body_label.append_text(entry.body.substr(cached.length()))
			body_label.set_meta(MarkdownUtils.META_RAW_BODY, entry.body)
			return
	MarkdownUtils.set_body_text(body_label, entry.body, markdown_enabled, 0.0, AgentColors.code_block_bg_html())
	pass


func markdown_enabled_for_entry(entry: ChatEntry) -> bool:
	if entry.kind == ChatEntry.KIND_TOOL:
		return false
	return MarkdownToggle.markdown_enabled


func unregister_session_labels(session_id: int) -> void:
	var session := AgentSessionManager.get_session(session_id)
	if session == null:
		return
	for entry: ChatEntry in session.chat_entries:
		entry_labels.erase(entry)
	pass


func get_active_chat_list() -> VBoxContainer:
	return chat_list_caches.get(AgentSessionManager.active_session_id)


func reset_stick_to_bottom() -> void:
	stick_to_bottom = true
	queue_scroll_to_bottom()
	pass


func on_chat_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			stick_to_bottom = false
	elif event is InputEventPanGesture:
		stick_to_bottom = false
	pass


func queue_scroll_to_bottom() -> void:
	if not stick_to_bottom:
		return
	var active_chat_list := get_active_chat_list()
	if active_chat_list == null or not active_chat_list.visible:
		return
	var count := active_chat_list.get_child_count()
	if count == 0:
		return
	chat_scroll.call_deferred("ensure_control_visible", active_chat_list.get_child(count - 1))
	pass


## First open may fill many bubbles; wait one frame so layout height is ready before scrolling.
func queue_scroll_to_bottom_after_layout() -> void:
	var tree := chat_scroll.get_tree()
	if tree == null:
		queue_scroll_to_bottom()
		return
	tree.process_frame.connect(func() -> void:
		queue_scroll_to_bottom()
	, CONNECT_ONE_SHOT)
	pass
