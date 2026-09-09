class_name ErrorBubble
extends Object

## Error bubble with optional resume action for the agent chat transcript.

const MAX_LINES := 28

const META_RESUME_BUTTON := "resume_button"


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat,
	session_id: int,
	running: bool
) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	wrapper.add_child(vbox)

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", AgentColors.chat_text_muted)
	title_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_label)

	var rich_text := MarkdownUtils.create_rich_text_label(
			AgentColors.error,
			StringUtils.first_lines(entry.body, MAX_LINES),
			MarkdownToggle.markdown_enabled,
			0.0,
			AgentColors.code_block_bg_html()
	)
	vbox.add_child(rich_text)
	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)

	if is_resumable(entry.body):
		var resume_button := Button.new()
		resume_button.text = "Resume"
		resume_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		style_resume_button(resume_button)
		resume_button.pressed.connect(on_resume_pressed.bind(session_id))
		wrapper.set_meta(META_RESUME_BUTTON, resume_button)
		vbox.add_child(resume_button)

	chat_list.add_child(wrapper)
	refresh_resume_buttons(chat_list, running)
	return rich_text


static func refresh(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	if entry == null:
		return
	var display := StringUtils.first_lines(entry.body, MAX_LINES)
	MarkdownUtils.set_rich_text_label_text(rich_text, display, MarkdownToggle.markdown_enabled, 0.0, AgentColors.code_block_bg_html())
	pass


static func refresh_resume_buttons(chat_list: VBoxContainer, running: bool) -> void:
	for child in chat_list.get_children():
		if not child.has_meta(META_RESUME_BUTTON):
			continue
		var resume_button: Button = child.get_meta(META_RESUME_BUTTON)
		resume_button.disabled = running
	pass


static func is_resumable(message: String) -> bool:
	return message != "session is busy"


static func on_resume_pressed(session_id: int) -> void:
	AgentEvents.events.session_resume.emit(session_id)
	pass


static func style_resume_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(88, 30)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))

	var normal := StyleBoxFlat.new()
	normal.bg_color = AgentColors.accent
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = AgentColors.accent.lightened(0.10)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = AgentColors.accent.darkened(0.08)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = AgentColors.accent.darkened(0.25)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	pass
