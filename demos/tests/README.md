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

## Configuration

The test suite supports all LLM providers:
- OpenAI
- Anthropic (Claude)
- Google (Gemini)
- Ollama (local)

Edit `config.txt` to switch between providers.