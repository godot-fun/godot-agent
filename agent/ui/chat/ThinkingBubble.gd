class_name ThinkingBubble
extends Object

## Thinking / reasoning bubble — plain text preview in chat.
## Full text lives on ChatEntry.body; the header ··· button opens it in AgentTextPopup.


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
	view_button.pressed.connect(AgentTextPopup.open_entry.bind(entry, wrapper))
	header.add_child(view_button)

	var line_label := Label.new()
	line_label.add_theme_color_override("font_color", AgentColors.chat_text_muted)
	line_label.add_theme_font_size_override("font_size", 11)
	header.add_child(line_label)

	vbox.add_child(header)

	var rich_text := create_rich_text(StringUtils.EMPTY)
	vbox.add_child(rich_text)

	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	ChatBubblePreview.apply(rich_text, entry.body)
	return rich_text


static func create_rich_text(text: String) -> RichTextLabel:
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
