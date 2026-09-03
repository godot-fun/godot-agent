# Code Agent

A minimal coding agent for Godot projects, inspired by [Pi](https://github.com/earendil-works/pi) — simple layers, four core tools, clear boundaries.

## Architecture

```
agent/
├── AgentEvents.gd      # Global event bus (like gui/WorkflowEvents)
├── CodeAgent.tscn      # Runnable Godot scene (F6)
├── CodeAgent.gd        # Main app — wiring + toolbar / workspace
├── loop/               # Agent loop, tool registry
├── tools/              # read, write, edit, bash, web_search
├── session/            # AgentSession, AgentSessionManager, transcript
└── ui/                 # Chat view, sidebar, input, theme
```

LLM calls go through **`zfoo/ai`** (`ChatMessage`, `OpenAiClient`, `OpenAiCompletion`).

Dependency flow (top → bottom):

```
CodeAgent  →  session/AgentSession  →  loop/AgentLoop  →  zfoo/ai/OpenAiClient
                                              ↓
                                         tools/*
```

| Layer | Responsibility |
|-------|----------------|
| **zfoo/ai** | HTTP chat completions, SSE streaming, tool-call parsing |
| **agent** | Turn loop: model → tools → model until done |
| **tools** | Pi-style tools against the project workspace |
| **session** | Message history, system prompt, persistence |
| **ui** | File sidebar + chat panel + streaming bubbles |

## Run

1. Set `OPENAI_API_KEY` (or configure `OpenAiClient.api_key` / `base_url` / `model` in code).
2. Open `agent/CodeAgent.tscn` in Godot and press **F6** (Run Current Scene).

Or set main scene temporarily:

```
run/main_scene="res://agent/CodeAgent.tscn"
```

## Tools

| Tool | Description |
|------|-------------|
| `read` | Read a text file |
| `write` | Create or overwrite a file |
| `edit` | Replace an exact unique string |
| `bash` | Run a shell command from project root |
| `web_search` | Search the web (DuckDuckGo, no API key) |

## UI

- **Left sidebar** — session list; click to switch; **+ New chat** or toolbar **New Chat**
- **Concurrent chats** — each session runs independently; switch sessions while others are thinking
- **Chat area** — user / assistant / tool messages with streaming
- **Input bar** — type a task; **Ctrl+Enter** or **Send** to run

## Extend

- Add tools: subclass `AgentTool`, register in `AgentToolRegistry._static_init()`.
- Change model: `OpenAiClient.model` / `OpenAiClient.base_url`.
- Customize prompt: edit `session/SystemPrompt.gd`.
- Resolve workspace paths: `AgentWorkspace.resolve_path()`.
