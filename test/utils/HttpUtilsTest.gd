
func is_https_url_test() -> void:
	assert(not HttpUtils.is_https_url(""))
	assert(not HttpUtils.is_https_url("   "))
	assert(not HttpUtils.is_https_url("http://example.com"))
	assert(HttpUtils.is_https_url("https://example.com"))
	assert(HttpUtils.is_https_url("  https://example.com  "))
	pass


func is_valid_http_url_test() -> void:
	assert(HttpUtils.is_valid_http_url("http://example.com"))
	assert(HttpUtils.is_valid_http_url("https://example.com"))
	assert(not HttpUtils.is_valid_http_url("ftp://example.com"))
	assert(not HttpUtils.is_valid_http_url("example.com"))
	pass


func get_host_from_url_test() -> void:
	assert(HttpUtils.get_host_from_url("https://www.google.com") == "www.google.com")
	assert(HttpUtils.get_host_from_url("http://localhost:8080") == "localhost")
	assert(HttpUtils.get_host_from_url("https://www.google.com/search") == "www.google.com")
	pass


func get_port_from_url_test() -> void:
	assert(HttpUtils.get_port_from_url("https://www.google.com") == 443)
	assert(HttpUtils.get_port_from_url("http://example.com") == 80)
	assert(HttpUtils.get_port_from_url("http://localhost:8080") == 8080)
	assert(HttpUtils.get_port_from_url("http://localhost:8080/api") == 8080)
	pass


func get_path_from_url_test() -> void:
	assert(HttpUtils.get_path_from_url("https://www.google.com/search") == "/search")
	assert(HttpUtils.get_path_from_url("https://www.google.com") == "/")
	assert(HttpUtils.get_path_from_url("http://localhost:8080/api/v1") == "/api/v1")
	pass


func has_header_test() -> void:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer token",
	])
	assert(HttpUtils.has_header(headers, "Content-Type"))
	assert(HttpUtils.has_header(headers, "content-type"))
	assert(HttpUtils.has_header(headers, "Authorization"))
	assert(not HttpUtils.has_header(headers, "Accept"))
	assert(not HttpUtils.has_header(PackedStringArray(), "Content-Type"))
	pass
