
# --------------------------------------------------------------------------------------------------
enum State {
	IDLE,
	RUNNING,
	STOPPED
}

func is_empty_or_blank_test() -> void:
	var emptyStr: String = ""
	var blankStr: String = "  	"
	assert(StringUtils.is_empty(emptyStr))
	assert(StringUtils.is_blank(emptyStr))
	assert(StringUtils.is_not_empty(blankStr))
	assert(StringUtils.is_blank(blankStr))
	pass

func enum_to_string_test() -> void:
	assert(StringUtils.enum_to_string(State, State.IDLE), "IDLE")
	pass

func substring_before_test() -> void:
	var path := "a/b/c.txt"
	assert(StringUtils.substring_before(path, "/") == "a")
	assert(StringUtils.substring_before(path, "#") == StringUtils.EMPTY)
	assert(StringUtils.substring_before("", "/") == StringUtils.EMPTY)
	pass

func substring_after_test() -> void:
	var path := "a/b/c.txt"
	assert(StringUtils.substring_after(path, "/") == "b/c.txt")
	assert(StringUtils.substring_after(path, "#") == StringUtils.EMPTY)
	assert(StringUtils.substring_after("", "/") == StringUtils.EMPTY)
	pass

func substring_before_last_test() -> void:
	var path := "a/b/c.txt"
	assert(StringUtils.substring_before_last(path, "/") == "a/b")
	assert(StringUtils.substring_before_last(path, ".") == "a/b/c")
	assert(StringUtils.substring_before_last(path, "#") == StringUtils.EMPTY)
	assert(StringUtils.substring_before_last("", "/") == StringUtils.EMPTY)
	pass

func substring_after_last_test() -> void:
	var path := "a/b/c.txt"
	assert(StringUtils.substring_after_last(path, "/") == "c.txt")
	assert(StringUtils.substring_after_last(path, ".") == "txt")
	assert(StringUtils.substring_after_last(path, "#") == StringUtils.EMPTY)
	assert(StringUtils.substring_after_last("", "/") == StringUtils.EMPTY)
	pass

func truncate_test() -> void:
	assert(StringUtils.truncate("abcdef", 10) == "abcdef")
	assert(StringUtils.truncate("abcdef", 6) == "abcdef")
	assert(StringUtils.truncate("abcdef", 5) == "ab...")
	assert(StringUtils.truncate("abcdef", 3) == "...")
	assert(StringUtils.truncate("abcdef", 2) == "ab")
	assert(StringUtils.truncate("", 5) == StringUtils.EMPTY)
	pass

func first_lines_test() -> void:
	assert(StringUtils.first_lines("a\nb\nc", 2) == "a\nb")
	assert(StringUtils.first_lines("a\nb", 3) == "a\nb")
	assert(StringUtils.first_lines("a\nb\nc", 0) == StringUtils.EMPTY)
	assert(StringUtils.first_lines("", 5) == StringUtils.EMPTY)
	assert(StringUtils.first_lines("single line", 28) == "single line")
	assert(StringUtils.first_lines("a\nb\n", 2) == "a\nb")
	pass

func first_lines_after_test() -> void:
	assert(StringUtils.first_lines_after("a\nb\nc", 2) == "c")
	assert(StringUtils.first_lines_after("a\nb", 3) == StringUtils.EMPTY)
	assert(StringUtils.first_lines_after("a\nb\nc", 0) == "a\nb\nc")
	assert(StringUtils.first_lines_after("", 5) == StringUtils.EMPTY)
	assert(StringUtils.first_lines_after("single line", 1) == StringUtils.EMPTY)
	assert(StringUtils.first_lines_after("a\nb\n", 2) == StringUtils.EMPTY)
	assert(StringUtils.first_lines_after("a\nb\nc\n", 2) == "c\n")
	pass

func last_lines_test() -> void:
	assert(StringUtils.last_lines("a\nb\nc", 2) == "b\nc")
	assert(StringUtils.last_lines("a\nb", 3) == "a\nb")
	assert(StringUtils.last_lines("a\nb\nc", 0) == StringUtils.EMPTY)
	assert(StringUtils.last_lines("", 5) == StringUtils.EMPTY)
	assert(StringUtils.last_lines("single line", 6) == "single line")
	assert(StringUtils.last_lines("a\nb\nc\nd\ne\nf\ng", 6) == "b\nc\nd\ne\nf\ng")
	pass
