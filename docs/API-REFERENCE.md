# NetLogo Multi-LLM Extension - API Reference

## Overview

The NetLogo Multi-LLM Extension provides a unified interface for multiple Large Language Model providers. All primitives are prefixed with `llm:`.

## Configuration Primitives

### llm:load-config

**Syntax**: `llm:load-config filename`

**Description**: Loads configuration from a file (key=value format)

**Parameters**:
- `filename` (string): Path to configuration file

**Example**:
```netlogo
llm:load-config "config.txt"
llm:load-config "models/gpt4-config.txt"
```

**Notes**:
- File path is relative to NetLogo model location
- Overwrites any existing configuration
- Validates provider readiness after loading (throws error if provider not ready)
- Prefer config file approach over runtime commands when possible

### llm:set-provider

**Syntax**: `llm:set-provider provider-name`

**Description**: Sets the active LLM provider

**Parameters**:
- `provider-name` (string): Provider identifier

**Valid Providers**:
- `"openai"` - OpenAI GPT models
- `"anthropic"` - Anthropic Claude models  
- `"gemini"` - Google Gemini models
- `"ollama"` - Local Ollama models

**Example**:
```netlogo
llm:set-provider "openai"
; Sets default model (gpt-4o-mini) and validates API key

llm:set-provider "ollama"
; Sets default model (llama3.2) and checks if Ollama server is reachable
```

**Notes**:
- Automatically applies provider defaults (model, base URL, etc.)
- Validates immediately: requires API key for cloud providers or reachable server for Ollama
- Throws helpful error with setup instructions if provider not ready
- Use `llm:provider-help` to get setup instructions if validation fails

### llm:set-api-key

**Syntax**: `llm:set-api-key api-key`

**Description**: Sets the API key for cloud providers

**Parameters**:
- `api-key` (string): API authentication key

**Example**:
```netlogo
llm:set-api-key "sk-your-openai-key-here"
llm:set-api-key "sk-ant-your-claude-key-here"
```

**Notes**:
- Stores key for the currently active provider (provider-specific key like `openai_api_key`)
- Not required for Ollama (local models)
- Keep API keys secure, avoid hard-coding in models
- Prefer setting keys in config file over runtime commands

### llm:set-model

**Syntax**: `llm:set-model model-name`

**Description**: Sets the specific model to use

**Parameters**:
- `model-name` (string): Model identifier

**Example**:
```netlogo
llm:set-model "gpt-4o-mini"
llm:set-model "claude-3-5-haiku-latest"
llm:set-model "llama3.2"
```

**Notes**:
- Validates model against current provider's supported models
- Throws error with model suggestions if model is invalid
- Use `llm:models` to see all available models for the current provider

## Chat Primitives

### llm:chat

**Syntax**: `llm:chat message`

**Description**: Sends a message and returns the response (synchronous)

**Parameters**:
- `message` (string): The message to send

**Returns**: String - The LLM's response

**Example**:
```netlogo
let response llm:chat "What is 2+2?"
print response  ; "2+2 equals 4"

let creative-response llm:chat "Write a haiku about turtles"
print creative-response
```

**Notes**:
- Blocks execution until response received
- Maintains conversation history per agent
- Throws error if request fails

### llm:chat-async

**Syntax**: `llm:chat-async message`

**Description**: Sends a message and returns an awaitable reporter (asynchronous)

**Parameters**:
- `message` (string): The message to send

**Returns**: AwaitableReporter - Use with `runresult` to get response

**Example**:
```netlogo
; Start async request
let awaitable-response llm:chat-async "Explain quantum physics"

; Do other work while waiting
print "Processing other tasks..."
repeat 10 [ tick ]

; Get the result when ready
let response runresult awaitable-response
print response
```

**Notes**:
- Non-blocking - allows other code to run while waiting
- Use `runresult` to retrieve the actual response
- Still maintains conversation history per agent

### llm:choose

**Syntax**: `llm:choose prompt choices`

**Description**: Ask LLM to select from predefined options

**Parameters**:
- `prompt` (string): The question or context
- `choices` (list): List of valid options to choose from

**Returns**: String - One of the provided choices

**Example**:
```netlogo
let decision llm:choose "What should I do next?" ["move", "turn", "wait"]
print decision  ; Will be exactly "move", "turn", or "wait"

let color-choice llm:choose "Pick a good color for this turtle" 
                           ["red" "blue" "green" "yellow"]
set color read-from-string color-choice
```

**Notes**:
- Forces LLM to return exactly one of the provided choices
- Useful for agent decision-making in models
- Maintains conversation context

## History Management

### llm:history

**Syntax**: `llm:history`

**Description**: Returns the conversation history for current agent

**Returns**: List - Conversation history as alternating user/assistant messages

**Example**:
```netlogo
llm:chat "Hello"
llm:chat "How are you?"
let history llm:history
print history
; ["Hello" "Hello! How can I help you?" "How are you?" "I'm doing well, thanks!"]
```

### llm:set-history

**Syntax**: `llm:set-history message-list`

**Description**: Sets the conversation history for current agent

**Parameters**:
- `message-list` (list): List of messages (alternating user/assistant)

**Example**:
```netlogo
; Set up a conversation context
llm:set-history ["You are a helpful turtle" "I understand, I'm a helpful turtle"]
let response llm:chat "What are you?"
print response  ; "I'm a helpful turtle, ready to assist you!"
```

**Notes**:
- Messages should alternate between user and assistant
- Overwrites existing history for this agent
- Use to prime conversations with context

### llm:clear-history

**Syntax**: `llm:clear-history`

**Description**: Clears conversation history for current agent

**Example**:
```netlogo
llm:chat "Hello"
print length llm:history  ; 2 (user + assistant message)
llm:clear-history
print length llm:history  ; 0
```

## Provider Information

### llm:providers

**Syntax**: `llm:providers`

**Description**: Returns list of READY providers (those with API keys or reachable servers)

**Returns**: List - Provider names that are ready to use

**Example**:
```netlogo
let ready-providers llm:providers
print ready-providers  ; ["openai" "ollama"] - only providers with keys/reachable

; Check if specific provider is ready
if member? "ollama" llm:providers [
  print "Ollama is ready for use"
]
```

**Notes**:
- Only lists providers that have API keys configured (OpenAI, Anthropic, Gemini) or are reachable (Ollama)
- Use `llm:providers-all` to see all supported providers regardless of readiness
- Use `llm:provider-status` for detailed status of each provider

### llm:providers-all

**Syntax**: `llm:providers-all`

**Description**: Returns list of all supported providers (regardless of readiness)

**Returns**: List - All supported provider names

**Example**:
```netlogo
let all-providers llm:providers-all
print all-providers  ; ["openai" "anthropic" "gemini" "ollama"]
```

### llm:provider-status

**Syntax**: `llm:provider-status`

**Description**: Returns detailed status information for all providers

**Returns**: List - Nested lists with provider status details

**Example**:
```netlogo
let status llm:provider-status
print status
; Output format:
; [["openai" ["ready" true] ["has-key" true]]
;  ["anthropic" ["ready" false] ["has-key" false]]
;  ["gemini" ["ready" false] ["has-key" false]]
;  ["ollama" ["ready" true] ["reachable" true] ["base-url" "http://localhost:11434"]]]

; Check specific provider status
foreach llm:provider-status [ provider-info ->
  let provider-name item 0 provider-info
  if provider-name = "ollama" [
    print provider-info
  ]
]
```

**Notes**:
- For cloud providers (OpenAI, Anthropic, Gemini): shows `ready` and `has-key` status
- For Ollama: shows `ready`, `reachable`, and `base-url`
- Use this to diagnose configuration issues

### llm:provider-help

**Syntax**: `llm:provider-help provider-name`

**Description**: Returns setup instructions for a specific provider

**Parameters**:
- `provider-name` (string): Provider to get help for

**Returns**: String - Multi-line setup instructions

**Example**:
```netlogo
; Get Ollama setup instructions
print llm:provider-help "ollama"

; Get OpenAI setup instructions
print llm:provider-help "openai"
```

**Notes**:
- Provides step-by-step setup instructions
- Includes installation, configuration, and verification steps
- Useful when a provider is not ready

### llm:active

**Syntax**: `llm:active`

**Description**: Returns the currently active provider and model

**Returns**: List - [provider model]

**Example**:
```netlogo
let current llm:active
print current  ; ["openai" "gpt-4o-mini"]
print (word "Using " item 0 current " with " item 1 current)
```

**Notes**:
- Use this to verify your current configuration
- Helpful for sanity checks before sending chat requests

### llm:config

**Syntax**: `llm:config`

**Description**: Returns a summary of the current configuration (with masked API keys)

**Returns**: String - Configuration summary

**Example**:
```netlogo
print llm:config
; Output: provider=openai, model=gpt-4o-mini, openai_api_key=sk-pr...jYzQ, ...
```

**Notes**:
- API keys are masked for security (shows first 4 and last 4 characters)
- Useful for debugging configuration issues

### llm:models

**Syntax**: `llm:models`

**Description**: Returns list of available models for current provider

**Returns**: List - Available model names for active provider

**Example**:
```netlogo
llm:set-provider "openai"
let openai-models llm:models
print openai-models  ; ["gpt-3.5-turbo" "gpt-4" "gpt-4o" "gpt-4o-mini" "o1" ...]

llm:set-provider "ollama"
let local-models llm:models
print local-models   ; Models installed locally via ollama
```

## Usage Patterns

### Basic Chat Bot

```netlogo
extensions [llm]

to setup
  llm:load-config "config.txt"
end

to chat-with-user
  let user-input user-input "What would you like to ask?"
  let response llm:chat user-input
  user-message response "LLM Response"
end
```

### Multi-Agent Conversations

```netlogo
extensions [llm]

turtles-own [personality]

to setup
  create-turtles 3
  llm:load-config "config.txt"
  
  ask turtles [
    set personality one-of ["helpful" "curious" "creative"]
    ; Each turtle gets its own conversation history
    llm:set-history (list (word "You are a " personality " assistant") 
                          (word "I understand, I'm " personality))
  ]
end

to converse
  ask turtles [
    let question "What's something interesting about science?"
    let response llm:chat question
    print (word "Turtle " who " (" personality "): " response)
  ]
end
```

### Async Processing

```netlogo
extensions [llm]

globals [pending-requests]

to setup
  set pending-requests []
  llm:load-config "config.txt"
end

to start-async-requests
  let questions ["What is AI?" "Explain gravity" "How do plants grow?"]
  
  foreach questions [ question ->
    let awaitable llm:chat-async question
    set pending-requests lput (list question awaitable) pending-requests
  ]
end

to check-responses
  let completed []
  let still-pending []
  
  foreach pending-requests [ request ->
    let question first request
    let awaitable last request
    
    ; Try to get response (non-blocking check would be ideal)
    carefully [
      let response runresult awaitable
      print (word "Q: " question " A: " response)
      set completed lput request completed
    ] [
      ; Still pending
      set still-pending lput request still-pending
    ]
  ]
  
  set pending-requests still-pending
  print (word "Completed: " length completed " Still pending: " length still-pending)
end
```

### Decision Making

```netlogo
extensions [llm]

turtles-own [current-action]

to setup
  create-turtles 10
  llm:load-config "config.txt"
end

to make-decisions
  ask turtles [
    let context (word "I'm a turtle at position " xcor "," ycor ". ")
    set context (word context "There are " count other turtles in-radius 3 " nearby turtles.")
    
    let action llm:choose (word context " What should I do?")
                         ["move-forward" "turn-left" "turn-right" "stop"]
    
    set current-action action
    execute-action action
  ]
end

to execute-action [action]
  if action = "move-forward" [ forward 1 ]
  if action = "turn-left" [ left 90 ]
  if action = "turn-right" [ right 90 ]
  if action = "stop" [ ]
end
```

## Error Handling

### Common Errors

**Configuration Errors**:
- `Provider not found` - Check provider name spelling
- `API key missing` - Set API key for cloud providers
- `Model not available` - Verify model exists and is accessible

**Request Errors**:
- `Request timeout` - Check network, increase timeout_seconds
- `Rate limited` - Wait before retrying, check API quotas
- `Invalid response` - Check model parameters, try different prompt

**Example Error Handling**:
```netlogo
to safe-chat [message]
  carefully [
    let response llm:chat message
    print response
  ] [
    print (word "Error: " error-message)
    print "Check your configuration and try again"
  ]
end
```

## Performance Tips

1. **Use Configuration Files**: Load settings once rather than setting each parameter
2. **Leverage Async**: Use `llm:chat-async` for multiple concurrent requests
3. **Manage History**: Clear history when context is no longer needed
4. **Choose Right Models**: Balance capability vs speed/cost for your use case
5. **Handle Errors**: Implement retry logic for production applications

## Advanced Configuration

### Custom Base URLs

For enterprise or custom deployments:

```
provider=openai
base_url=https://your-custom-openai-endpoint.com/v1
api_key=your-key
model=gpt-4o-mini
```

### Timeout Tuning

Adjust timeouts based on model and request complexity:

```
# Fast models, simple requests
timeout_seconds=15

# Complex reasoning, large responses  
timeout_seconds=120
```

### Temperature Settings

Control response randomness:

```
# Deterministic, factual responses
temperature=0.0

# Creative, varied responses  
temperature=1.0

# Balanced (recommended)
temperature=0.7
```
