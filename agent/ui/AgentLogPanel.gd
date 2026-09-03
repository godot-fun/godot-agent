class_name AgentLogPanel
extends RefCounted

## Toolbar log button and popup window for tailing the system log file.

const REFRESH_MS := 2000
const REFRESH_TIMER := "code_agent_log_refresh"

var button: Button
var log_window: Window
var log_output: TextEdit


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(p_button: Button, p_log_window: Window, p_log_output: TextEdit) -> void:
	button = p_button
	log_window = p_log_window
	log_output = p_log_output
	button.pressed.connect(on_pressed)
	log_window.close_requested.connect(on_close_requested)
	log_window.window_input.connect(on_window_key_input)
	SchedulerBus.schedule_at_fixed_rate(refresh, REFRESH_MS, REFRESH_TIMER)
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


# ---------------------------------------------------------------------------
# Theme & window
# ---------------------------------------------------------------------------

func apply_theme(_is_dark: bool = false) -> void:
	AgentToolbarButton.style(button, "View system log")
	pass


func on_pressed() -> void:
	if log_window.visible:
		log_window.hide()
		return
	var viewport_size := log_window.get_viewport().get_visible_rect().size
	log_window.size = Vector2i(
		int(viewport_size.x * 0.68),
		int(viewport_size.y * 0.78),
	)
	log_window.popup_centered()
	refresh()
	pass


# ---------------------------------------------------------------------------
# Log refresh
# ---------------------------------------------------------------------------

func refresh() -> void:
	if not log_window.visible:
		return
	log_output.text = LoggerHelper.tail_log()
	log_output.scroll_vertical = log_output.get_line_count()
	pass


func on_close_requested() -> void:
	log_window.hide()
	pass


func on_window_key_input(event: InputEvent) -> void:
	if not log_window.visible:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			on_close_requested()
			log_window.set_input_as_handled()
	pass
