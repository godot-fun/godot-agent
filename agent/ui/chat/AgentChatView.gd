class_name AgentChatView
extends RefCounted

## Chat transcript area — bubbles, streaming, scroll, error resume.
## One bubble list per session; switching shows the cached list.

const BUBBLE_BODY_MARGIN_H := 12
const LIST_SEPARATION := 10
const META_BUBBLE_RICH_TEXT := "bubble_rich_text"


## Live streaming slot — maps OpenAI stream channel to bubble widgets for one agent step.
class StreamSlot:
	var entry: ChatEntry = null
	var rich_text: RichTextLabel = null


class SessionStreamSlots:
	var slots: Dictionary[String, StreamSlot] = {}


var chat_scroll: ScrollContainer
var chat_host: Control

var chat_list_caches: Dictionary[int, VBoxContainer] = {}
## Per-session reasoning/content slots while a turn is in flight.
var session_stream_slots: Dictionary[int, SessionStreamSlots] = {}
var chat_bubble_flusher: ChatBubbleFlusher = ChatBubbleFlusher.new()
## When true, new content keeps the transcript scrolled to the latest bubble.
var stick_to_bottom: bool = true


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(
	p_chat_scroll: ScrollContainer,
	p_chat_host: Control
) -> void:
	chat_scroll = p_chat_scroll
	chat_host = p_chat_host
	chat_bubble_flusher.setup()
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
	AgentEvents.events.bubble_rich_text_flushed.connect(on_bubble_rich_text_flushed)
	pass


func on_session_selected(session_id: int) -> void:
	show_session(session_id)
	refresh_error_resume_buttons()
	pass


func on_session_removed(session_id: int) -> void:
	drop_list(session_id)
	session_stream_slots.erase(session_id)
	pass


## Scroll after ChatBubbleFlusher drains a batch (see AgentEvents.bubble_rich_text_flushed).
func on_bubble_rich_text_flushed() -> void:
	queue_scroll_to_bottom()
	pass


func on_session_stop(session_id: int) -> void:
	if AgentSessionManager.is_active(session_id):
		refresh_error_resume_buttons()
	chat_bubble_flusher.flush_now()
	session_stream_slots.erase(session_id)
	var session := AgentSessionManager.get_session(session_id)
	if session != null:
		sync_new_entries(session)
	pass


func on_turn_start(session_id: int) -> void:
	session_stream_slots.erase(session_id)
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
		var rich_text := get_bubble_rich_text(session.id, entry)
		if rich_text == null:
			continue
		match entry.kind:
			ChatEntry.KIND_THINKING:
				ThinkingBubble.refresh(rich_text, entry)
			ChatEntry.KIND_ERROR:
				ErrorBubble.refresh(rich_text, entry)
			_:
				ChatBubbleFlusher.refresh_rich_text(rich_text, entry)
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
	session_stream_slots.erase(session.id)
	for entry: ChatEntry in session.chat_entries:
		append_entry_bubble(entry, session.id)
	if AgentSessionManager.is_running(session.id):
		restore_session_stream_slots(session.id, session)
	pass


func drop_list(session_id: int) -> void:
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if list == null:
		return
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
	if get_bubble_rich_text(session_id, entry) != null:
		return
	if chat_list_caches.get(session_id) == null:
		return
	append_entry_bubble(entry, session_id)
	pass


## Streaming token — ensure slot exists, then queue UI refresh (not immediate).
func on_chat_entry_update(session_id: int, entry: ChatEntry, channel: String) -> void:
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if list == null:
		return

	if not session_stream_slots.has(session_id):
		session_stream_slots[session_id] = SessionStreamSlots.new()
	var container: SessionStreamSlots = session_stream_slots[session_id]

	var slot: StreamSlot = container.slots.get(channel)
	if slot == null or slot.entry != entry:
		slot = StreamSlot.new()
		slot.entry = entry
		slot.rich_text = get_bubble_rich_text(session_id, entry)
		if slot.rich_text == null:
			slot.rich_text = append_entry_bubble(entry, session_id)
		container.slots[channel] = slot
	elif slot.rich_text != null:
		chat_bubble_flusher.enqueue(slot.rich_text, slot.entry)
	pass


# ---------------------------------------------------------------------------
# Streaming restore
# ---------------------------------------------------------------------------

## Reattach stream slots after rebuild when switching back to a running session.
func restore_session_stream_slots(session_id: int, session: AgentSession) -> void:
	if session.run == null:
		return
	var container := SessionStreamSlots.new()
	if session.run.step_thinking_entry != null:
		var thinking_slot := StreamSlot.new()
		thinking_slot.entry = session.run.step_thinking_entry
		thinking_slot.rich_text = get_bubble_rich_text(session_id, session.run.step_thinking_entry)
		container.slots["reasoning"] = thinking_slot
	if session.run.step_agent_entry != null:
		var agent_slot := StreamSlot.new()
		agent_slot.entry = session.run.step_agent_entry
		agent_slot.rich_text = get_bubble_rich_text(session_id, session.run.step_agent_entry)
		container.slots["content"] = agent_slot
	if not container.slots.is_empty():
		session_stream_slots[session_id] = container
	pass


# ---------------------------------------------------------------------------
# Bubbles
# ---------------------------------------------------------------------------

func append_entry_bubble(entry: ChatEntry, session_id: int) -> RichTextLabel:
	var chat_list: VBoxContainer = chat_list_caches.get(session_id)
	if chat_list == null:
		return null
	var rich_text: RichTextLabel = null
	match entry.kind:
		ChatEntry.KIND_SYSTEM:
			rich_text = append_bubble(chat_list, entry, AgentColors.chat_text_muted, AgentColors.system_bubble, AgentColors.system_title)
		ChatEntry.KIND_USER:
			rich_text = append_bubble(chat_list, entry, AgentColors.chat_text, AgentColors.user_bubble)
		ChatEntry.KIND_THINKING:
			rich_text = ThinkingBubble.append(
					chat_list,
					entry,
					build_bubble_style(AgentColors.thinking_bubble)
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_AGENT:
			rich_text = append_bubble(chat_list, entry, AgentColors.chat_text, AgentColors.assistant_bubble)
		ChatEntry.KIND_TOOL:
			rich_text = append_bubble(chat_list, entry, AgentColors.success, AgentColors.tool_bubble)
		ChatEntry.KIND_RESULT:
			rich_text = append_bubble(chat_list, entry, AgentColors.chat_text_muted, AgentColors.result_bubble)
		ChatEntry.KIND_ERROR:
			rich_text = ErrorBubble.append(
					chat_list,
					entry,
					build_bubble_style(AgentColors.panel),
					session_id,
					AgentSessionManager.is_running(session_id)
			)
			queue_scroll_to_bottom()
		_:
			rich_text = append_bubble(chat_list, entry, AgentColors.chat_text_muted, AgentColors.panel)
	return rich_text


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

	var rich_text := MarkdownUtils.create_rich_text_label(
		text_color,
		entry.body,
		MarkdownToggle.markdown_enabled_for_entry(entry),
		0.0,
		AgentColors.code_block_bg_html()
	)
	vbox.add_child(rich_text)
	wrapper.set_meta(META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	queue_scroll_to_bottom()
	return rich_text


## chat_entries index matches VBoxContainer child order; label lives on wrapper meta.
func get_bubble_rich_text(session_id: int, entry: ChatEntry) -> RichTextLabel:
	var session := AgentSessionManager.get_session(session_id)
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if session == null or list == null:
		return null
	var index := session.chat_entries.find(entry)
	if index < 0 or index >= list.get_child_count():
		return null
	var wrapper: Node = list.get_child(index)
	return wrapper.get_meta(META_BUBBLE_RICH_TEXT) as RichTextLabel


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
