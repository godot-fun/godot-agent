class_name ThinkingBubble
extends Object

## Thinking / reasoning bubble — plain text preview (six lines) in chat.
## Full text lives on ChatEntry.body; a header button opens a popup for the full view.

const PREVIEW_LINES := 6


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat
) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	wrapper.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", AgentColors.thinking_title)
	title_label.add_theme_font_size_override("font_size", 12)
	header.add_child(title_label)

	var view_button := Button.new()
	view_button.text = "···"
	style_view_button(view_button)
	view_button.pressed.connect(open_full_view.bind(entry, wrapper))
	header.add_child(view_button)

	var line_label := Label.new()
	line_label.add_theme_color_override("font_color", AgentColors.chat_text_muted)
	line_label.add_theme_font_size_override("font_size", 11)
	header.add_child(line_label)

	vbox.add_child(header)

	var body_label := create_body_label(StringUtils.last_lines(entry.body, PREVIEW_LINES))
	vbox.add_child(body_label)

	wrapper.set_meta(AgentChatView.META_BODY_LABEL, body_label)

	chat_list.add_child(wrapper)
	refresh(body_label, entry)
	return body_label


static func on_stream_delta(body_label: RichTextLabel, entry: ChatEntry) -> void:
	if body_label == null or entry == null or not is_instance_valid(body_label):
		return
	refresh(body_label, entry)
	pass


static func refresh(body_label: RichTextLabel, entry: ChatEntry) -> void:
	if entry == null or not is_instance_valid(body_label):
		return
	var lines := entry.body.count("\n")
	var header := body_label.get_parent().get_child(0) as HBoxContainer
	var view_button := header.get_child(1) as Button
	var line_label := header.get_child(2) as Label
	var show_more := lines > PREVIEW_LINES
	view_button.visible = show_more
	line_label.visible = show_more
	if show_more:
		line_label.text = StringUtils.format("+{} line{}", lines, "" if lines == 1 else "s")
	body_label.text = StringUtils.last_lines(entry.body, PREVIEW_LINES)
	pass


static func create_body_label(text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.selection_enabled = true
	label.scroll_active = false
	label.fit_content = true
	label.bbcode_enabled = false
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("default_color", AgentColors.chat_text_muted)
	label.add_theme_font_override("normal_font", Fonts.regular())
	label.text = text
	return label


static func style_view_button(button: Button) -> void:
	button.tooltip_text = "View full thinking"
	button.custom_minimum_size = Vector2(22, 18)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", AgentColors.thinking_title)
	button.add_theme_color_override("font_hover_color", AgentColors.thinking_title.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", AgentColors.thinking_title.darkened(0.08))

	var normal := StyleBoxFlat.new()
	normal.bg_color = AgentColors.thinking_bubble.lightened(0.08)
	normal.border_color = AgentColors.thinking_title.darkened(0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = AgentColors.thinking_bubble.lightened(0.16)
	hover.border_color = AgentColors.thinking_title

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = AgentColors.thinking_bubble.darkened(0.06)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover.duplicate())
	button.add_theme_stylebox_override("disabled", normal.duplicate())
	pass


static func open_full_view(entry: ChatEntry, anchor: Control) -> void:
	if entry == null or anchor == null or not is_instance_valid(anchor):
		return
	var tree := anchor.get_tree()
	if tree == null:
		return

	var window := Window.new()
	window.title = entry.title if not StringUtils.is_blank(entry.title) else "Thinking"
	window.transient = true
	window.min_size = Vector2i(840, 520)

	var text := TextEdit.new()
	text.text = entry.body
	text.editable = false
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 12
	text.offset_top = 12
	text.offset_right = -12
	text.offset_bottom = -12
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.grow_vertical = Control.GROW_DIRECTION_BOTH
	text.add_theme_font_override("font", Fonts.regular())
	text.add_theme_color_override("font_color", AgentColors.chat_text_muted)
	window.add_child(text)

	window.close_requested.connect(func() -> void: window.queue_free())
	window.window_input.connect(on_full_view_input.bind(window))

	tree.root.add_child(window)
	var viewport_size := anchor.get_viewport().get_visible_rect().size
	const EDGE_MARGIN := 64
	var max_w := int(viewport_size.x) - EDGE_MARGIN * 2
	var max_h := int(viewport_size.y) - EDGE_MARGIN * 2
	window.size = Vector2i(
		clampi(int(viewport_size.x * 0.76), window.min_size.x, max_w),
		clampi(int(viewport_size.y * 0.78), window.min_size.y, max_h),
	)
	window.popup_centered()
	text.set_caret_line(maxi(text.get_line_count() - 1, 0))
	pass


static func on_full_view_input(event: InputEvent, window: Window) -> void:
	if not is_instance_valid(window):
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			window.queue_free()
			window.set_input_as_handled()
	pass
