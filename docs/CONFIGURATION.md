# LLM Extension Configuration Guide

This guide explains how to create, save, and use a configuration file for the NetLogo LLM extension.

## Format
- Plain text, UTF-8 encoded, one `key=value` per line.
- Empty lines are ignored; lines starting with `#` are comments.
- No quotes required; avoid trailing spaces around `=`.
- Supported keys: `provider`, `api_key`, `model`, `base_url`, `temperature`, `max_tokens`, `timeout_seconds`.

## Where to Save the File
- Recommended: save the file next to your `.nlogo` model (e.g., `config.txt`).
- Alternatively: save anywhere and pass a relative or absolute path.
- Resolution: the loader checks the path you pass, then the current working directory.

## How to Create It
1. Open a text editor (VS Code, Notepad, TextEdit in plain-text mode).
2. Paste one of the examples below and adjust values.
3. Save as `config.txt` (or `config-openai.txt`, etc.). Keep it out of version control if it contains secrets.

## Provider Examples

OpenAI
```
provider=openai
api_key=sk-REPLACE_ME
model=gpt-4o-mini
temperature=0.7
max_tokens=1000
timeout_seconds=30
```

Anthropic (Claude)
```
provider=anthropic
api_key=REPLACE_ME
model=claude-3-5-sonnet-20241022
temperature=0.7
max_tokens=4000
timeout_seconds=30
```

Google (Gemini)
```
provider=gemini
api_key=REPLACE_ME
model=gemini-1.5-pro
base_url=https://generativelanguage.googleapis.com/v1beta
temperature=0.7
max_tokens=2048
timeout_seconds=30
```

Local (Ollama, no API key)
```
provider=ollama
model=llama3.2
base_url=http://localhost:11434
temperature=0.7
max_tokens=2048
timeout_seconds=30
```

## Ollama Quick Start (No API Key)
Use Ollama to run models locally without any cloud credentials.

1) Install Ollama
- Download and install: https://ollama.com/download
- Docs/README: https://github.com/ollama/ollama

2) Start the server
- macOS/Windows apps usually start the background server automatically.
- CLI (any OS):
```
ollama serve
```
- Linux service (if installed as a service):
```
sudo systemctl enable --now ollama
```

3) Choose and download a model
- Browse models: https://ollama.com/library
- Pull a model (examples):
```
ollama pull llama3.2   
# or
ollama pull mistral
ollama pull qwen2
```

4) Verify installed models
```
ollama list
```

5) Quick local test
```
ollama run llama3.2
> Write a haiku about NetLogo.
```

6) Verify the server is reachable
```
curl http://localhost:11434/api/tags
```

7) Configure this extension for Ollama
- In your config file (see example above), set:
  - `provider=ollama`
  - `model=<one from ollama list>` (e.g., `llama3.2`, `mistral`)
  - `base_url=http://localhost:11434`
- Then in NetLogo:
```
extensions [ llm ]
llm:load-config "config-ollama.txt"
show llm:chat "Name two agent-based modeling use cases."
```

Notes
- The extension’s `llm:models` reports supported models; `ollama list` shows what is actually installed locally.
- Some models are large; ensure sufficient RAM/VRAM. Close other apps if startup fails.
- Default port is `11434`; adjust `base_url` if you run on a different host/port.

## Loading in NetLogo
Add the extension and load your config file:
```
extensions [ llm ]
llm:load-config "config.txt"        ;; or a path like "configs/openai.txt"
```
You can override values at runtime:
```
llm:set-model "gpt-4o"
```

## Verifying & Troubleshooting
- Verify provider and models:
```
show llm:providers
show llm:models
```
- Test a simple call:
```
show llm:chat "Say hello in five words."
```
- If you see missing key errors, ensure `api_key` is set for cloud providers and your `model` is supported.

## Security Tips
- Do not commit secrets. Keep your config in `.gitignore`.
- Use `demos/config-reference.txt` as a safe template and keep your real `config.txt` local.
