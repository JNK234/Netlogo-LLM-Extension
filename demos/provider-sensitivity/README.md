# Provider Sensitivity Demo

Compares how different LLM providers respond to identical prompts. Reveals differences in response style, length, reasoning approach, and decision-making across OpenAI, Anthropic, Gemini, and Ollama.

## Files

- `provider-sensitivity.nlogo` - Main comparison model
- `tests.nlogo` - Test suite for config, provider switching, and comparison logic
- `config` - Multi-provider configuration (set your API keys here)

## Features

- Sends identical prompts to all ready providers and displays results side-by-side
- Four prompt categories: factual, creative, reasoning, decision
- `llm:choose` comparison to test constrained decision-making across providers
- Custom prompt input for ad-hoc comparisons
- Per-provider average response length statistics
- Graceful handling of unavailable providers

## Setup

1. Edit `config` with API keys for every provider you want to compare
2. For Ollama, ensure the server is running (`ollama serve`)
3. At minimum, configure **two** providers to see meaningful comparisons

## Running the Demo

1. Open `provider-sensitivity.nlogo` in NetLogo
2. Click **setup** to load config and detect ready providers
3. Select a **prompt-category** from the chooser
4. Click **go** (one prompt at a time) or **go-all** (run through all prompts)
5. Click **Show Results** for a formatted comparison table with length stats
6. Click **Compare Choose** to test `llm:choose` across providers
7. Type a custom prompt and click **Compare Custom** for one-off tests
8. Click **Provider Status** to inspect configuration state

## Running Tests

1. Open `tests.nlogo` in NetLogo
2. Click **setup** then **Run All Tests**
3. Tests cover: config loading, provider discovery, switching, status reporting, active config, sync chat, choose, history isolation, and multi-provider comparison

## Configuration

The demo uses provider-specific API keys so all providers can be configured simultaneously:

| Key | Provider |
|-----|----------|
| `openai_api_key` | OpenAI |
| `anthropic_api_key` | Anthropic |
| `gemini_api_key` | Gemini |
| `ollama_base_url` | Ollama (local) |

Only providers with valid keys (or a reachable Ollama server) will appear as "ready" during setup.
