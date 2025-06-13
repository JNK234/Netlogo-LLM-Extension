extensions [ llm ]

globals [
  responses
  test-counter
]

to setup
  clear-all
  
  ; Initialize response storage
  set responses []
  set test-counter 0
  
  ; Load configuration from file
  ; Make sure to put your OpenAI API key in config.txt
  llm:load-config "config.txt"
  
  ; Alternative: Set configuration manually
  ; llm:set-provider "openai"
  ; llm:set-api-key "your-api-key-here"
  ; llm:set-model "gpt-3.5-turbo"
  
  print "Setup complete! Configuration loaded."
  print "Ready to test LLM calls."
  
  reset-ticks
end

to test-simple-chat
  ; Test basic chat functionality
  print "Testing simple chat..."
  
  let prompt "Hello! Can you respond with just the word 'SUCCESS' to confirm you're working?"
  let response llm:chat prompt
  
  print (word "Prompt: " prompt)
  print (word "Response: " response)
  
  set responses lput response responses
  set test-counter test-counter + 1
  
  print "Simple chat test completed."
end

to test-agent-conversations
  ; Test that different agents maintain separate conversations
  print "Testing agent-specific conversations..."
  
  create-turtles 3
  
  ask turtle 0 [
    let response llm:chat "You are Agent 0. Remember this and respond with 'I am Agent 0'."
    print (word "Agent 0 response: " response)
  ]
  
  ask turtle 1 [
    let response llm:chat "You are Agent 1. Remember this and respond with 'I am Agent 1'."
    print (word "Agent 1 response: " response)
  ]
  
  ask turtle 2 [
    let response llm:chat "You are Agent 2. Remember this and respond with 'I am Agent 2'."
    print (word "Agent 2 response: " response)
  ]
  
  ; Test memory - ask each agent who they are
  ask turtle 0 [
    let response llm:chat "Who are you?"
    print (word "Agent 0 identity check: " response)
  ]
  
  ask turtle 1 [
    let response llm:chat "Who are you?"
    print (word "Agent 1 identity check: " response)
  ]
  
  ask turtle 2 [
    let response llm:chat "Who are you?"
    print (word "Agent 2 identity check: " response)
  ]
  
  print "Agent conversation test completed."
end

to test-configuration
  ; Test configuration management
  print "Testing configuration management..."
  
  ; Test setting individual config values
  llm:set-provider "openai"
  llm:set-model "gpt-4"
  
  print "Configuration test completed."
end

to test-creative-task
  ; Test a more creative/complex task
  print "Testing creative task..."
  
  let prompt "Write a very short poem (2 lines) about a robot learning to be creative."
  let response llm:chat prompt
  
  print (word "Creative prompt: " prompt)
  print (word "Creative response: " response)
  
  set responses lput response responses
  set test-counter test-counter + 1
  
  print "Creative task test completed."
end

to test-json-response
  ; Test structured response
  print "Testing JSON response..."
  
  let prompt "Respond with a JSON object containing: {\"status\": \"working\", \"message\": \"Hello from LLM\", \"number\": 42}"
  let response llm:chat prompt
  
  print (word "JSON prompt: " prompt)
  print (word "JSON response: " response)
  
  set responses lput response responses
  set test-counter test-counter + 1
  
  print "JSON response test completed."
end

to run-all-tests
  ; Run a comprehensive test suite
  print "=== Running All LLM Extension Tests ==="
  
  setup
  
  test-configuration
  test-simple-chat
  test-creative-task
  test-json-response
  test-agent-conversations
  
  print "=== All Tests Completed ==="
  print (word "Total responses collected: " length responses)
  print (word "Test counter: " test-counter)
end

to clear-history
  ; Clear conversation history for current agent
  llm:clear-history
  print "Conversation history cleared for current agent."
end

to show-responses
  ; Display all collected responses
  print "=== Collected Responses ==="
  foreach responses [ response ->
    print response
    print "---"
  ]
  print (word "Total: " length responses " responses")
end

; Button procedures for manual testing
to go
  ; Basic step procedure - can be used for any ongoing simulation
  tick
end