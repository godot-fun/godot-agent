class_name AgentSessionSidebar
extends RefCounted

## Left sidebar — session list with select / delete / drag reorder.

var session_list: VBoxContainer
var new_session_button: Button
var sidebar_title: Label
var sidebar_panel: PanelContainer

var session_rows: Dictionary[int, PanelContainer] = {}
var hover_session_id: int = AgentSessionManager.INVALID_SESSION_ID


# ---------------------------------------------------------------------------
# Setup & theme
# ---------------------------------------------------------------------------

func setup(
	p_session_list: VBoxContainer,
	p_new_session_button: Button,
	p_sidebar_title: Label,
	p_sidebar_panel: PanelContainer
) -> void:
	session_list = p_session_list
	new_session_button = p_new_session_button
	sidebar_title = p_sidebar_title
	sidebar_panel = p_sidebar_panel
	new_session_button.pressed.connect(on_new_session_pressed)
	AgentEvents.events.session_added.connect(on_session_added)
	AgentEvents.events.session_removed.connect(on_session_removed)
	AgentEvents.events.session_selected.connect(select_item)
	AgentEvents.events.session_title_changed.connect(on_session_refresh)
	AgentEvents.events.agent_start.connect(on_session_refresh)
	AgentEvents.events.session_stop.connect(on_session_stop)
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


func on_session_refresh(session_id: int, _arg: Variant = null) -> void:
	refresh_item(session_id)
	pass


func on_session_stop(session_id: int) -> void:
	refresh_item(session_id)
	pass


func apply_theme(_is_dark: bool = false) -> void:
	sidebar_panel.add_theme_stylebox_override("panel", build_sidebar_style())
	sidebar_panel.queue_redraw()
	sidebar_title.add_theme_color_override("font_color", AgentColors.sidebar_title)
	new_session_button.add_theme_color_override("font_color", AgentColors.sidebar_text)
	new_session_button.add_theme_color_override("font_hover_color", AgentColors.sidebar_row_accent)
	new_session_button.add_theme_color_override("font_pressed_color", AgentColors.sidebar_row_accent)
	for session_id: int in session_rows:
		style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func build_sidebar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = AgentColors.sidebar
	style.border_color = AgentColors.sidebar_border
	style.set_border_width(SIDE_RIGHT, 1)
	return style


# ---------------------------------------------------------------------------
# List rebuild & refresh
# ---------------------------------------------------------------------------

func rebuild() -> void:
	clear()
	for session_index: AgentSessionIndexes.SessionIndex in AgentSessionManager.session_indexes.indexes:
		append_row(session_index.id, session_index.title)
	select_item(AgentSessionManager.active_session_id)
	pass


func refresh_item(session_id: int) -> void:
	var title := AgentSessionManager.get_title(session_id)
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return
	var select_button: Button = row_panel.get_meta("select_button")
	if select_button != null:
		select_button.text = format_session_label(session_id, title)
	pass


func select_item(session_id: int) -> void:
	refresh_item(session_id)
	for row_session_id: int in session_rows:
		style_session_row(row_session_id, row_session_id == session_id)
	pass


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func on_session_added(session_id: int, title: String) -> void:
	append_row(session_id, title)
	session_list.move_child(session_rows[session_id], 0)
	pass


func on_session_removed(session_id: int) -> void:
	remove_row(session_id)
	pass


func on_new_session_pressed() -> void:
	var session := AgentSessionManager.create_session()
	AgentSessionManager.select_session(session.id)
	pass


func on_session_row_pressed(session_id: int) -> void:
	AgentSessionManager.select_session(session_id)
	pass


func on_session_delete_pressed(session_id: int) -> void:
	AgentSessionManager.delete_session(session_id)
	pass


# ---------------------------------------------------------------------------
# Row build & remove
# ---------------------------------------------------------------------------

func clear() -> void:
	for child in session_list.get_children():
		child.queue_free()
	session_rows.clear()
	pass


func append_row(session_id: int, title: String) -> void:
	var row_panel := PanelContainer.new()
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	row_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	row_panel.mouse_entered.connect(on_session_row_mouse_entered.bind(session_id))
	row_panel.mouse_exited.connect(on_session_row_mouse_exited.bind(session_id))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row_panel.add_child(row)

	var select_button := Button.new()
	select_button.text = format_session_label(session_id, title)
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select_button.focus_mode = Control.FOCUS_NONE
	select_button.flat = true
	select_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
	select_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	select_button.pressed.connect(on_session_row_pressed.bind(session_id))
	select_button.set_drag_forwarding(get_row_drag_data.bind(session_id), can_drop_on_row.bind(session_id), drop_on_row)

	var delete_button := Button.new()
	delete_button.text = "×"
	delete_button.tooltip_text = "Delete chat"
	delete_button.custom_minimum_size = Vector2(28, 28)
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.flat = true
	delete_button.add_theme_color_override("font_color", AgentColors.sidebar_muted)
	delete_button.add_theme_color_override("font_hover_color", AgentColors.error)
	delete_button.add_theme_color_override("font_pressed_color", AgentColors.error)
	delete_button.pressed.connect(on_session_delete_pressed.bind(session_id))

	row.add_child(select_button)
	row.add_child(delete_button)
	row_panel.set_meta("select_button", select_button)
	row_panel.set_meta("delete_button", delete_button)
	session_list.add_child(row_panel)
	session_rows[session_id] = row_panel
	style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func remove_row(session_id: int) -> void:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return
	if hover_session_id == session_id:
		hover_session_id = AgentSessionManager.INVALID_SESSION_ID
	row_panel.queue_free()
	session_rows.erase(session_id)
	pass


# ---------------------------------------------------------------------------
# Row styling
# ---------------------------------------------------------------------------

func on_session_row_mouse_entered(session_id: int) -> void:
	hover_session_id = session_id
	style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func on_session_row_mouse_exited(session_id: int) -> void:
	if hover_session_id == session_id:
		hover_session_id = AgentSessionManager.INVALID_SESSION_ID
	style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func build_session_row_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if selected:
		style.bg_color = AgentColors.sidebar_row_selected
		style.border_color = AgentColors.sidebar_row_accent
		style.set_border_width(SIDE_LEFT, 3)
	elif hovered:
		style.bg_color = AgentColors.sidebar_row_hover
	else:
		style.bg_color = Color(0, 0, 0, 0)
	return style


func style_session_row(session_id: int, selected: bool) -> void:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return
	var select_button: Button = row_panel.get_meta("select_button")
	if select_button == null:
		return

	var hovered := hover_session_id == session_id
	row_panel.add_theme_stylebox_override("panel", build_session_row_style(selected, hovered))

	var text_color := AgentColors.sidebar_text if selected else AgentColors.sidebar_muted
	if hovered and not selected:
		text_color = AgentColors.sidebar_text
	select_button.add_theme_color_override("font_color", text_color)
	select_button.add_theme_color_override("font_hover_color", text_color)
	select_button.add_theme_color_override("font_pressed_color", text_color)

	var delete_button: Button = row_panel.get_meta("delete_button")
	if delete_button != null:
		delete_button.add_theme_color_override("font_color", AgentColors.sidebar_muted)
		delete_button.add_theme_color_override("font_hover_color", AgentColors.error)
		delete_button.add_theme_color_override("font_pressed_color", AgentColors.error)
	pass


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func format_session_label(session_id: int, title: String) -> String:
	if AgentSessionManager.is_running(session_id):
		return title + " ●"
	return title


# ---------------------------------------------------------------------------
# Drag reorder
# ---------------------------------------------------------------------------

func get_row_drag_data(_at_position: Vector2, session_id: int) -> Variant:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return null
	row_panel.set_drag_preview(Control.new())
	return session_id


func can_drop_on_row(_at_position: Vector2, data: Variant, target_id: int) -> bool:
	var from_row: PanelContainer = session_rows.get(data)
	var target_row: PanelContainer = session_rows.get(target_id)
	if from_row == null or target_row == null:
		return from_row != null
	if from_row != target_row:
		session_list.move_child(from_row, target_row.get_index())
		AgentSessionManager.move_index(data, from_row.get_index())
	return true


func drop_on_row(_at_position: Vector2, _data: Variant) -> void:
	pass
