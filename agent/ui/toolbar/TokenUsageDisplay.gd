class_name TokenUsageDisplay
extends RefCounted

## Toolbar label — cumulative session token usage (left of the skill toggle).

var label: Label


func setup(p_label: Label) -> void:
	label = p_label
	AgentEvents.events.theme_changed.connect(apply_theme)
	AgentEvents.events.session_selected.connect(refresh)
	AgentEvents.events.message_complete.connect(on_message_complete)
	apply_theme()
	refresh(AgentSessionManager.active_session_id)
	pass


func on_message_complete(session_id: int, _usage: OpenAiUsage) -> void:
	if session_id != AgentSessionManager.active_session_id:
		return
	refresh(session_id)
	pass


func refresh(session_id: int = AgentSessionManager.active_session_id) -> void:
	if label == null:
		return
	if session_id == AgentSessionManager.INVALID_SESSION_ID:
		label.text = ""
		label.tooltip_text = ""
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		label.text = ""
		label.tooltip_text = ""
		return
	label.text = format_usage(session.usage)
	label.tooltip_text = format_tooltip(session.usage)
	pass


func apply_theme(_is_dark: bool = false) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", AgentColors.toolbar_muted)
	label.add_theme_font_size_override("font_size", 11)
	pass


static func format_usage(usage: OpenAiUsage) -> String:
	return StringUtils.format("{} tokens", format_count(usage.total_tokens))


static func format_tooltip(usage: OpenAiUsage) -> String:
	return StringUtils.format(
		"Prompt: {} · Completion: {} · Total: {}",
		usage.prompt_tokens,
		usage.completion_tokens,
		usage.total_tokens
	)


static func format_count(n: int) -> String:
	if n >= 1_000_000:
		return StringUtils.format("{}M", n / 1_000_000)
	if n >= 10_000:
		return StringUtils.format("{}k", n / 1000)
	if n >= 1000:
		return StringUtils.format("{}k", snappedf(float(n) / 1000.0, 0.1))
	return str(n)
