class_name ChatBubblePreview
extends Object

## Shared preview truncation for Result / Thinking bubbles.
## Keep the last PREVIEW_LINES, then the last PREVIEW_CHARS of that window.

const PREVIEW_LINES := 6
const PREVIEW_CHARS := 600


static func preview(s: String) -> String:
	var text := StringUtils.last_lines(s, PREVIEW_LINES)
	if text.length() <= PREVIEW_CHARS:
		return text
	return text.substr(text.length() - PREVIEW_CHARS)


static func extra_line_count(s: String) -> int:
	if StringUtils.is_empty(s):
		return 0
	return maxi(0, s.count("\n") + 1 - PREVIEW_LINES)


static func apply(rich_text: RichTextLabel, body: String) -> void:
	if not is_instance_valid(rich_text):
		return
	var text := preview(body)
	var header := rich_text.get_parent().get_child(0) as HBoxContainer
	var view_button := header.get_child(1) as Button
	var line_label := header.get_child(2) as Label
	view_button.visible = text != body
	var extra_lines := extra_line_count(body)
	line_label.visible = extra_lines > 0
	if extra_lines > 0:
		line_label.text = StringUtils.format("+{} line{}", extra_lines, "" if extra_lines == 1 else "s")
	rich_text.text = text
	rich_text.visible = StringUtils.is_not_blank(body)
	pass
