class_name ChatArea
extends RefCounted

## Chat region and outer shell background colors.

var chat_area: Panel
var shell: Control


func setup(p_chat_area: Panel, p_shell: Control) -> void:
	chat_area = p_chat_area
	shell = p_shell
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme(_is_dark: bool = false) -> void:
	chat_area.add_theme_stylebox_override("panel", build_chat_style())
	chat_area.queue_redraw()
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = AgentColors.chat
	shell.add_theme_stylebox_override("panel", shell_style)
	pass


func build_chat_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = AgentColors.chat
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style
