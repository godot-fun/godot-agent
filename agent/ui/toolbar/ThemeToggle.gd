class_name ThemeToggle
extends RefCounted

## Circular toolbar button for switching dark / light color schemes.

const BUTTON_SIZE := 28
const ICON_SIZE := 14

var button: Button


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(p_button: Button) -> void:
	button = p_button
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------

func apply_theme(_is_dark: bool = false) -> void:
	var tooltip := "Switch to light theme" if AgentColors.is_dark() else "Switch to dark theme"
	AgentToolbarButton.style(button, tooltip, BUTTON_SIZE / 2)
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.add_theme_constant_override("icon_max_height", ICON_SIZE)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_icon(button.is_hovered())
	pass


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func on_pressed() -> void:
	AgentColors.toggle_theme()
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


# ---------------------------------------------------------------------------
# Icons
# ---------------------------------------------------------------------------

func update_icon(hovered: bool) -> void:
	var show_moon := not AgentColors.is_dark()
	var icon_color := AgentColors.toolbar_title
	if hovered:
		icon_color = Color(1.0, 0.92, 0.55) if AgentColors.is_dark() else Color.WHITE
	elif not AgentColors.is_dark():
		icon_color = AgentColors.accent
	button.icon = make_icon(ICON_SIZE, icon_color, show_moon)
	pass


func make_icon(size: int, color: Color, show_moon: bool) -> ImageTexture:
	if show_moon:
		return make_moon_icon(size, color)
	return make_sun_icon(size, color)


func make_sun_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size / 2.0
	var cy := size / 2.0
	var core_radius := size * 0.16
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= core_radius:
				img.set_pixel(x, y, color)
	for ray_index in range(8):
		var angle := TAU * float(ray_index) / 8.0
		var inner := core_radius + 1.5
		var outer := size * 0.42
		var ray_half := maxf(0.8, size * 0.045)
		for step in range(int(outer - inner)):
			var ray_radius := inner + step
			var px := cx + cos(angle) * ray_radius
			var py := cy + sin(angle) * ray_radius
			var tangent_x := -sin(angle)
			var tangent_y := cos(angle)
			for offset in range(-int(ray_half), int(ray_half) + 1):
				var draw_x := int(round(px + tangent_x * offset))
				var draw_y := int(round(py + tangent_y * offset))
				if draw_x >= 0 and draw_x < size and draw_y >= 0 and draw_y < size:
					img.set_pixel(draw_x, draw_y, color)
	return ImageTexture.create_from_image(img)


func make_moon_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size * 0.46
	var cy := size / 2.0
	var outer_radius := size * 0.34
	var cut_cx := size * 0.58
	var cut_radius := size * 0.30
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			var in_outer := dx * dx + dy * dy <= outer_radius * outer_radius
			var cut_dx := x - cut_cx
			var cut_dy := y - cy
			var in_cut := cut_dx * cut_dx + cut_dy * cut_dy <= cut_radius * cut_radius
			if in_outer and not in_cut:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
