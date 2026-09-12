class_name ThemeColorSelect
extends RefCounted

## Circular toolbar control — theme accent color swatch + popup ColorPicker.

const BUTTON_SIZE := 28
const CORNER_RADIUS := 14

var button: Button
var popup: PopupPanel
var color_picker: ColorPicker


func setup(p_button: Button) -> void:
	button = p_button
	AgentColors.load_theme_color_from_settings()
	build_popup()
	button.text = ""
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	AgentEvents.events.theme_changed.connect(apply_theme)
	AgentEvents.events.theme_color_changed.connect(on_theme_color_changed)
	apply_theme()
	pass


func build_popup() -> void:
	popup = PopupPanel.new()
	color_picker = ColorPicker.new()
	color_picker.edit_alpha = true
	color_picker.color = AgentColors.theme_color
	color_picker.custom_minimum_size = Vector2(300, 320)
	color_picker.color_changed.connect(on_picker_color_changed)
	popup.add_child(color_picker)
	button.add_child(popup)
	pass


func apply_theme(_is_dark: bool = false) -> void:
	AgentToolbarButton.style(button, "Theme color", CORNER_RADIUS)
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	update_swatch(button.is_hovered())
	pass


func update_swatch(hovered: bool) -> void:
	var fill := AgentColors.theme_color
	if hovered:
		fill = fill.lightened(0.12)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var base: StyleBox = button.get_theme_stylebox("normal")
		if base == null or not base is StyleBoxFlat:
			continue
		var flat := (base as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.bg_color = fill
		flat.content_margin_left = 4
		flat.content_margin_right = 4
		flat.content_margin_top = 4
		flat.content_margin_bottom = 4
		if state == "hover" or (state == "focus" and hovered):
			flat.border_color = AgentColors.accent
		button.add_theme_stylebox_override(state, flat)
	pass


func on_pressed() -> void:
	color_picker.color = AgentColors.theme_color
	var anchor := button.global_position + Vector2(0.0, button.size.y + 6.0)
	popup.position = Vector2i(int(anchor.x - 140.0), int(anchor.y))
	popup.popup()
	pass


func on_picker_color_changed(new_color: Color) -> void:
	AgentColors.set_theme_color(new_color)
	pass


func on_theme_color_changed(_color: Color) -> void:
	color_picker.set_block_signals(true)
	color_picker.color = AgentColors.theme_color
	color_picker.set_block_signals(false)
	update_swatch(button.is_hovered())
	pass


func on_mouse_entered() -> void:
	update_swatch(true)
	pass


func on_mouse_exited() -> void:
	update_swatch(false)
	pass
