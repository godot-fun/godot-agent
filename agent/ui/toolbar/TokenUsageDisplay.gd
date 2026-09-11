class_name TokenUsageDisplay
extends RefCounted

## Toolbar badge — current context length from the latest LLM request (left of the skill toggle).

var wrap: PanelContainer
var label: Label


func setup(p_wrap: PanelContainer) -> void:
	wrap = p_wrap
	label = wrap.get_child(0) as Label
	AgentEvents.events.theme_changed.connect(apply_theme)
	AgentEvents.events.session_selected.connect(refresh)
	AgentEvents.events.message_complete.connect(on_message_complete)
	refresh(AgentSessionManager.active_session_id)
	apply_theme()
	pass


func on_message_complete(session_id: int, _usage: OpenAiUsage) -> void:
	if session_id == AgentSessionManager.active_session_id:
		refresh(session_id)
	pass


func refresh(session_id: int = AgentSessionManager.active_session_id) -> void:
	if label == null or session_id == AgentSessionManager.INVALID_SESSION_ID:
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var usage := session.usage
	label.text = StringUtils.format("{} tokens", format_count(usage.prompt_tokens))
	label.tooltip_text = StringUtils.format(
		"Context: {} · Completion: {} · Total: {} (last request)",
		usage.prompt_tokens,
		usage.completion_tokens,
		usage.total_tokens
	)
	pass


static func format_count(n: int) -> String:
	if n >= 1_000_000:
		return StringUtils.format("{}M", n / 1_000_000)
	if n >= 10_000:
		return StringUtils.format("{}k", n / 1000)
	if n >= 1000:
		return StringUtils.format("{}k", snappedf(float(n) / 1000.0, 0.1))
	return str(n)


func apply_theme(_is_dark: bool = false) -> void:
	if wrap == null or label == null:
		return
	label.add_theme_color_override("font_color", AgentColors.accent)
	label.add_theme_font_size_override("font_size", 12)
	var style := StyleBoxFlat.new()
	if AgentColors.is_dark():
		style.bg_color = AgentColors.accent.darkened(0.72)
	else:
		style.bg_color = AgentColors.accent.lightened(0.58)
	style.bg_color.a = 0.35 if AgentColors.is_dark() else 0.25
	style.border_color = AgentColors.accent
	style.border_color.a = 0.65
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	wrap.add_theme_stylebox_override("panel", style)
	pass
