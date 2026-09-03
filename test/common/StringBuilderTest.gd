
func StringBuilder_append_test() -> void:
	var builder := StringBuilder.new()
	builder.append("Hel").append("lo")
	assert(builder.build_string() == "Hello")
	pass


func StringBuilder_append_line_test() -> void:
	var builder := StringBuilder.new()
	builder.append_line("a").append_line("b")
	assert(builder.build_string() == "a\nb\n")
	pass


func StringBuilder_clear_test() -> void:
	var builder := StringBuilder.new()
	builder.append("x")
	builder.clear()
	assert(builder.is_empty())
	assert(builder.length() == 0)
	assert(builder.build_string() == StringUtils.EMPTY)
	pass


func StringBuilder_length_test() -> void:
	var builder := StringBuilder.new()
	builder.append("ab").append("cde")
	assert(builder.size() == 2)
	assert(builder.length() == 5)
	pass


func StringBuilder_build_joined_test() -> void:
	var builder := StringBuilder.new()
	builder.append("a").append("b").append("c")
	assert(builder.build_joined(", ") == "a, b, c")
	pass


func StringBuilder_append_empty_test() -> void:
	var builder := StringBuilder.new()
	builder.append("").append("x")
	assert(builder.size() == 2)
	assert(builder.build_string() == "x")
	pass


func StringBuilder_append_if_not_empty_test() -> void:
	var builder := StringBuilder.new()
	builder.append_if_not_empty("").append_if_not_empty("x")
	assert(builder.size() == 1)
	assert(builder.build_string() == "x")
	pass
