
func telnet_test() -> void:
	assert(not await NetUtils.telnet("", 8080))
	assert(not await NetUtils.telnet("127.0.0.1", 0))
	assert(not await NetUtils.telnet("127.0.0.1", 70000))
	assert(not await NetUtils.telnet("127.0.0.1", 59999, 500))
	assert(await NetUtils.telnet("127.0.0.1", 10809))
	pass
