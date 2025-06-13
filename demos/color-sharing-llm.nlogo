extensions [ llm string table ]

globals [ 
  colors 
  response-counter
]

turtles-own [
  name
  favorite-color
  last-message
  response-reporter
  message
  response-pending
]

undirected-link-breed [ connections connection ]
directed-link-breed [ facts fact ]

to setup
  clear-all
  
  ; Load configuration from file - make sure config.txt has your OpenAI API key
  llm:load-config "config.txt"
  
  ; Alternative: Set configuration manually
  ; llm:set-provider "openai"
  ; llm:set-api-key "your-api-key-here"
  ; llm:set-model "gpt-3.5-turbo"
  
  set-default-shape turtles "person"
  set-default-shape facts "directed"
  
  let names ["Alice" "Ben" "Cindy" "David" "Emily" "Frank"
    "Gina" "Harry" "Isabella" "Jack" "Katie" "Liam"
    "Maggie" "Noah" "Olivia" "Patrick" "Quinn" "Rachel"
    "Samuel" "Tracy" "Ursula" "Vanessa" "William" "Xander"
    "Yvette" "Zack"]
    
  set colors ["red" "blue" "green" "orange" "purple" "yellow"]
  set response-counter 0
  
  create-turtles num-agents [
    fd 10
    set size 2
    set name item who names
    set favorite-color one-of colors
    set color runresult favorite-color
    set last-message ""
    set message ""
    set response-pending false
  ]
  
  ; Create network connections
  ask turtles [
    create-connections-with min-n-of 2 other turtles [ distance myself ]
  ]
  
  ; Set up agent personalities and knowledge
  ask turtles [
    set label (word name ": " favorite-color)
    
    ; Set up conversation history with system prompt
    llm:set-history (list
      (list "system" get-system-prompt)
    )
  ]
  
  print "Setup complete! Agents are ready to communicate."
  print (word "Created " count turtles " agents with " count connections " connections.")
  
  reset-ticks
end

to go
  ; Start async conversations for all agents
  ask turtles [
    if not response-pending [
      start-conversation
    ]
  ]
  
  ; Process completed responses
  ask turtles [
    if response-pending [
      process-response
    ]
  ]
  
  ; Clean up old facts
  ask facts [ die ]
  
  tick
end

to start-conversation
  ; Collect messages from neighbors
  let neighbor-messages (sentence [(word name ": " last-message "\n")] of link-neighbors with [ last-message != "" ])
  
  let conversation-prompt (word
    neighbor-messages
    " What would you like to say to your neighbors?"
    " Your response must be a raw JSON object with the keys `message`, `knowledge`, and `reasoning`."
    " `message` is what you want to say to your neighbors (one short sentence)"
    " `knowledge` is an object with agent names as keys and their favorite colors as values, or \"unknown\" if you haven't learned their color yet."
    " `reasoning` is a brief explanation of what you're trying to learn or share."
    " Your response should contain ONLY the JSON object, no other text."
  )
  
  ; Start async LLM call
  set response-reporter llm:chat-async conversation-prompt
  set response-pending true
  set response-counter response-counter + 1
end

to process-response
  ; Check if response is ready (this is synchronous in our current implementation)
  carefully [
    let raw-response runresult response-reporter
    
    ; Parse JSON response
    let response-data table:from-json raw-response
    set message table:get response-data "message"
    
    ; Update knowledge about other agents
    let knowledge table:get response-data "knowledge"
    foreach table:to-list knowledge [ pair ->
      let agent-name first pair
      let agent-color last pair
      
      ; Create visual fact links to show learned knowledge
      create-facts-to other turtles with [ name = agent-name ] [
        if member? agent-color colors [
          set color runresult agent-color
          set label (word "knows: " agent-name " likes " agent-color)
        ]
      ]
    ]
    
    ; Update display
    set label word-wrap (word name ": " message) 30
    set last-message message
    set response-pending false
    
    ; Debug output
    if show-debug [
      print (word name " said: " message)
      if table:has-key? response-data "reasoning" [
        print (word "  Reasoning: " table:get response-data "reasoning")
      ]
    ]
    
  ] [
    ; Handle errors gracefully
    if show-debug [
      print (word name " had an error: " error-message)
      print (word "Raw response: " runresult response-reporter)
    ]
    set message "..."
    set last-message message
    set response-pending false
  ]
end

to-report get-system-prompt
  let neighbor-names reduce [ [s w] -> (word s ", " w) ] [name] of link-neighbors
  
  report (word
    "You are an agent in a social network simulation. "
    "Your name is " name ". "
    "Your favorite color is " favorite-color ". "
    "Your direct neighbors are: " neighbor-names ". "
    "Your goal is to learn the favorite colors of all other agents in the network by talking to your neighbors. "
    "Be social and ask questions to discover information. "
    "Share what you know to help others. "
    "Keep your messages short and friendly. "
    "Always respond in the exact JSON format requested."
  )
end

to-report word-wrap [ str len ]
  let line ""
  let wrapped ""
  foreach (string:split str " ") [ w ->
    if length line + length w > len [
      set wrapped (word wrapped "\n" line)
      set line ""
    ]
    set line string:trim (word line " " w)
  ]
  report string:trim (word wrapped "\n" line)
end

to reset-conversations
  ; Clear all conversation histories
  ask turtles [
    llm:clear-history
    llm:set-history (list
      (list "system" get-system-prompt)
    )
    set last-message ""
    set message ""
    set response-pending false
  ]
  
  ask facts [ die ]
  set response-counter 0
  
  print "All conversations reset!"
end

to show-network-stats
  print "=== Network Statistics ==="
  print (word "Total agents: " count turtles)
  print (word "Total connections: " count connections)
  print (word "LLM responses generated: " response-counter)
  
  let agents-with-knowledge count turtles with [ any? out-fact-neighbors ]
  print (word "Agents with learned knowledge: " agents-with-knowledge)
  
  ask turtles [
    let known-colors count out-fact-neighbors
    if known-colors > 0 [
      print (word name " knows " known-colors " other agents' favorite colors")
    ]
  ]
end

to test-single-agent
  ; Test LLM functionality with just one agent
  ask turtle 0 [
    print (word "Testing LLM with agent: " name)
    
    let test-prompt "Hello! Can you respond with a JSON object containing your name and favorite color? Use the format: {\"name\": \"your-name\", \"color\": \"your-color\"}"
    
    let response llm:chat test-prompt
    print (word "Response: " response)
    
    carefully [
      let parsed table:from-json response
      print (word "Parsed name: " table:get parsed "name")
      print (word "Parsed color: " table:get parsed "color")
    ] [
      print (word "Failed to parse JSON: " error-message)
    ]
  ]
end