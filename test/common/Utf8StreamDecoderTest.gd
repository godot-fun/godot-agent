
func Utf8StreamDecoder_split_multibyte_across_chunks_test() -> void:
	var text := "你好世界"
	var bytes := text.to_utf8_buffer()
	var decoder := Utf8StreamDecoder.new()
	var out := StringUtils.EMPTY
	for i in range(bytes.size()):
		out += decoder.push(bytes.slice(i, i + 1))
	out += decoder.flush()
	assert(out == text)
	pass


func Utf8StreamDecoder_ascii_and_cjk_mixed_chunks_test() -> void:
	var decoder := Utf8StreamDecoder.new()
	var part1 := decoder.push("data: {\"content\":\"".to_utf8_buffer())
	var part2 := decoder.push("你".to_utf8_buffer().slice(0, 1))
	var part3 := decoder.push("你".to_utf8_buffer().slice(1))
	part3 += decoder.push("好\"}\n".to_utf8_buffer())
	part3 += decoder.flush()
	assert(part1 + part2 + part3 == "data: {\"content\":\"你好\"}\n")
	pass


func Utf8StreamDecoder_is_valid_utf8_test() -> void:
	assert(Utf8StreamDecoder.is_valid_utf8(PackedByteArray()))
	assert(Utf8StreamDecoder.is_valid_utf8("hello".to_utf8_buffer()))
	assert(Utf8StreamDecoder.is_valid_utf8("你好".to_utf8_buffer()))
	assert(not Utf8StreamDecoder.is_valid_utf8(PackedByteArray([0x1F, 0x8B])))
	assert(not Utf8StreamDecoder.is_valid_utf8(PackedByteArray([0xE4])))
	assert(not Utf8StreamDecoder.is_valid_utf8(PackedByteArray([0xFF])))
	pass
