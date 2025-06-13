# NetLogo Multi-LLM Extension Specification

## Overview

A NetLogo extension that provides a unified interface for multiple Large Language Model (LLM) providers, starting with OpenAI and designed for easy extensibility to Anthropic Claude, Google Gemini, Ollama, and others.

## Design Principles

- **Extensibility First**: Built using Strategy + Factory patterns to minimize code duplication when adding new providers
- **Iterative Development**: Start with fully functional OpenAI implementation, then extend iteratively
- **Simple Interface**: Clean, consistent primitives regardless of underlying provider
- **Per-Agent Context**: Each NetLogo agent maintains separate conversation history for maximum flexibility

## Core Primitives

### Configuration Management
- `llm:set-provider <string>` - Set active provider ("openai", "gemini", "anthropic", "ollama")
- `llm:set-api-key <string>` - Set API key for current provider
- `llm:set-model <string>` - Set model within provider (e.g., "gpt-4", "claude-3-sonnet")
- `llm:load-config <filename>` - Load configuration from external file (source of truth)

### Core Chat Functionality
- `llm:chat <string>` - Synchronous chat request, returns response string
- `llm:chat-async <string>` - Asynchronous chat request, returns reporter for later collection

### History Management
- `llm:history` - Get current agent's conversation history as NetLogo list
- `llm:set-history <list>` - Set conversation history for current agent
- `llm:clear-history` - Clear current agent's conversation history

## Configuration File Format

Simple key=value format for external configuration:

```
provider=openai
api_key=sk-abc123...
model=gpt-4
base_url=https://api.openai.com/v1
```

- External file is the source of truth
- Individual `llm:set-*` commands can override for testing
- Easy to parse in NetLogo environment

## Architecture Design

### Strategy Pattern
```scala
trait LLMProvider {
  def chat(messages: Seq[ChatMessage]): Future[ChatMessage]
  def setConfig(key: String, value: String): Unit
  def validateConfig(): Boolean
}
```

### Concrete Implementations
- `OpenAIProvider` - Initial implementation
- `GeminiProvider` - Future implementation
- `AnthropicProvider` - Future implementation
- `OllamaProvider` - Future implementation

### Factory Pattern
```scala
object ProviderFactory {
  def createProvider(name: String, config: Map[String, String]): LLMProvider
}
```

### Extension Structure
```scala
class LLMExtension extends DefaultClassManager {
  private var currentProvider: Option[LLMProvider] = None
  private val messageHistory: WeakHashMap[Agent, ArrayBuffer[ChatMessage]] = WeakHashMap()
  
  // Primitive registration and management
}
```

## Implementation Phases

### Phase 1: OpenAI Baseline (MVP)
- Core extension framework with Strategy+Factory architecture
- OpenAI provider implementation with chat functionality
- Configuration file loading
- Basic primitives: `llm:set-provider`, `llm:set-api-key`, `llm:set-model`, `llm:chat`, `llm:load-config`
- Per-agent conversation history
- Manual testing with NetLogo models

### Phase 2: Enhanced Functionality
- Async chat support (`llm:chat-async`)
- History management primitives (`llm:history`, `llm:set-history`, `llm:clear-history`)
- Better error handling and user feedback
- Documentation and examples

### Phase 3: Multi-Provider Support
- Anthropic Claude provider
- Google Gemini provider
- Ollama local model support
- Provider-specific configuration handling

### Phase 4: Advanced Features
- Automated testing framework
- Advanced conversation management
- Performance optimizations
- Extended model-specific features

## Project Structure

Based on proven NetLogo extension structure:

```
NetLogoLLMExtension/
├── build.sbt                    # SBT build configuration
├── README.md                    # Usage documentation
├── LICENSE                      # License file
├── demos/                       # Example NetLogo models
│   ├── config.txt              # Sample configuration
│   └── basic-chat.nlogo        # Basic chat demo
├── project/                     # SBT project configuration
│   ├── build.properties
│   └── plugins.sbt
└── src/main/                    # Source code
    ├── LLMExtension.scala       # Main extension class
    ├── providers/               # Provider implementations
    │   ├── LLMProvider.scala    # Provider trait
    │   ├── OpenAIProvider.scala # OpenAI implementation
    │   └── ProviderFactory.scala
    └── models/                  # Data models
        ├── ChatMessage.scala
        ├── ChatRequest.scala
        └── ChatResponse.scala
```

## Dependencies

- Scala 2.12.17 (NetLogo compatibility)
- NetLogo 6.3.0 extension framework
- sttp.client3 for HTTP requests
- upickle for JSON serialization
- Provider-specific dependencies as needed

## Error Handling Strategy

**Phase 1**: Direct error printing to console
**Later phases**: Unified error model with standard error codes

## Testing Strategy

**Phase 1**: Manual testing with NetLogo models
**Later phases**: Automated unit and integration tests

## Success Criteria

### Phase 1 Complete When:
- OpenAI provider successfully sends and receives chat messages
- Configuration loading from external file works
- Per-agent conversation history functions correctly
- Basic primitives are fully functional
- Manual testing demonstrates reliable operation
- Code architecture supports easy addition of new providers

### Extension Complete When:
- Multiple LLM providers supported
- Comprehensive error handling
- Automated testing suite
- Complete documentation and examples
- Production-ready reliability

## Repository Setup

- Create new GitHub repository: `NetLogoLLMExtension`
- Initialize with standard NetLogo extension structure
- Commit specification document
- Set up continuous integration for builds
- Create development and main branches

## Future Considerations

- Stream-based responses for long completions
- Function calling support for compatible models
- Model-specific parameter tuning
- Usage analytics and cost tracking
- Multi-modal support (text + images)