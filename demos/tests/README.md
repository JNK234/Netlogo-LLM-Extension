# LLM Extension Tests

This directory contains test models for the NetLogo LLM Extension.

## Files

- `tests.nlogox` - Main test suite for LLM extension functionality
- `config.txt` - Configuration file for running tests

## Setup

1. Ensure you have the LLM extension installed
2. Edit `config.txt` with your provider settings and API keys
3. For Ollama (local), ensure the Ollama server is running

## Running Tests

1. Open `tests.nlogox` in NetLogo
2. The model will automatically load the config file
3. Run individual test procedures:
   - `test-extension-loading` - Tests basic extension loading
   - `test-sync-chat` - Tests synchronous chat functionality
   - `test-async-chat` - Tests asynchronous chat functionality
   - `test-providers-list` - Tests provider listing and status primitives
   - `test-active-config` - Tests active configuration reporting
   - `test-provider-help` - Tests provider help system
   - `test-models-list` - Tests model listing for each provider

## Configuration

The test suite supports all LLM providers:
- OpenAI (requires API key)
- Anthropic/Claude (requires API key)
- Google/Gemini (requires API key)
- Ollama (requires running server, no API key)

Edit `config.txt` to switch between providers. You can configure multiple providers at once using provider-specific keys (`openai_api_key`, `anthropic_api_key`, etc.).

## New Features Tested

### Provider Status and Information
- `llm:providers` - Lists only READY providers (with keys or reachable)
- `llm:providers-all` - Lists all supported providers
- `llm:provider-status` - Detailed status for each provider
- `llm:provider-help` - Setup instructions for a provider

### Active Configuration
- `llm:active` - Returns current provider and model
- `llm:config` - Returns full config summary (with masked keys)

### Immediate Validation
- Provider readiness is validated immediately when setting provider or loading config
- Clear error messages with setup guidance if validation fails
- Ollama reachability checked when selecting Ollama provider
