class_name OrbTheme
extends RefCounted

## Dark / light palettes for the Jarvis orb overlay.

class RenderSettings:
	var glow_intensity: float = 1.0
	var glow_strength: float = 0.85
	var glow_bloom: float = 0.28
	var adjustment_brightness: float = 1.05
	var neuron_emission_scale: float = 1.65
	var filament_emission_scale: float = 1.45
	var orb_overlay_alpha: float = 0.88


static func is_dark() -> bool:
	return AgentColors.is_dark()


static func neuron_color_for(phase: OrbPhase.Phase, dark: bool = is_dark()) -> Color:
	if dark:
		return _dark_neuron_color(phase)
	return _light_neuron_color(phase)


static func filament_color_for(phase: OrbPhase.Phase, dark: bool = is_dark()) -> Color:
	if dark:
		return _dark_filament_color(phase)
	return _light_filament_color(phase)


static func char_color_for(phase: OrbPhase.Phase, dark: bool = is_dark()) -> Color:
	var neuron := neuron_color_for(phase, dark)
	if dark:
		return Color(
			clampf(neuron.r * 1.08, 0.0, 1.0),
			clampf(neuron.g * 1.08, 0.0, 1.0),
			clampf(neuron.b * 1.08, 0.0, 1.0),
			1.0,
		)
	return neuron


static func char_outline_color(dark: bool = is_dark()) -> Color:
	if dark:
		return Color(0.0, 0.35, 0.55, 0.92)
	return Color(0.0, 0.12, 0.22, 0.75)


static func vignette_color(dark: bool = is_dark()) -> Color:
	if dark:
		return Color(0.0, 0.03, 0.06, 1.0)
	return Color(0.9, 0.94, 0.99, 1.0)


static func vignette_strength(dark: bool = is_dark()) -> float:
	return 0.42 if dark else 0.18


static func render_settings(dark: bool = is_dark()) -> RenderSettings:
	var settings := RenderSettings.new()
	if dark:
		settings.glow_intensity = 1.72
		settings.glow_strength = 1.05
		settings.glow_bloom = 0.46
		settings.adjustment_brightness = 1.14
		settings.neuron_emission_scale = 2.15
		settings.filament_emission_scale = 1.95
		settings.orb_overlay_alpha = 0.92
	else:
		settings.glow_intensity = 1.05
		settings.glow_strength = 0.72
		settings.glow_bloom = 0.2
		settings.adjustment_brightness = 1.0
		settings.neuron_emission_scale = 1.55
		settings.filament_emission_scale = 1.25
		settings.orb_overlay_alpha = 0.86
	return settings


static func _dark_neuron_color(phase: OrbPhase.Phase) -> Color:
	match phase:
		OrbPhase.Phase.REASONING:
			return Color(0.84, 0.58, 1.0, 0.98)
		OrbPhase.Phase.GENERATING:
			return Color(0.42, 1.0, 1.0, 0.98)
		OrbPhase.Phase.TOOL_EXEC:
			return Color(1.0, 0.86, 0.42, 0.98)
		OrbPhase.Phase.SUCCESS:
			return Color(0.35, 1.0, 0.82, 0.98)
		OrbPhase.Phase.ERROR:
			return Color(1.0, 0.42, 0.55, 0.98)
		OrbPhase.Phase.AWAKE, OrbPhase.Phase.TURN_COOLDOWN:
			return Color(0.48, 1.0, 1.0, 0.98)
		_:
			return Color(0.42, 0.96, 1.0, 0.82)


static func _light_neuron_color(phase: OrbPhase.Phase) -> Color:
	match phase:
		OrbPhase.Phase.REASONING:
			return Color(0.66, 0.33, 0.97, 0.88)
		OrbPhase.Phase.GENERATING:
			return Color(0.0, 0.72, 0.82, 0.88)
		OrbPhase.Phase.TOOL_EXEC:
			return Color(0.86, 0.62, 0.12, 0.9)
		OrbPhase.Phase.SUCCESS:
			return Color(0.0, 0.72, 0.55, 0.88)
		OrbPhase.Phase.ERROR:
			return Color(0.88, 0.18, 0.32, 0.9)
		OrbPhase.Phase.AWAKE, OrbPhase.Phase.TURN_COOLDOWN:
			return Color(0.0, 0.68, 0.78, 0.88)
		_:
			return Color(0.0, 0.62, 0.72, 0.72)


static func _dark_filament_color(phase: OrbPhase.Phase) -> Color:
	match phase:
		OrbPhase.Phase.REASONING:
			return Color(1.0, 0.58, 0.92, 0.82)
		OrbPhase.Phase.GENERATING:
			return Color(0.92, 0.48, 1.0, 0.84)
		OrbPhase.Phase.TOOL_EXEC:
			return Color(0.52, 0.82, 1.0, 0.82)
		OrbPhase.Phase.SUCCESS:
			return Color(1.0, 0.9, 0.52, 0.8)
		OrbPhase.Phase.ERROR:
			return Color(1.0, 0.62, 0.28, 0.82)
		OrbPhase.Phase.AWAKE, OrbPhase.Phase.TURN_COOLDOWN:
			return Color(1.0, 0.55, 0.98, 0.84)
		_:
			return Color(0.95, 0.45, 1.0, 0.72)


static func _light_filament_color(phase: OrbPhase.Phase) -> Color:
	match phase:
		OrbPhase.Phase.REASONING:
			return Color(0.82, 0.28, 0.72, 0.58)
		OrbPhase.Phase.GENERATING:
			return Color(0.62, 0.22, 0.82, 0.58)
		OrbPhase.Phase.TOOL_EXEC:
			return Color(0.22, 0.48, 0.82, 0.58)
		OrbPhase.Phase.SUCCESS:
			return Color(0.82, 0.66, 0.18, 0.55)
		OrbPhase.Phase.ERROR:
			return Color(0.88, 0.38, 0.12, 0.58)
		OrbPhase.Phase.AWAKE, OrbPhase.Phase.TURN_COOLDOWN:
			return Color(0.58, 0.22, 0.82, 0.58)
		_:
			return Color(0.52, 0.18, 0.72, 0.52)
