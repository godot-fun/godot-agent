class_name CharStreamUtils
extends RefCounted

## Chunk → char queue, path templates, and step-text phrase extraction.

const MAX_SPAWN_PER_CHUNK := 8
const MAX_PHRASE_LEN := 56
const MIN_PHRASE_LEN := 2
const CODE_CHAR_BOOST: Dictionary = {"{": 2, "}": 2, "[": 2, "]": 2, "(": 2, ")": 2, ";": 2, "=": 2, "/": 2}

const STOP_WORDS: Array[String] = [
	"the", "and", "for", "with", "that", "this", "from", "into", "true", "false", "null", "none",
]


static func extract_spawn_chars(chunk: String, max_count: int = MAX_SPAWN_PER_CHUNK) -> Array[String]:
	var result: Array[String] = []
	if chunk.is_empty():
		return result
	for i in chunk.length():
		var ch := chunk.substr(i, 1)
		if ch == " " or ch == "\n" or ch == "\r" or ch == "\t":
			continue
		var weight: int = int(CODE_CHAR_BOOST.get(ch, 1))
		for _w in weight:
			result.append(ch)
			if result.size() >= max_count:
				return result
	return result


## Thinking / reasoning stream — float whole tokens split on whitespace.
static func extract_spawn_words(chunk: String, max_count: int = MAX_SPAWN_PER_CHUNK) -> Array[String]:
	var result: Array[String] = []
	if chunk.is_empty():
		return result
	var normalized := chunk.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	for part in normalized.split(" ", false):
		var word := part.strip_edges()
		if word.is_empty():
			continue
		result.append(word)
		if result.size() >= max_count:
			return result
	return result


## Words and short clauses taken directly from agent step text (CN + EN + paths).
static func extract_step_phrases(text: String, max_count: int = 5) -> Array[String]:
	var result: Array[String] = []
	if text.is_empty() or max_count <= 0:
		return result
	var seen: Dictionary = {}
	var cleaned := clean_step_text(text)
	if cleaned.is_empty():
		return result

	for clause in split_clauses(cleaned):
		try_add_phrase(result, seen, clause, max_count)
		if result.size() >= max_count:
			return result

	var index := 0
	while index < cleaned.length() and result.size() < max_count:
		var ch := cleaned.substr(index, 1)
		var token := ""
		if is_path_char(ch):
			token = read_run(cleaned, index, is_path_char)
		elif is_cjk(ch):
			token = read_run(cleaned, index, is_cjk)
		elif is_word_char(ch):
			token = read_run(cleaned, index, is_word_char)
		if token.is_empty():
			index += 1
			continue
		try_add_phrase(result, seen, token, max_count)
		index += token.length()
	return result


static func clean_step_text(text: String) -> String:
	var cleaned := text.strip_edges()
	cleaned = cleaned.replace("```", " ")
	cleaned = cleaned.replace("`", "")
	cleaned = cleaned.replace("**", "")
	cleaned = cleaned.replace("__", "")
	cleaned = cleaned.replace("\r", "\n")
	while cleaned.contains("\n\n"):
		cleaned = cleaned.replace("\n\n", "\n")
	return cleaned.strip_edges()


static func is_clause_delimiter(ch: String) -> bool:
	if ch == "\n" or ch == "。" or ch == "！" or ch == "？" or ch == "!" or ch == "?":
		return true
	if ch == ";" or ch == "；" or ch == "，" or ch == "," or ch == ".":
		return true
	return false


static func split_clauses(text: String) -> Array[String]:
	var parts: Array[String] = []
	var current := ""
	for i in text.length():
		var ch := text.substr(i, 1)
		if is_clause_delimiter(ch):
			if not current.strip_edges().is_empty():
				parts.append(current.strip_edges())
			current = ""
			continue
		current += ch
	if not current.strip_edges().is_empty():
		parts.append(current.strip_edges())
	return parts


## Shorten long display text at the last punctuation before max_len (not a hard char chop).
static func truncate_at_punctuation(text: String, max_len: int) -> String:
	var phrase := text.strip_edges()
	if phrase.length() <= max_len:
		return phrase
	var cut := find_last_delimiter_index(phrase, max_len)
	if cut >= MIN_PHRASE_LEN:
		return phrase.substr(0, cut).strip_edges()
	for clause in split_clauses(phrase):
		var part := clause.strip_edges()
		if part.is_empty():
			continue
		if part.length() <= max_len:
			return part
		var inner_cut := find_last_delimiter_index(part, max_len)
		if inner_cut >= MIN_PHRASE_LEN:
			return part.substr(0, inner_cut).strip_edges()
	return phrase.substr(0, max_len).strip_edges() + "…"


static func try_add_phrase(result: Array[String], seen: Dictionary, raw: String, max_count: int) -> void:
	var phrase := format_phrase(raw)
	if phrase.is_empty() or seen.has(phrase):
		return
	if not is_useful_phrase(phrase):
		return
	seen[phrase] = true
	result.append(phrase)
	pass


static func format_phrase(raw: String) -> String:
	return truncate_at_punctuation(raw.strip_edges(), MAX_PHRASE_LEN)


static func find_last_delimiter_index(text: String, before: int) -> int:
	var limit := clampi(before, 0, text.length())
	var last := -1
	for i in limit:
		if is_clause_delimiter(text.substr(i, 1)):
			last = i
	return last


static func is_useful_phrase(phrase: String) -> bool:
	if phrase.length() < MIN_PHRASE_LEN:
		return false
	if phrase.is_empty():
		return false
	var alpha_or_cjk := 0
	for i in phrase.length():
		var ch := phrase.substr(i, 1)
		if is_cjk(ch) or is_word_char(ch):
			alpha_or_cjk += 1
	if alpha_or_cjk < MIN_PHRASE_LEN:
		return false
	if phrase.length() <= 4 and STOP_WORDS.has(phrase.to_lower()):
		return false
	return true


static func read_run(text: String, start: int, matcher: Callable) -> String:
	var run := ""
	var index := start
	while index < text.length():
		var ch := text.substr(index, 1)
		if not bool(matcher.call(ch)):
			break
		run += ch
		index += 1
	return run


static func is_cjk(ch: String) -> bool:
	if ch.is_empty():
		return false
	var code := ch.unicode_at(0)
	return (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0x3400 and code <= 0x4DBF) or (code >= 0x3000 and code <= 0x303F)


static func is_word_char(ch: String) -> bool:
	if ch.is_empty():
		return false
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"


static func is_path_char(ch: String) -> bool:
	return is_word_char(ch) or ch == "/" or ch == "\\" or ch == "." or ch == "-" or ch == ":" or ch == "@" or ch == "#"


static func build_curve(style: OrbPhase.PathStyle, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> Curve3D:
	var curve := Curve3D.new()
	if neurons.is_empty():
		_build_fallback_curve(curve, style, rng)
		return curve
	match style:
		OrbPhase.PathStyle.SPIRAL_IN:
			_build_spiral_in(curve, neurons, rng)
		OrbPhase.PathStyle.ORBIT:
			_build_orbit(curve, neurons, rng)
		OrbPhase.PathStyle.CHAOTIC:
			_build_chaotic(curve, neurons, rng)
		_:
			_build_transverse(curve, neurons, rng)
	curve.bake_interval = 0.05
	curve.get_baked_length()
	return curve


static func pick_neuron(neurons: PackedVector3Array, rng: RandomNumberGenerator) -> Vector3:
	if neurons.is_empty():
		return Vector3.ZERO
	return neurons[rng.randi_range(0, neurons.size() - 1)]


static func _build_fallback_curve(curve: Curve3D, style: OrbPhase.PathStyle, rng: RandomNumberGenerator) -> void:
	var extent: float = OrbVisualScale.PATH_EXTENT
	var start := Vector3(-extent, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
	var end := Vector3(extent, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
	if style == OrbPhase.PathStyle.SPIRAL_IN:
		start = Vector3(rng.randf_range(1.0, extent), rng.randf_range(-0.65, 0.65), rng.randf_range(-0.65, 0.65))
		end = Vector3.ZERO
	curve.add_point(start)
	curve.add_point(start.lerp(end, 0.35) + Vector3(0, rng.randf_range(-0.35, 0.35), rng.randf_range(-0.45, 0.45)))
	curve.add_point(end)
	pass


static func _build_transverse(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var extent: float = OrbVisualScale.PATH_EXTENT
	var side := 1.0 if rng.randf() > 0.5 else -1.0
	var start := Vector3(-extent * side, rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6))
	var end := Vector3(extent * -side, rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6))
	var mid := pick_neuron(neurons, rng)
	curve.add_point(start)
	curve.add_point(start.lerp(mid, 0.45) + Vector3(0, rng.randf_range(-0.2, 0.2), 0))
	curve.add_point(mid)
	curve.add_point(mid.lerp(end, 0.55) + Vector3(0, rng.randf_range(-0.2, 0.2), 0))
	curve.add_point(end)
	pass


static func _build_spiral_in(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var extent: float = OrbVisualScale.PATH_EXTENT
	var start := Vector3(
		rng.randf_range(-extent, extent),
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	)
	curve.add_point(start)
	for step in 3:
		var t := float(step + 1) / 4.0
		var ring := start.lerp(Vector3.ZERO, t)
		ring += Vector3(
			sin(t * TAU * 1.5 + rng.randf()) * (1.0 - t) * 0.42,
			cos(t * TAU * 1.2) * (1.0 - t) * 0.3,
			sin(t * TAU * 0.9) * (1.0 - t) * 0.36
		)
		curve.add_point(ring)
	var hub := pick_neuron(neurons, rng) * 0.35
	curve.add_point(hub)
	pass


static func _build_orbit(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var radius := rng.randf_range(1.15, 1.55)
	var tilt := rng.randf_range(-0.45, 0.45)
	for step in 5:
		var angle: float = float(step) / 4.0 * TAU * 0.85
		var pos := Vector3(cos(angle) * radius, sin(angle) * 0.3 + tilt, sin(angle) * radius * 0.55)
		curve.add_point(pos)
	var inner := pick_neuron(neurons, rng) * 0.5
	curve.add_point(inner)
	pass


static func _build_chaotic(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var pos := pick_neuron(neurons, rng) * 1.25
	curve.add_point(pos)
	for _step in 4:
		pos += Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.55, 0.55))
		curve.add_point(pos)
	pass
