class_name AgentTextPopup
extends Window

## Shared read-only text popup for Code Agent.
##
## Two close modes:
## - One-shot (`destroy_on_close = true`, default) — thinking / result full view.
##   `open()` / `open_entry()` create a window, Esc or the close button `queue_free`s it.
## - Reusable (`destroy_on_close = false`) — system log. Keep one instance, `hide()` on
##   close, `popup_centered_fit()` + `set_text()` on the next open.

const EDGE_MARGIN := 64
const WIDTH_RATIO := 0.76
const HEIGHT_RATIO := 0.78
const TEXT_MARGIN := 12

## When true, close destroys this window. When false, close only hides it for reuse.
var destroy_on_close := true
var text_edit: TextEdit


# ---------------------------------------------------------------------------
# One-shot helpers (thinking / result bubbles)
# ---------------------------------------------------------------------------

## Create, parent, fill, and show a popup. Used by `open_entry` and any other one-shot text view.
static func open(host: Node, title: String, text: String, anchor: Control = null) -> AgentTextPopup:
	var popup := AgentTextPopup.new()
	popup.title = title
	host.add_child(popup)
	popup.set_text(text)
	popup.popup_centered_fit(anchor)
	return popup


## Open the full `ChatEntry.body` from a bubble header button. `anchor` sizes against the chat viewport.
static func open_entry(entry: ChatEntry, anchor: Control) -> void:
	if entry == null or anchor == null or not is_instance_valid(anchor):
		return
	var tree := anchor.get_tree()
	if tree == null:
		return
	var title := entry.title if not StringUtils.is_blank(entry.title) else "Full view"
	open(tree.root, title, entry.body, anchor)
	pass


# ---------------------------------------------------------------------------
# Window chrome
# ---------------------------------------------------------------------------

func _init() -> void:
	# Hidden until popup_centered_fit(); otherwise add_child would flash a default-sized window.
	transient = true
	visible = false
	min_size = Vector2i(840, 520)
	close_requested.connect(on_close_requested)
	window_input.connect(on_window_input)

	text_edit = TextEdit.new()
	text_edit.editable = false
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_edit.offset_left = TEXT_MARGIN
	text_edit.offset_top = TEXT_MARGIN
	text_edit.offset_right = -TEXT_MARGIN
	text_edit.offset_bottom = -TEXT_MARGIN
	text_edit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text_edit.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(text_edit)
	apply_theme()
	pass


func apply_theme() -> void:
	text_edit.add_theme_font_override("font", Fonts.regular())
	text_edit.add_theme_color_override("font_color", AgentColors.chat_text_muted)
	pass


func set_text(text: String) -> void:
	text_edit.text = text
	# Jump to the end so a long log / thinking dump shows the latest lines first.
	text_edit.scroll_vertical = text_edit.get_line_count()
	pass


# ---------------------------------------------------------------------------
# Size & close
# ---------------------------------------------------------------------------

## Size relative to the main viewport (not this Window), then center.
## Pass a Control in the main scene when available; otherwise fall back to the scene tree root.
func popup_centered_fit(anchor: Control = null) -> void:
	var viewport_size := resolve_viewport_size(anchor)
	var max_w := int(viewport_size.x) - EDGE_MARGIN * 2
	var max_h := int(viewport_size.y) - EDGE_MARGIN * 2
	size = Vector2i(
		clampi(int(viewport_size.x * WIDTH_RATIO), min_size.x, max_w),
		clampi(int(viewport_size.y * HEIGHT_RATIO), min_size.y, max_h),
	)
	popup_centered()
	pass


func resolve_viewport_size(anchor: Control) -> Vector2:
	# Window is itself a Viewport, so get_viewport() on this node is the popup — use the anchor / root instead.
	if anchor != null and is_instance_valid(anchor):
		return anchor.get_viewport().get_visible_rect().size
	if get_tree() != null:
		return get_tree().root.get_visible_rect().size
	return Vector2(min_size)


func on_close_requested() -> void:
	if destroy_on_close:
		queue_free()
		return
	hide()
	pass


func on_window_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			on_close_requested()
			set_input_as_handled()
	pass
