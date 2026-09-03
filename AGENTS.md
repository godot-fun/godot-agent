# Project Directory Structure

Separate **framework**, **resources (by type)**, and **game code**. Do not mix them.

```
project-root/
├── zfoo/          # Framework only — sync/upgrade; no game business logic
├── assets/        # Extra assets (video, fonts, 3D, …)
├── audio/         # Audio assets
├── image/         # Image assets
├── config/        # CSV/JSON tables (optional)
├── shader/        # Custom shaders (optional)
├── scene/         # Runnable and instanced .tscn scenes
├── script/        # Game scripts (.gd), systems, data models
├── test/          # Unit tests (UnitTest.gd scenes)
└── project.godot
```

## Resource directories (no `.gd` logic)

**`image/`** — textures and sprites:

```
image/
├── ui/            # Buttons, panels, icons
├── characters/    # Character sprites and portraits
├── backgrounds/   # Scene backgrounds
├── tiles/         # Tilemap tiles
└── effects/       # VFX and particle textures
```

**`audio/`** — use with zfoo `Audio` API:

```
audio/
├── bgm/           # Looping background music
├── sfx/           # Short one-shot sound effects
└── voice/         # Voice-over and narration
```

**`assets/`** — video, fonts, 3D, and other extra binary assets:

```
assets/
├── video/         # Cutscenes, trailers, background video
├── font/          # Font files (.ttf, .otf, …)
├── 3d/            # Models, meshes, materials, animations
└── …              # Other misc assets as needed
```

**Other resource roots** (add when needed): `config/`, `shader/`.

## Game code — `scene/` and `script/`

```
scene/
├── boot/
├── main/
├── gameplay/
└── ui/

script/
├── autoload/      # Game Autoloads (after GodotFramework)
├── core/          # Constants, ResPath, shared base classes
├── data/          # Resource classes and .tres instances
├── systems/       # Pure logic (inventory, save, quest, …)
└── network/       # Packets and codec (zfoo Router)
```

# GDScript (this project)

- **Types**: Use explicit types on function signatures and return values (`-> void`, etc.). Use the `class_name` type when a class has one. **Prefer `:=` for locals** to lock in the inferred type at declaration; use `var x = ...` only when you need Variant or mixed types.
- **Docs**: Use `##` comments for scene entry points or complex logic. Match the tone of nearby files.
- **Nodes**: Prefer `@onready var name: Type = $Path`.
- **Trailing pass**: If a function has no `return` statement, end the body with `pass`.

# Underscores and naming (Godot 4)

**`_` is mainly for engine callbacks** (`_ready`, `_process`, `_notification`, `_init`, etc.). **Do not prefix business methods** like `_refresh_xxx` — that clutters the file with `_` like lifecycle hooks. Use `_` on variables sparingly for internal details. GDScript has no real private; use structure and folders instead.

**Member variables**: Normal state/refs usually **no `_`** (`player`, `news_cache`). Too many `_` names hurt autocomplete and search, and look like lifecycle hooks. Use `_` only for clear implementation details (`_http_client`, `_buffer`, `_is_loading`). Official small demos often use `var _speed`; large projects do not need that pattern everywhere.

| Kind | Naming | Notes |
|------|--------|-------|
| Engine lifecycle | `_ready`, `_process`, `_input`, `physics_*`, etc. | Keep the official `_` prefix. |
| Normal members | `player`, `ui_panel`, `news_cache` | **No** `_` prefix. |
| Internal vars | `_http_client`, `_buffer`, `_retry_count` | Implementation detail; **use sparingly**. |
| Signal handlers | `on_buy_pressed`, `on_timer_timeout`, or `handle_buy`, `handle_close` | **No** `_on_*`; keep separate from engine hooks. |
| Business / utils | `refresh_trendings`, `set_tab`, `load_config_file` | **No** `_` prefix; distinguish from lifecycle funcs. |

When connecting signals in `_ready`, prefer:

```gdscript
func _ready() -> void:
	button.pressed.connect(on_buy_item)
	pass

func on_buy_item() -> void:
	pass

func refresh_ui() -> void:
	update_labels()
	pass
```


# godot-framework

## AI — OpenAI-compatible chat

```gdscript
# Set OPENAI_API_KEY env, or override OpenAiClient.api_key / base_url / model
var reply := await OpenAiClient.async_chat("hello", "you are a helpful assistant")

# Streaming — on_delta called for each token fragment; read full text from completion.content
var stream_completion := await OpenAiClient.async_chat_messages_stream(
	OpenAiClient.build_messages("hello", "you are a helpful assistant"),
	[],
	func(delta: String): print(delta)
)
var streamed := stream_completion.content

# Multi-turn
var messages: Array[ChatMessage] = []
messages.append(ChatMessage.new(ChatMessage.ROLE_USER, "hello"))
var reply2 := await OpenAiClient.async_chat_messages(messages)

# Tool-calling agent loop (see agent/)
var tools: Array[OpenAiToolDef] = registry.get_schemas()
var completion := await OpenAiClient.async_chat_messages_stream(messages, tools, func(delta: String): print(delta))
```

---


## Alert — Floating toast messages

```gdscript
Alert.alert("Saved successfully", Colors.success)
Alert.alert("Network error", Colors.error)
```

---


## Audio — play music, sound, voice，SoundEffect

```gdscript
# Single track or playlist (auto cross-fade near end of track)
Audio.play_music("res://audio/bgm.mp3")
Audio.play_musics(["res://audio/a.mp3", "res://audio/b.mp3"])

# One-shot sound / voice
await Audio.play_voice("res://audio/narration.mp3")

# Multi-channel SFX (overlapping sounds on SoundEffect bus)
Audios.play("res://audio/click.mp3", 0.8)
```

---

## Animation

```gdscript
# plays a one-shot sprite sheet animation and removes itself when finished. Multi-row sheet: 4 columns × 4 rows, scale 0.5, 13 fps
EffectAnimation2D.spawn(Vector2(500, 200), self, "res://effects/attack.png", Vector2i(4, 4), 0.5, 13)
```

---

## Unit tests

- Attach `zfoo/gdtest/UnitTest.gd` to a scene; it scans `.gd` files in the scene’s folder.
- In each file, every no-arg method whose name **starts or ends with `test`** (case-insensitive) is run as a unit test.

## Integration tests

- Attach `zfoo/gdtest/IntegrationTest.gd` to a scene; it scans the scene’s folder for `.tscn` whose name **starts or ends with `test`**, then runs them one by one.
- Each finished test scene must emit `gdf.events.test_passed` (UnitTest does this automatically).

---

## HotUpdate

- Godot PCK Hot Update for single pck
- Workflow: Launch App → Check Version → Download PCK → Verify MD5 → Load PCK → Enter Game

---

## Http

```gdscript
# GET request
var response := await HttpHelper.async_get("https://api.example.com/data")
if response.success:
    Log.info(response.get_body_string())
```

---

## Log

- file logger at `{user_data}/logs/godot.log`

```gdscript
Log.info("player login uid:[{}]", user_id)
Log.error("load failed path:[{}] err:[{}]", path, err)
```

---

## Network

- support `TcpClient`, `TcpClientThread`, `WebsocketClient`, `WebsocketClientThread`

```gdscript
# Create a network seesion
# `ICodec` for encode/decode
var session: Session = TcpClient.new(Codec.new(), "127.0.0.1:80")

# Register receiver (typically at login / session init)
Router.register_receiver(LoginResponse, func(packet: LoginResponse) -> void: on_login_response(packet))

# Send message is Fire-and-forget
Router.send(session, SomeRequest.new())

# Request–response (waits for matching reply or timeout)
var reply: LoginResponse = await Router.async_ask(session, LoginRequest.new())
```

---

## ResourceHelper — async loading

- Avoid blocking the main thread when loading large assets.

```gdscript
var texture: Texture2D = await ResourceHelper.async_load("res://assets/icon.svg")
var scene: PackedScene = await ResourceHelper.async_load("res://scene/Level.tscn")
```

---

## SceneHelper — scenes & nodes

```gdscript
# Switch scene with fade transition (default: RectTransitionFade)
await SceneHelper.async_change_scene_to_file("res://scene/Main.tscn")

# Custom slide transition
await SceneHelper.async_change_scene_to_file("res://scene/Main.tscn", RectTransitionSlide.new())

# Instantiate a scene as child of a node
var node := SceneHelper.add_scene_to_node(load("res://scene/Popup.tscn"), self)

# Safe queue_free
SceneHelper.queue_free(old_node)
```

---

## SchedulerBus — delayed & periodic tasks

```gdscript
var sw := StopWatch.new() # sw.cost_seconds()

# Run once after 1000 ms
SchedulerBus.schedule(func() -> void: do_something(), 1000)

# Run every 2000 ms (optional timer name, optional sub-thread)
SchedulerBus.schedule_at_fixed_rate(func() -> void: poll_status(), 2000)
```

---

## Setting — persistent user config

```gdscript
Setting.set_bool("sound_enabled", true)
Setting.set_string("nickname", "player1")
Setting.save()

var enabled := Setting.get_bool("sound_enabled", false)
var name := Setting.get_string("nickname", "")
```

---

## Utils — common helpers

- Also available: `ArrayUtils`, `CollectionUtils`, `NumberUtils`, `NetUtils`, `HttpUtils`, `IdUtils`, `RateLimitUtils`.

```gdscript
# StringUtils
var msg := StringUtils.format("score:[{}] name:[{}]", score, name)
if StringUtils.is_blank(text):
    return

# TimeUtils
var ts := TimeUtils.now()              # cached ms timestamp (updated each second)
var now_str := TimeUtils.date()        # "yyyy-mm-dd hh:mm:ss"

# JsonUtils — plain objects with public fields
var obj = JsonUtils.json_to_object('{"name":"test","age":10}', Student)
var json := JsonUtils.object_to_json(obj)

# FileUtils
FileUtils.write_string_to_file("user://log.txt", content)
var text := FileUtils.read_file_to_string("user://log.txt")
FileUtils.delete_file("user://log.txt")

# RandomUtils
var n := RandomUtils.random_int_limit(100)
var item = RandomUtils.random_ele(items)

# ThreadUtils — non-blocking wait on main thread
await ThreadUtils.async_sleep(500)
```

---

## GodotFramework — gdf

The Autoload node runs `GodotFramework.gd`, whose global class name is `gdf`.

```gdscript
# Defer a callable to the main thread (useful from network / worker callbacks)
gdf.callable_deferred(func() -> void: refresh_ui())

# Graceful exit (waits a few frames before quit)
await gdf.quit()
```

