func get_proxy_from_env_test() -> void:
	var snapshot := snapshot_proxy_env()
	assert(read_proxy_env("", "") == StringUtils.EMPTY)
	assert(read_proxy_env("HTTPS_PROXY", "http://127.0.0.1:7890") == "127.0.0.1:7890")
	assert(read_proxy_env("HTTPS_PROXY", "http://user:pass@127.0.0.1:7890/extra/path") == "127.0.0.1:7890")
	assert(read_proxy_env("HTTPS_PROXY", "127.0.0.1:8888") == "127.0.0.1:8888")
	assert(read_proxy_env("ALL_PROXY", "socks5h://127.0.0.1:1080") == "127.0.0.1:1080")
	assert(read_proxy_env("HTTPS_PROXY", "not-a-proxy") == StringUtils.EMPTY)
	for key: String in ProxyUtils.ENV_KEYS:
		OS.set_environment(key, "")
	OS.set_environment("HTTPS_PROXY", "http://127.0.0.1:7890")
	OS.set_environment("HTTP_PROXY", "http://127.0.0.1:8080")
	assert(ProxyUtils.get_proxy_from_env() == "127.0.0.1:7890")
	restore_proxy_env(snapshot)
	pass


func async_detect_proxy_test() -> void:
	var snapshot := snapshot_proxy_env()
	clear_proxy_env()
	OS.set_environment("HTTPS_PROXY", "http://127.0.0.1:7890")
	var from_env := await ProxyUtils.async_detect_proxy()
	assert(from_env != null)
	assert(from_env.source == ProxyUtils.SOURCE_ENV)
	assert(from_env.address == "127.0.0.1:7890")
	clear_proxy_env()
	var from_probe := await ProxyUtils.async_detect_proxy(100)
	if from_probe != null:
		assert(from_probe.source == ProxyUtils.SOURCE_PROBE)
	restore_proxy_env(snapshot)
	pass


static func read_proxy_env(key: String, value: String) -> String:
	clear_proxy_env()
	if StringUtils.is_not_blank(key):
		OS.set_environment(key, value)
	return ProxyUtils.get_proxy_from_env()


static func snapshot_proxy_env() -> Dictionary:
	var snapshot := {}
	for key: String in ProxyUtils.ENV_KEYS:
		snapshot[key] = OS.get_environment(key)
	return snapshot


static func clear_proxy_env() -> void:
	for key: String in ProxyUtils.ENV_KEYS:
		OS.set_environment(key, "")


static func restore_proxy_env(snapshot: Dictionary) -> void:
	for key: String in ProxyUtils.ENV_KEYS:
		OS.set_environment(key, str(snapshot.get(key, "")))
