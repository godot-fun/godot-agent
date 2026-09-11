class_name AgentOrbController
extends Control

## Event-driven Jarvis orb overlay — shows while the active session agent runs.

var running_session_id: int = AgentSessionManager.INVALID_SESSION_ID
var phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var current_tool_name: String = ""

var vignette: JarvisOrbOverlay
var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var jarvis_orb: JarvisOrb
var fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	build_scene()
	connect_events()
	hide_orb_immediate()
	pass


func build_scene() -> void:
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "Viewport"
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.offset_right = 0.0
	viewport_container.offset_bottom = 0.0
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)

	sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.own_world_3d = true
	viewport_container.add_child(sub_viewport)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.glow_enabled = true
	environment.glow_intensity = 1.15
	environment.glow_strength = 0.85
	environment.glow_bloom = 0.28
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	env.environment = environment
	sub_viewport.add_child(env)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.05, OrbVisualScale.CAMERA_DISTANCE)
	camera.fov = OrbVisualScale.CAMERA_FOV
	sub_viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)

	jarvis_orb = JarvisOrb.new()
	sub_viewport.add_child(jarvis_orb)

	vignette = JarvisOrbOverlay.new()
	vignette.name = "Vignette"
	add_child(vignette)
	pass


func connect_events() -> void:
	AgentEvents.events.agent_start.connect(on_agent_start)
	AgentEvents.events.agent_end.connect(on_agent_end)
	AgentEvents.events.session_stop.connect(on_session_stop)
	AgentEvents.events.session_selected.connect(on_session_selected)
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.turn_end.connect(on_turn_end)
	AgentEvents.events.message_update.connect(on_message_update)
	AgentEvents.events.message_complete.connect(on_message_complete)
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	AgentEvents.events.chat_entry_add.connect(on_chat_entry_add)
	AgentEvents.events.theme_changed.connect(on_theme_changed)
	pass


func on_agent_start(session_id: int) -> void:
	running_session_id = session_id
	if jarvis_orb != null:
		jarvis_orb.reset_growth()
	if not AgentSessionManager.is_active(session_id):
		return
	transition_to(OrbPhase.Phase.AWAKE)
	show_orb()
	feed_latest_user_prompt(session_id)
	pass


func feed_latest_user_prompt(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null or jarvis_orb == null:
		return
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER:
			jarvis_orb.add_step_text(entry.body)
			return
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	if session_id != running_session_id:
		return
	var is_stop: bool = error_message == "Stop." or error_message == "Stop..."
	var end_phase: OrbPhase.Phase = OrbPhase.Phase.SUCCESS
	if StringUtils.is_not_blank(error_message) and not is_stop:
		end_phase = OrbPhase.Phase.ERROR
	transition_to(end_phase)
	var delay: float = 1.1 if end_phase == OrbPhase.Phase.ERROR else 0.75
	await get_tree().create_timer(delay).timeout
	if running_session_id == session_id:
		hide_orb()
		running_session_id = AgentSessionManager.INVALID_SESSION_ID
	pass


func on_session_stop(session_id: int) -> void:
	if session_id != running_session_id:
		return
	if visible:
		return
	running_session_id = AgentSessionManager.INVALID_SESSION_ID
	pass


func on_session_selected(session_id: int) -> void:
	if running_session_id == AgentSessionManager.INVALID_SESSION_ID:
		hide_orb_immediate()
		return
	if AgentSessionManager.is_active(running_session_id) and AgentSessionManager.is_running(running_session_id):
		show_orb_immediate()
	else:
		hide_orb_immediate()
	pass


func on_turn_start(session_id: int) -> void:
	if not _should_handle(session_id):
		return
	jarvis_orb.clear_stream_queue()
	transition_to(OrbPhase.Phase.AWAKE)
	pass


func on_turn_end(session_id: int) -> void:
	if not _should_handle(session_id):
		return
	transition_to(OrbPhase.Phase.TURN_COOLDOWN)
	pass


func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	if not _should_handle(session_id):
		return
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		transition_to(OrbPhase.Phase.REASONING)
	elif phase != OrbPhase.Phase.TOOL_EXEC:
		transition_to(OrbPhase.Phase.GENERATING)
	jarvis_orb.add_stream_chunk(chunk)
	jarvis_orb.neuron_net.pulse_random(0.35)
	pass


func on_message_complete(session_id: int, _usage: OpenAiUsage) -> void:
	if not _should_handle(session_id):
		return
	jarvis_orb.neuron_net.pulse_random(1.0)
	pass


func on_tool_execution_start(session_id: int, _tool_call_id: String, tool_name: String, args: Dictionary[String, String]) -> void:
	if not _should_handle(session_id):
		return
	current_tool_name = tool_name
	transition_to(OrbPhase.Phase.TOOL_EXEC, tool_name)
	var body := AgentSessionManager.format_tool_body(tool_name, args)
	jarvis_orb.add_step_text(body)
	pass


func on_tool_execution_end(session_id: int, _tool_call_id: String, tool_name: String, result: String) -> void:
	if not _should_handle(session_id):
		return
	if StringUtils.is_not_empty(result):
		var snippet := result if result.length() <= 180 else result.substr(0, 180)
		jarvis_orb.add_step_text(snippet)
	if phase == OrbPhase.Phase.TOOL_EXEC:
		transition_to(OrbPhase.Phase.AWAKE)
	pass


func on_chat_entry_add(session_id: int, entry: ChatEntry) -> void:
	if session_id != running_session_id or not _should_handle(session_id):
		return
	if entry.kind == ChatEntry.KIND_ERROR:
		jarvis_orb.add_step_text(entry.body)
	pass


func on_theme_changed(_is_dark: bool) -> void:
	if vignette != null:
		vignette.set_strength(0.45 if AgentColors.is_dark() else 0.22)
	pass


func transition_to(new_phase: OrbPhase.Phase, tool_name: String = "") -> void:
	phase = new_phase
	if jarvis_orb != null:
		jarvis_orb.set_phase(new_phase, tool_name if not tool_name.is_empty() else current_tool_name)
	pass


func show_orb() -> void:
	show_orb_immediate()
	modulate.a = 0.0
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(self, "modulate:a", 0.88, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if vignette != null:
		var target: float = 0.45 if AgentColors.is_dark() else 0.22
		fade_tween.tween_method(vignette.set_strength, 0.0, target, 0.45)
	pass


func show_orb_immediate() -> void:
	visible = true
	modulate.a = 0.88
	scale = Vector2.ONE
	if vignette != null:
		vignette.set_strength(0.45 if AgentColors.is_dark() else 0.22)
	pass


func hide_orb() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.55)
	if vignette != null:
		fade_tween.tween_method(vignette.set_strength, vignette.color.a, 0.0, 0.55)
	fade_tween.chain().tween_callback(hide_orb_immediate)
	pass


func hide_orb_immediate() -> void:
	visible = false
	modulate.a = 0.0
	phase = OrbPhase.Phase.IDLE
	if vignette != null:
		vignette.set_strength(0.0)
	if jarvis_orb != null:
		jarvis_orb.clear_stream_queue()
		jarvis_orb.reset_growth()
		jarvis_orb.set_phase(OrbPhase.Phase.IDLE)
	pass


func _should_handle(session_id: int) -> bool:
	if session_id != running_session_id:
		return false
	if not AgentSessionManager.is_active(session_id):
		return false
	return visible
