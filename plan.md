# NetLogo Multi-LLM Extension - TDD Implementation Plan

## Overall Strategy

This plan follows test-driven development principles with incremental, iterative implementation. Each step builds upon the previous one, ensuring continuous integration and no orphaned code. We'll start with the most basic functionality and gradually add complexity.

## Phase 1: Foundation and Basic OpenAI Integration

### Step 1: Project Structure and Build Setup ✅ COMPLETED

**Objective**: Establish the basic project structure with proper SBT configuration and dependencies.

**Status**: ✅ **COMPLETED** - All files created, project compiles successfully with Java 11

**Implementation Notes**:
- ⚠️ **Java Version Requirement**: Must use Java 11 for compilation (Java 17+ causes SBT compatibility issues)
- All build files configured correctly using proven NetLogo extension plugin setup
- Project structure established with proper directories
- Dependencies added: sttp.client3, upickle for JSON handling

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

### Step 6: Main Extension Class with Basic Primitives

**Objective**: Implement the main extension class with configuration primitives.

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

### Step 7: Agent History Management

**Objective**: Implement per-agent conversation history using WeakHashMap.

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

### Step 8: Basic Chat Primitive Implementation

**Objective**: Implement the core llm:chat primitive that ties everything together.

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

### Step 9: Demo NetLogo Model and Manual Testing

**Objective**: Create a working NetLogo model to demonstrate and test the extension.

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

### Step 10: Integration and Polish

**Objective**: Final integration, testing, and preparation for Phase 1 completion.

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

## Phase 2: Enhanced Functionality (Future)

### Async Chat Support
- Implement llm:chat-async primitive with Future-based responses
- Add AwaitableReporter pattern for non-blocking operations
- Test concurrent chat requests from multiple agents

### History Management Primitives  
- Add llm:history reporter for getting agent conversation history
- Implement llm:set-history command for programmatic history management
- Add llm:clear-history command for resetting agent conversations

### Advanced Error Handling
- Create unified error codes and messages
- Add retry logic for transient failures
- Implement rate limiting and quota management

## Phase 3: Multi-Provider Support (Future)

### Provider Abstraction Enhancement
- Extend provider interface for provider-specific features
- Add provider capabilities negotiation
- Implement provider-specific configuration handling

### Additional Providers
- Add Anthropic Claude provider implementation
- Add Google Gemini provider implementation  
- Add Ollama local provider implementation

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