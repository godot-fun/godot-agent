class_name AgentToolRegistry
extends RefCounted

## Maps tool names to AgentTool instances and builds OpenAI tool schemas.

static var tools: Dictionary[String, AgentTool] = {}
static var schemas: Array[OpenAiToolDef] = []

static func _static_init() -> void:
	register(ReadTool.new())
	register(WriteTool.new())
	register(EditTool.new())
	register(BashTool.new())
	register(WebSearchTool.new())
	pass


static func register(tool: AgentTool) -> void:
	tools[tool.name] = tool
	schemas.append(tool.get_schema())
	pass
