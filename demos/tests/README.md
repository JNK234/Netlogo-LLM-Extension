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

### Basic Functionality Tests
   - `test-extension-loading` - Tests basic extension loading
   - `test-sync-chat` - Tests synchronous chat functionality
   - `test-async-chat` - Tests asynchronous chat functionality
   - `test-choose` - Tests constrained choice functionality
   - `test-providers-list` - Tests provider listing and status primitives
   - `test-active-config` - Tests active configuration reporting
   - `test-provider-help` - Tests provider help system
   - `test-models-list` - Tests model listing for each provider
   - `test-provider-switching` - Tests switching between providers
   - `test-config-loading` - Tests loading configuration from file

### Config Validation Tests (New)
   - `test-ollama-not-running` - Tests error handling when Ollama server is unreachable
   - `test-invalid-config` - Tests validation when API keys are missing
   - `test-provider-readiness` - Tests provider readiness detection
   - `test-config-error-messages` - Tests helpful error messages and provider help

### Complete Test Suites
   - `test-multi-provider-complete` - Runs all basic functionality tests
   - `test-config-validation-complete` - Runs all config validation tests

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
- `llm:provider-status` - Detailed status for each provider (ready, has-key, reachable, base-url)
- `llm:provider-help` - Setup instructions for a provider

### Active Configuration
- `llm:active` - Returns current provider and model
- `llm:config` - Returns full config summary (with masked keys)

### Immediate Validation
- Provider readiness is validated immediately when setting provider or loading config
- Clear error messages with setup guidance if validation fails
- Ollama reachability checked when selecting Ollama provider
- API key presence validated for cloud providers (OpenAI, Anthropic, Gemini)

## Testing Config Validation

### Testing Ollama Server Not Running
To test Ollama error handling when the server is not installed or running:

1. Ensure Ollama is NOT running (don't start `ollama serve`)
2. Run `test-ollama-not-running` in NetLogo Command Center
3. Expected results:
   - Provider status shows `reachable: false`
   - Ollama does NOT appear in `llm:providers` list
   - Attempting to chat produces helpful error message
   - `llm:provider-help "ollama"` shows installation instructions

### Testing Missing API Keys
To test API key validation:

1. Run `test-invalid-config` in NetLogo Command Center
2. Expected results:
   - Provider status shows `has-key: false` for providers without keys
   - Providers without keys do NOT appear in `llm:providers` list
   - Attempting to use provider without key produces error message
   - `llm:provider-help` shows where to obtain API keys

### Running Complete Validation Suite
Run `test-config-validation-complete` to execute all config validation tests:
- Provider readiness checks
- Ollama server reachability detection
- API key validation
- Error message clarity
- Active configuration reporting
