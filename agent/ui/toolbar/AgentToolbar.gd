class_name AgentToolbar
extends RefCounted

## Top toolbar — panel chrome, title, and workspace path button.

var toolbar_panel: PanelContainer
var title_label: Label
var project_button: Button


func setup(
	p_toolbar_panel: PanelContainer,
	p_title_label: Label,
	p_project_button: Button
) -> void:
	toolbar_panel = p_toolbar_panel
	title_label = p_title_label
	project_button = p_project_button
	project_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	project_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	project_button.tooltip_text = "Click to choose workspace folder"
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme(_is_dark: bool = false) -> void:
	toolbar_panel.add_theme_stylebox_override("panel", build_toolbar_style())
	toolbar_panel.queue_redraw()
	title_label.add_theme_color_override("font_color", AgentColors.toolbar_title)
	project_button.add_theme_color_override("font_color", AgentColors.toolbar_muted)
	project_button.add_theme_color_override("font_hover_color", AgentColors.toolbar_title)
	project_button.add_theme_color_override("font_pressed_color", AgentColors.toolbar_title)
	pass


func build_toolbar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = AgentColors.toolbar
	style.border_color = AgentColors.toolbar_border
	style.set_border_width(SIDE_BOTTOM, 1)
	if not AgentColors.is_dark():
		style.set_border_width(SIDE_TOP, 1)
	return style
