# NetLogo Multi-LLM Extension

A comprehensive NetLogo extension that provides unified access to multiple Large Language Model (LLM) providers including OpenAI, Anthropic Claude, Google Gemini, and local Ollama models.

## ✨ Features

- **Multi-Provider Support**: OpenAI, Anthropic, Google Gemini, and Ollama
- **Unified API**: Same NetLogo primitives work with all providers
- **True Async Processing**: Non-blocking LLM requests with `llm:chat-async`
- **Per-Agent Memory**: Automatic conversation history per NetLogo agent
- **Constrained Choice**: `llm:choose` for agent decision-making
- **Flexible Configuration**: File-based config with easy provider switching
- **Production Ready**: Timeout handling, error management, extensible architecture

## 🚀 Quick Start

1. **Install Extension**: Copy `llm.jar` to your NetLogo extensions folder
2. **Configure Provider**: Create `config.txt` with your preferred LLM provider
3. **Load in NetLogo**: Add `extensions [llm]` to your model
4. **Start Chatting**: Use `llm:chat "Hello!"` to test

### Example NetLogo Model

```netlogo
extensions [llm]

to setup
  ; Load your configuration file
  llm:load-config "config.txt"
  print "LLM extension loaded successfully!"
end

to test-chat
  let response llm:chat "What is NetLogo?"
  print response
end

to async-example
  ; Start a non-blocking request
  let awaitable llm:chat-async "Explain agent-based modeling"
  
  ; Do other work while waiting
  print "Processing other tasks..."
  
  ; Get the response when ready
  let response runresult awaitable
  print response
end
```

## 📖 Documentation

### Setup and Configuration
- **[SETUP.md](SETUP.md)** - Complete installation and configuration guide
- **[PROVIDER-GUIDE.md](PROVIDER-GUIDE.md)** - Detailed provider configuration with all hyperparameters

### API Reference and Usage
- **[API-REFERENCE.md](API-REFERENCE.md)** - Complete primitive documentation with examples
- **[EXAMPLES.md](EXAMPLES.md)** - Comprehensive usage examples and patterns
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

### Demo Models
- **[demos/](demos/)** - Working NetLogo models demonstrating extension capabilities

## 🔧 Supported Providers

| Provider | Models | API Key Required | Local |
|----------|---------|------------------|--------|
| **OpenAI** | GPT-4o, GPT-4o-mini, GPT-4-turbo, GPT-3.5-turbo | ✅ | ❌ |
| **Anthropic** | Claude-3.5 Sonnet, Claude-3 Opus/Sonnet/Haiku | ✅ | ❌ |
| **Google Gemini** | Gemini-1.5 Pro/Flash, Gemini-Pro | ✅ | ❌ |
| **Ollama** | Llama 3.2, Mistral, CodeLlama, DeepSeek, and more | ❌ | ✅ |

## 🎯 Core Primitives

### Configuration
- `llm:load-config filename` - Load provider configuration from file
- `llm:set-provider provider` - Switch between providers
- `llm:set-api-key key` - Set API key for cloud providers
- `llm:set-model model` - Set specific model

### Chat Operations
- `llm:chat message` - Send message, get response (synchronous)
- `llm:chat-async message` - Send message, return awaitable (asynchronous)
- `llm:choose prompt choices` - Get LLM to pick from predefined options

### History Management
- `llm:history` - Get conversation history for current agent
- `llm:set-history messages` - Set conversation context
- `llm:clear-history` - Clear conversation memory

### Provider Information
- `llm:providers` - List available providers
- `llm:models` - List models for current provider

## 💡 Key Use Cases

### 🤖 Intelligent Agents
Create NetLogo agents that make decisions using natural language reasoning:

```netlogo
ask turtles [
  let situation (word "I'm at position " xcor "," ycor " with " energy " energy")
  let action llm:choose situation ["move-forward" "turn-left" "turn-right" "rest"]
  execute-action action
]
```

### 🧠 Multi-Agent Conversations
Enable agents with different personalities to interact:

```netlogo
turtles-own [personality]

ask turtles [
  set personality one-of ["optimistic" "analytical" "creative"]
  llm:set-history (list (word "You are " personality) "I understand")
  
  let response llm:chat "What do you think about cooperation?"
  print (word personality " turtle: " response)
]
```

### ⚡ Async Processing
Handle multiple LLM requests simultaneously without blocking:

```netlogo
; Start multiple requests
let awaitable1 llm:chat-async "Analyze this data..."
let awaitable2 llm:chat-async "Generate a hypothesis..."

; Do other work
update-simulation

; Collect results when ready
let analysis runresult awaitable1
let hypothesis runresult awaitable2
```

## 🛠️ Installation

### Requirements
- NetLogo 7.0.0 or later
- Java 11 or later
- Internet connection (for cloud providers) or Ollama (for local models)

### Installation Steps

1. **Download Extension**
   - Copy `llm.jar` to your NetLogo extensions directory
   - **Windows**: `%APPDATA%\NetLogo\[version]\extensions\`
   - **Mac**: `~/Library/Application Support/NetLogo/[version]/extensions/`
   - **Linux**: `~/.netlogo/[version]/extensions/`

2. **Configure Provider**
   - Copy `demos/config.txt` to your model directory
   - Edit with your API keys and preferred settings
   - See [SETUP.md](SETUP.md) for detailed configuration

3. **Test Installation**
   - Create a simple NetLogo model with `extensions [llm]`
   - Run `llm:load-config "config.txt"`
   - Test with `llm:chat "Hello!"`

## 🔐 Configuration Examples

### OpenAI (Recommended for getting started)
```ini
provider=openai
model=gpt-4o-mini
api_key=sk-your-openai-key-here
temperature=0.7
max_tokens=1000
```

### Local Ollama (Free, no API key needed)
```ini
provider=ollama
model=llama3.2
temperature=0.7
max_tokens=2048
timeout_seconds=60
```

### Anthropic Claude (High quality responses)
```ini
provider=anthropic
model=claude-3-haiku-20240307
api_key=sk-ant-your-claude-key-here
temperature=0.5
max_tokens=4000
```

## 🔬 Research Applications

This extension is designed for:

- **Agent-Based Modeling**: LLM-powered agents with natural language reasoning
- **Social Simulation**: Agents with distinct personalities and communication patterns
- **Educational Models**: Teaching AI concepts in accessible NetLogo environment
- **Research Prototyping**: Quick experimentation with different LLM providers
- **Behavioral Studies**: Modeling human-like decision making and interaction

## 🏗️ Architecture

The extension uses a **Strategy + Factory pattern** for extensible provider management:

- **LLMProvider trait**: Common interface for all providers
- **ProviderFactory**: Creates appropriate provider instances
- **ConfigStore**: Manages configuration with validation
- **WeakHashMap**: Per-agent conversation history with automatic cleanup
- **AwaitableReporter**: True async support using NetLogo's reporter pattern

This architecture makes it easy to add new providers and ensures consistent behavior across all LLM services.

## 🚨 Important Notes

### API Costs
- Cloud providers (OpenAI, Anthropic, Gemini) charge per token
- Monitor usage at provider dashboards to avoid unexpected costs
- Consider using local Ollama models for development and testing
- See [PROVIDER-GUIDE.md](PROVIDER-GUIDE.md) for cost optimization tips

### Rate Limits
- All providers have rate limits (requests per minute/hour)
- Implement appropriate delays in your models
- Use async processing to maximize throughput
- Consider upgrading API tiers for higher limits

### Security
- Never commit API keys to version control
- Use configuration files with appropriate permissions
- Rotate API keys regularly
- Be cautious with sensitive data in prompts

## 📊 Version Information

- **Current Version**: 1.0.0
- **NetLogo Compatibility**: 7.0.0+
- **Scala Version**: 3.7.0
- **Last Updated**: 2024


