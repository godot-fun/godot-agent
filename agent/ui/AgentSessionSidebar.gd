class_name AgentSessionSidebar
extends RefCounted

## Left sidebar — session list with select / delete / drag reorder.

const DRAG_TYPE := "agent_session_row"

var session_list: VBoxContainer
var new_session_button: Button
var sidebar_title: Label
var sidebar_panel: PanelContainer

var session_rows: Dictionary[int, PanelContainer] = {}
var hover_session_id: int = AgentSessionManager.INVALID_SESSION_ID
var drag_session_id: int = AgentSessionManager.INVALID_SESSION_ID
var drop_target_id: int = AgentSessionManager.INVALID_SESSION_ID
var drop_insert_after: bool = false
var skip_row_press: bool = false


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
	end_session_drag()
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
	if skip_row_press:
		skip_row_press = false
		return
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
	var row_panel := SessionRow.new()
	row_panel.sidebar = self
	row_panel.session_id = session_id
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	row_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	row_panel.mouse_entered.connect(on_session_row_mouse_entered.bind(session_id))
	row_panel.mouse_exited.connect(on_session_row_mouse_exited.bind(session_id))
	row_panel.set_meta("session_id", session_id)

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
	select_button.set_drag_forwarding(
		get_row_drag_data.bind(session_id),
		can_drop_on_row.bind(session_id),
		drop_on_row.bind(session_id)
	)

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


func build_session_row_style(selected: bool, hovered: bool, drop_edge: int = 0, dragging: bool = false) -> StyleBoxFlat:
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
	if dragging:
		var bg := style.bg_color
		bg.a *= 0.4
		style.bg_color = bg
	if drop_edge < 0:
		style.border_color = AgentColors.sidebar_row_accent
		style.set_border_width(SIDE_TOP, 2)
	elif drop_edge > 0:
		style.border_color = AgentColors.sidebar_row_accent
		style.set_border_width(SIDE_BOTTOM, 2)
	return style


func style_session_row(session_id: int, selected: bool) -> void:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return
	var select_button: Button = row_panel.get_meta("select_button")
	if select_button == null:
		return

	var hovered := hover_session_id == session_id
	var drop_edge := 0
	if drop_target_id == session_id and drag_session_id != session_id:
		drop_edge = 1 if drop_insert_after else -1
	row_panel.add_theme_stylebox_override(
		"panel",
		build_session_row_style(selected, hovered, drop_edge, session_id == drag_session_id)
	)

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

func is_session_drag(data: Variant) -> bool:
	return data is Dictionary and str(data.get("type", "")) == DRAG_TYPE


func get_row_drag_data(_at_position: Vector2, session_id: int) -> Variant:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return null
	drag_session_id = session_id
	skip_row_press = true
	var preview := Label.new()
	preview.text = format_session_label(session_id, AgentSessionManager.get_title(session_id))
	preview.add_theme_color_override("font_color", AgentColors.sidebar_text)
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", build_session_row_style(false, true))
	wrap.add_child(preview)
	row_panel.set_drag_preview(wrap)
	refresh_row_styles()
	return {"type": DRAG_TYPE, "session_id": session_id}


func can_drop_on_row(at_position: Vector2, data: Variant, target_id: int) -> bool:
	if not is_session_drag(data):
		return false
	var target_row: PanelContainer = session_rows.get(target_id)
	if target_row == null:
		return false
	var from_id := int(data.session_id)
	if from_id == target_id:
		if drop_target_id != AgentSessionManager.INVALID_SESSION_ID:
			drop_target_id = AgentSessionManager.INVALID_SESSION_ID
			refresh_row_styles()
		return true
	var insert_after := at_position.y > target_row.size.y * 0.5
	if drop_target_id == target_id and drop_insert_after == insert_after:
		return true
	drop_target_id = target_id
	drop_insert_after = insert_after
	refresh_row_styles()
	return true


func drop_on_row(at_position: Vector2, data: Variant, target_id: int) -> void:
	if not is_session_drag(data):
		end_session_drag()
		return
	var from_id := int(data.session_id)
	var from_row: PanelContainer = session_rows.get(from_id)
	var target_row: PanelContainer = session_rows.get(target_id)
	if from_row == null or target_row == null:
		end_session_drag()
		return
	var to_index := target_row.get_index()
	if at_position.y > target_row.size.y * 0.5:
		to_index += 1
	var from_index := from_row.get_index()
	if from_index < to_index:
		to_index -= 1
	to_index = clampi(to_index, 0, session_list.get_child_count() - 1)
	if from_index != to_index:
		session_list.move_child(from_row, to_index)
		persist_row_order()
	end_session_drag()
	pass


func persist_row_order() -> void:
	var ordered_ids: Array[int] = []
	for child in session_list.get_children():
		if child.has_meta("session_id"):
			ordered_ids.append(int(child.get_meta("session_id")))
	AgentSessionManager.reorder_sessions(ordered_ids)
	pass


func refresh_row_styles() -> void:
	for session_id: int in session_rows:
		style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func end_session_drag() -> void:
	if drag_session_id == AgentSessionManager.INVALID_SESSION_ID and drop_target_id == AgentSessionManager.INVALID_SESSION_ID:
		return
	drag_session_id = AgentSessionManager.INVALID_SESSION_ID
	drop_target_id = AgentSessionManager.INVALID_SESSION_ID
	drop_insert_after = false
	refresh_row_styles()
	pass


## Row Control so Godot drag notifications reach the sidebar (RefCounted cannot receive them).
class SessionRow extends PanelContainer:
	var sidebar: AgentSessionSidebar
	var session_id: int = AgentSessionManager.INVALID_SESSION_ID


	func _get_drag_data(at_position: Vector2) -> Variant:
		return sidebar.get_row_drag_data(at_position, session_id)


	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		return sidebar.can_drop_on_row(at_position, data, session_id)


	func _drop_data(at_position: Vector2, data: Variant) -> void:
		sidebar.drop_on_row(at_position, data, session_id)
		pass


	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and sidebar != null:
			sidebar.end_session_drag()
		pass
