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
	
	var is_proxy := await NetUtils.telnet(NetUtils.LOCAL_LOOPBACK_IP, 10809)
	if is_proxy:
		register(WebSearchToolProxy.new())
	else:
		register(WebSearchToolBing.new())
	pass


static func register(tool: AgentTool) -> void:
	tools[tool.name] = tool
	schemas.append(tool.get_schema())
	pass
