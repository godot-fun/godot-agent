class_name AgentColors
extends RefCounted

## Cursor / Codex inspired palettes for Code Agent UI (dark + light).

enum ColorScheme {
	DARK,
	LIGHT,
}

const SETTING_KEY := "agent_dark_theme"

static var current_scheme: ColorScheme = ColorScheme.DARK

static var sidebar: Color
static var sidebar_border: Color
static var sidebar_title: Color
static var sidebar_text: Color
static var sidebar_muted: Color
static var sidebar_row_selected: Color
static var sidebar_row_hover: Color
static var sidebar_row_accent: Color
static var toolbar: Color
static var toolbar_border: Color
static var toolbar_title: Color
static var toolbar_muted: Color
static var toolbar_button: Color
static var chat: Color
static var chat_text: Color
static var chat_text_muted: Color
static var chat_bubble_border: Color
static var chat_input: Color
static var chat_input_border: Color
static var panel: Color
static var accent: Color
static var user_bubble: Color
static var assistant_bubble: Color
static var system_bubble: Color
static var thinking_bubble: Color
static var tool_bubble: Color
static var file_tool_bubble: Color
static var file_tool_title: Color
static var result_bubble: Color
static var success: Color
static var error: Color
static var system_title: Color
static var thinking_title: Color
static var code_block_bg: Color


# ---------------------------------------------------------------------------
# Theme API
# ---------------------------------------------------------------------------

static func _static_init() -> void:
	apply_dark_palette()
	pass


static func is_dark() -> bool:
	return current_scheme == ColorScheme.DARK


static func load_saved_theme() -> void:
	var use_dark := Setting.get_bool(SETTING_KEY, true)
	apply_color_scheme(ColorScheme.DARK if use_dark else ColorScheme.LIGHT, false, false)


static func toggle_theme() -> void:
	apply_color_scheme(ColorScheme.LIGHT if is_dark() else ColorScheme.DARK)


static func apply_color_scheme(scheme: ColorScheme, persist: bool = true, emit_signal: bool = true) -> void:
	current_scheme = scheme
	if scheme == ColorScheme.DARK:
		apply_dark_palette()
	else:
		apply_light_palette()
	if persist:
		Setting.set_bool(SETTING_KEY, scheme == ColorScheme.DARK)
		Setting.save()
	if emit_signal:
		AgentEvents.events.theme_changed.emit(scheme == ColorScheme.DARK)


static func code_block_bg_html() -> String:
	return code_block_bg.to_html(false)


## read / write / edit share one amber file-tool color; other tools stay green.
static func is_file_tool(tool_name: String) -> bool:
	return tool_name == ReadTool.NAME or tool_name == WriteTool.NAME or tool_name == EditTool.NAME


static func tool_bubble_color(tool_name: String) -> Color:
	return file_tool_bubble if is_file_tool(tool_name) else tool_bubble


static func tool_title_color(tool_name: String) -> Color:
	return file_tool_title if is_file_tool(tool_name) else success


# ---------------------------------------------------------------------------
# Dark palette
# ---------------------------------------------------------------------------

static func apply_dark_palette() -> void:
	sidebar = Color(0.10, 0.11, 0.13)
	sidebar_border = Color(0.18, 0.20, 0.24)
	sidebar_title = Color(0.50, 0.52, 0.58)
	sidebar_text = Color(0.90, 0.91, 0.93)
	sidebar_muted = Color(0.55, 0.57, 0.62)
	sidebar_row_selected = Color(0.14, 0.15, 0.18)
	sidebar_row_hover = Color(0.12, 0.13, 0.16)
	sidebar_row_accent = Color(0.35, 0.65, 0.95)
	toolbar = Color(0.06, 0.07, 0.09)
	toolbar_border = Color(0.16, 0.18, 0.22)
	toolbar_title = Color(0.93, 0.94, 0.96)
	toolbar_muted = Color(0.52, 0.54, 0.60)
	toolbar_button = Color(0.11, 0.12, 0.15)
	chat = Color(0.07, 0.08, 0.10)
	chat_text = Color(0.90, 0.91, 0.93)
	chat_text_muted = Color(0.55, 0.57, 0.62)
	chat_bubble_border = Color(0.22, 0.24, 0.28)
	chat_input = Color(0.12, 0.13, 0.16)
	chat_input_border = Color(0.22, 0.24, 0.28)
	panel = Color(0.12, 0.13, 0.16)
	accent = Color(0.35, 0.65, 0.95)
	user_bubble = Color(0.16, 0.22, 0.32)
	assistant_bubble = Color(0.14, 0.15, 0.18)
	system_bubble = Color(0.10, 0.13, 0.19)
	thinking_bubble = Color(0.17, 0.13, 0.22)
	tool_bubble = Color(0.14, 0.20, 0.16)
	file_tool_bubble = Color(0.22, 0.16, 0.10)
	file_tool_title = Color(0.95, 0.72, 0.38)
	result_bubble = Color(0.13, 0.16, 0.20)
	success = Color(0.30, 0.78, 0.45)
	error = Color(0.85, 0.30, 0.30)
	system_title = Color(0.55, 0.68, 0.88)
	thinking_title = Color(0.72, 0.58, 0.88)
	code_block_bg = Color(0.07, 0.08, 0.10)


# ---------------------------------------------------------------------------
# Light palette
# ---------------------------------------------------------------------------

static func apply_light_palette() -> void:
	sidebar = Color("#F3F3F4")
	sidebar_border = Color("#E4E4E7")
	sidebar_title = Color("#71717A")
	sidebar_text = Color("#18181B")
	sidebar_muted = Color("#71717A")
	sidebar_row_selected = Color("#FFFFFF")
	sidebar_row_hover = Color("#ECECEF")
	sidebar_row_accent = Color("#2563EB")
	toolbar = Color("#F3F3F4")
	toolbar_border = Color("#E4E4E7")
	toolbar_title = Color("#18181B")
	toolbar_muted = Color("#71717A")
	toolbar_button = Color("#F4F4F5")
	chat = Color("#FAFAFA")
	chat_text = Color("#18181B")
	chat_text_muted = Color("#71717A")
	chat_bubble_border = Color("#E4E4E7")
	chat_input = Color("#FFFFFF")
	chat_input_border = Color("#E4E4E7")
	panel = Color("#FFFFFF")
	accent = Color("#2563EB")
	user_bubble = Color("#EFF6FF")
	assistant_bubble = Color("#FFFFFF")
	system_bubble = Color("#F4F4F5")
	thinking_bubble = Color("#F5F3FF")
	tool_bubble = Color("#F0FDF4")
	file_tool_bubble = Color("#FFF7ED")
	file_tool_title = Color("#EA580C")
	result_bubble = Color("#F4F4F5")
	success = Color("#16A34A")
	error = Color("#DC2626")
	system_title = Color("#4F46E5")
	thinking_title = Color("#7C3AED")
	code_block_bg = Color("#f0f1f5")
