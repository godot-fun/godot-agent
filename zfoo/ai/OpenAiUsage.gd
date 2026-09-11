class_name OpenAiUsage
extends RefCounted

## Token counts from an OpenAI-compatible `usage` response block.

var prompt_tokens: int = 0
var completion_tokens: int = 0
var total_tokens: int = 0


func has_data() -> bool:
	return prompt_tokens > 0 or completion_tokens > 0 or total_tokens > 0


func copy_from(other: OpenAiUsage) -> void:
	prompt_tokens = other.prompt_tokens
	completion_tokens = other.completion_tokens
	total_tokens = other.total_tokens
	pass
