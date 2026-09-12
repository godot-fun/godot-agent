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
	return OrbTheme.neuron_color_for(phase)


static func filament_color_for(phase: Phase) -> Color:
	return OrbTheme.filament_color_for(phase)


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
