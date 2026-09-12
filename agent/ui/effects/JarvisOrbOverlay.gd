class_name JarvisOrbOverlay
extends ColorRect

## Full-screen vignette behind the orb — non-interactive.

var theme_dark: bool = true
var strength: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	apply_theme(AgentColors.is_dark())
	set_strength(0.0)
	pass


func apply_theme(dark: bool) -> void:
	theme_dark = dark
	set_strength(strength)
	pass


func set_strength(value: float) -> void:
	strength = clampf(value, 0.0, 0.78)
	var tint := OrbTheme.vignette_color(theme_dark)
	color = Color(tint.r, tint.g, tint.b, strength)
	pass
