class_name OrbPhase
extends RefCounted

## Visual phase for the Jarvis orb — driven by AgentEvents lifecycle.

enum Phase {
	IDLE,
	AWAKE,
	REASONING,
	GENERATING,
	TOOL_EXEC,
	TURN_COOLDOWN,
	SUCCESS,
	ERROR,
}

enum PathStyle {
	SPIRAL_IN,
	TRANSVERSE,
	ORBIT,
	CHAOTIC,
}


static func path_style_for(phase: Phase) -> PathStyle:
	match phase:
		Phase.REASONING:
			return PathStyle.SPIRAL_IN
		Phase.TOOL_EXEC:
			return PathStyle.ORBIT
		Phase.ERROR:
			return PathStyle.CHAOTIC
		_:
			return PathStyle.TRANSVERSE


static func color_for(phase: Phase) -> Color:
	match phase:
		Phase.REASONING:
			return Color(0.66, 0.33, 0.97, 1.0)
		Phase.GENERATING:
			return Color(0.0, 0.92, 1.0, 1.0)
		Phase.TOOL_EXEC:
			return Color(0.96, 0.72, 0.26, 1.0)
		Phase.SUCCESS:
			return Color(0.0, 0.92, 0.63, 1.0)
		Phase.ERROR:
			return Color(1.0, 0.27, 0.4, 1.0)
		Phase.AWAKE, Phase.TURN_COOLDOWN:
			return Color(0.0, 0.9, 1.0, 1.0)
		_:
			return Color(0.0, 0.85, 1.0, 0.6)


static func keywords_for(phase: Phase, tool_name: String = "") -> Array[String]:
	if phase == Phase.TOOL_EXEC and not tool_name.is_empty():
		if AgentColors.is_file_tool(tool_name):
			return ["SOURCE", "PATCH", "FILE"]
		if tool_name == BashTool.NAME:
			return ["EXECUTE", "PIPELINE", "SHELL"]
		if tool_name == WebSearchToolProxy.NAME or tool_name == WebSearchToolBing.NAME:
			return ["DATASTREAM", "RETRIEVE", "SEARCH"]
		return ["PROCESS", "TOOL", "RUN"]
	match phase:
		Phase.REASONING:
			return ["INFERENCE", "COGNITION", "REASON"]
		Phase.GENERATING:
			return ["SYNTHESIS", "OUTPUT", "STREAM"]
		Phase.AWAKE:
			return ["NETWORK", "ONLINE", "READY"]
		Phase.SUCCESS:
			return ["COMPLETE", "DONE"]
		Phase.ERROR:
			return ["FAULT", "ABORT"]
		_:
			return ["THINK", "PROCESS"]
