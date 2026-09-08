
func local_host_test() -> void:
	var address := NetUtils.local_host()
	assert(StringUtils.is_not_empty(address))
	var parts := address.split(".")
	assert(parts.size() == 4)
	for part: String in parts:
		var octet := part.to_int()
		assert(octet >= 0 and octet <= 255)
	pass


func telnet_test() -> void:
	assert(not await NetUtils.telnet("", 8080))
	assert(not await NetUtils.telnet("127.0.0.1", 0))
	assert(not await NetUtils.telnet("127.0.0.1", 70000))
	assert(not await NetUtils.telnet("127.0.0.1", 59999, 500))
	# assert(await NetUtils.telnet("127.0.0.1", 10809))
	pass
