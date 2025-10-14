# NetLogo LLM Extension: Complete Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Multi-Provider Support](#multi-provider-support)
4. [NetLogo Primitives Reference](#netlogo-primitives-reference)
5. [Advanced Features](#advanced-features)
6. [Configuration Guide](#configuration-guide)
7. [Usage Examples](#usage-examples)
8. [Best Practices](#best-practices)
9. [Technical Implementation](#technical-implementation)
10. [Troubleshooting](#troubleshooting)

## Overview

The NetLogo Multi-LLM Extension is a sophisticated integration that brings Large Language Model capabilities directly into NetLogo agent-based modeling environments. This extension enables researchers and educators to create intelligent agents that can make decisions, solve problems, and adapt their behavior using state-of-the-art AI models.

### Key Capabilities

- **Multi-Provider Support**: Seamlessly switch between OpenAI (GPT), Anthropic (Claude), Google (Gemini), and local Ollama models
- **Per-Agent Memory**: Each NetLogo agent maintains its own conversation history with automatic memory management
- **True Async Processing**: Non-blocking LLM requests that allow agents to continue other work while waiting for responses
- **Constrained Choice**: Force models to select from predefined options for agent decision-making
- **Template System**: Use YAML templates for structured prompts with variable substitution
- **External Configuration**: Runtime provider switching without code changes

### Built With
- **Scala 3.7.0** - Modern Scala with advanced type safety
- **NetLogo 7.0.0-beta1** - Latest NetLogo platform
- **sttp.client3** - HTTP client for API communication
- **upickle/ujson** - JSON serialization
- **circe-yaml** - YAML template processing

## Architecture

The extension implements a clean, extensible architecture using proven design patterns:

### Core Components

```scala
LLMExtension (Main Class)
├── ConfigStore (Thread-safe configuration management)
├── ProviderFactory (Creates provider instances)
├── LLMProvider (Unified interface)
│   ├── OpenAIProvider
│   ├── ClaudeProvider
│   ├── GeminiProvider
│   └── OllamaProvider
└── Per-Agent Memory (WeakHashMap for automatic cleanup)
```

### Design Patterns Used

- **Strategy Pattern**: Unified `LLMProvider` interface for all providers
- **Factory Pattern**: `ProviderFactory` creates and configures providers
- **Singleton Pattern**: Thread-safe `ConfigStore` for global configuration
- **Observer Pattern**: Per-agent conversation histories with automatic cleanup

## Multi-Provider Support

The extension supports four major LLM providers with unified API access:

### OpenAI (GPT Models)
```netlogo
llm:set-provider "openai"
llm:set-api-key "sk-your-openai-key"
llm:set-model "gpt-4o-mini"  ; or gpt-4o, gpt-4-turbo, gpt-3.5-turbo
```

**Supported Models:**
- `gpt-4o` - Latest multimodal model
- `gpt-4o-mini` - Fast, cost-effective
- `gpt-4-turbo` - High capability
- `gpt-3.5-turbo` - Balanced performance

### Anthropic (Claude Models)
```netlogo
llm:set-provider "anthropic"
llm:set-api-key "your-anthropic-key"
llm:set-model "claude-3-5-sonnet-20241022"
```

**Supported Models:**
- `claude-3-5-sonnet-20241022` - Latest and most capable
- `claude-3-opus-20240229` - Highest capability
- `claude-3-sonnet-20240229` - Balanced performance
- `claude-3-haiku-20240307` - Fast and efficient

### Google (Gemini Models)
```netlogo
llm:set-provider "gemini"
llm:set-api-key "your-gemini-key"
llm:set-model "gemini-1.5-pro"
```

**Supported Models:**
- `gemini-1.5-pro` - High capability, large context
- `gemini-1.5-flash` - Fast, efficient
- `gemini-1.0-pro` - Stable baseline
- `gemini-pro` - Legacy model

### Ollama (Local Models)
```netlogo
llm:set-provider "ollama"
llm:set-model "llama3.2"  ; No API key needed
```

**Supported Models:**
- `llama3.2`, `llama3.1`, `llama3`, `llama2` - Meta's Llama family
- `mistral`, `mixtral` - Mistral AI models
- `codellama` - Code-specialized Llama
- `phi3`, `gemma`, `qwen2`, `deepseek-coder` - Various specialized models

## NetLogo Primitives Reference

### Configuration Primitives

#### `llm:load-config filename`
Loads configuration from an external file.

```netlogo
llm:load-config "demos/config.txt"
```

**File Format (key=value pairs):**
```ini
provider=openai
model=gpt-4o-mini
api_key=sk-your-key-here
temperature=0.7
max_tokens=200
```

#### `llm:set-provider provider-name`
Switches to a different LLM provider.

```netlogo
llm:set-provider "anthropic"  ; Switch to Claude
llm:set-provider "ollama"     ; Switch to local models
```

#### `llm:set-api-key api-key`
Sets the API key for the current provider.

```netlogo
llm:set-api-key "sk-proj-your-openai-key"
llm:set-api-key "your-anthropic-key"
```

#### `llm:set-model model-name`
Selects a specific model within the current provider.

```netlogo
llm:set-model "gpt-4o"                     ; OpenAI
llm:set-model "claude-3-5-sonnet-20241022" ; Anthropic
llm:set-model "gemini-1.5-pro"             ; Google
llm:set-model "llama3.2"                   ; Ollama
```

### Core Chat Primitives

#### `llm:chat message`
**Returns:** String - LLM response
**Behavior:** Synchronous (blocks until response received)

```netlogo
let response llm:chat "What is the optimal foraging strategy?"
print response  ; "A combination of random walk and directed movement..."
```

#### `llm:chat-async message`
**Returns:** Reporter - Awaitable that resolves to response string
**Behavior:** Asynchronous (returns immediately, resolve with `runresult`)

```netlogo
; Start async requests
let future1 llm:chat-async "Analyze this situation..."
let future2 llm:chat-async "Generate a strategy..."

; Do other work while waiting
ask turtles [ fd 1 ]

; Resolve when ready
let analysis runresult future1
let strategy runresult future2
```

#### `llm:chat-with-template template-file variables`
**Returns:** String - LLM response
**Uses:** YAML templates with variable substitution

```netlogo
let response llm:chat-with-template "demos/analysis-template.yaml" (list
  ["data" "Agent fitness: 15, 23, 8, 31, 12"]
  ["context" "After 1000 simulation ticks"]
  ["goal" "identify patterns and improvements"]
)
```

**Template Format (YAML):**
```yaml
system: "You are an expert data analyst for agent-based models."
template: |
  Data: {data}
  Context: {context}
  Goal: {goal}
  
  Provide detailed analysis with specific recommendations.
```

#### `llm:choose prompt choices`
**Returns:** String - One of the provided choices
**Behavior:** Constrains LLM to select from predefined options

```netlogo
let action llm:choose "I see food ahead. What should I do?" [
  "move-forward"
  "turn-left" 
  "turn-right"
  "stop-and-wait"
]
print action  ; Will be one of the four choices above
```

### History Management Primitives

#### `llm:history`
**Returns:** List - Agent's conversation history as `[role content]` pairs

```netlogo
let history llm:history
foreach history [ msg ->
  let role item 0 msg
  let content item 1 msg
  print (word role ": " content)
]
```

#### `llm:set-history history-list`
Sets the conversation history for the current agent.

```netlogo
llm:set-history [
  ["system" "You are an optimistic agent"]
  ["user" "Hello!"]
  ["assistant" "Hello! I'm excited to help you succeed!"]
]
```

#### `llm:clear-history`
Clears the current agent's conversation history.

```netlogo
llm:clear-history  ; Fresh start for this agent
```

### Provider Information Primitives

#### `llm:providers`
**Returns:** List - Available provider names

```netlogo
let providers llm:providers
print providers  ; ["anthropic" "gemini" "ollama" "openai"]
```

#### `llm:models`
**Returns:** List - Models available for current provider

```netlogo
llm:set-provider "openai"
let models llm:models
print models  ; ["gpt-3.5-turbo" "gpt-4" "gpt-4-turbo" "gpt-4o" "gpt-4o-mini"]
```

## Advanced Features

### Per-Agent Memory Management

Each NetLogo agent automatically maintains its own conversation history using a `WeakHashMap` for memory efficiency:

```scala
private val messageHistory: WeakHashMap[Agent, ArrayBuffer[ChatMessage]] = WeakHashMap()
```

**Key Benefits:**
- **Automatic Cleanup**: Memory is freed when agents are destroyed
- **Thread Safety**: Concurrent access is properly synchronized
- **Per-Agent Context**: Each agent maintains separate conversation threads

**Example Usage:**
```netlogo
create-turtles 3 [
  ; Each turtle gets its own personality
  llm:set-history [["system" (word "You are agent " who " with personality: " one-of ["curious" "cautious" "aggressive"])]]
  
  ; Each maintains separate conversation
  let response llm:chat "How should I explore this environment?"
  print (word "Agent " who " says: " response)
]
```

### True Asynchronous Processing

The extension implements true non-blocking async using NetLogo's `AwaitableReporter` pattern:

```scala
private def createAwaitableReporter(future: Future[String]): AnonymousReporter = {
  new AnonymousReporter {
    override def report(context: Context, args: Array[AnyRef]): AnyRef = {
      Await.result(future, timeoutSeconds.seconds)
    }
  }
}
```

**Performance Benefits:**
- **Non-Blocking**: Agents continue other activities while waiting
- **Concurrent Requests**: Multiple LLM calls can run simultaneously  
- **Timeout Handling**: Configurable timeouts prevent hanging

**Real-World Example:**
```netlogo
to parallel-agent-analysis
  ask turtles [
    ; Start async analysis for each agent
    let awaitable llm:chat-async (word 
      "Analyze my situation: position=" xcor "," ycor 
      " energy=" energy 
      " nearby-agents=" count turtles in-radius 5)
    
    ; Store the awaitable for later resolution
    set analysis-future awaitable
  ]
  
  ; Agents do other work while LLM processes
  ask turtles [ 
    fd random 3
    rt random 360 
  ]
  
  ; Resolve all async operations
  ask turtles [
    let analysis runresult analysis-future
    make-decision-based-on analysis
  ]
end
```

### Constrained Choice System

The `llm:choose` primitive implements intelligent constraint enforcement:

```scala
// Create constrained prompt that forces selection from choices
val constrainedPrompt = s"""$prompt
        
You must respond with EXACTLY ONE of the following options (no other text):
${choices.zipWithIndex.map { case (choice, idx) => s"${idx + 1}. $choice" }.mkString("\n")}

Response:"""
```

**Fallback Strategy:**
1. **Exact Match**: Look for choice text in response
2. **Partial Match**: Find closest matching choice
3. **Number Parsing**: Extract numbered selection (1, 2, 3...)
4. **Random Fallback**: Select random choice if parsing fails

**Example with Complex Choices:**
```netlogo
let strategy llm:choose 
  (word "Current energy: " energy " | Nearby food: " count food-sources in-radius 10)
  [
    "aggressive-foraging: move fast, take risks"
    "conservative-foraging: move slowly, avoid others" 
    "collaborative-foraging: follow successful agents"
    "exploratory-foraging: search new areas"
    "rest-and-recover: stay still to conserve energy"
  ]
```

### YAML Template System

Templates provide structured, reusable prompt patterns:

**Template Structure:**
```yaml
system: "System prompt that sets AI behavior"
template: |
  User prompt with {variable} substitution
  Multiple lines supported
  {another_variable} can be used anywhere
```

**Variable Substitution:**
```netlogo
llm:chat-with-template "analysis-template.yaml" (list
  ["data" fitness-values]
  ["generation" current-generation]
  ["population" population-size]
)
```

**Advanced Template Example:**
```yaml
system: "You are an evolutionary algorithm expert analyzing NetLogo agent performance."
template: |
  SIMULATION DATA:
  Generation: {generation}
  Population Size: {population}
  Fitness Data: {data}
  Environmental Conditions: {conditions}
  
  ANALYSIS REQUIRED:
  1. Identify performance trends
  2. Suggest parameter adjustments
  3. Predict next generation outcomes
  4. Recommend selection strategies
  
  Provide specific, actionable insights for NetLogo simulation optimization.
```

## Configuration Guide

### File-Based Configuration

Configuration files use simple `key=value` format:

```ini
# Provider and model selection
provider=openai
model=gpt-4o-mini

# Authentication
api_key=sk-your-key-here

# Generation parameters
temperature=0.7        # 0.0 (deterministic) to 1.0 (creative)
max_tokens=200        # Maximum response length
timeout_seconds=30    # Request timeout

# Provider-specific settings
base_url=https://api.openai.com/v1  # Custom API endpoint
```

### Runtime Configuration

```netlogo
; Method 1: Load from file
llm:load-config "path/to/config.txt"

; Method 2: Set individual parameters
llm:set-provider "anthropic"
llm:set-api-key "your-key"
llm:set-model "claude-3-haiku-20240307"

; Method 3: Quick provider switching
llm:set-provider "ollama"  ; No API key needed for local models
llm:set-model "llama3.2"
```

### Provider-Specific Configuration

#### OpenAI Configuration
```ini
provider=openai
model=gpt-4o-mini
api_key=sk-proj-your-key-here
base_url=https://api.openai.com/v1
temperature=0.7
max_tokens=150
```

#### Anthropic Configuration  
```ini
provider=anthropic
model=claude-3-haiku-20240307
api_key=your-anthropic-key
base_url=https://api.anthropic.com/v1
temperature=0.5
max_tokens=4000
```

#### Gemini Configuration
```ini
provider=gemini
model=gemini-1.5-flash
api_key=your-gemini-key
base_url=https://generativelanguage.googleapis.com/v1beta
temperature=0.8
max_tokens=2048
```

#### Ollama Configuration
```ini
provider=ollama
model=llama3.2
base_url=http://localhost:11434
temperature=0.7
max_tokens=2048
# No api_key needed for local Ollama
```

## Usage Examples

### Example 1: Intelligent Foraging Agents

```netlogo
extensions [llm]

globals [
  food-sources-data
]

breed [smart-agents smart-agent]

smart-agents-own [
  strategy
  energy
  decision-history
]

to setup
  clear-all
  
  ; Configure LLM
  llm:load-config "config.txt"
  
  ; Create environment
  create-smart-agents 10 [
    set color red
    set energy 100
    set strategy "exploring"
    setxy random-xcor random-ycor
    
    ; Give each agent a unique personality
    let personality one-of ["aggressive" "cautious" "collaborative" "innovative"]
    llm:set-history [
      ["system" (word "You are a " personality " foraging agent. "
                      "Make decisions that align with this personality.")]
    ]
  ]
  
  ; Scatter food sources
  repeat 50 [
    ask patch random-pxcor random-pycor [ set pcolor green ]
  ]
  
  reset-ticks
end

to go
  ask smart-agents [
    ; Gather environmental information
    let nearby-food count patches in-radius 5 with [pcolor = green]
    let nearby-agents count other smart-agents in-radius 5
    let current-situation (word 
      "Energy: " energy 
      " | Food nearby: " nearby-food 
      " | Other agents: " nearby-agents
      " | Current strategy: " strategy)
    
    ; Make intelligent decision
    let action llm:choose current-situation [
      "move-to-food"
      "avoid-competition" 
      "follow-successful-agent"
      "explore-new-area"
      "rest-and-conserve"
    ]
    
    ; Execute chosen action
    execute-action action
    
    ; Update energy
    set energy energy - 1
    if pcolor = green [
      set energy energy + 20
      set pcolor black
    ]
  ]
  
  tick
end

to execute-action [action]
  if action = "move-to-food" [
    let target one-of patches in-radius 10 with [pcolor = green]
    if target != nobody [ face target fd 1 ]
  ]
  
  if action = "avoid-competition" [
    if any? other smart-agents in-radius 3 [
      rt 180 fd 2
    ]
  ]
  
  if action = "follow-successful-agent" [
    let successful max-one-of other smart-agents in-radius 10 [energy]
    if successful != nobody [ face successful fd 1 ]
  ]
  
  if action = "explore-new-area" [
    rt random 60 - 30 fd 2
  ]
  
  if action = "rest-and-conserve" [
    ; Do nothing, conserve energy
  ]
end
```

### Example 2: Async Multi-Agent Communication

```netlogo
extensions [llm]

breed [coordinators coordinator]
breed [workers worker]

to async-coordination-demo
  clear-all
  llm:load-config "config.txt"
  
  ; Create coordinator
  create-coordinators 1 [
    set color blue
    setxy 0 0
  ]
  
  ; Create workers
  create-workers 5 [
    set color red
    setxy random-xcor random-ycor
  ]
  
  ; Parallel analysis phase
  ask coordinators [
    ; Start async analysis
    let awaitable llm:chat-async (word
      "Analyze workforce of " count workers " agents. "
      "Current positions: " [list xcor ycor] of workers " "
      "Suggest optimal task allocation strategy.")
    
    ; Store for later
    set analysis-future awaitable
  ]
  
  ask workers [
    ; Each worker analyzes their local situation
    let awaitable llm:chat-async (word
      "I am worker " who " at position " xcor "," ycor ". "
      "Other workers nearby: " count other workers in-radius 10 ". "
      "What specialized role should I take?")
    
    set role-future awaitable
  ]
  
  ; Simulation continues while LLMs process
  repeat 10 [
    ask workers [ fd 0.5 rt random 30 ]
    wait 0.1
  ]
  
  ; Resolve async operations
  ask coordinators [
    let strategy runresult analysis-future
    print (word "Coordinator strategy: " strategy)
  ]
  
  ask workers [
    let role runresult role-future  
    print (word "Worker " who " role: " role)
  ]
end
```

### Example 3: Template-Based Code Evolution

```netlogo
extensions [llm]

globals [
  evolution-template
  current-generation
]

breed [evolved-agents evolved-agent]

evolved-agents-own [
  behavior-code
  fitness-score
  generation-born
]

to setup-evolution
  clear-all
  llm:load-config "config.txt"
  
  set current-generation 0
  
  ; Create initial population
  create-evolved-agents 10 [
    set behavior-code "fd 1 rt random 360"  ; Simple random walk
    set fitness-score 0
    set generation-born 0
    set color scale-color red fitness-score 0 100
  ]
  
  reset-ticks
end

to evolve-population
  ; Evaluate current generation
  ask evolved-agents [
    evaluate-fitness
  ]
  
  ; Select top performers
  let top-performers n-of 3 evolved-agents with-max [fitness-score]
  
  ; Evolve their code using templates
  ask top-performers [
    let evolved-code llm:chat-with-template "code-evolution-template.yaml" (list
      ["current_code" behavior-code]
      ["fitness_score" fitness-score]
      ["generation" current-generation]
      ["environment_info" "Food scattered randomly, competition present"]
      ["improvement_goal" "Increase food collection efficiency"]
    )
    
    ; Create offspring with evolved code
    hatch 2 [
      set behavior-code evolved-code
      set fitness-score 0
      set generation-born current-generation + 1
      set color scale-color red fitness-score 0 100
    ]
  ]
  
  ; Remove worst performers
  ask min-n-of 6 evolved-agents [fitness-score] [ die ]
  
  set current-generation current-generation + 1
  tick
end

to evaluate-fitness
  ; Run behavior code and measure success
  let start-energy energy
  
  carefully [
    run behavior-code
    ; Additional fitness evaluation logic
    if pcolor = green [
      set fitness-score fitness-score + 10
      set pcolor black
    ]
  ] [
    ; Penalize invalid code
    set fitness-score fitness-score - 5
  ]
end
```

## Best Practices

### 1. Provider Selection Guidelines

**For Research/Education:**
- **Ollama + Llama 3.2**: Free, private, good for learning
- **OpenAI GPT-4o-mini**: Excellent quality-to-cost ratio
- **Anthropic Claude Haiku**: Fast, reliable, good reasoning

**For Production:**
- **OpenAI GPT-4o**: Best overall performance
- **Anthropic Claude Sonnet**: Excellent reasoning capabilities
- **Gemini 1.5 Pro**: Large context windows for complex scenarios

### 2. Memory Management

```netlogo
; Good: Let the extension handle memory automatically
ask turtles [
  let response llm:chat "What should I do?"
  ; History automatically maintained per agent
]

; Avoid: Manual history management unless necessary
; The WeakHashMap handles cleanup automatically
```

### 3. Async Usage Patterns

```netlogo
; Good: Start multiple async operations, then resolve
let futures []
ask turtles [
  set futures lput llm:chat-async "Analyze situation" futures
]
; ... do other work ...
let responses map runresult futures

; Avoid: Blocking immediately after async call
let future llm:chat-async "Question"
let response runresult future  ; Defeats the purpose
```

### 4. Error Handling

```netlogo
; Good: Wrap LLM calls in careful blocks
ask turtles [
  carefully [
    let action llm:choose "What to do?" ["option1" "option2"]
    execute-action action
  ] [
    ; Fallback behavior
    rt random 360 fd 1
  ]
]
```

### 5. Configuration Management

```netlogo
; Good: Use external config files
llm:load-config "config.txt"

; Good: Check available providers/models
if member? "ollama" llm:providers [
  llm:set-provider "ollama"
  llm:set-model "llama3.2"
]
```

### 6. Template Design

```yaml
# Good: Clear, structured templates
system: "You are a NetLogo agent behavior specialist."
template: |
  CURRENT STATE:
  {state_description}
  
  GOAL: {objective}
  
  CONSTRAINTS:
  - Use only NetLogo primitives
  - Consider energy efficiency
  - Avoid infinite loops
  
  Generate optimal behavior code:
```

### 7. Performance Optimization

```netlogo
; Good: Batch operations when possible
ask turtles [
  if ticks mod 10 = 0 [  ; Only call LLM every 10 ticks
    let strategy llm:choose "Current situation" ["explore" "exploit" "rest"]
    set current-strategy strategy
  ]
  execute-strategy current-strategy
]

; Configure appropriate timeouts
llm:load-config "config.txt"  ; timeout_seconds=30
```

## Technical Implementation

### Thread Safety

The extension ensures thread-safe operation through:

```scala
// Thread-safe configuration store
class ConfigStore {
  private val config: TrieMap[String, String] = TrieMap()
  
  def set(key: String, value: String): Unit = {
    config.update(key, value)
  }
}

// Synchronized agent history access
private def getAgentHistory(agent: Agent): ArrayBuffer[ChatMessage] = {
  messageHistory.synchronized {
    messageHistory.getOrElseUpdate(agent, ArrayBuffer.empty[ChatMessage])
  }
}
```

### Memory Management

```scala
// WeakHashMap ensures automatic cleanup when agents are destroyed
private val messageHistory: WeakHashMap[Agent, ArrayBuffer[ChatMessage]] = WeakHashMap()

// Cleanup on clear-all
override def clearAll(): Unit = {
  messageHistory.clear()
}
```

### Provider Abstraction

```scala
trait LLMProvider {
  def chat(messages: Seq[ChatMessage]): Future[ChatMessage]
  def setConfig(key: String, value: String): Unit
}

// Factory pattern for provider creation
object ProviderFactory {
  def createProvider(providerName: String): Try[LLMProvider] = {
    providerName.toLowerCase.trim match {
      case "openai" => Try(new OpenAIProvider())
      case "anthropic" => Try(new ClaudeProvider())
      case "gemini" => Try(new GeminiProvider())
      case "ollama" => Try(new OllamaProvider())
    }
  }
}
```

### Async Implementation

```scala
// Create AwaitableReporter for true async behavior
private def createAwaitableReporter(future: Future[String]): AnonymousReporter = {
  new AnonymousReporter {
    override def report(context: Context, args: Array[AnyRef]): AnyRef = {
      val timeoutSeconds = configStore.getOrElse("timeout_seconds", "30").toInt
      Await.result(future, timeoutSeconds.seconds)
    }
  }
}
```

## Troubleshooting

### Common Issues

#### 1. API Key Errors
```
Error: "Failed to initialize LLM provider: OpenAI API key should start with 'sk-'"
```
**Solution:** Verify API key format and provider match:
```netlogo
llm:set-provider "openai"
llm:set-api-key "sk-proj-your-actual-key-here"
```

#### 2. Model Not Found
```
Error: "Unsupported OpenAI model: 'gpt-5'"
```
**Solution:** Check available models:
```netlogo
llm:set-provider "openai"
let models llm:models
print models  ; See supported models
```

#### 3. Timeout Issues
```
Error: "Async LLM operation failed: Timeout"
```
**Solution:** Increase timeout in configuration:
```ini
timeout_seconds=60  # Increase from default 30
```

#### 4. Ollama Connection Issues
```
Error: "Failed to connect to Ollama at localhost:11434"
```
**Solution:** Ensure Ollama is running:
```bash
# Start Ollama server
ollama serve

# Verify model is installed
ollama list
ollama pull llama3.2  # If not available
```

#### 5. Memory Issues with Large Histories
```netlogo
; Clear history periodically for long-running simulations
if ticks mod 1000 = 0 [
  ask turtles [ llm:clear-history ]
]
```

### Debug Information

Enable verbose logging by checking provider responses:
```netlogo
to debug-llm-setup
  print (word "Available providers: " llm:providers)
  
  foreach llm:providers [ provider ->
    llm:set-provider provider
    print (word provider " models: " llm:models)
  ]
  
  ; Test basic functionality
  llm:set-provider "openai"  ; or your preferred provider
  let test-response llm:chat "Say hello"
  print (word "Test response: " test-response)
end
```

### Performance Monitoring

```netlogo
globals [
  llm-call-count
  llm-total-time
]

to monitor-llm-performance
  set llm-call-count 0
  set llm-total-time 0
  
  ask turtles [
    let start-time timer
    let response llm:chat "Quick test"
    let end-time timer
    
    set llm-call-count llm-call-count + 1
    set llm-total-time llm-total-time + (end-time - start-time)
  ]
  
  print (word "Average LLM response time: " (llm-total-time / llm-call-count) " seconds")
end
```

---

## Conclusion

The NetLogo Multi-LLM Extension provides a powerful, flexible platform for integrating advanced AI capabilities into agent-based models. Its clean architecture, comprehensive provider support, and advanced features like per-agent memory and async processing make it suitable for both educational and research applications.

The extension's design emphasizes:
- **Ease of Use**: Simple primitives with comprehensive documentation
- **Flexibility**: Multiple providers with runtime switching
- **Performance**: True async processing and efficient memory management  
- **Extensibility**: Clean architecture for adding new providers and features

Whether you're building intelligent agents for research, teaching AI concepts, or exploring complex adaptive systems, this extension provides the tools needed to create sophisticated, LLM-powered NetLogo models.

---

**Documentation Version:** 1.0  
**Extension Version:** Compatible with NetLogo 7.0.0-beta1+  
**Last Updated:** July 2025  
**License:** [Check project repository for current license]
