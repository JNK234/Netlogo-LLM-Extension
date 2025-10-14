# NetLogo Multi-LLM Extension

Unified LLM capabilities for NetLogo with multi-provider support (OpenAI, Anthropic/Claude, Google/Gemini, and local Ollama), per‑agent memory, async requests, and simple configuration.

## Quick Links
- Usage Guide: `docs/USAGE.md`
- Configuration Guide: `docs/CONFIGURATION.md`
- API Reference: `docs/API-REFERENCE.md`
- Provider Guide: `docs/PROVIDER-GUIDE.md`
- Demos: `demos/`
- Full Reference Doc: `NetLogo-LLM-Extension-Documentation.md`

## Quick Start
1) Add the extension in your model:
```
extensions [ llm ]
```
2) Configure a provider (recommended via file):
```
llm:load-config "config.txt"
```
See `docs/CONFIGURATION.md` for ready-to-copy examples (OpenAI, Anthropic, Gemini, Ollama). For inline setup:
```
llm:set-provider "openai"
llm:set-api-key "sk-REPLACE_ME"
llm:set-model "gpt-4o-mini"
```
3) Chat:
```
show llm:chat "Say hello in five words."
```

## Core Features
- Multi-provider with a single set of primitives.
- Per-agent conversation history and `llm:clear-history`.
- Synchronous `llm:chat` and asynchronous `llm:chat-async` (+ `runresult`).
- Prompt templates with `llm:chat-with-template` (YAML + variables).
- Constrained decisions with `llm:choose`.

## Install
- Per-model or global installation instructions and build steps are in `docs/USAGE.md`.
- The `demos/` folder contains working models you can open immediately.

## Notes
- Keep API keys out of `.nlogo` files; prefer `llm:load-config`.
- For local, no-API usage, see the Ollama quick start in `docs/CONFIGURATION.md`.

If you need deeper details (architecture, patterns, troubleshooting), start with `docs/USAGE.md` and the full reference document.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](../LICENSE) file for details.
