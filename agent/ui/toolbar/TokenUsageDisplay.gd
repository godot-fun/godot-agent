class_name TokenUsageDisplay
extends RefCounted

## Toolbar badge — current context length from the latest LLM request (left of the skill toggle).
##
## Shows [member OpenAiUsage.prompt_tokens] from the last API call (input context size, not session total).
## Color follows a traffic-light scale against [constant MAX_CONTEXT_TOKENS]:
##
## ```
## 0% ── accent→green gradient ──► 50% ── yellow ──► 75% ── orange ──► 90% ── red
## ```

## Reference context window for ratio / badge color (TODO: tie to OpenAiClient.model when known).
const MAX_CONTEXT_TOKENS := 128_000
const THRESHOLD_WARN := 0.50
const THRESHOLD_CAUTION := 0.75
const THRESHOLD_CRITICAL := 0.90

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
	# prompt_tokens = last request input size (current context length).
	label.text = StringUtils.format("{} tokens", format_count(usage.prompt_tokens))
	var pct := int(round(token_ratio(usage.prompt_tokens) * 100.0))
	label.tooltip_text = StringUtils.format(
		"Context: {} ({}%) · Completion: {} · Total: {} (last request)",
		usage.prompt_tokens,
		pct,
		usage.completion_tokens,
		usage.total_tokens
	)
	apply_badge_style(usage.prompt_tokens)
	pass


## Compact badge text: 999 → "999", 1500 → "1.5k", 12000 → "12k", 2M+ → "2M".
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
	label.add_theme_font_size_override("font_size", 12)
	apply_badge_style(current_prompt_tokens())
	pass


func current_prompt_tokens() -> int:
	var session_id := AgentSessionManager.active_session_id
	if session_id == AgentSessionManager.INVALID_SESSION_ID:
		return 0
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return 0
	return session.usage.prompt_tokens


## Text + panel tint share the same traffic-light color for the given context size.
func apply_badge_style(prompt_tokens: int) -> void:
	if wrap == null or label == null:
		return
	var color := color_for_tokens(prompt_tokens)
	label.add_theme_color_override("font_color", color)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.bg_color.a = 0.28 if AgentColors.is_dark() else 0.18
	style.border_color = color
	style.border_color.a = 0.75
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	wrap.add_theme_stylebox_override("panel", style)
	pass


static func token_ratio(n: int) -> float:
	return clampf(float(n) / float(MAX_CONTEXT_TOKENS), 0.0, 1.0)


static func color_for_tokens(n: int) -> Color:
	var ratio := token_ratio(n)
	if ratio >= THRESHOLD_CRITICAL:
		return AgentColors.error
	if ratio >= THRESHOLD_CAUTION:
		return AgentColors.file_tool_title
	if ratio >= THRESHOLD_WARN:
		return warn_yellow()
	# Low context: accent → success so an empty session is not fully green.
	var green_t := ratio / THRESHOLD_WARN
	var start := AgentColors.accent if AgentColors.is_dark() else AgentColors.accent.lightened(0.08)
	return start.lerp(AgentColors.success, green_t)


## 50–75% band — fixed yellow (between green and orange).
static func warn_yellow() -> Color:
	return Color(0.94, 0.84, 0.35) if AgentColors.is_dark() else Color("#CA8A04")
