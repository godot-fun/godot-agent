class_name JarvisToggle
extends RefCounted

## Toolbar toggle for the Jarvis 3D orb overlay during agent runs.

const SETTING_KEY := "agent_jarvis_orb_enabled"
const BUTTON_SIZE := 28
const CORNER_RADIUS := 14
const ICON_DRAW_SIZE := 24
const ICON_DISPLAY_SIZE := 24
const RING_COUNT := 3
## Integer pixel radii on ICON_DRAW_SIZE canvas (Bresenham outline).
const RING_RADII: Array[int] = [2, 7, 11]

static var jarvis_orb_enabled: bool = true

var button: Button


static func refresh_from_settings() -> void:
	jarvis_orb_enabled = Setting.get_bool(SETTING_KEY, true)
	pass


func setup(p_button: Button) -> void:
	refresh_from_settings()
	button = p_button
	button.text = ""
	button.toggled.connect(on_toggled)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	AgentEvents.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme(_is_dark: bool = false) -> void:
	refresh_from_settings()
	if button == null:
		return
	var tooltip := (
		"Hide run animation"
		if jarvis_orb_enabled
		else "Show run animation while agent works"
	)
	AgentToolbarButton.style(button, tooltip, CORNER_RADIUS)
	apply_equal_icon_margins(2)
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", ICON_DISPLAY_SIZE)
	button.add_theme_constant_override("icon_max_height", ICON_DISPLAY_SIZE)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	update_icon(button.is_hovered())
	button.set_block_signals(true)
	button.button_pressed = jarvis_orb_enabled
	button.set_block_signals(false)
	pass


func apply_equal_icon_margins(margin: int) -> void:
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := button.get_theme_stylebox(state_name) as StyleBoxFlat
		if box == null:
			continue
		box.content_margin_left = margin
		box.content_margin_right = margin
		box.content_margin_top = margin
		box.content_margin_bottom = margin
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


func update_icon(hovered: bool) -> void:
	var icon_color := AgentColors.toolbar_muted
	if jarvis_orb_enabled:
		icon_color = AgentColors.accent if AgentColors.is_dark() else AgentColors.accent.darkened(0.15)
	if hovered:
		icon_color = AgentColors.toolbar_title
	button.icon = make_concentric_rings_icon(ICON_DRAW_SIZE, icon_color)
	pass


func make_concentric_rings_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2i(size / 2, size / 2)
	for ring_index in range(RING_COUNT):
		draw_circle_outline(img, center, RING_RADII[ring_index], color)
	return ImageTexture.create_from_image(img)


func draw_circle_outline(img: Image, center: Vector2i, radius: int, col: Color) -> void:
	if radius <= 0:
		return
	var x := 0
	var y := radius
	var decision := 3 - 2 * radius
	plot_circle_octants(img, center, x, y, col)
	while x <= y:
		if decision < 0:
			decision += 4 * x + 6
		else:
			decision += 4 * (x - y) + 10
			y -= 1
		x += 1
		plot_circle_octants(img, center, x, y, col)
	pass


func plot_circle_octants(img: Image, center: Vector2i, x: int, y: int, col: Color) -> void:
	set_icon_pixel(img, center.x + x, center.y + y, col)
	set_icon_pixel(img, center.x - x, center.y + y, col)
	set_icon_pixel(img, center.x + x, center.y - y, col)
	set_icon_pixel(img, center.x - x, center.y - y, col)
	set_icon_pixel(img, center.x + y, center.y + x, col)
	set_icon_pixel(img, center.x - y, center.y + x, col)
	set_icon_pixel(img, center.x + y, center.y - x, col)
	set_icon_pixel(img, center.x - y, center.y - x, col)
	pass


func set_icon_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)
	pass


func on_toggled(enabled: bool) -> void:
	jarvis_orb_enabled = enabled
	Setting.set_bool(SETTING_KEY, enabled)
	Setting.save()
	apply_theme()
	AgentEvents.events.jarvis_orb_changed.emit(enabled)
	pass
