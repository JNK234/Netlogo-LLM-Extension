# Color Sharing Demo

This demo showcases multi-agent communication using the LLM extension. Agents share information about their favorite colors and build a social knowledge network.

## Files

- `color-sharing.nlogox` - Main NetLogo model using LLM extension
- `color-sharing-interface.txt` - Interface elements for the model
- `config.txt` - LLM configuration file

## Features

- Agents communicate using natural language via LLM
- Each agent maintains conversation history
- Agents share knowledge about favorite colors
- Visual network shows social connections
- Real-time conversation display

## Setup

1. Edit `config.txt` with your LLM provider settings
2. For cloud providers (OpenAI, Anthropic, Gemini), add your API key
3. For Ollama, ensure the server is running locally

## Running the Demo

1. Open `color-sharing.nlogox` in NetLogo
2. Click `setup` to initialize agents and load configuration
3. Click `go` to start agent conversations
4. Watch agents share color preferences and build knowledge

## Configuration Options

The demo supports multiple LLM providers:
- OpenAI (GPT models)
- Anthropic (Claude)
- Google (Gemini)
- Ollama (local models)

Adjust `temperature` and `max_tokens` in config.txt to control response creativity and length.