
func ArrayUtils_test() -> void:
	var array: Array[int] = []
	assert(ArrayUtils.is_empty(array))
	array.append(1)
	assert(ArrayUtils.is_not_empty(array))
	pass


func CollectionUtils_test() -> void:
	var map: Dictionary[int, int] = {}
	assert(CollectionUtils.is_empty(map))
	map[1] = 100
	assert(CollectionUtils.is_not_empty(map))
	pass


func FileUtils_test() -> void:
	var path: String = "./zfoo_test_temp.txt"
	var content: String = "hello godot!"
	FileUtils.write_string_to_file(path, content)
	var readContent := FileUtils.read_file_to_string(path)
	assert(content == readContent)
	FileUtils.delete_file(path)
	pass


func RandomUtils_test() -> void:
	var boolValue := RandomUtils.random_boolean()
	if boolValue:
		assert(boolValue == true)
	else:
		assert(boolValue == false)
	var intValue := RandomUtils.random_int()
	assert(intValue < RandomUtils.MAX_INT)
	assert(intValue >= RandomUtils.MIN_INT)
	var intLimitValue := RandomUtils.random_int_limit(100)
	assert(intLimitValue >= 0)
	var negativeIntValue := RandomUtils.random_int_range(-100, -1)
	assert(negativeIntValue < 0)
	var array: Array[int] = [1, 2, 3]
	var randomElement = RandomUtils.random_ele(array)
	assert(array.find(randomElement) >= 0)
	pass



func TimeUtils_test() -> void:
	var timestamp := TimeUtils.current_time_millis()
	# YYYY-MM-DD HH:MM:SS
	var dateTimeStr := Time.get_datetime_string_from_system(false, true)
	assert(dateTimeStr == TimeUtils.time_to_datetime_string(timestamp))
	assert(dateTimeStr.split(" ")[0] == TimeUtils.time_to_date_string(timestamp))

	var now := TimeUtils.now()
	await ThreadUtils.async_sleep(2000)
	assert(now != TimeUtils.now())
	pass

func NumberUtils_test() -> void:
	var int32Max: int = 2_147_483_647
	var int32Min: int = -2_147_483_648
	var int64Max: int = 9_223_372_036_854_775_807
	var int64Min: int = -9_223_372_036_854_775_808
	assert(NumberUtils.INT32_MAX == int32Max)
	assert(NumberUtils.INT32_MIN == int32Min)
	assert(NumberUtils.INT64_MAX == int64Max)
	assert(NumberUtils.INT64_MIN == int64Min)
	@warning_ignore("assert_always_true")
	assert(NumberUtils.INT64_MAX + 1 == NumberUtils.INT64_MIN)
	pass

