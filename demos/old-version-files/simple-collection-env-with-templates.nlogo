extensions [ llm table fp rnd ]

globals [
  generation
  init-rule
  generation-stats
  best-rule
  best-rule-fitness
  error-log
  init-pseudocode
]

breed [llm-agents llm-agent]
breed [food-sources food-source]

llm-agents-own [
  input ;; observation vector
  rule ;; current rule (llm-generated)
  energy ;; current score
  lifetime ;; age of the agent (in generations)
  food-collected  ;; total food agent gathered
  parent-id ;; who number of parent
  parent-rule ;; parent rule
  pseudocode ;; descriptive text rule
  parent-pseudocode ;; pseudocode associated with the parent
]

;;; Setup Procedures

to setup
  clear-all
  
  ; Configure LLM for code evolution (replace with your preferred provider)
  llm:set-provider "openai"  ; or "anthropic", "gemini", etc.
  llm:set-model "gpt-4"      ; or your preferred model
  
  set init-rule "lt random 20 rt random 20 fd 1"
  set init-pseudocode "Take left turn randomly within 0-20 degrees, then take right turn randomly within 0-20 degrees and move forward 1"
  
  set generation-stats []
  set error-log []
  set best-rule-fitness 0
  
  spawn-food 30  ; num-food-sources
  setup-llm-agents
  reset-ticks
end

to setup-llm-agents
  create-llm-agents 10 [  ; num-llm-agents
    set color red
    setxy random-xcor random-ycor
    set rule init-rule
    set parent-id "na"
    set parent-rule "na"
    set pseudocode init-pseudocode
    set parent-pseudocode "na"
    init-agent-params
  ]
end

to init-agent-params
  set energy 0
  set food-collected 0
  set lifetime 0
end

to spawn-food [num]
  create-food-sources num [
    set shape "circle"
    set color green
    set size 0.5
    setxy random-xcor random-ycor
  ]
end

;;; Go Procedures

to go
  ask llm-agents [
    set lifetime lifetime + 1
    set input get-observation
    run-rule
    eat-food
  ]
  evolve-agents
  replenish-food
  tick
end

to run-rule
  carefully [
    run rule
  ] [
    let error-info (word
      "ERROR WHILE RUNNING RULE: " rule
      " | Agent: " who
      " | Tick: " ticks
      " | Fitness: " fitness
      " | Error: " error-message
    )
    print error-info
    set error-log lput error-info error-log
  ]
end

to evolve-agents
  if ticks >= 1 and ticks mod 500 = 0 [  ; ticks-per-generation
    print word "\nGeneration: " generation
    
    let parents select-best-agents 2  ; select top 2 agents
    let kill-num length parents
    
    foreach parents [ parent ->
      ask parent [
        let my-parent-id who
        let my-rule rule
        let my-pseudocode pseudocode
        hatch 1 [
          set parent-id my-parent-id
          set parent-rule my-rule
          set parent-pseudocode my-pseudocode
          
          ; NEW: Use LLM template instead of Python mutation
          set rule mutate-rule-with-llm my-rule
          
          init-agent-params
        ]
      ]
    ]
    
    ; Remove worst performers
    ask min-n-of kill-num llm-agents [fitness] [ die ]
    
    ; Reset for next generation
    ask llm-agents [
      set food-collected 0
      set energy 0
    ]
    
    set generation generation + 1
    set error-log []
  ]
end

; NEW: LLM-based mutation using templates
to-report mutate-rule-with-llm [current-rule]
  ; Track code evolution in conversation history
  llm:chat (word "CODE_VERSION: " current-rule)
  
  ; Get the agent's code evolution history
  let code-history get-code-evolution-history
  
  ; Use template to evolve the code
  let new-rule llm:chat-with-template "demos/code-evolution-template.yaml" (list
    ["current_code" current-rule]
    ["code_history" code-history]
    ["objective" "improve food collection efficiency and movement strategy"]
    ["constraints" "only use NetLogo movement commands: fd, bk, lt, rt, random"]
    ["performance_notes" (word "current fitness: " fitness " | food collected: " food-collected)]
  )
  
  ; Clean up the response (remove any extra text)
  set new-rule clean-code-response new-rule
  
  report new-rule
end

; Extract code evolution history from conversation
to-report get-code-evolution-history
  let history llm:history
  let code-versions []
  foreach history [ msg ->
    let role item 0 msg
    let content item 1 msg
    if role = "user" and (substring content 0 13) = "CODE_VERSION:" [
      set code-versions lput (substring content 14 (length content)) code-versions
    ]
  ]
  
  ; Format as string for template
  ifelse length code-versions > 0 [
    let formatted-history ""
    let version-num 1
    foreach code-versions [ version ->
      set formatted-history (word formatted-history "v" version-num ": " version "\n")
      set version-num version-num + 1
    ]
    report formatted-history
  ] [
    report "No previous versions"
  ]
end

; Clean up LLM response to extract just the NetLogo code
to-report clean-code-response [response]
  ; Remove common prefixes/suffixes that LLMs might add
  let cleaned response
  
  ; Remove newlines and extra spaces
  set cleaned reduce word (but-first but-last (word " " cleaned " "))
  
  ; If it looks like it has explanatory text, try to extract just the code
  ; This is a simple heuristic - you might need to adjust based on your LLM
  if (position ":" cleaned) != false [
    let colon-pos position ":" cleaned
    if colon-pos < 50 [  ; if colon is near the beginning, skip to after it
      set cleaned substring cleaned (colon-pos + 1) (length cleaned)
    ]
  ]
  
  ; Trim whitespace
  while [first cleaned = " "] [ set cleaned substring cleaned 1 (length cleaned) ]
  while [last cleaned = " "] [ set cleaned substring cleaned 0 (length cleaned - 1) ]
  
  report cleaned
end

to select-best-agents [num-agents]
  let best-agents max-n-of num-agents llm-agents [fitness]
  report sort-on [fitness] best-agents
end

to eat-food
  if any? food-sources-here [
    ask one-of food-sources-here [
      die
    ]
    set energy energy + 1
    set food-collected food-collected + 1
  ]
end

to replenish-food
  if count food-sources < 30 [  ; num-food-sources
    spawn-food (30 - count food-sources)
  ]
end

;;; Helpers and Observable Reporters

to-report fitness
  report energy
end

to-report mean-fitness
  report mean [fitness] of llm-agents
end

to-report get-observation
  let dist 7
  let angle 20
  let obs []
  ;; obs order is [left-cone right-cone center-cone]
  foreach [-20 40 -20] [a ->
    rt a
    set obs lput (get-in-cone dist angle) obs
  ]
  report obs
end

to-report get-in-cone [dist angle]
  let val 0
  let cone other food-sources in-cone dist angle
  let f min-one-of cone with [is-food-source? self] [distance myself]
  if f != nobody [
    set val distance f
  ]
  report val
end

; Test function to demonstrate template usage
to test-template-evolution
  ; Create a test agent and evolve its code
  create-llm-agents 1 [
    set rule "fd 1"
    set energy 5
    set food-collected 3
    
    print (word "Original rule: " rule)
    
    let evolved-rule mutate-rule-with-llm rule
    print (word "Evolved rule: " evolved-rule)
    
    die  ; clean up test agent
  ]
end
