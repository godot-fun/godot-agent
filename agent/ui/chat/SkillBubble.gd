class_name SkillBubble
extends RefCounted

## Skill index bubble — toolbar toggle + expandable Markdown preview of .cursor/skills/README.md.

const SETTING_KEY := "agent_skill_in_prompt_enabled"
const PREVIEW_LINES := 8
const README_REL := ".cursor/skills/README.md"
const META_EXPANDED := "skill_bubble_expanded"
const META_EXPAND_BUTTON := "skill_bubble_expand_button"

static var skill_in_prompt_enabled: bool = true

var button: Button


static func is_enabled() -> bool:
	return skill_in_prompt_enabled


func setup_toggle(p_button: Button) -> void:
	skill_in_prompt_enabled = Setting.get_bool(SETTING_KEY, true)
	button = p_button
	button.toggled.connect(on_toggled)
	AgentEvents.events.theme_changed.connect(apply_toggle_theme)
	apply_toggle_theme()
	pass


func apply_toggle_theme(_is_dark: bool = false) -> void:
	skill_in_prompt_enabled = Setting.get_bool(SETTING_KEY, true)
	var tooltip := "Include skill index in system prompt (new chats)" if not skill_in_prompt_enabled else "Skill index included in system prompt (new chats)"
	AgentToolbarButton.style(button, tooltip)
	button.set_block_signals(true)
	button.button_pressed = skill_in_prompt_enabled
	button.set_block_signals(false)
	pass


func on_toggled(enabled: bool) -> void:
	skill_in_prompt_enabled = enabled
	Setting.set_bool(SETTING_KEY, enabled)
	Setting.save()
	apply_toggle_theme()
	pass


static func load_readme_text() -> String:
	var path := AgentWorkspace.resolve_path(README_REL)
	if not FileAccess.file_exists(path):
		return ""
	return FileUtils.read_file_to_string(path)


static func build_llm_message(readme_text: String) -> String:
	return StringUtils.format(
		"""Skill index (.cursor/skills/README.md):

{}""",
		readme_text.strip_edges()
	)


static func preview(body: String) -> String:
	return StringUtils.first_lines(body, PREVIEW_LINES)


static func needs_expand(body: String) -> bool:
	if StringUtils.is_blank(body):
		return false
	return preview(body) != body


static func hidden_line_count(body: String) -> int:
	if StringUtils.is_blank(body):
		return 0
	return maxi(0, body.count("\n") + 1 - PREVIEW_LINES)


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat
) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)
	wrapper.set_meta(META_EXPANDED, false)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	wrapper.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", AgentColors.chat_text_muted)
	title_label.add_theme_font_size_override("font_size", 12)
	header.add_child(title_label)

	var expand_button := Button.new()
	style_expand_button(expand_button)
	expand_button.pressed.connect(on_expand_pressed.bind(wrapper, entry))
	header.add_child(expand_button)
	wrapper.set_meta(META_EXPAND_BUTTON, expand_button)

	vbox.add_child(header)

	var rich_text := MarkdownUtils.create_rich_text_label(
		AgentColors.chat_text_muted,
		StringUtils.EMPTY,
		true,
		0.0,
		AgentColors.code_block_bg_html()
	)
	vbox.add_child(rich_text)
	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	refresh(rich_text, entry, wrapper)
	return rich_text


static func on_expand_pressed(wrapper: PanelContainer, entry: ChatEntry) -> void:
	if not is_instance_valid(wrapper):
		return
	var expanded := bool(wrapper.get_meta(META_EXPANDED, false))
	wrapper.set_meta(META_EXPANDED, not expanded)
	var rich_text := wrapper.get_meta(AgentChatView.META_BUBBLE_RICH_TEXT) as RichTextLabel
	if rich_text != null:
		refresh(rich_text, entry, wrapper)
	pass


static func refresh(rich_text: RichTextLabel, entry: ChatEntry, wrapper: PanelContainer = null) -> void:
	if not is_instance_valid(rich_text):
		return
	if wrapper == null:
		wrapper = find_wrapper(rich_text)
	if wrapper == null:
		return

	var expanded := bool(wrapper.get_meta(META_EXPANDED, false))
	var can_expand := needs_expand(entry.body)
	var display := entry.body if expanded or not can_expand else preview(entry.body)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownUtils.set_rich_text_label_text(rich_text, display, true, 0.0, AgentColors.code_block_bg_html())

	var expand_button := wrapper.get_meta(META_EXPAND_BUTTON) as Button
	if expand_button != null:
		expand_button.visible = can_expand
		if can_expand:
			if expanded:
				expand_button.text = "Collapse"
				expand_button.tooltip_text = "Show first 8 lines"
			else:
				var hidden := hidden_line_count(entry.body)
				expand_button.text = StringUtils.format("Expand (+{} line{})", hidden, "" if hidden == 1 else "s")
				expand_button.tooltip_text = "Show full skill index"
	pass


static func find_wrapper(rich_text: RichTextLabel) -> PanelContainer:
	var vbox := rich_text.get_parent()
	if vbox == null:
		return null
	return vbox.get_parent() as PanelContainer


static func style_expand_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 18)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", AgentColors.accent)
	button.add_theme_color_override("font_hover_color", AgentColors.accent.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", AgentColors.accent.darkened(0.08))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.content_margin_left = 4
	normal.content_margin_right = 4

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = AgentColors.accent
	hover.bg_color.a = 0.12
	hover.set_corner_radius_all(4)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover.duplicate())
	button.add_theme_stylebox_override("focus", hover.duplicate())
	button.add_theme_stylebox_override("disabled", normal.duplicate())
	pass
