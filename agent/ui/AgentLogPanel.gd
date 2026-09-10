class_name AgentLogPanel
extends RefCounted

## Toolbar Log button plus a reusable `AgentTextPopup` that tails the system log file.
## Unlike thinking/result popups, this window is created once and hidden — not freed — on close.

const REFRESH_MS := 2000
const REFRESH_TIMER := "code_agent_log_refresh"

var button: Button
var popup: AgentTextPopup


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(p_button: Button, host: Node) -> void:
	button = p_button
	popup = AgentTextPopup.new()
	popup.title = "System Log"
	# Keep the same window so the refresh timer can reuse it; Esc / close only hides.
	popup.destroy_on_close = false
	host.add_child(popup)
	button.pressed.connect(on_pressed)
	SchedulerBus.schedule_at_fixed_rate(refresh, REFRESH_MS, REFRESH_TIMER)
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


# ---------------------------------------------------------------------------
# Theme & window
# ---------------------------------------------------------------------------

func apply_theme(_is_dark: bool = false) -> void:
	AgentToolbarButton.style(button, "View system log")
	if popup != null:
		popup.apply_theme()
	pass


func on_pressed() -> void:
	if popup.visible:
		popup.hide()
		return
	popup.popup_centered_fit()
	refresh()
	pass


# ---------------------------------------------------------------------------
# Log refresh
# ---------------------------------------------------------------------------

func refresh() -> void:
	if popup == null or not popup.visible:
		return
	popup.set_text(LoggerHelper.tail_log())
	pass
