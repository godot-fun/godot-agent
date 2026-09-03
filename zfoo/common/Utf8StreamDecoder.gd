class_name Utf8StreamDecoder
extends RefCounted

## Incrementally decodes UTF-8 from byte chunks without splitting multibyte characters.

var pending: PackedByteArray = PackedByteArray()


func push(chunk: PackedByteArray) -> String:
	if chunk.is_empty():
		return StringUtils.EMPTY
	pending.append_array(chunk)
	return decode_complete()


func flush() -> String:
	if pending.is_empty():
		return StringUtils.EMPTY
	var text := pending.get_string_from_utf8()
	pending.clear()
	return text


func clear() -> void:
	pending.clear()
	pass


static func is_valid_utf8(data: PackedByteArray) -> bool:
	var i := 0
	while i < data.size():
		var seq_len := leading_byte_length(data[i])
		if seq_len == 0:
			return false
		if i + seq_len > data.size():
			return false
		for j in range(1, seq_len):
			if (data[i + j] & 0xC0) != 0x80:
				return false
		i += seq_len
	return true


static func leading_byte_length(b: int) -> int:
	if b < 0x80:
		return 1
	if b < 0xC0:
		return 0
	if b < 0xE0:
		return 2
	if b < 0xF0:
		return 3
	if b < 0xF8:
		return 4
	return 0


func decode_complete() -> String:
	var out := StringBuilder.new()
	var i := 0
	while i < pending.size():
		var b: int = pending[i]
		var seq_len := leading_byte_length(b)
		if seq_len == 0:
			i += 1
			continue
		if i + seq_len > pending.size():
			break
		var valid := true
		for j in range(1, seq_len):
			if (pending[i + j] & 0xC0) != 0x80:
				valid = false
				break
		if not valid:
			i += 1
			continue
		out.append(pending.slice(i, i + seq_len).get_string_from_utf8())
		i += seq_len
	if i > 0:
		pending = pending.slice(i)
	return out.build_string()
