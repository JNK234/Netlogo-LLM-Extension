# LLM Extension Tests

Test suite for the NetLogo LLM extension, covering provider discovery, chat primitives, and thinking/reasoning model support.

## Setup

1. Install the LLM extension in NetLogo.
2. Copy or edit `config.txt` with your provider API keys.
3. For Ollama tests, ensure `ollama serve` is running.

## Test Procedures

### Offline (no API key needed)

| Procedure | What it tests |
|---|---|
| `test-provider-discovery` | `llm:providers-all`, `llm:providers`, `llm:provider-status` |
| `test-provider-help` | `llm:provider-help` for each provider |
| `test-invalid-provider` | Rejection of unknown provider names |

### Config-dependent (needs config loaded)

| Procedure | What it tests |
|---|---|
| `test-active-config` | `llm:active`, `llm:config`, `llm:list-models` |
| `test-model-validation` | Valid/invalid model acceptance via `llm:set-model` |

### API tests (makes LLM calls)

| Procedure | What it tests |
|---|---|
| `test-sync-chat` | `llm:chat` synchronous call |
| `test-async-chat` | `llm:chat-async` asynchronous call |
| `test-choose` | `llm:choose` constrained choice |
| `test-history` | `llm:history` and `llm:clear-history` |
| `test-backward-compat` | `llm:chat` still returns a plain string |

### Thinking / reasoning

| Procedure | What it tests |
|---|---|
| `test-thinking-config` | `set-thinking`, `set-reasoning-effort`, `set-thinking-budget` (no API call) |
| `test-chat-with-thinking` | `llm:chat-with-thinking` returns `[answer thinking]` list; thinking excluded from history |
| `test-reasoning-marker` | `[reasoning]` tag in `llm:list-models` output |

## Running All Tests

In the NetLogo Command Center:

```
run-all-tests
```

This executes every procedure listed above in order.

## Optional: Ollama Thinking Test

Requires a local Ollama server with a thinking-capable model.

```
ollama pull qwen3:0.6b
ollama serve
```

Then in the Command Center:

```
test-ollama-qwen3-thinking
```

This switches to Ollama, runs a regular chat and a `chat-with-thinking` call against `qwen3:0.6b`, and verifies the return format.
