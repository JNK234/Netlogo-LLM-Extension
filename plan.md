# NetLogo Multi-LLM Extension - TDD Implementation Plan

## Overall Strategy

This plan follows test-driven development principles with incremental, iterative implementation. Each step builds upon the previous one, ensuring continuous integration and no orphaned code. We'll start with the most basic functionality and gradually add complexity.

## Phase 1: Foundation and Basic OpenAI Integration

### Step 1: Project Structure and Build Setup ✅ COMPLETED

**Objective**: Establish the basic project structure with proper SBT configuration and dependencies.

**Status**: ✅ **COMPLETED** - All files created, project compiles successfully with Java 11

**Implementation Notes**:
- ⚠️ **Java Version Requirement**: Must use Java 11 for compilation (Java 17+ causes SBT compatibility issues)
- **Java Version Management**: SDKMAN with project-specific .sdkmanrc file configured for automatic Java 11 switching
- All build files configured correctly using proven NetLogo extension plugin setup
- Project structure established with proper directories
- Dependencies added: sttp.client3, upickle for JSON handling

**Java Version Setup** (Long-term Solution):
```bash
# One-time SDKMAN setup
curl -s "https://get.sdkman.io" | bash
sdk install java 11.0.12-open
echo "sdkman_auto_env=true" >> ~/.sdkman/etc/config

# Project automatically switches to Java 11 via .sdkmanrc file
# No manual version switching required for development
```

**Prompt**:
```
Set up a NetLogo extension project with the following requirements:
1. Create build.sbt with NetLogoExtension plugin configuration
2. Set up proper Scala 2.12.17 configuration for NetLogo 6.3.0 compatibility
3. Add dependencies: sttp.client3, upickle for JSON handling
4. Create the basic directory structure: src/main/, project/, demos/
5. Create placeholder files with basic structure (no implementation)
6. Ensure the project compiles successfully with sbt compile
7. Create a basic test that verifies the project structure is correct

Files to create:
- build.sbt
- project/build.properties  
- project/plugins.sbt
- src/main/LLMExtension.scala (empty extension class)
- Basic compilation test

Success criteria: sbt compile runs without errors
```

### Step 2: Data Models and Core Abstractions ✅ COMPLETED

**Objective**: Create the foundational data structures and provider abstraction.

**Status**: ✅ **COMPLETED** - All data models and provider trait implemented, compiles successfully

**Prompt**:
```
Implement the core data models and provider abstraction with the following requirements:
1. Create ChatMessage case class with role and content fields
2. Create ChatRequest and ChatResponse case classes for OpenAI API
3. Create LLMProvider trait with basic method signatures
4. Add proper JSON serialization using upickle
5. Write unit tests for all data models
6. Ensure all models serialize/deserialize correctly to/from JSON
7. Test that the provider trait compiles and can be extended

Files to create/modify:
- src/main/models/ChatMessage.scala
- src/main/models/ChatRequest.scala  
- src/main/models/ChatResponse.scala
- src/main/providers/LLMProvider.scala
- Basic unit tests for JSON serialization

Success criteria: All models serialize properly, trait compiles, tests pass
```

### Step 3: Configuration Management ✅ COMPLETED

**Objective**: Implement configuration loading from key=value files and in-memory storage.

**Status**: ✅ **COMPLETED** - Config loader, store, and demo files created

**Prompt**:
```
Implement configuration management with the following requirements:
1. Create ConfigLoader utility that parses key=value format files
2. Handle common configuration keys: provider, api_key, model, base_url
3. Implement error handling for malformed files and missing keys
4. Create ConfigStore for in-memory configuration management
5. Write comprehensive tests for file parsing edge cases
6. Test with various file formats and error conditions
7. Ensure configuration can be loaded, stored, and retrieved reliably

Files to create:
- src/main/config/ConfigLoader.scala
- src/main/config/ConfigStore.scala
- Test files with various configuration scenarios
- Unit tests for all configuration functionality

Success criteria: Can load config from files, handle errors gracefully, all tests pass
```

### Step 4: Basic OpenAI Provider Implementation

**Objective**: Implement a minimal OpenAI provider that can send HTTP requests.

**Prompt**:
```
Create a basic OpenAI provider implementation with the following requirements:
1. Implement OpenAIProvider that extends LLMProvider trait
2. Add HTTP client using sttp.client3 for API requests
3. Implement basic chat method that sends requests to OpenAI API
4. Handle API responses and parse JSON into ChatMessage objects
5. Add proper error handling for network issues and API errors
6. Create mock tests that don't require real API calls
7. Add integration test that can be run with real API key (optional)

Files to create:
- src/main/providers/OpenAIProvider.scala
- Mock tests for HTTP requests/responses
- Integration test (can be disabled by default)

Success criteria: Provider can send HTTP requests, parse responses, handle errors, tests pass
```

### Step 5: Provider Factory Implementation ✅ COMPLETED

**Objective**: Create factory pattern for provider instantiation and management.

**Status**: ✅ **COMPLETED** - Factory with validation and extensibility implemented

**Prompt**:
```
Implement provider factory with the following requirements:
1. Create ProviderFactory object that can instantiate providers by name
2. Support "openai" provider type initially
3. Pass configuration to providers during creation
4. Handle unknown provider names gracefully
5. Add validation for provider configuration requirements
6. Write tests for factory creation and error cases
7. Ensure factory integrates properly with configuration system

Files to create:
- src/main/providers/ProviderFactory.scala
- Unit tests for factory creation and validation
- Integration tests with configuration system

Success criteria: Factory creates providers correctly, validates config, handles errors, tests pass
```

### Step 6: Main Extension Class with Basic Primitives ✅ COMPLETED

**Objective**: Implement the main extension class with configuration primitives.

**Status**: ✅ **COMPLETED** - All primitives implemented and working

**Prompt**:
```
Implement the main LLMExtension class with basic primitives:
1. Create LLMExtension extending DefaultClassManager
2. Implement llm:set-provider primitive
3. Implement llm:set-api-key primitive  
4. Implement llm:set-model primitive
5. Implement llm:load-config primitive
6. Add proper primitive registration in load() method
7. Include basic error handling and validation
8. Write tests for each primitive's functionality

Files to create/modify:
- src/main/LLMExtension.scala (complete implementation)
- Unit tests for each primitive
- Integration tests with NetLogo context mocking

Success criteria: Extension registers primitives, config primitives work, tests pass, compiles as NetLogo extension
```

### Step 7: Agent History Management ✅ COMPLETED

**Objective**: Implement per-agent conversation history using WeakHashMap.

**Status**: ✅ **COMPLETED** - History management implemented with WeakHashMap

**Prompt**:
```
Add conversation history management with the following requirements:
1. Use WeakHashMap to store per-agent conversation history
2. Implement history storage and retrieval for each NetLogo agent
3. Handle agent cleanup when agents are removed from simulation
4. Add methods to get, set, and clear agent history
5. Ensure thread safety for concurrent access
6. Write tests for history management across multiple agents
7. Test memory management and cleanup behavior

Files to modify:
- src/main/LLMExtension.scala (add history management)
- Unit tests for history operations
- Tests for multi-agent scenarios

Success criteria: History stored per-agent, memory managed properly, thread-safe, tests pass
```

### Step 8: Basic Chat Primitive Implementation ✅ COMPLETED

**Objective**: Implement the core llm:chat primitive that ties everything together.

**Status**: ✅ **COMPLETED** - Chat primitive working with full integration

**Prompt**:
```
Implement the llm:chat primitive with full integration:
1. Create ChatReporter that implements the llm:chat primitive
2. Integrate with provider factory and current provider
3. Add messages to agent history before sending
4. Store responses in agent history after receiving
5. Handle provider initialization and configuration validation
6. Add comprehensive error handling with user-friendly messages
7. Write integration tests that exercise the complete flow
8. Test with mock providers and real OpenAI (optional)

Files to modify:
- src/main/LLMExtension.scala (add ChatReporter)
- Integration tests for complete chat flow
- End-to-end tests with mock and real providers

Success criteria: llm:chat works end-to-end, history managed, errors handled, tests pass
```

### Step 9: Demo NetLogo Model and Manual Testing ✅ COMPLETED

**Objective**: Create a working NetLogo model to demonstrate and test the extension.

**Status**: ✅ **COMPLETED** - Color-sharing demo created and functional

**Implementation Notes**:
- ⚠️ **Async Implementation Deferred**: The `llm:chat-async` primitive was not fully implemented, so demo uses synchronous `llm:chat`
- Demo includes robust error handling for JSON parsing failures
- Configuration loading improved to search multiple file paths
- All NetLogo-specific bugs fixed (undefined variables, color assignments, string functions)

**Prompt**:
```
Create a demo NetLogo model for manual testing:
1. Create basic-chat.nlogo model in demos/ directory
2. Include setup procedure that loads configuration
3. Add simple chat interface for testing
4. Create sample config.txt with placeholder values
5. Add instructions for setting up API keys
6. Include examples of different chat scenarios
7. Test the complete extension workflow manually
8. Document any issues or improvements needed

Files to create:
- demos/basic-chat.nlogo
- demos/config.txt (sample configuration)
- demos/README.md (usage instructions)
- Manual testing checklist

Success criteria: Demo model works, can chat with OpenAI, configuration loads properly
```

### Step 10: Integration and Polish ✅ COMPLETED

**Objective**: Final integration, testing, and preparation for Phase 1 completion.

**Status**: ✅ **COMPLETED** - True async chat with AwaitableReporter pattern, constrained choice functionality working, configurable timeouts implemented, both primitives tested and functional

**Implementation Notes**:

- Fixed all NetLogo compatibility issues (color assignments, undefined variables)
- Improved JSON parsing with graceful error handling and fallback to raw responses
- Enhanced configuration loading with multi-path search capability
- Created robust error handling throughout the extension
- Validated end-to-end functionality with color-sharing social simulation demo

**Prompt**:
```
Complete Phase 1 with final integration and polish:
1. Run complete test suite and fix any remaining issues
2. Add comprehensive error messages and user feedback
3. Ensure all primitives work together seamlessly
4. Add logging for debugging purposes
5. Create README.md with installation and usage instructions
6. Test with various NetLogo scenarios and agent types
7. Verify all success criteria for Phase 1 are met
8. Prepare for Phase 2 planning

Files to create/modify:
- README.md (comprehensive documentation)
- Final integration tests
- Performance and stress tests
- Documentation improvements

Success criteria: All Phase 1 requirements met, extension ready for real use, documentation complete
```

## 🎯 PHASE 1 COMPLETE - STATUS & NEXT PHASES

### Phase 1 Summary ✅ COMPLETED

**Delivered Functionality:**

- Complete NetLogo extension with OpenAI provider integration
- Strategy + Factory pattern architecture for extensible provider system
- Per-agent conversation history using WeakHashMap for proper memory management  
- Configuration management with external file loading (key=value format)
- All core primitives implemented and functional
- Working social simulation demo (color-sharing agents via LLM communication)
- Robust error handling with JSON parsing fallbacks

**Implemented Primitives:**

- Configuration: `llm:set-provider`, `llm:set-api-key`, `llm:set-model`, `llm:load-config`
- Chat: `llm:chat` (synchronous), `llm:chat-async` (returns reporter - basic implementation)
- History: `llm:history`, `llm:set-history`, `llm:clear-history`

**Architecture Achievements:**

- Strategy pattern with LLMProvider trait successfully implemented
- Factory pattern with ProviderFactory for dynamic provider creation
- WeakHashMap-based per-agent conversation history working correctly
- JSON serialization with upickle/ujson hybrid approach
- NetLogo extension framework properly integrated

**Known Current Limitations:**

- `llm:chat-async` implementation is basic (returns reporter but not truly async)
- No rate limiting or retry logic for API calls
- Error handling could be more granular with specific error codes
- Only OpenAI provider implemented

## Phase 2: Essential Multi-LLM Support - Balanced Approach

### Design Philosophy: Best of Both Worlds

**Keep Existing Strengths:**
- ✅ Strategy + Factory pattern architecture (extensibility)
- ✅ Modular package structure (maintainability)
- ✅ Configuration system with file loading (flexibility)
- ✅ Multi-provider support foundation

**Add NetLogoGptExtension Proven Patterns:**
- ✅ AwaitableReporter for true async
- ✅ Constrained choice functionality (`llm:choose`)
- ✅ Simple, direct error handling
- ✅ Essential features without over-engineering

### Step 11: Fix Async + Add Constrained Choice ✅ COMPLETED

**Objective**: Fix broken async using AwaitableReporter + add missing killer feature from GPT extension

**NetLogoGptExtension Key Feature Missing**: `gpt:choose` with logit bias for constrained multiple choice - this is crucial for ABM applications where you need agents to pick from specific options.

**Current Issues**:
- `llm:chat-async` blocks when called (not truly async)
- Missing constrained choice capability that makes LLMs much more useful for agent-based modeling

**Prompt**:
```
Fix async and add constrained choice following NetLogoGptExtension patterns:
1. Create AwaitableReporter case class that wraps Future and defers execution until runresult
2. Replace current ChatAsyncReporter with AwaitableReporter implementation  
3. Add llm:choose primitive with logit bias for multiple choice (key GPT extension feature)
4. Add configurable timeout from config (timeout_seconds, default 30 like GPT extension)
5. Ensure Future starts immediately but execution defers until runresult is called
6. Add proper error handling for timeouts and Future failures following GPT patterns
7. Test constrained choice with list of options (essential for ABM scenarios)
8. Test async behavior with multiple concurrent agents

Files to modify:
- src/main/LLMExtension.scala (add AwaitableReporter + ChooseReporter)
- src/main/config/ConfigStore.scala (add timeout configuration)
- Unit tests for async and constrained choice functionality

**Status**: ✅ **COMPLETED** - True async chat with AwaitableReporter pattern works correctly with runresult, constrained choice functionality (llm:choose) working with predefined options, configurable timeouts implemented (default 30 seconds), both primitives tested and functional in test-basic.nlogo

Success criteria: ✅ llm:chat-async works like GPT extension, ✅ llm:choose enables constrained agent choices, ✅ configurable timeouts, ✅ conversation history correct, ✅ tests pass
```

### Step 12: Multi-Provider Implementation ✅ READY

**Objective**: Add Claude, Gemini, and Ollama providers using existing extensible architecture

**Keep What Works**: Use existing Strategy+Factory patterns, enhance rather than rebuild

**Prompt**:
```
Implement multi-provider support using existing architecture:
1. Create ClaudeProvider implementing existing LLMProvider trait
2. Create GeminiProvider implementing existing LLMProvider trait  
3. Create OllamaProvider implementing existing LLMProvider trait
4. Enhance existing ProviderFactory to support all providers
5. Add provider-specific configuration validation to existing ConfigStore
6. Add llm:providers primitive to list available providers
7. Add llm:models primitive to list models for current provider
8. Test provider switching using existing llm:set-provider primitive

Files to create:
- src/main/providers/ClaudeProvider.scala (Anthropic API integration)
- src/main/providers/GeminiProvider.scala (Google API integration) 
- src/main/providers/OllamaProvider.scala (local Ollama integration)

Files to modify:
- src/main/providers/ProviderFactory.scala (add new providers)
- src/main/LLMExtension.scala (add provider info primitives)
- src/main/config/ConfigStore.scala (provider-specific validation)

Success criteria: All providers work with existing primitives, provider switching seamless,
configuration validation works, new info primitives functional, tests pass
```

### Step 13: Essential Resilience Features ✅ READY

**Objective**: Add basic reliability without over-engineering

**Keep It Simple**: Basic retry logic and rate limiting, no complex circuit breakers

**Prompt**:
```
Add essential resilience features following GPT extension simplicity:
1. Add simple retry logic: max 3 attempts with basic exponential backoff
2. Add basic rate limiting: configurable requests_per_minute (default 60)
3. Enhance error messages to be more user-friendly like GPT extension
4. Add configurable timeouts (replace hard-coded 30 seconds)
5. Integrate retry and rate limiting into existing LLMProvider trait
6. Distinguish retryable (network, 5xx) vs non-retryable (auth, 4xx) errors
7. Test retry and rate limiting with all providers
8. Ensure all resilience features work with both sync and async chat

Files to modify:
- src/main/providers/LLMProvider.scala (add retry and rate limiting methods)
- src/main/providers/OpenAIProvider.scala (integrate resilience features)
- src/main/providers/ClaudeProvider.scala (integrate resilience features)
- src/main/providers/GeminiProvider.scala (integrate resilience features)
- src/main/providers/OllamaProvider.scala (integrate resilience features)
- src/main/config/ConfigStore.scala (add resilience configuration)

Success criteria: Basic retry works for transient failures, rate limiting prevents overuse,
better error messages, configurable timeouts, works for all providers, tests pass
```

### Step 14: Multi-Provider Demo and Documentation ✅ READY

**Objective**: Create comprehensive demo and documentation for NetLogo users

**User Focus**: Make it easy for NetLogo users to get started with any provider

**Prompt**:
```
Create multi-provider demo and user-ready documentation:
1. Create multi-provider NetLogo demo showcasing provider switching
2. Include constrained choice examples using llm:choose with all providers
3. Add configuration examples for each provider (OpenAI, Claude, Gemini, Ollama)
4. Update README with clear setup instructions for each provider
5. Add troubleshooting guide for common configuration issues
6. Test complete user workflow: config → load → chat → choose → switch provider
7. Document all primitives with examples
8. Verify extension ready for real NetLogo users

Files to create:
- demos/multi-provider-demo.nlogo (comprehensive demo with all providers)
- demos/configs/openai-config.txt (OpenAI configuration example)
- demos/configs/claude-config.txt (Claude configuration example)
- demos/configs/gemini-config.txt (Gemini configuration example)
- demos/configs/ollama-config.txt (Ollama configuration example)

Files to modify:
- README.md (comprehensive setup guide for all providers)
- docs/troubleshooting.md (common issues and solutions)
- docs/primitives.md (complete primitive reference)

Success criteria: Demo works with all providers, documentation clear and complete,
setup instructions work for new users, troubleshooting guide helpful, ready for distribution
```

## Phase 2 Success Criteria (Balanced Approach)

**Phase 2 Complete When:**
- ✅ **True async chat** with AwaitableReporter pattern works like NetLogoGptExtension
- ✅ **Constrained choice** (`llm:choose`) enables agents to pick from specific options
- ✅ **Multi-provider support** - OpenAI, Claude, Gemini, Ollama all working
- ✅ **Provider switching** seamless via configuration and primitives
- ✅ **Essential resilience** - basic retry logic and rate limiting
- ✅ **Better error handling** - user-friendly messages like GPT extension
- ✅ **Configurable timeouts** - replace hard-coded values
- ✅ **Multi-provider demo** showcases all capabilities and constrained choice
- ✅ **Clear documentation** for NetLogo users with setup guides
- ✅ **Ready for real users** - config-based workflow fully functional

**Key Deliverables:**
- Working async chat using proven AwaitableReporter pattern
- Constrained choice functionality crucial for agent-based modeling
- Four LLM providers accessible through unified interface
- Essential reliability without over-engineering
- Complete user documentation and working demos

## Phase 3: Advanced Features (Future Extensions)

**Note**: Phase 3 is **optional** and focuses on advanced features for specialized use cases. The extension is fully functional after Phase 2.

### Overview: Extension Points

**Architecture Ready**: The existing Strategy+Factory pattern architecture makes these features easy to add as extensions when needed.

### Step 15: Streaming Response Support (Optional) 📋 FUTURE

**When Needed**: For long completions that benefit from real-time updates

**Reference**: Not implemented in NetLogoGptExtension - this would be a novel addition

**High-Level Approach**:
- Add streaming support to LLMProvider trait
- Implement server-sent events (SSE) handling for compatible providers  
- Add `llm:chat-stream` primitive for streaming responses
- Handle partial response updates in NetLogo interface

### Step 16: Function Calling Support (Optional) 📋 FUTURE

**When Needed**: For advanced LLM integration where models can call NetLogo procedures

**High-Level Approach**:
- Add function calling support to LLMProvider trait
- Create NetLogo-specific function definition system
- Add `llm:register-function` primitive for function registration
- Implement function call orchestration and execution

### Step 17: Multi-modal Support (Optional) 📋 FUTURE

**When Needed**: For text + image capabilities with compatible providers

**High-Level Approach**:
- Add multi-modal support to LLMProvider trait
- Implement image input handling (file paths, base64)
- Add `llm:chat-with-image` primitive for image + text requests
- Create image processing utilities for NetLogo compatibility

### Step 18: Usage Analytics (Optional) 📋 FUTURE

**When Needed**: For cost tracking and usage monitoring in production deployments

**High-Level Approach**:
- Create analytics system for usage tracking
- Add cost calculation for all providers (tokens, requests)
- Add `llm:get-usage-stats` primitive for usage reporting
- Implement usage history and trend analysis

## Phase 3 Implementation Notes

**Extension-Friendly Design**: Each of these features can be added independently thanks to the existing architecture:
- **Strategy Pattern**: LLMProvider trait easily extended with new capabilities
- **Factory Pattern**: ProviderFactory can handle new provider features
- **Configuration System**: ConfigStore ready for new configuration options
- **Primitive System**: Extension class ready for new primitives

**When to Implement**: Add these features when specific use cases require them, not proactively.

## Extension Complete After Phase 2 

**Primary Goal Achieved**: A working, extensible multi-LLM NetLogo extension ready for real users

### Final Success Criteria

**Core Functionality Complete When:**
- ✅ **Multi-provider support** - OpenAI, Claude, Gemini, Ollama all working
- ✅ **True async chat** using proven AwaitableReporter pattern
- ✅ **Constrained choice** (`llm:choose`) for agent-based modeling scenarios
- ✅ **Config-based workflow** - users can easily switch providers via configuration
- ✅ **Essential reliability** - retry logic, rate limiting, proper error handling
- ✅ **NetLogo-ready documentation** - clear setup guides and working demos
- ✅ **Extensible architecture** - ready for future advanced features

### Architecture Achievements

**Strategy + Factory Success**: The existing extensible architecture allows for:
- Easy addition of new LLM providers
- Provider-specific configuration and features
- Consistent interface regardless of underlying provider
- Future extension with advanced features (streaming, function calling, etc.)

**NetLogo Integration Success**: Following proven patterns from NetLogoGptExtension:
- Per-agent conversation history with proper memory management
- True async support compatible with NetLogo's execution model
- Simple, direct error handling suitable for research/educational use
- Constrained choice functionality essential for agent-based modeling

### Extension Ready For

**✅ Research Applications**: Agent-based models with LLM-powered agents
**✅ Educational Use**: Teaching AI concepts in NetLogo environment  
**✅ Prototyping**: Quick experimentation with different LLM providers
**✅ Production Simulations**: Reliable operation with proper error handling

**Future Extensions Available**: The architecture is ready for advanced features when specific use cases require them, including streaming, function calling, multi-modal support, and usage analytics.

## Success Criteria for Each Step

Each step must meet these criteria before proceeding:

1. All tests pass (unit, integration, as applicable)
2. Code compiles without warnings
3. No orphaned or unused code
4. Proper error handling implemented
5. Documentation updated as needed
6. Manual testing completed successfully
7. Step integrates properly with previous steps

## Risk Management

- **API Changes**: Mock providers for testing reduce dependency on external APIs
- **Configuration Issues**: Comprehensive config validation prevents runtime errors
- **Memory Management**: WeakHashMap ensures proper cleanup of agent data
- **Threading**: Proper synchronization prevents race conditions
- **NetLogo Integration**: Each step tested with NetLogo context mocking

## Testing Strategy

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test component interactions
- **Mock Tests**: Test without external dependencies
- **Manual Tests**: Real NetLogo model testing
- **Performance Tests**: Ensure scalability with many agents

This plan ensures steady progress with no large jumps in complexity, comprehensive testing at each step, and proper integration throughout the development process.
