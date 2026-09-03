class_name SystemPrompt
extends RefCounted

## Minimal coding-agent system prompt (Pi-style, under ~500 tokens).


static func build() -> String:
	return StringUtils.format(
		"""You are a coding agent in a Godot project workspace.

Project root: {}

{}

{}

You have five tools: read, write, edit, bash, web_search.
- read: read file contents
- write: create or overwrite a file
- edit: replace an exact unique string in a file
- bash: run shell commands from project root
- web_search: search the web for docs, errors, APIs, or facts

Rules:
- Prefer edit over write when changing existing files.
- Use read before edit to verify content.
- Use web_search when you need up-to-date docs or facts not in the repo.
- Keep changes minimal and focused.
- Explain briefly what you did after finishing.""",
		AgentWorkspace.get_root(),
		build_godot_context(),
		build_os_context()
	)


static func build_godot_context() -> String:
	var build := StringBuilder.new()
	build.append(StringUtils.format("Godot version: {}", OSUtils.godot_version()))
	var executable_path := OS.get_executable_path()
	if StringUtils.is_not_blank(executable_path):
		build.append(StringUtils.format("Godot executable: {}", executable_path))
	return build.build_joined(StringUtils.LS)


static func build_os_context() -> String:
	var build := StringBuilder.new()
	build.append(StringUtils.format("Operating system: {} {}", OS.get_name(), OS.get_version()))
	var alias := OS.get_version_alias()
	if StringUtils.is_not_blank(alias):
		build.append(StringUtils.format("OS version alias: {}", alias))
	var distro := OS.get_distribution_name()
	if StringUtils.is_not_blank(distro):
		build.append(StringUtils.format("Distribution: {}", distro))
	build.append(StringUtils.format("Locale: {}", OS.get_locale()))
	var tz := Time.get_time_zone_from_system()
	if StringUtils.is_not_blank(str(tz.get("name", ""))):
		build.append(StringUtils.format("Time zone: {}", tz.get("name", "")))
	build.append(StringUtils.format("CPU cores: {}", OS.get_processor_count()))
	var arch := detect_architecture()
	if StringUtils.is_not_blank(arch):
		build.append(StringUtils.format("Architecture: {}", arch))
	if OSUtils.is_windows():
		build.append("Bash tool runs via: cmd.exe")
	else:
		build.append("Bash tool runs via: /bin/sh")
	return build.build_joined(StringUtils.LS)


static func detect_architecture() -> String:
	if OS.has_feature("arm64"):
		return "arm64"
	if OS.has_feature("x86_64") or OS.has_feature("x64"):
		return "x86_64"
	if OS.has_feature("x86_32") or OS.has_feature("x86"):
		return "x86"
	if OS.has_feature("arm32"):
		return "arm32"
	return ""
