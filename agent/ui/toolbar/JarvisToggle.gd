class_name JarvisToggle
extends RefCounted

## Toolbar toggle for the Jarvis 3D orb overlay during agent runs.

const SETTING_KEY := "agent_jarvis_orb_enabled"

static var jarvis_orb_enabled: bool = true

var button: Button


static func refresh_from_settings() -> void:
	jarvis_orb_enabled = Setting.get_bool(SETTING_KEY, true)
	pass


func setup(p_button: Button) -> void:
	refresh_from_settings()
	button = p_button
	button.toggled.connect(on_toggled)
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme(_is_dark: bool = false) -> void:
	refresh_from_settings()
	if button == null:
		return
	var tooltip := "Hide Jarvis orb overlay" if jarvis_orb_enabled else "Show Jarvis orb overlay"
	AgentToolbarButton.style(button, tooltip)
	button.set_block_signals(true)
	button.button_pressed = jarvis_orb_enabled
	button.set_block_signals(false)
	pass


func on_toggled(enabled: bool) -> void:
	jarvis_orb_enabled = enabled
	Setting.set_bool(SETTING_KEY, enabled)
	Setting.save()
	apply_theme()
	AgentEvents.events.jarvis_orb_changed.emit(enabled)
	pass
