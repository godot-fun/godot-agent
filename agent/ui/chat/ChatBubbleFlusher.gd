class_name ChatBubbleFlusher
extends RefCounted

## Coalesces streaming chat bubble UI updates.
## Agent tokens arrive faster than useful repaint rate — enqueue (rich_text, entry)
## pairs and flush every FLUSH_MS via SchedulerBus. Listeners use
## AgentEvents.bubble_rich_text_flushed to scroll or react after a batch.

const FLUSH_MS := 100
const TIMER_NAME := "agent_chat_bubble_flush"


## One pending sync target; entry.body mutates in place while rich_text stays fixed.
class PendingItem:
	var rich_text: RichTextLabel = null
	var entry: ChatEntry = null

	func _init(p_rich_text: RichTextLabel, p_entry: ChatEntry) -> void:
		rich_text = p_rich_text
		entry = p_entry


## Deduped by rich_text — same bubble only appears once per flush window.
var pending: Array[PendingItem] = []


func setup() -> void:
	SchedulerBus.schedule_at_fixed_rate(flush, FLUSH_MS, TIMER_NAME)
	pass


## Record a bubble that changed since the last flush; refresh entry pointer if already queued.
func enqueue(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	if rich_text == null or entry == null:
		return
	for item: PendingItem in pending:
		if item.rich_text == rich_text:
			item.entry = entry
			return
	pending.append(PendingItem.new(rich_text, entry))
	pass


## Drain pending immediately — e.g. agent run finished before the next timer tick.
func flush_now() -> void:
	flush()
	pass


func flush() -> void:
	if pending.is_empty():
		return
	# Swap so enqueue during flush goes to the next batch.
	var batch := pending
	pending = []
	for item: PendingItem in batch:
		if item.entry == null or item.rich_text == null or not is_instance_valid(item.rich_text):
			continue
		refresh_rich_text(item.rich_text, item.entry, true)
	await ThreadUtils.async_sleep(FLUSH_MS)
	AgentEvents.events.chat_bubble_flushed.emit()
	pass


## Push entry.body into the bubble RichTextLabel.
## incremental=true appends plain-text deltas when markdown is off (streaming agent reply).
static func refresh_rich_text(rich_text: RichTextLabel, entry: ChatEntry, incremental: bool = false) -> void:
	## Thinking / Result use their own preview rules; other kinds honor MarkdownToggle.
	if entry.kind == ChatEntry.KIND_THINKING:
		ThinkingBubble.on_stream_delta(rich_text, entry)
		return
	if entry.kind == ChatEntry.KIND_RESULT:
		ResultBubble.refresh(rich_text, entry)
		return
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	var markdown_enabled := MarkdownToggle.markdown_enabled_for_entry(entry)
	if incremental and not markdown_enabled:
		var cached := MarkdownUtils.get_raw_body_from_rich_text_label(rich_text)
		if entry.body.length() > cached.length() and entry.body.begins_with(cached):
			if rich_text.bbcode_enabled:
				rich_text.bbcode_enabled = false
			rich_text.append_text(entry.body.substr(cached.length()))
			rich_text.set_meta(MarkdownUtils.META_RAW_BODY, entry.body)
			return
	# Full re-render — markdown on, or body changed in a non-prefix way.
	MarkdownUtils.set_rich_text_label_text(rich_text, entry.body, markdown_enabled, 0.0, AgentColors.code_block_bg_html())
	pass
