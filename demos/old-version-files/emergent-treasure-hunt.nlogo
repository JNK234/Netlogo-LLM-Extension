; ABOUTME: Emergent treasure hunt where agents discover what treasure is and where to find it through LLM-mediated communication in a maze
; ABOUTME: Agents share partial knowledge clues and use collaborative reasoning to solve the mystery

extensions [ llm ]

breed [treasure-hunters hunter]
breed [treasures treasure]

globals [
  maze-width
  maze-height
  treasure-discovered?
  treasure-definition
  treasure-location
  communication-pairs
  ; Interface widget variables
  ; num-hunters              ; Number of treasure hunters (slider)
   ;communication-range      ; Range for agent communication (slider)
  ; confidence-threshold     ; Confidence level needed to manifest treasure (slider)
  ; show-trails?            ; Whether to show agent trails (switch)
  ; show-communications?    ; Whether to show communication visuals (switch)
  ; default-strategy        ; Default exploration strategy (chooser)
  ; llm-config-file        ; Path to LLM configuration file (input)

]

patches-own [
  wall?                  ; true if this patch is a wall
  explored?              ; true if an agent has been here
  meeting-glow          ; visual effect when agents meet here
  path-color            ; color for path visualization
]

treasure-hunters-own [
  knowledge-fragment    ; the one clue each agent knows
  learned-facts         ; accumulated knowledge from conversations
  current-goal          ; what agent is trying to do now
  confidence-level      ; how confident agent is in their understanding
  last-communication   ; tick when last communicated
  exploration-strategy  ; how this agent moves through maze
  memory-trail         ; patches this agent has visited
]

treasures-own [
  glow-phase           ; for animation effect
  discovered-by        ; which agents found it
]

to setup
  clear-all

  ; Initialize interface variables with defaults if not set
  if num-hunters = 0 [ set num-hunters 5 ]
  if communication-range = 0 [ set communication-range 2 ]
  if confidence-threshold = 0 [ set confidence-threshold 0.7 ]
  if default-strategy = 0 [ set default-strategy "mixed" ]
  ; For config file, try to use the one in the same directory as the model
  if llm-config-file = 0 [
    ; Try just the filename first (works if model saved and opened from same location)
    set llm-config-file "config.txt"
  ]
  ; Initialize boolean switches (0 means not set by interface)
  if show-trails? = 0 [ set show-trails? true ]
  if show-communications? = 0 [ set show-communications? true ]

  ; Initialize LLM extension with default configuration
  setup-llm

  ; Set world dimensions for good maze
  set maze-width 21   ; odd number for proper maze generation
  set maze-height 21
  resize-world 0 (maze-width - 1) 0 (maze-height - 1)

  ; Initialize global variables
  set treasure-discovered? false
  set treasure-definition ""
  set treasure-location nobody
  set communication-pairs []

  ; Generate the maze
  generate-maze

  ; Create treasure-hunting agents with unique knowledge
  create-treasure-hunters num-hunters [
    setup-hunter
  ]

  ; Visual setup
  setup-visual-appearance

  reset-ticks
end

to setup-llm
  ; Load LLM configuration from file if it exists
  if llm-config-file != 0 and llm-config-file != "" [
    ; Try loading the config file
    ; Note: The file should be in the same directory as the model
    ; or you can use an absolute path
    carefully [
      llm:load-config llm-config-file
    ] [
      ; If loading fails, use Ollama as default
      print (word "Note: Could not load " llm-config-file ". Using Ollama with llama3.2")
      llm:set-provider "ollama"
      llm:set-model "llama3.2"
    ]
  ]
end

to generate-maze
  ; Initialize all patches as walls
  ask patches [
    set wall? true
    set explored? false
    set meeting-glow 0
    set path-color gray - 2
    set pcolor gray - 2  ; dark gray walls
  ]

  ; Create a simple maze using recursive backtracking algorithm
  ; Start with a grid of walls and carve out passages
  let start-patch patch 1 1
  ask start-patch [
    set wall? false
    set pcolor brown + 1  ; light tan path
  ]

  ; Carve maze paths
  carve-maze-from start-patch

  ; Ensure there are some open meeting areas
  create-meeting-areas

  ; Create dead ends and complexity
  add-maze-complexity
end

to carve-maze-from [current-patch]
  ; Recursive backtracking maze generation
  ask current-patch [
    set wall? false
    set pcolor brown + 1

    ; Get possible directions (2 patches away to maintain walls)
    let possible-directions []

    ; Check each cardinal direction
    if pxcor + 2 < maze-width [
      let east-patch patch (pxcor + 2) pycor
      if east-patch != nobody and [wall?] of east-patch [
        set possible-directions lput east-patch possible-directions
      ]
    ]

    if pycor + 2 < maze-height [
      let north-patch patch pxcor (pycor + 2)
      if north-patch != nobody and [wall?] of north-patch [
        set possible-directions lput north-patch possible-directions
      ]
    ]

    if pxcor - 2 >= 0 [
      let west-patch patch (pxcor - 2) pycor
      if west-patch != nobody and [wall?] of west-patch [
        set possible-directions lput west-patch possible-directions
      ]
    ]

    if pycor - 2 >= 0 [
      let south-patch patch pxcor (pycor - 2)
      if south-patch != nobody and [wall?] of south-patch [
        set possible-directions lput south-patch possible-directions
      ]
    ]

    ; Randomly visit unvisited neighbors
    while [length possible-directions > 0] [
      let next-patch one-of possible-directions
      set possible-directions remove next-patch possible-directions

      if [wall?] of next-patch [
        ; Carve path to next cell
        let between-patch patch (([pxcor] of next-patch + pxcor) / 2) (([pycor] of next-patch + pycor) / 2)
        ask between-patch [
          set wall? false
          set pcolor brown + 1
        ]

        ; Recursively carve from next cell
        carve-maze-from next-patch
      ]
    ]
  ]
end

to create-meeting-areas
  ; Create some larger open areas where agents can meet
  let meeting-spots []
  repeat 3 [
    let spot one-of patches with [not wall? and pxcor > 2 and pxcor < maze-width - 3 and pycor > 2 and pycor < maze-height - 3]
    if spot != nobody [
      ask spot [
        ask patches in-radius 1 [
          if wall? [
            set wall? false
            set pcolor brown + 2  ; slightly different color for meeting areas
          ]
        ]
      ]
      set meeting-spots lput spot meeting-spots
    ]
  ]
end

to add-maze-complexity
  ; Add some additional paths to make the maze more interesting
  repeat 5 [
    let wall-patch one-of patches with [wall? and count neighbors with [not wall?] >= 2]
    if wall-patch != nobody [
      ask wall-patch [
        set wall? false
        set pcolor brown + 1
      ]
    ]
  ]
end

to setup-hunter
  ; Place hunter at a random open patch
  let open-patches patches with [not wall?]
  if any? open-patches [
    move-to one-of open-patches
  ]

  ; Assign unique knowledge fragment
  set knowledge-fragment assign-knowledge-fragment
  set learned-facts []
  set current-goal "explore"
  set confidence-level 0
  set last-communication 0
  set memory-trail []

  ; Visual appearance with unique shapes and colors
  set shape one-of ["person" "circle" "triangle" "square" "star"]
  set color one-of [red blue green yellow magenta cyan orange pink]
  set size 0.9

  ; Set exploration strategy
  ifelse default-strategy = "mixed" [
    set exploration-strategy one-of ["methodical" "random" "wall-follower"]
  ] [
    set exploration-strategy default-strategy
  ]

  ; Enable pen for trail with agent's color (based on switch)
  ifelse show-trails? = true [
    pen-down
    set pen-size 2
  ] [
    pen-up
  ]

  ; Log agent creation
  print (word "Hunter " who " created with clue: \"" knowledge-fragment "\"")
  print (word "  Strategy: " exploration-strategy ", Starting at (" pxcor ", " pycor ")")
end

to-report assign-knowledge-fragment
  ; Each agent gets one piece of the treasure puzzle
  let fragments [
    "The treasure is golden and round like the sun"
    "Look where two main paths cross each other"
    "The special place has coordinates that add up to exactly 15"
    "It only appears when all clues are combined"
    "The treasure glows and makes everyone happy"
    "Find the spot furthest from any wall"
  ]

  ; Assign unique fragments (cycle through if more agents than fragments)
  let my-index who mod length fragments
  report item my-index fragments
end

to setup-visual-appearance
  ; Set patch colors and visual effects
  ask patches [
    if not wall? [
      set path-color brown + 1
    ]
  ]

  ; Create visual border
  ask patches with [pxcor = 0 or pxcor = maze-width - 1 or pycor = 0 or pycor = maze-height - 1] [
    set pcolor black
  ]
end

to go
  ; Main simulation loop
  if not any? treasure-hunters [ stop ]

  ; Agent actions
  ask treasure-hunters [
    move-through-maze
    detect-nearby-agents
    analyze-current-situation
    take-action-based-on-goal
    update-exploration-memory
    update-agent-appearance
  ]

  ; Update environment
  update-visual-effects
  check-treasure-conditions

  tick

  ; Stop if treasure is found and celebrated
  if treasure-discovered? and any? treasures [
    if ticks mod 30 = 0 [  ; celebration effect every 30 ticks
      celebrate-success
    ]
  ]
end

to move-through-maze
  ; Different movement strategies
  if exploration-strategy = "random" [
    let possible-moves patches with [not wall? and distance myself <= 1]
    if any? possible-moves [
      move-to one-of possible-moves
    ]
  ]

  if exploration-strategy = "methodical" [
    ; Try to explore unseen areas
    let unexplored patches with [not wall? and not explored? and distance myself <= 1]
    ifelse any? unexplored [
      move-to one-of unexplored
    ] [
      ; If no unexplored nearby, move randomly
      let possible-moves patches with [not wall? and distance myself <= 1]
      if any? possible-moves [
        move-to one-of possible-moves
      ]
    ]
  ]

  if exploration-strategy = "wall-follower" [
    ; Follow walls (right-hand rule) - safe implementation
    right 90
    while [patch-ahead 1 = nobody or [wall?] of patch-ahead 1] [
      right 90
    ]
    ; Only move if destination is valid and not a wall
    let target-patch patch-ahead 1
    if target-patch != nobody and not [wall?] of target-patch [
      move-to target-patch
    ]
  ]

  ; Mark current location as explored
  ask patch-here [
    set explored? true
    set pcolor path-color + 0.5  ; slightly brighter for explored areas
  ]
end

to detect-nearby-agents
  ; Check for other agents within communication range
  let nearby-hunters other treasure-hunters in-radius communication-range

  if any? nearby-hunters and (ticks - last-communication) > 5 [
    let communication-partner one-of nearby-hunters

    ; Enhanced visual effect for communication
    ask patch-here [
      set meeting-glow 15  ; bright glow effect
      set pcolor yellow
    ]

    ; Create spreading communication effect
    ask patches in-radius 1.5 [
      if not wall? [
        set meeting-glow 8
        set pcolor yellow - 1
      ]
    ]

    ; Visual connection between communicating agents
    ask communication-partner [
      set color color + 3  ; brighten communicating agent
      pen-up
      move-to patch-here
      pen-down
      move-to [patch-here] of myself
      pen-up
    ]

    ; Initiate LLM-based conversation
    communicate-with communication-partner
    set last-communication ticks
  ]
end

to communicate-with [partner]
  ; Share knowledge using LLM
  let my-info (word knowledge-fragment ". I have learned: " learned-facts)
  let partner-info (word [knowledge-fragment] of partner ". They have learned: " [learned-facts] of partner)
  let combined-info (word "I know: " my-info ". My partner knows: " partner-info)

  ; Log the interaction
  print (word "=== AGENT INTERACTION at tick " ticks " ===")
  print (word "Hunter " who " meets Hunter " [who] of partner)
  print (word "Location: (" pxcor ", " pycor ")")
  print "Sharing knowledge..."

  ; Use LLM to synthesize information
  let conversation-result ""
  carefully [
    print "Consulting LLM for insights..."
    set conversation-result llm:chat (word combined-info ". What can we conclude about finding a treasure? Give me new insights.")
    print (word "LLM Response: " conversation-result)
  ] [
    ; If LLM call fails, log the error details
    print (word "ERROR: LLM call failed with: " error-message)
    print "Falling back to simple combination"
    set conversation-result (word "Combining clues: " [knowledge-fragment] of partner)
  ]

  ; Update learned facts
  if conversation-result != "" [
    set learned-facts lput conversation-result learned-facts
    print (word "Hunter " who " learned: " conversation-result)

    ; Partner also learns
    ask partner [
      set learned-facts lput conversation-result learned-facts
      print (word "Hunter " who " also learned this insight")
    ]
  ]

  ; Update confidence based on information gained
  set confidence-level confidence-level + 0.2
  if confidence-level > 1 [ set confidence-level 1 ]
  print (word "Confidence levels updated. Hunter " who ": " precision confidence-level 2)
  print "================================"
end

to analyze-current-situation
  ; Use LLM to determine next goal based on current knowledge
  if length learned-facts > 1 and confidence-level > 0.3 [
    let situation-summary (word "My original clue: " knowledge-fragment
                               ". What I've learned from others: " learned-facts
                               ". I'm currently at coordinates " pxcor " " pycor
                               ". What should be my next goal?")

    let possible-goals ["explore-more" "find-center" "find-crossing" "search-systematically" "gather-more-info"]

    carefully [
      print (word "Hunter " who " analyzing situation...")
      let old-goal current-goal
      set current-goal llm:choose situation-summary possible-goals
      if current-goal != old-goal [
        print (word "Hunter " who " changed goal from '" old-goal "' to '" current-goal "'")
      ]
    ] [
      ; Fallback if LLM fails
      print (word "ERROR in goal analysis: " error-message)
      set current-goal one-of possible-goals
      print (word "Hunter " who " randomly selected goal: " current-goal)
    ]
  ]
end

to take-action-based-on-goal
  ; Act based on current goal
  if current-goal = "find-center" [
    ; Move toward center of maze
    let center-patch patch (maze-width / 2) (maze-height / 2)
    if center-patch != nobody [
      face center-patch
    ]
  ]

  if current-goal = "find-crossing" [
    ; Look for intersection points
    let crossings patches with [not wall? and count neighbors with [not wall?] >= 3]
    if any? crossings [
      let nearest-crossing min-one-of crossings [distance myself]
      face nearest-crossing
    ]
  ]

  if current-goal = "search-systematically" [
    ; Check if current location matches learned criteria
    check-treasure-location
  ]
end

to check-treasure-location
  ; Check if current location might be treasure location based on accumulated knowledge
  let location-matches? false

  ; Analyze learned facts to see if current location fits
  if length learned-facts > 2 [
    let location-description (word "I am at coordinates " pxcor " " pycor
                                  ". The sum is " (pxcor + pycor)
                                  ". This location has " count neighbors with [not wall?] " open neighbors."
                                  ". Based on what I know: " learned-facts
                                  ". Could this be the treasure location?")

    carefully [
      let location-assessment llm:choose location-description ["yes-likely" "no-unlikely" "need-more-info"]
      if location-assessment = "yes-likely" [
        set location-matches? true
      ]
    ] [
      ; Simple fallback check
      if (pxcor + pycor) = 15 and count neighbors with [not wall?] >= 3 [
        set location-matches? true
      ]
    ]
  ]

  ; If location seems right and we have enough knowledge, try to manifest treasure
  if location-matches? and confidence-level > confidence-threshold [
    attempt-treasure-manifestation
  ]
end

to attempt-treasure-manifestation
  ; Try to make treasure appear based on collective knowledge
  if not treasure-discovered? [
    print "=== TREASURE MANIFESTATION ATTEMPT ==="
    print (word "Hunter " who " attempting to manifest treasure at (" pxcor ", " pycor ")")

    let all-knowledge []
    ask treasure-hunters [
      set all-knowledge lput knowledge-fragment all-knowledge
      set all-knowledge sentence all-knowledge learned-facts
    ]

    let combined-knowledge reduce word all-knowledge
    print "Combining all collective knowledge..."

    carefully [
      print "Asking LLM to describe the treasure..."
      let treasure-description llm:chat (word "Based on all our clues: " combined-knowledge
                                             ". What exactly is the treasure and what does it look like?")
      print (word "LLM treasure description: " treasure-description)

      if length treasure-description > 10 [  ; Got a substantial description
        set treasure-definition treasure-description
        set treasure-location patch-here
        print (word "TREASURE MANIFESTED! " treasure-definition)
        manifest-treasure
      ]
    ] [
      ; Fallback treasure manifestation
      print (word "ERROR in treasure description: " error-message)
      print "Checking if we have enough clues for fallback..."
      if length all-knowledge > 4 [  ; Enough clues gathered
        set treasure-definition "A glowing golden orb that brings joy"
        set treasure-location patch-here
        print "TREASURE MANIFESTED using fallback description!"
        manifest-treasure
      ]
    ]
    print "================================"
  ]
end

to manifest-treasure
  ; Create the treasure at the determined location
  set treasure-discovered? true

  ask treasure-location [
    sprout-treasures 1 [
      set shape "circle"
      set color yellow
      set size 1.2
      set glow-phase 0
      set discovered-by nobody
    ]
    set pcolor (yellow + 2)  ; golden color
  ]

  ; Visual celebration
  ask treasure-hunters [
    set color color + 2  ; brighten colors
    face treasure-location
  ]
end

to update-exploration-memory
  ; Track where agent has been
  if not member? patch-here memory-trail [
    set memory-trail lput patch-here memory-trail
  ]

  ; Keep memory manageable
  if length memory-trail > 50 [
    set memory-trail but-first memory-trail
  ]
end

to update-agent-appearance
  ; Visual feedback based on confidence level
  let base-color color

  ; Size increases with confidence
  set size (0.9 + 0.4 * confidence-level)

  ; Brightness increases with confidence
  if confidence-level > 0.5 [
    set color (base-color + 2)
  ]

  ; High-confidence agents get special effects
  if confidence-level > 0.8 [
    ; Create halo effect around high-confidence agents
    ask patches in-radius 1 [
      if not wall? and meeting-glow <= 0 [
        set pcolor (pcolor + 0.5)
      ]
    ]
  ]
end

to update-visual-effects
  ; Update meeting glow effects
  ask patches with [meeting-glow > 0] [
    set meeting-glow meeting-glow - 1
    if meeting-glow <= 0 [
      set pcolor path-color
      if explored? [ set pcolor path-color + 0.5 ]
    ]
  ]

  ; Enhanced treasure glow and surrounding effects
  if any? treasures [
    ask treasures [
      set glow-phase glow-phase + 0.3
      ; Pulsing treasure colors
      set color (yellow + 2 + 2 * sin(glow-phase * 180))  ; pulsing golden
      set size (1.2 + 0.3 * sin(glow-phase * 90))

      ; Treasure radiates light to surrounding patches
      ask patches in-radius 2 [
        if not wall? [
          let distance-from-treasure distance myself
          let glow-intensity (3 - distance-from-treasure) / 3
          set pcolor (yellow + glow-intensity * 2)  ; golden glow
        ]
      ]

      ; Sparkle effect
      if random 10 < 3 [
        ask one-of patches in-radius 1.5 with [not wall?] [
          set pcolor white
          set meeting-glow 3
        ]
      ]
    ]
  ]
end

to check-treasure-conditions
  ; Check if treasure has been found by agents
  if treasure-discovered? and any? treasures [
    let treasure-patch [patch-here] of one-of treasures
    let hunters-at-treasure treasure-hunters-on treasure-patch

    if any? hunters-at-treasure [
      ask one-of treasures [
        set discovered-by hunters-at-treasure
      ]
    ]
  ]
end

to celebrate-success
  ; Visual celebration when treasure is found
  if any? treasures [
    ask one-of treasures [
      ask patches in-radius 3 [
        set pcolor (pcolor + random 3 - 1)
      ]
    ]

    ask treasure-hunters [
      right random 60 - 30  ; dance movement
    ]
  ]
end

; Utility reporters
to-report knowledge-summary
  ; Report summary of all agent knowledge
  let summary ""
  ask treasure-hunters [
    set summary (word summary "Agent " who ": " knowledge-fragment " | ")
  ]
  report summary
end

to-report treasure-status
  ; Report current treasure discovery status
  if treasure-discovered? [
    report (word "DISCOVERED: " treasure-definition)
  ]
  report "Still searching..."
end