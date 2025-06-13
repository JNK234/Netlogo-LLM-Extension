# NetLogo Multi-LLM Extension - TODO Tracker

## Phase 1: Foundation and Basic OpenAI Integration

### Step 1: Project Structure and Build Setup
- [ ] Create build.sbt with NetLogoExtension plugin configuration
- [ ] Set up Scala 2.12.17 configuration for NetLogo 6.3.0 compatibility  
- [ ] Add dependencies: sttp.client3, upickle
- [ ] Create directory structure: src/main/, project/, demos/
- [ ] Create placeholder files with basic structure
- [ ] Ensure project compiles with sbt compile
- [ ] Create basic compilation test
- [ ] **Status**: Not Started

### Step 2: Data Models and Core Abstractions  
- [ ] Create ChatMessage case class with role and content
- [ ] Create ChatRequest and ChatResponse case classes
- [ ] Create LLMProvider trait with method signatures
- [ ] Add JSON serialization using upickle
- [ ] Write unit tests for all data models
- [ ] Test JSON serialization/deserialization
- [ ] Test provider trait compilation
- [ ] **Status**: Not Started

### Step 3: Configuration Management
- [ ] Create ConfigLoader for key=value file parsing
- [ ] Handle configuration keys: provider, api_key, model, base_url
- [ ] Implement error handling for malformed files
- [ ] Create ConfigStore for in-memory configuration
- [ ] Write tests for file parsing edge cases
- [ ] Test error conditions and file formats
- [ ] Ensure reliable config load/store/retrieve
- [ ] **Status**: Not Started

### Step 4: Basic OpenAI Provider Implementation
- [ ] Implement OpenAIProvider extending LLMProvider
- [ ] Add HTTP client using sttp.client3
- [ ] Implement basic chat method for API requests
- [ ] Handle API responses and JSON parsing
- [ ] Add error handling for network/API issues
- [ ] Create mock tests (no real API calls)
- [ ] Add optional integration test with real API
- [ ] **Status**: Not Started

### Step 5: Provider Factory Implementation
- [ ] Create ProviderFactory object for provider instantiation
- [ ] Support "openai" provider type initially
- [ ] Pass configuration to providers during creation
- [ ] Handle unknown provider names gracefully
- [ ] Add validation for provider configuration
- [ ] Write tests for factory creation and error cases
- [ ] Ensure factory integrates with configuration system
- [ ] **Status**: Not Started

### Step 6: Main Extension Class with Basic Primitives
- [ ] Create LLMExtension extending DefaultClassManager
- [ ] Implement llm:set-provider primitive
- [ ] Implement llm:set-api-key primitive
- [ ] Implement llm:set-model primitive
- [ ] Implement llm:load-config primitive
- [ ] Add primitive registration in load() method
- [ ] Include error handling and validation
- [ ] Write tests for each primitive
- [ ] **Status**: Not Started

### Step 7: Agent History Management
- [ ] Use WeakHashMap for per-agent conversation history
- [ ] Implement history storage and retrieval per agent
- [ ] Handle agent cleanup when removed from simulation
- [ ] Add methods to get, set, and clear agent history
- [ ] Ensure thread safety for concurrent access
- [ ] Write tests for multi-agent history management
- [ ] Test memory management and cleanup
- [ ] **Status**: Not Started

### Step 8: Basic Chat Primitive Implementation
- [ ] Create ChatReporter implementing llm:chat primitive
- [ ] Integrate with provider factory and current provider
- [ ] Add messages to agent history before sending
- [ ] Store responses in agent history after receiving
- [ ] Handle provider initialization and config validation
- [ ] Add comprehensive error handling
- [ ] Write integration tests for complete flow
- [ ] Test with mock and real providers
- [ ] **Status**: Not Started

### Step 9: Demo NetLogo Model and Manual Testing
- [ ] Create basic-chat.nlogo model in demos/
- [ ] Include setup procedure that loads configuration
- [ ] Add simple chat interface for testing
- [ ] Create sample config.txt with placeholder values
- [ ] Add instructions for setting up API keys
- [ ] Include examples of different chat scenarios
- [ ] Test complete extension workflow manually
- [ ] Document issues and improvements needed
- [ ] **Status**: Not Started

### Step 10: Integration and Polish
- [ ] Run complete test suite and fix issues
- [ ] Add comprehensive error messages and feedback
- [ ] Ensure all primitives work together seamlessly
- [ ] Add logging for debugging purposes
- [ ] Create README.md with installation/usage instructions
- [ ] Test with various NetLogo scenarios and agent types
- [ ] Verify all Phase 1 success criteria are met
- [ ] Prepare for Phase 2 planning
- [ ] **Status**: Not Started

## Phase 1 Success Criteria Checklist
- [ ] OpenAI provider successfully sends and receives chat messages
- [ ] Configuration loading from external file works
- [ ] Per-agent conversation history functions correctly
- [ ] Basic primitives are fully functional
- [ ] Manual testing demonstrates reliable operation
- [ ] Code architecture supports easy addition of new providers

## Phase 2: Enhanced Functionality (Future)
- [ ] Async chat support (llm:chat-async)
- [ ] History management primitives (llm:history, llm:set-history, llm:clear-history)
- [ ] Better error handling and user feedback
- [ ] Documentation and examples

## Phase 3: Multi-Provider Support (Future)
- [ ] Anthropic Claude provider
- [ ] Google Gemini provider
- [ ] Ollama local model support
- [ ] Provider-specific configuration handling

## Phase 4: Advanced Features (Future)
- [ ] Automated testing framework
- [ ] Advanced conversation management
- [ ] Performance optimizations
- [ ] Extended model-specific features

## Current Status
- **Current Phase**: Phase 1 - Foundation and Basic OpenAI Integration
- **Current Step**: Step 1 - Project Structure and Build Setup
- **Overall Progress**: 0% (0/10 steps completed)

## Notes
- Each step must be completed and tested before moving to the next
- All tests must pass before marking a step as complete
- Manual testing should be performed for integration steps
- Documentation should be updated as features are implemented