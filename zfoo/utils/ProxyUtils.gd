class_name ProxyUtils
extends Object

## Local HTTP proxy detection for HttpHelper / AsyncHttp.
## Tries environment variables first, then telnet-probes common loopback ports
## (Clash, V2Ray, etc.) when env vars are unset.

## `ProxyDetectionResult.source` — proxy address read from HTTPS_PROXY / HTTP_PROXY / ALL_PROXY.
const SOURCE_ENV: String = "env"
## `ProxyDetectionResult.source` — proxy found by telnet on 127.0.0.1 and COMMON_LOCAL_PORTS.
const SOURCE_PROBE: String = "probe"

const ENV_KEYS: PackedStringArray = [
	"HTTPS_PROXY", "HTTP_PROXY", "ALL_PROXY",
	"https_proxy", "http_proxy", "all_proxy",
]

## Loopback ports tried by async_detect_local_proxy (in order).
const COMMON_LOCAL_PORTS: PackedInt32Array = [
	7890, 10809, 7897, 1080, 10808, 8080, 8888,
]


## Outcome of async_detect_proxy when a proxy is found. Null means no proxy.
class ProxyDetectionResult:
	## Normalized "host:port" for HttpHelper / AsyncHttp.
	var address: String = ""
	## How the address was found: SOURCE_ENV or SOURCE_PROBE.
	var source: String = ""

	func _init(_address: String = "", _source: String = "") -> void:
		address = _address
		source = _source

	func _to_string() -> String:
		return StringUtils.format("ProxyDetectionResult[address:{}, source:{}]", address, source)


## Detect a usable local HTTP proxy.
## Returns ProxyDetectionResult when found; null when env and loopback probe both miss.
static func async_detect_proxy(timeout_millis: int = 1000) -> ProxyDetectionResult:
	var from_env := get_proxy_from_env()
	if StringUtils.is_not_blank(from_env):
		return ProxyDetectionResult.new(from_env, SOURCE_ENV)

	var from_local := await async_detect_local_proxy(timeout_millis)
	if StringUtils.is_not_blank(from_local):
		return ProxyDetectionResult.new(from_local, SOURCE_PROBE)

	return null


## Read proxy from HTTPS_PROXY / HTTP_PROXY / ALL_PROXY (and lowercase variants).
## Strips scheme, credentials, and path; returns normalized "host:port". Empty when unset or invalid.
static func get_proxy_from_env() -> String:
	for key: String in ENV_KEYS:
		var raw := OS.get_environment(key)
		if StringUtils.is_blank(raw):
			continue

		var value := _remove_scheme(raw)
		var slash_index := value.find("/")
		if slash_index != -1:
			value = value.substr(0, slash_index)

		var at_index := value.rfind("@")
		if at_index != -1:
			value = value.substr(at_index + 1)

		var colon_index := value.rfind(":")
		if colon_index == -1:
			continue

		var host := value.substr(0, colon_index).strip_edges()
		var port := int(value.substr(colon_index + 1).strip_edges())
		if StringUtils.is_blank(host) or port < 1 or port > 65535:
			continue

		return StringUtils.format("{}:{}", host, port)
	return StringUtils.EMPTY


## Telnet COMMON_LOCAL_PORTS on loopback. Returns normalized "host:port" for the first open port; empty when none respond within timeout_millis.
static func async_detect_local_proxy(timeout_millis: int = 1000) -> String:
	for port: int in COMMON_LOCAL_PORTS:
		var open := await NetUtils.telnet(NetUtils.LOCAL_LOOPBACK_IP, port, timeout_millis)
		if open:
			return StringUtils.format("{}:{}", NetUtils.LOCAL_LOOPBACK_IP, port)
	return StringUtils.EMPTY


## Strip URL scheme (e.g. http://, socks5://). Returns input unchanged when no "://" is present.
static func _remove_scheme(raw: String) -> String:
	var value := raw.strip_edges()
	if not value.contains("://"):
		return value
	return StringUtils.substring_after(value, "://")
