extensions [llm]

globals [
  current-agent-code
  code-evolution-history
]

; Example 1: Using the code evolution template
to example-code-evolution
  ; Set up some example data
  set current-agent-code "lt random 20 rt random 20 fd 1"
  set code-evolution-history "v1: fd 1\nv2: lt 10 fd 1\nv3: lt random 10 fd 1"
  
  ; Set up LLM (configure your provider first)
  llm:set-provider "openai"  ; or your preferred provider
  llm:set-model "gpt-4"
  
  ; Use template to evolve code
  let new-code llm:chat-with-template "demos/code-evolution-template.yaml" (list
    ["current_code" current-agent-code]
    ["code_history" code-evolution-history]
    ["objective" "improve food collection efficiency"]
    ["constraints" "valid NetLogo movement commands only"]
    ["performance_notes" "current version moves randomly, needs more purpose"]
  )
  
  print (word "Original code: " current-agent-code)
  print (word "Evolved code: " new-code)
end

; Example 2: Using the analysis template
to example-data-analysis
  ; Analyze some simulation data
  let fitness-data "Agent 1: 15, Agent 2: 23, Agent 3: 8, Agent 4: 31, Agent 5: 12"
  
  let analysis llm:chat-with-template "demos/analysis-template.yaml" (list
    ["data" fitness-data]
    ["context" "NetLogo agent fitness after 1000 ticks"]
    ["goal" "identify patterns and suggest improvements"]
    ["trends" "fitness generally increasing over generations"]
  )
  
  print "=== Fitness Analysis ==="
  print analysis
end

; Example 3: Using the reasoning template
to example-problem-solving
  let solution llm:chat-with-template "demos/reasoning-template.yaml" (list
    ["problem" "Agents are clustering instead of spreading out to find food"]
    ["available_info" "10 agents, 50 food sources, 100x100 world"]
    ["constraints" "Cannot change world size or agent count"]
    ["success_criteria" "More even distribution and higher average fitness"]
  )
  
  print "=== Problem Solving ==="
  print solution
end

; Example 4: Using templates with agent conversations
to example-agent-conversation
  ; Create some agents and have them use templates
  create-turtles 3 [
    set color red
    setxy random-xcor random-ycor
    
    ; Each agent gets personalized advice
    let advice llm:chat-with-template "demos/simple-template.yaml" (list
      ["task" "provide movement strategy"]
      ["input" (word "I am agent " who " at position " xcor ", " ycor)]
      ["context" "food is scattered randomly across the world"]
    )
    
    print (word "Agent " who " received: " advice)
  ]
end

; Utility function to track code evolution for an agent
to track-my-code-evolution [new-code]
  ; Add to conversation history to track evolution
  llm:chat (word "CODE_VERSION: " new-code)
end

; Utility function to get code history for an agent
to-report get-my-code-history
  let history llm:history
  let code-versions []
  foreach history [ msg ->
    let role item 0 msg
    let content item 1 msg
    if role = "user" and (substring content 0 13) = "CODE_VERSION:" [
      set code-versions lput (substring content 14 (length content)) code-versions
    ]
  ]
  report code-versions
end

; Example of integrating with existing mutation system
to-report evolve-agent-code [current-code objective]
  ; Track this version
  track-my-code-evolution current-code
  
  ; Get evolution history
  let history get-my-code-history
  
  ; Use template to evolve
  let evolved-code llm:chat-with-template "demos/code-evolution-template.yaml" (list
    ["current_code" current-code]
    ["code_history" (reduce word history)]
    ["objective" objective]
    ["constraints" "NetLogo syntax only"]
    ["performance_notes" "based on fitness evaluation"]
  )
  
  report evolved-code
end
