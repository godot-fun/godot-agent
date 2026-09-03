class_name MarkdownUtils
extends Object

## Markdown → RichTextLabel BBCode.
##
## Syntax map
## ----------
## `#`–`###### Title`     → `[font_size=N]Title[/font_size]`
## ` ``` / ~~~ ` fence    → `[table=1][cell border=… bg=…][code]…[/code][/cell][/table]`
## `` `code` ``           → `[code]code[/code]`
## `---` `***` `___`      → centered rule line
## `> quote`              → `[indent][color]▎[/color] [color]quote[/color][/indent]`
## `-` `*` `+` item       → `• item`  (`- [ ]` / `- [x]` → ☐ / ☑)
## `1. item` / `1) item`  → `1. item`
## `**bold**` / `__bold__` → `[b]bold[/b]`
## `*italic*` / `_italic_` → `[i]italic[/i]`
## `***both***`           → `[b][i]both[/i][/b]`
## `~~strike~~`           → `[s]strike[/s]`
## `<u>text</u>`          → `[u]text[/u]` (inline HTML, not CommonMark)
## `[label](url)`         → `[url=url]label[/url]`
## `![alt](url)`          → `[img]url[/img]`
## GFM `\| col \|` table  → `[table=N][cell border=…]…[/cell][/table]` (header row bold + bg)
## leftover `[` / `]`     → `[lb]` / `[rb]` (incl. literal `[b]`, `[url=…]`)
##
## Block pass then inline pass. Block order is load-bearing: fences first so
## inner `---` / `#` stay literal; HR before lists so `---` is not `- --`.
##
## Inline replacements are stashed via [method protect] as U+E000/index/U+E001
## tokens so later regexes cannot rematch already-built tags
## (`[code]**x**[/code]` must not become bold). Whatever is left outside a token is
## bracket-escaped before restore, so a literal `[b]` in the source stays text
## instead of becoming a live tag. Restore runs high index → low because an outer
## token's body holds the inner tokens it was built from.

# h1–h6; body uses RichTextLabel default size
const HEADING_FONT_SIZES: PackedInt32Array = [32, 28, 24, 22, 20, 18]
const HORIZONTAL_RULE_LINE := "[center]────────────────[/center]"

# Private-use tokens; must not appear in source markdown.
# ESCAPE_SENTINEL: `[lb]` itself contains `]`, so `[`/`]` cannot be replaced in place.
const PROTECT_START := "\uE000"
const PROTECT_END := "\uE001"
const ESCAPE_SENTINEL := "\uE002"
const NBSP := "\u00A0"
# RichTextLabel `[cell]` has no border by default; these draw the grid on chat bubbles.
const TABLE_CELL_BORDER := "#5a5e6a"
const TABLE_HEADER_BG := "#ffffff14"
const TABLE_CELL_PADDING := "8,4,8,4"
# Fenced code block: dark fill + border frame.
const CODE_BLOCK_BG := "#121418"
const CODE_BLOCK_BORDER := "#5a5e6a"
const CODE_BLOCK_PADDING := "6,6,6,6"
const BLOCKQUOTE_BAR := "#59a5f2"
const BLOCKQUOTE_TEXT := "#8c919e"
# Dest allows one `(...)` nest (Wikipedia). Title is optional `"..."` / `'...'`.
const LINK_DEST := "((?:<[^>]+>|[^()\\s]+|\\([^)]*\\))+)"
const LINK_TITLE := "(?:\\s+(?:\"[^\"]*\"|'[^']*'))?"

# Flanking: marker must touch the word (`*em*`), so `3 * 4 * 5` stays plain.
static var re_inline_code: RegEx = compile_regex("`([^`\\n]+)`") # `code` → [code]
static var re_image: RegEx = compile_regex("!\\[([^\\]]*)\\]\\(" + LINK_DEST + LINK_TITLE + "\\)") # ![alt](url) → [img]
static var re_link: RegEx = compile_regex("\\[([^\\]]+)\\]\\(" + LINK_DEST + LINK_TITLE + "\\)") # [label](url) → [url]
static var re_dunder: RegEx = compile_regex("(?<![A-Za-z0-9])__[A-Za-z_][A-Za-z0-9_]*__(?![A-Za-z0-9])") # keep __init__
static var re_bold_italic: RegEx = compile_regex("(?<!\\*)\\*\\*\\*(?!\\*|\\s)([^\\n]+?)(?<!\\s)\\*\\*\\*(?!\\*)") # ***both***
static var re_bold: RegEx = compile_regex("(?<!\\*)\\*\\*(?!\\*|\\s)([^\\n]+?)(?<!\\s)\\*\\*(?!\\*)") # **bold**
static var re_bold_underscore: RegEx = compile_regex("(?<![A-Za-z0-9])__(?![\\s_])([^_\\n]+)(?<![\\s_])__(?![A-Za-z0-9])") # __bold__
static var re_strike: RegEx = compile_regex("~~(?!\\s)([^~\\n]+)(?<!\\s)~~") # ~~strike~~
static var re_italic: RegEx = compile_regex("(?<!\\*)\\*(?!\\*|\\s)([^\\n]+?)(?<!\\s|\\*)\\*(?!\\*)") # *italic*
static var re_italic_underscore: RegEx = compile_regex("(?<![A-Za-z0-9])_(?![\\s_])([^_\\n]+)(?<![\\s_])_(?![A-Za-z0-9])") # _italic_
static var re_html_underline: RegEx = compile_regex("(?i)<u>([^<\\n]+)</u>") # <u>html underline</u>
static var re_table_separator_cell: RegEx = compile_regex("^\\s*:?-+:?\\s*$") # --- / :---:


static func compile_regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		Log.error("MarkdownUtils regex compile failed pattern:[{}] err:[{}]", pattern, err)
	return regex


## Converts Markdown to BBCode for RichTextLabel (`bbcode_enabled` must be on).
## [param code_block_bg] optional hex for fenced ``` code blocks (theme-aware callers).
static func to_bbcode(markdown: String, code_block_bg: String = StringUtils.EMPTY) -> String:
	if StringUtils.is_blank(markdown):
		return StringUtils.EMPTY

	var fence_bg := code_block_bg if StringUtils.is_not_empty(code_block_bg) else CODE_BLOCK_BG
	var lines := normalize_newlines(markdown).split("\n")
	var out: PackedStringArray = []
	var i := 0
	while i < lines.size():
		var line: String = lines[i]

		# ```lang / ~~~  …  ``` / ~~~  →  [code]…[/code]
		# Unclosed fence swallows the rest of the document (same as CommonMark).
		var fence := parse_code_fence(line)
		if StringUtils.is_not_empty(fence):
			i += 1
			var code_lines: PackedStringArray = []
			while i < lines.size() and not is_closing_fence(lines[i], fence):
				code_lines.append(lines[i])
				i += 1
			if i < lines.size():
				i += 1
			out.append(format_code_fence_bbcode("\n".join(code_lines), fence_bg))
			continue

		# --- / *** / ___  →  [center]────[/center]
		if is_horizontal_rule_line(line):
			out.append(HORIZONTAL_RULE_LINE)
			i += 1
			continue

		# # Title  →  [font_size=32]Title[/font_size]
		var heading_level := parse_heading_level(line)
		if heading_level > 0:
			var size := HEADING_FONT_SIZES[heading_level - 1]
			out.append(
					StringUtils.format(
							"[font_size={}]{}[/font_size]",
							size,
							inline_to_bbcode(extract_heading_text(line, heading_level))
					)
			)
			i += 1
			continue

		# > quote  →  indented line with left bar + muted color
		if is_blockquote_line(line):
			var quote_lines: PackedStringArray = []
			while i < lines.size() and is_blockquote_line(lines[i]):
				quote_lines.append(strip_blockquote_prefix(lines[i]))
				i += 1
			out.append(format_blockquote_bbcode("\n".join(quote_lines)))
			continue

		# | h1 | h2 | + |---|  →  [table=2][cell][b]h1[/b][/cell]…[/table]
		var table := parse_table_block(lines, i)
		if table.has("next"):
			out.append(table["bbcode"])
			i = table["next"]
			continue

		# - item / 1. item / - [ ] task  →  • / 1. / ☐ ☑
		var list_line := format_list_line(line)
		if StringUtils.is_not_empty(list_line):
			out.append(list_line)
			i += 1
			continue

		if StringUtils.is_blank(line):
			out.append("")
		else:
			out.append(inline_to_bbcode(line))
		i += 1

	return "\n".join(out)


## CRLF / lone CR → LF so Windows sources do not leave `\r` on markers.
static func normalize_newlines(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "\n")


static func count_leading_spaces(line: String) -> int:
	var n := 0
	while n < line.length() and line[n] == " ":
		n += 1
	return n


## CommonMark ATX: 0–3 leading spaces. 4+ is indented code, not a heading.
static func atx_content_source(line: String) -> String:
	var leading := count_leading_spaces(line)
	if leading == 0 or leading > 3:
		return line
	return line.substr(leading)


## `# Title` / `## Title` … `###### Title` (space/tab required). `#not-a-heading` → 0.
static func parse_heading_level(line: String) -> int:
	var source := atx_content_source(line)
	if StringUtils.is_empty(source) or source[0] != "#":
		return 0
	var level := 0
	while level < source.length() and level < 6 and source[level] == "#":
		level += 1
	if level == 0 or level >= source.length():
		return 0
	if source[level] != " " and source[level] != "\t":
		return 0
	var content := strip_closing_atx_hashes(source.substr(level).strip_edges())
	return level if StringUtils.is_not_blank(content) else 0


static func extract_heading_text(line: String, level: int) -> String:
	var source := atx_content_source(line)
	return strip_closing_atx_hashes(source.substr(level).strip_edges())


## `# Title ##` → `Title`. Closing `#` run is stripped only when a space precedes it.
static func strip_closing_atx_hashes(content: String) -> String:
	if StringUtils.is_empty(content):
		return content
	var i := content.length() - 1
	while i >= 0 and content[i] == "#":
		i -= 1
	if i >= 0 and i < content.length() - 1 and (content[i] == " " or content[i] == "\t"):
		return content.substr(0, i).strip_edges()
	return content


## Opening fence: ` ``` ` or ` ~~~ ` (run ≥ 3). Info string (` ```python`) is ignored.
static func parse_code_fence(line: String) -> String:
	var leading := count_leading_spaces(line)
	if leading > 3:
		return StringUtils.EMPTY
	var rest := line.substr(leading)
	var fence_char := ""
	if rest.begins_with("`"):
		fence_char = "`"
	elif rest.begins_with("~"):
		fence_char = "~"
	else:
		return StringUtils.EMPTY
	var n := 0
	while n < rest.length() and rest[n] == fence_char:
		n += 1
	if n < 3:
		return StringUtils.EMPTY
	return rest.substr(0, n)


## Closer: same character as [param fence], no info string, length ≥ opening run.
static func is_closing_fence(line: String, fence: String) -> bool:
	var leading := count_leading_spaces(line)
	if leading > 3:
		return false
	var rest := line.substr(leading).strip_edges(false, true)
	if rest.length() < fence.length():
		return false
	for index in rest.length():
		if rest[index] != fence[0]:
			return false
	return true


## Thematic break: `---`, `***`, `___`, or `- - -`. Mixed `-_*-` is not an HR.
static func is_horizontal_rule_line(line: String) -> bool:
	var trimmed := line.strip_edges()
	if trimmed.length() < 3:
		return false
	var hr_char := trimmed[0]
	if hr_char != "-" and hr_char != "*" and hr_char != "_":
		return false
	var marker_count := 0
	for index in trimmed.length():
		var ch: String = trimmed[index]
		if ch == hr_char:
			marker_count += 1
		elif ch != " ":
			return false
	return marker_count >= 3


## `>` after 0–3 spaces. Nested `>>` is left as leftover `>` in the quote body.
static func is_blockquote_line(line: String) -> bool:
	var leading := count_leading_spaces(line)
	if leading > 3:
		return false
	return line.substr(leading).begins_with(">")


static func strip_blockquote_prefix(line: String) -> String:
	var leading := count_leading_spaces(line)
	var rest := line.substr(leading) if leading <= 3 else line
	if rest.begins_with(">"):
		rest = rest.substr(1)
		if rest.begins_with(" "):
			rest = rest.substr(1)
	return rest


## Blockquote: left accent bar + muted body (plain `[indent][i]` is too subtle in chat).
static func format_blockquote_bbcode(text: String) -> String:
	var body := inline_to_bbcode(text)
	return StringUtils.format(
			"[indent][color={}]▎[/color] [color={}]{}[/color][/indent]",
			BLOCKQUOTE_BAR,
			BLOCKQUOTE_TEXT,
			body
	)


## GFM table: header row + `\| --- \|` separator + body rows. Needs the separator line.
static func parse_table_block(lines: PackedStringArray, start: int) -> Dictionary:
	if start + 1 >= lines.size():
		return {}
	if not is_table_row_line(lines[start]):
		return {}
	if not is_table_separator_line(lines[start + 1]):
		return {}
	var header := parse_table_cells(lines[start])
	var columns := header.size()
	if columns == 0:
		return {}
	var body_rows: Array[PackedStringArray] = []
	var index := start + 2
	while index < lines.size() and is_table_row_line(lines[index]):
		body_rows.append(normalize_table_row(parse_table_cells(lines[index]), columns))
		index += 1
	return {
		"bbcode": format_table_bbcode(header, body_rows, columns),
		"next": index,
	}


static func is_table_row_line(line: String) -> bool:
	return line.contains("|") and parse_table_cells(line).size() > 0


static func is_table_separator_line(line: String) -> bool:
	var cells := parse_table_cells(line)
	if cells.is_empty():
		return false
	for cell in cells:
		if re_table_separator_cell.search(cell) == null:
			return false
	return true


static func parse_table_cells(line: String) -> PackedStringArray:
	if not line.contains("|"):
		return PackedStringArray()
	var body := line.strip_edges()
	if body.begins_with("|"):
		body = body.substr(1)
	if body.ends_with("|"):
		body = body.substr(0, body.length() - 1)
	var cells: PackedStringArray = []
	for part in body.split("|"):
		cells.append(part.strip_edges())
	return cells


static func normalize_table_row(cells: PackedStringArray, columns: int) -> PackedStringArray:
	var row: PackedStringArray = []
	for index in columns:
		if index < cells.size():
			row.append(cells[index])
		else:
			row.append("")
	return row


## One line of `[cell]` tags; cell text is single-line (Godot table layout requirement).
static func format_table_bbcode(header: PackedStringArray, body_rows: Array[PackedStringArray], columns: int) -> String:
	var chunks: PackedStringArray = []
	chunks.append(StringUtils.format("[table={}]", columns))
	for cell in header:
		chunks.append(format_table_cell(cell, true))
	for row in body_rows:
		for cell in row:
			chunks.append(format_table_cell(cell, false))
	chunks.append("[/table]")
	return "".join(chunks)


static func format_table_cell(text: String, is_header: bool) -> String:
	var content := inline_to_bbcode(text)
	if is_header:
		content = StringUtils.format("[b]{}[/b]", content)
		return StringUtils.format(
				"[cell border={} bg={} padding={}]{}[/cell]",
				TABLE_CELL_BORDER,
				TABLE_HEADER_BG,
				TABLE_CELL_PADDING,
				content
		)
	return StringUtils.format(
			"[cell border={} padding={}]{}[/cell]",
			TABLE_CELL_BORDER,
			TABLE_CELL_PADDING,
			content
	)


## `- item` / `* item` / `+ item` → `• item`; `1. item` / `1) item` → `1. item`.
static func format_list_line(line: String) -> String:
	var prefix_len := parse_unordered_list_prefix_length(line)
	if prefix_len > 0:
		return format_unordered_list_item(line.substr(prefix_len).strip_edges())

	prefix_len = parse_ordered_list_prefix_length(line)
	if prefix_len > 0:
		var trimmed := line.strip_edges(true, false)
		var number := trimmed.substr(0, parse_leading_integer_length(trimmed))
		var item := line.substr(prefix_len).strip_edges()
		return StringUtils.format("{}. {}", number, inline_to_bbcode(item))

	return StringUtils.EMPTY


## GFM task list: `- [ ]` → ☐, `- [x]` / `- [X]` → ☑; otherwise `•`.
static func format_unordered_list_item(item: String) -> String:
	if item.begins_with("[ ] "):
		return StringUtils.format("☐ {}", inline_to_bbcode(item.substr(4)))
	if item.length() >= 4 and item.substr(0, 3).to_lower() == "[x]" and item[3] == " ":
		return StringUtils.format("☑ {}", inline_to_bbcode(item.substr(4)))
	return StringUtils.format("• {}", inline_to_bbcode(item))


## Prefix length of `- `/`* `/`+ ` (or tab). `0` if the line is not an unordered item.
static func parse_unordered_list_prefix_length(line: String) -> int:
	if StringUtils.is_empty(line):
		return 0
	var trimmed := line.strip_edges(true, false)
	if StringUtils.is_empty(trimmed):
		return 0
	var first: String = trimmed[0]
	if first != "-" and first != "*" and first != "+":
		return 0
	if trimmed.length() < 2:
		return 0
	if trimmed[1] != " " and trimmed[1] != "\t":
		return 0
	return line.length() - trimmed.length() + 2


## Prefix length of `1. ` / `1) ` (or tab). `0` if the line is not an ordered item.
static func parse_ordered_list_prefix_length(line: String) -> int:
	if StringUtils.is_empty(line):
		return 0
	var trimmed := line.strip_edges(true, false)
	if StringUtils.is_empty(trimmed):
		return 0
	var number_len := parse_leading_integer_length(trimmed)
	if number_len == 0 or number_len >= trimmed.length():
		return 0
	var marker := trimmed[number_len]
	if marker != "." and marker != ")":
		return 0
	if number_len + 1 >= trimmed.length():
		return 0
	var after := trimmed[number_len + 1]
	if after != " " and after != "\t":
		return 0
	return line.length() - trimmed.length() + number_len + 2


static func parse_leading_integer_length(text: String) -> int:
	var n := 0
	while n < text.length() and text[n] >= "0" and text[n] <= "9":
		n += 1
	return n


## Inline Markdown → BBCode. Protect → escape leftover brackets → restore.
static func inline_to_bbcode(text: String) -> String:
	if StringUtils.is_empty(text):
		return StringUtils.EMPTY
	var parts: Array[String] = []
	return restore_protected(inline_body(text, parts), parts)


## Converted text with every leftover `[` / `]` escaped, tags still stashed in [param parts].
## Escaping before [method restore_protected] is what keeps a literal `[b]` in the source
## from turning into a live tag; tokens hold no brackets, so they survive untouched.
## Emphasis and link labels go through here too — their bodies land inside [param parts]
## and are never scanned again, so `**a[0]b**` must be escaped on the way in.
static func inline_body(text: String, parts: Array[String]) -> String:
	return escape_bbcode_literals(apply_inline(text, parts))


## Order is load-bearing: code, then images (so `![a](u)` is not a link), then
## links, then `__init__` as literal, then `***` / `**` / `__` / `~~` / `*` / `_`,
## plus inline HTML `<u>`.
## Recurse into link labels and emphasis so `**foo *bar* baz**` / `[**b**](url)` work.
static func apply_inline(text: String, parts: Array[String]) -> String:
	var s := text
	# `code` → [code]code[/code]
	s = regex_sub(
			s,
			re_inline_code,
			func(m: RegExMatch) -> String:
				return protect(parts, wrap_code(m.get_string(1)))
	)
	# <u>html</u> → [u]html[/u]  (CommonMark has no native underline)
	s = regex_sub(
			s,
			re_html_underline,
			func(m: RegExMatch) -> String:
				return protect(
						parts,
						StringUtils.format("[u]{}[/u]", inline_body(m.get_string(1), parts))
				)
	)
	# ![alt](url "title") → [img]url[/img]
	s = regex_sub(
			s,
			re_image,
			func(m: RegExMatch) -> String:
				var url := escape_bbcode_literals(parse_link_destination(m.get_string(2)))
				return protect(parts, StringUtils.format("[img]{}[/img]", url))
	)
	# [label](url "title") → [url=url]label[/url]
	s = regex_sub(
			s,
			re_link,
			func(m: RegExMatch) -> String:
				var label := inline_body(m.get_string(1), parts)
				var url := escape_bbcode_literals(parse_link_destination(m.get_string(2)))
				return protect(parts, StringUtils.format("[url={}]{}[/url]", url, label))
	)
	# `__init__` would otherwise become `[b]init[/b]` (and then `_init_` italic).
	s = regex_sub(
			s,
			re_dunder,
			func(m: RegExMatch) -> String:
				return protect(parts, escape_bbcode_literals(m.get_string(0)))
	)
	# ***both*** → [b][i]both[/i][/b]
	s = regex_sub(
			s,
			re_bold_italic,
			func(m: RegExMatch) -> String:
				return protect(
						parts,
						StringUtils.format("[b][i]{}[/i][/b]", inline_body(m.get_string(1), parts))
				)
	)
	# **bold** → [b]bold[/b]
	s = regex_sub(
			s,
			re_bold,
			func(m: RegExMatch) -> String:
				return protect(parts, StringUtils.format("[b]{}[/b]", inline_body(m.get_string(1), parts)))
	)
	# __bold__ → [b]bold[/b]  (not __init__)
	s = regex_sub(
			s,
			re_bold_underscore,
			func(m: RegExMatch) -> String:
				return protect(parts, StringUtils.format("[b]{}[/b]", inline_body(m.get_string(1), parts)))
	)
	# ~~strike~~ → [s]strike[/s]
	s = regex_sub(
			s,
			re_strike,
			func(m: RegExMatch) -> String:
				return protect(parts, StringUtils.format("[s]{}[/s]", inline_body(m.get_string(1), parts)))
	)
	# *italic* → [i]italic[/i]
	s = regex_sub(
			s,
			re_italic,
			func(m: RegExMatch) -> String:
				return protect(parts, StringUtils.format("[i]{}[/i]", inline_body(m.get_string(1), parts)))
	)
	# _italic_ → [i]italic[/i]  (not my_var_name)
	s = regex_sub(
			s,
			re_italic_underscore,
			func(m: RegExMatch) -> String:
				return protect(parts, StringUtils.format("[i]{}[/i]", inline_body(m.get_string(1), parts)))
	)
	return s


## Link/image dest: `[t](<url>)` unwraps; `[t](url "title")` / `[t](url 'title')` drops title.
static func parse_link_destination(raw: String) -> String:
	var dest := raw.strip_edges()
	if dest.begins_with("<"):
		var end := dest.find(">")
		if end != -1:
			return dest.substr(1, end - 1).strip_edges()
	var title_dq := dest.find(" \"")
	var title_sq := dest.find(" '")
	var cut := dest.length()
	if title_dq != -1:
		cut = title_dq
	if title_sq != -1 and title_sq < cut:
		cut = title_sq
	return dest.substr(0, cut).strip_edges()


## Fenced block → one full-width `[cell]` with background + border.
static func format_code_fence_bbcode(code: String, bg: String = CODE_BLOCK_BG) -> String:
	return StringUtils.format(
			"[table=1][cell shrink=false expand=1 border={} bg={} padding={}]{}[/cell][/table]",
			CODE_BLOCK_BORDER,
			bg,
			CODE_BLOCK_PADDING,
			wrap_code(code)
	)


## Inline `` `code` `` → mono font only (no table — would break the paragraph flow).
static func wrap_code(code: String) -> String:
	return StringUtils.format("[code]{}[/code]", escape_bbcode_literals(preserve_code_spaces(code)))


## RichTextLabel collapses ASCII spaces in `[code]`; NBSP keeps indent visible.
static func preserve_code_spaces(code: String) -> String:
	return code.replace("\t", "    ").replace(" ", NBSP)


## Stash finished BBCode and leave a token that no inline regex will match.
static func protect(parts: Array[String], bbcode: String) -> String:
	var index := parts.size()
	parts.append(bbcode)
	return "%s%d%s" % [PROTECT_START, index, PROTECT_END]


## High → low so token `1` does not replace the prefix of token `10`.
static func restore_protected(text: String, parts: Array[String]) -> String:
	var s := text
	var index := parts.size() - 1
	while index >= 0:
		s = s.replace("%s%d%s" % [PROTECT_START, index, PROTECT_END], parts[index])
		index -= 1
	return s


static func regex_sub(text: String, regex: RegEx, replacer: Callable) -> String:
	if StringUtils.is_empty(text):
		return text
	var matches := regex.search_all(text)
	if matches.is_empty():
		return text
	var chunks: PackedStringArray = []
	var pos := 0
	for m in matches:
		chunks.append(text.substr(pos, m.get_start() - pos))
		chunks.append(str(replacer.call(m)))
		pos = m.get_end()
	chunks.append(text.substr(pos))
	return "".join(chunks)


## `[` → `[lb]`, `]` → `[rb]`. Must go through [constant ESCAPE_SENTINEL]:
## `[hello]` → `[lb]hello]` → `[lb[rb]hello[rb]` if `]` is replaced second.
static func escape_bbcode_literals(text: String) -> String:
	if StringUtils.is_empty(text):
		return StringUtils.EMPTY
	return text.replace("[", ESCAPE_SENTINEL).replace("]", "[rb]").replace(ESCAPE_SENTINEL, "[lb]")


# ---------------------------------------------------------------------------
# RichTextLabel body (markdown UI)
# ---------------------------------------------------------------------------

const META_RAW_BODY := "raw_body"
const BODY_LABEL_MIN_HEIGHT := 24
const TABLE_V_SEPARATION := 0


static func create_body_label(text_color: Color, raw_text: String, markdown_enabled: bool, content_width: float = 0.0, code_block_bg: String = StringUtils.EMPTY) -> RichTextLabel:
	var label := RichTextLabel.new()
	configure_body_label(label, text_color)
	label.meta_clicked.connect(handle_meta_clicked)
	set_body_text(label, raw_text, markdown_enabled, content_width, code_block_bg)
	return label


static func configure_body_label(label: RichTextLabel, text_color: Color) -> void:
	label.selection_enabled = true
	label.scroll_active = false
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("default_color", text_color)
	label.add_theme_font_override("normal_font", Fonts.regular())
	label.add_theme_font_override("bold_font", Fonts.bold())
	label.add_theme_font_override("italics_font", Fonts.semibold())
	label.add_theme_font_override("bold_italics_font", Fonts.bold())
	label.add_theme_font_override("mono_font", Fonts.semibold())
	label.add_theme_constant_override("table_v_separation", TABLE_V_SEPARATION)
	label.custom_minimum_size = Vector2(0, BODY_LABEL_MIN_HEIGHT)
	pass


static func get_raw_body(label: RichTextLabel) -> String:
	return str(label.get_meta(META_RAW_BODY, ""))


static func set_body_text(label: RichTextLabel, raw_text: String, markdown_enabled: bool, content_width: float = 0.0, code_block_bg: String = StringUtils.EMPTY) -> void:
	label.set_meta(META_RAW_BODY, raw_text)
	if markdown_enabled:
		var bbcode := to_bbcode(raw_text, code_block_bg)
		# Enabling bbcode re-parses existing text; raw markdown may contain literal
		# `[cell]` / `[table]` (e.g. in backticks) and crash RichTextLabel.
		if label.bbcode_enabled:
			label.text = bbcode
		else:
			label.bbcode_enabled = false
			label.text = bbcode
			label.bbcode_enabled = true
	else:
		if label.bbcode_enabled:
			label.bbcode_enabled = false
		label.text = raw_text
	sync_body_label_width(label, content_width)
	pass


static func append_body_text(label: RichTextLabel, delta: String, markdown_enabled: bool, content_width: float = 0.0, code_block_bg: String = StringUtils.EMPTY) -> void:
	set_body_text(label, get_raw_body(label) + delta, markdown_enabled, content_width, code_block_bg)
	pass


static func sync_body_label_width(label: RichTextLabel, content_width: float) -> void:
	if content_width <= 0.0:
		return
	var min_y := label.custom_minimum_size.y
	if label.is_inside_tree():
		label.set_deferred("custom_minimum_size", Vector2(content_width, min_y))
	else:
		label.custom_minimum_size = Vector2(content_width, min_y)
	pass


static func handle_meta_clicked(meta: Variant) -> void:
	var url := str(meta).strip_edges()
	if StringUtils.is_blank(url):
		return
	var lower := url.to_lower()
	if lower.begins_with("javascript:") or lower.begins_with("data:"):
		Log.info("blocked unsafe link:[{}]", url)
		return
	if not lower.begins_with("http://") and not lower.begins_with("https://") and not lower.begins_with("mailto:"):
		if url.begins_with("//"):
			url = "https:" + url
		elif url.contains(".") and not url.contains(" "):
			url = "https://" + url
		else:
			Log.info("unsupported link:[{}]", url)
			return
	var err := OS.shell_open(url)
	if err != OK:
		Log.error("open link failed url:[{}] err:[{}]", url, err)
	pass
