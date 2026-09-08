class_name ChatBubbleFlusher
extends RefCounted

## Batches chat bubble RichTextLabel updates; flushes every 100 ms via SchedulerBus.

const FLUSH_MS := 100
const TIMER_NAME := "agent_chat_bubble_flush"


class PendingItem:
	var rich_text: RichTextLabel = null
	var entry: ChatEntry = null

	func _init(p_rich_text: RichTextLabel, p_entry: ChatEntry) -> void:
		rich_text = p_rich_text
		entry = p_entry


var pending: Array[PendingItem] = []


func setup() -> void:
	SchedulerBus.schedule_at_fixed_rate(flush, FLUSH_MS, TIMER_NAME)
	pass


func enqueue(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	if rich_text == null or entry == null:
		return
	for item: PendingItem in pending:
		if item.rich_text == rich_text:
			item.entry = entry
			return
	pending.append(PendingItem.new(rich_text, entry))
	pass


func flush_now() -> void:
	flush()
	pass


func flush() -> void:
	if pending.is_empty():
		return
	var batch := pending
	pending = []
	for item: PendingItem in batch:
		if item.entry == null or item.rich_text == null or not is_instance_valid(item.rich_text):
			continue
		apply(item.rich_text, item.entry, true)
	AgentEvents.events.bubble_rich_text_flushed.emit()
	pass


static func apply(rich_text: RichTextLabel, entry: ChatEntry, incremental: bool = false) -> void:
	if entry.kind == ChatEntry.KIND_THINKING:
		ThinkingBubble.on_stream_delta(rich_text, entry)
		return
	refresh_rich_text(rich_text, entry, incremental)
	pass


static func refresh_rich_text(rich_text: RichTextLabel, entry: ChatEntry, incremental: bool = false) -> void:
	var markdown_enabled := MarkdownToggle.markdown_enabled_for_entry(entry)
	if incremental and not markdown_enabled:
		var cached := MarkdownUtils.get_raw_body_from_rich_text_label(rich_text)
		if entry.body.length() > cached.length() and entry.body.begins_with(cached):
			if rich_text.bbcode_enabled:
				rich_text.bbcode_enabled = false
			rich_text.append_text(entry.body.substr(cached.length()))
			rich_text.set_meta(MarkdownUtils.META_RAW_BODY, entry.body)
			return
	MarkdownUtils.set_rich_text_label_text(rich_text, entry.body, markdown_enabled, 0.0, AgentColors.code_block_bg_html())
	pass
