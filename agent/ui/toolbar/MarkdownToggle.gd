class_name MarkdownToggle
extends RefCounted

## Toolbar toggle for chat bubble Markdown rendering.

const SETTING_KEY := "agent_markdown_enabled"

static var markdown_enabled: bool = false

var button: Button


func setup(p_button: Button) -> void:
	markdown_enabled = Setting.get_bool(SETTING_KEY, false)
	button = p_button
	button.toggled.connect(on_toggled)
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme(_is_dark: bool = false) -> void:
	markdown_enabled = Setting.get_bool(SETTING_KEY, false)
	AgentToolbarButton.style(
			button,
			"Show raw text" if markdown_enabled else "Render Markdown as BBCode"
	)
	button.set_block_signals(true)
	button.button_pressed = markdown_enabled
	button.set_block_signals(false)
	pass


func on_toggled(enabled: bool) -> void:
	markdown_enabled = enabled
	Setting.set_bool(SETTING_KEY, enabled)
	Setting.save()
	apply_theme()
	AgentEvents.events.markdown_changed.emit(enabled)
	pass
