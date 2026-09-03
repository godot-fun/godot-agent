# --------------------------------------------------------------------------------------------------
class Teacher:
	var name: String
	var age: int
	pass

static var teacher1 := Teacher.new()
static var teacher2 := Teacher.new()

static func test_before() -> void:
	teacher1.name = "Peter"
	teacher1.age = 50
	teacher2.name = "David"
	teacher2.age = 40
	pass

func simple_json_test() -> void:
	var json := "{\"name\": \"test\", \"age\": 10}"
	var obj = JsonUtils.json_to_object(json, Teacher)
	var json_text := JsonUtils.object_to_json(obj)
	assert(json == json_text)
	pass



# --------------------------------------------------------------------------------------------------
class Student:
	var name: String
	var age: int
	var subjects: Array[String]
	var teachers: Array[Teacher]
	var scores: Dictionary[String, int]
	var teacherMap: Dictionary[String, Teacher]
	var friendMap: Dictionary[int, String]
pass


func json_escapes_control_characters_test() -> void:
	# Godot String cannot hold U+0000: char(0) logs "Unexpected NUL character" and becomes U+FFFD.
	# Valid char() range excludes 0x0000; test ESC + VT only, plus round-trip behavior.
	var content := "ansi" + char(0x1B) + "[0m" + "x" + char(0x0B) + "vt"
	var json := JsonUtils.object_to_json(content)
	assert(JSON.parse_string(json) == content)
	assert(json.contains("\\u001b"))
	assert(json.contains("\\u000b"))
	assert(not json.contains(char(0x1B)))
	assert(not json.contains(char(0x0B)))
	var wrapped := JsonUtils.object_to_json({"role": "tool", "content": content})
	var parsed: Dictionary = JSON.parse_string(wrapped)
	assert(parsed["role"] == "tool")
	assert(parsed["content"] == content)
	pass


func json_test() -> void:
	var student := Student.new()
	student.name = "Peter"
	student.age = 30
	student.subjects = ["math", "history"]
	student.teachers = [teacher1, teacher1]
	student.scores = {}
	student.scores["math"] = 100
	student.scores["history"] = 99
	student.teacherMap = {}
	student.teacherMap["Peter"] = teacher1
	student.teacherMap["David"] = teacher2
	student.friendMap[1] = "Jay"
	student.friendMap[99] = "Sun"
	student.friendMap[-999] = "zfoo"
	var json := JsonUtils.object_to_json(student)
	var obj: Student = JsonUtils.json_to_object(json, Student)
	var json_text := JsonUtils.object_to_json(obj)
	assert(json == json_text)
	pass