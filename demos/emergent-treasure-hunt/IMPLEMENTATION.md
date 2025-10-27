# Treasure Hunt - Technical Implementation Guide

## Architecture Overview

This document explains the technical implementation of the treasure hunt simulation, demonstrating how to build complex multi-agent AI systems with the NetLogo LLM Extension.

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   NetLogo Environment                    │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Maze World (21x21)                  │  │
│  │  ┌────────┐  ┌────────┐  ┌────────┐            │  │
│  │  │Agent 0 │  │Agent 1 │  │Agent 2 │  ...       │  │
│  │  │Clue A  │  │Clue B  │  │Clue C  │            │  │
│  │  └───┬────┘  └───┬────┘  └───┬────┘            │  │
│  │      │            │            │                  │  │
│  │      └────────────┴────────────┘                  │  │
│  │                   │                                │  │
│  │                   ▼                                │  │
│  │        ┌──────────────────────┐                  │  │
│  │        │  LLM Extension Core  │                  │  │
│  │        │  - Message History   │                  │  │
│  │        │  - Provider Factory  │                  │  │
│  │        └──────────┬───────────┘                  │  │
│  └───────────────────┼──────────────────────────────┘  │
└────────────────────┼─────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                      │
    ┌─────▼─────┐         ┌─────▼─────┐
    │  OpenAI   │         │  Ollama   │
    │  Claude   │    or   │  (Local)  │
    │  Gemini   │         │           │
    └───────────┘         └───────────┘
```

## Core Components

### 1. World Structure

**Global Variables**
```netlogo
globals [
  maze-width                  ; World width (21)
  maze-height                 ; World height (21)
  treasure-discovered?        ; Boolean: has treasure been found
  treasure-definition         ; String: LLM-generated description
  treasure-location           ; Patch: where treasure manifested
  communication-pairs         ; List: tracking agent meetings
]
```

**Patch Properties**
```netlogo
patches-own [
  wall?                ; Boolean: is this a wall
  explored?            ; Boolean: has any agent visited
  meeting-glow         ; Number: visual effect countdown
  path-color           ; Color: base color for paths
]
```

### 2. Agent Architecture

**Agent State**
```netlogo
treasure-hunters-own [
  knowledge-fragment      ; String: agent's initial clue
  learned-facts          ; List[String]: accumulated insights
  current-goal           ; String: current objective
  confidence-level       ; Number 0-1: epistemic certainty
  last-communication     ; Number: tick of last meeting
  exploration-strategy   ; String: movement algorithm
  memory-trail          ; List[Patch]: visited locations
]
```

**Agent Lifecycle**
```
Setup Phase:
  ├─ Spawn at random open patch
  ├─ Assign unique knowledge fragment
  ├─ Set exploration strategy
  ├─ Initialize confidence = 0
  └─ Enable visual trail

Main Loop (each tick):
  ├─ move-through-maze()
  ├─ detect-nearby-agents()
  │   └─ communicate-with(partner)  [LLM]
  ├─ analyze-current-situation()    [LLM]
  │   └─ update current-goal
  ├─ take-action-based-on-goal()
  ├─ update-exploration-memory()
  └─ update-agent-appearance()
```

### 3. Maze Generation

**Algorithm**: Recursive Backtracking
```netlogo
to generate-maze
  1. Initialize all patches as walls
  2. Start at patch (1, 1)
  3. carve-maze-from(start-patch):
     - Mark current patch as path
     - Get unvisited neighbors (2 steps away)
     - For each random neighbor:
       * Carve path between current and neighbor
       * Recursively carve from neighbor
  4. create-meeting-areas (3 open spaces)
  5. add-maze-complexity (5 extra paths)
end
```

**Result**: Perfect maze with multiple meeting areas and dead ends

### 4. Exploration Strategies

**Random**
```netlogo
if exploration-strategy = "random" [
  let possible-moves patches with [not wall? and distance myself <= 1]
  if any? possible-moves [ move-to one-of possible-moves ]
]
```

**Methodical** (Prefers unexplored)
```netlogo
if exploration-strategy = "methodical" [
  let unexplored patches with [
    not wall? and not explored? and distance myself <= 1
  ]
  ifelse any? unexplored [
    move-to one-of unexplored
  ] [
    ; Fall back to random if all nearby explored
    move-to one-of patches with [not wall? and distance myself <= 1]
  ]
]
```

**Wall-Follower** (Right-hand rule)
```netlogo
if exploration-strategy = "wall-follower" [
  right 90
  while [patch-ahead 1 = nobody or [wall?] of patch-ahead 1] [
    right 90
  ]
  let target-patch patch-ahead 1
  if target-patch != nobody and not [wall?] of target-patch [
    move-to target-patch
  ]
]
```

### 5. Communication System

**Detection Phase**
```netlogo
to detect-nearby-agents
  let nearby-hunters other treasure-hunters in-radius communication-range

  if any? nearby-hunters and (ticks - last-communication) > 5 [
    let communication-partner one-of nearby-hunters

    ; Visual effects
    ask patch-here [
      set meeting-glow 15
      set pcolor yellow
    ]
    ask patches in-radius 1.5 [
      if not wall? [
        set meeting-glow 8
        set pcolor yellow - 1
      ]
    ]

    ; Initiate conversation
    communicate-with communication-partner
    set last-communication ticks
  ]
end
```

**Knowledge Exchange (LLM Integration)**
```netlogo
to communicate-with [partner]
  ; Prepare combined knowledge
  let my-info (word knowledge-fragment ". I have learned: " learned-facts)
  let partner-info (word [knowledge-fragment] of partner
                         ". They have learned: " [learned-facts] of partner)
  let combined-info (word "I know: " my-info ". My partner knows: " partner-info)

  ; LLM synthesis
  carefully [
    set conversation-result llm:chat (word combined-info
      ". What can we conclude about finding a treasure? Give me new insights.")

    ; Both agents learn the same insight
    set learned-facts lput conversation-result learned-facts
    ask partner [
      set learned-facts lput conversation-result learned-facts
    ]
  ] [
    ; Fallback if LLM fails
    set conversation-result (word "Combining clues: " [knowledge-fragment] of partner)
  ]

  ; Update confidence
  set confidence-level confidence-level + 0.2
  if confidence-level > 1 [ set confidence-level 1 ]
end
```

**Key Design Decisions:**
- **Both agents learn**: Simulates true knowledge sharing
- **LLM synthesis**: Creates emergent insights beyond simple concatenation
- **Fallback mechanism**: Graceful degradation if LLM fails
- **Cooldown period**: Prevents spam (5 tick minimum between communications)

### 6. Goal-Driven Behavior

**Situation Analysis**
```netlogo
to analyze-current-situation
  if length learned-facts > 1 and confidence-level > 0.3 [
    let situation-summary (word
      "My original clue: " knowledge-fragment
      ". What I've learned from others: " learned-facts
      ". I'm currently at coordinates " pxcor " " pycor
      ". What should be my next goal?")

    let possible-goals [
      "explore-more"
      "find-center"
      "find-crossing"
      "search-systematically"
      "gather-more-info"
    ]

    carefully [
      set current-goal llm:choose situation-summary possible-goals
    ] [
      ; Fallback to random
      set current-goal one-of possible-goals
    ]
  ]
end
```

**Goal Execution**
```netlogo
to take-action-based-on-goal
  if current-goal = "find-center" [
    let center-patch patch (maze-width / 2) (maze-height / 2)
    if center-patch != nobody [ face center-patch ]
  ]

  if current-goal = "find-crossing" [
    let crossings patches with [not wall? and count neighbors with [not wall?] >= 3]
    if any? crossings [
      let nearest-crossing min-one-of crossings [distance myself]
      face nearest-crossing
    ]
  ]

  if current-goal = "search-systematically" [
    check-treasure-location
  ]
end
```

### 7. Treasure Discovery Logic

**Location Validation**
```netlogo
to check-treasure-location
  let location-matches? false

  if length learned-facts > 2 [
    let location-description (word
      "I am at coordinates " pxcor " " pycor
      ". The sum is " (pxcor + pycor)
      ". This location has " count neighbors with [not wall?] " open neighbors."
      ". Based on what I know: " learned-facts
      ". Could this be the treasure location?")

    carefully [
      let location-assessment llm:choose location-description
        ["yes-likely" "no-unlikely" "need-more-info"]
      if location-assessment = "yes-likely" [
        set location-matches? true
      ]
    ] [
      ; Fallback: hardcoded logic for clue "coordinates add to 15"
      if (pxcor + pycor) = 15 and count neighbors with [not wall?] >= 3 [
        set location-matches? true
      ]
    ]
  ]

  if location-matches? and confidence-level > confidence-threshold [
    attempt-treasure-manifestation
  ]
end
```

**Manifestation Process**
```netlogo
to attempt-treasure-manifestation
  if not treasure-discovered? [
    ; Collect ALL knowledge from ALL agents
    let all-knowledge []
    ask treasure-hunters [
      set all-knowledge lput knowledge-fragment all-knowledge
      set all-knowledge sentence all-knowledge learned-facts
    ]

    let combined-knowledge reduce word all-knowledge

    ; LLM generates treasure description
    carefully [
      let treasure-description llm:chat (word
        "Based on all our clues: " combined-knowledge
        ". What exactly is the treasure and what does it look like?")

      if length treasure-description > 10 [
        set treasure-definition treasure-description
        set treasure-location patch-here
        manifest-treasure
      ]
    ] [
      ; Fallback treasure
      if length all-knowledge > 4 [
        set treasure-definition "A glowing golden orb that brings joy"
        set treasure-location patch-here
        manifest-treasure
      ]
    ]
  ]
end
```

### 8. Visual Effects System

**Agent Visualization**
```netlogo
to update-agent-appearance
  ; Size increases with confidence
  set size (0.9 + 0.4 * confidence-level)

  ; Brightness increases with confidence
  if confidence-level > 0.5 [
    set color (base-color + 2)
  ]

  ; High-confidence agents get halo effect
  if confidence-level > 0.8 [
    ask patches in-radius 1 [
      if not wall? and meeting-glow <= 0 [
        set pcolor (pcolor + 0.5)
      ]
    ]
  ]
end
```

**Communication Effects**
```netlogo
; Meeting glow decay
to update-visual-effects
  ask patches with [meeting-glow > 0] [
    set meeting-glow meeting-glow - 1
    if meeting-glow <= 0 [
      set pcolor path-color
      if explored? [ set pcolor path-color + 0.5 ]
    ]
  ]
end
```

**Treasure Animation**
```netlogo
; Pulsating treasure
ask treasures [
  set glow-phase glow-phase + 0.3
  set color (yellow + 2 + 2 * sin(glow-phase * 180))
  set size (1.2 + 0.3 * sin(glow-phase * 90))

  ; Radiating light
  ask patches in-radius 2 [
    if not wall? [
      let distance-from-treasure distance myself
      let glow-intensity (3 - distance-from-treasure) / 3
      set pcolor (yellow + glow-intensity * 2)
    ]
  ]

  ; Sparkles
  if random 10 < 3 [
    ask one-of patches in-radius 1.5 with [not wall?] [
      set pcolor white
      set meeting-glow 3
    ]
  ]
]
```

## LLM Integration Patterns

### Pattern 1: Synchronous Knowledge Synthesis

**Use Case**: Agent-to-agent knowledge exchange

```netlogo
let result llm:chat prompt
; Blocks until LLM responds
; Agent waits, then uses result
```

**Pros**:
- Simple, sequential logic
- Guaranteed result before proceeding

**Cons**:
- Blocks agent during LLM call
- Can slow simulation

### Pattern 2: Constrained Selection

**Use Case**: Choosing from predefined options

```netlogo
let choice llm:choose description options
; LLM must pick from provided list
```

**Pros**:
- Guaranteed valid output
- Prevents hallucination
- Forces structured thinking

**Cons**:
- Limited to predefined choices
- May miss creative solutions

### Pattern 3: Asynchronous Processing (Not currently used)

**Potential Enhancement**:
```netlogo
; Start LLM call without blocking
let awaitable llm:chat-async prompt

; Do other work
move-through-maze
update-visual-effects

; Get result when needed
let result runresult awaitable
```

**Benefits**:
- Agents continue moving during LLM calls
- Better performance
- More realistic parallelism

## Performance Considerations

### LLM Call Frequency

Current design limits LLM calls:
- **Communication**: Once per 5 ticks per pair
- **Goal analysis**: Only when confidence > 0.3 and learned-facts > 1
- **Location check**: Only when goal = "search-systematically"

### Token Optimization

Prompts are kept concise:
- Use `max_tokens=500` in config
- Summarize instead of full context
- Combine related queries

### Fallback Mechanisms

Every LLM call has fallback:
```netlogo
carefully [
  ; Try LLM operation
] [
  ; Use simple heuristic if fails
]
```

## Emergent Properties

### Knowledge Propagation

Knowledge spreads like an epidemic:
1. Agent A meets Agent B
2. Both synthesize new insight
3. Agent A meets Agent C (shares A+B knowledge)
4. Agent B meets Agent D (shares A+B knowledge)
5. Exponential growth of collective knowledge

### Spatial Clustering

Agents naturally cluster:
- Meeting areas become hot spots
- Agents with similar goals converge
- High-traffic areas explored more

### Confidence Cascades

Confidence builds collectively:
- Initial meetings: Low confidence
- Middle phase: Accelerating confidence
- Late phase: High confidence everywhere

### Goal Synchronization

Agents' goals tend to align:
- Early: All "explore-more"
- Middle: Mix of goals based on knowledge
- Late: Many "search-systematically"

## Testing Strategy

### Unit Tests

Test individual components:
```netlogo
; Test maze generation
setup
assert [ count patches with [wall?] > 0 ]
assert [ count patches with [not wall?] > 0 ]

; Test agent creation
assert [ count treasure-hunters = num-hunters ]
assert [ all? treasure-hunters [knowledge-fragment != ""] ]
```

### Integration Tests

Test LLM integration:
```netlogo
; Test communication
setup
ask one-of treasure-hunters [
  let partner one-of other treasure-hunters
  communicate-with partner
  assert [ length learned-facts > 0 ]
]
```

### End-to-End Tests

Run full simulation:
```netlogo
setup
repeat 1000 [ go ]
assert [ treasure-discovered? or ticks >= 1000 ]
```

## Extension Ideas

### 1. Agent Personalities

Add personality traits affecting LLM prompts:
```netlogo
treasure-hunters-own [
  ...
  personality  ; "curious", "skeptical", "impulsive"
]

; Modify prompts
llm:chat (word "As a " personality " hunter, " ...)
```

### 2. Dynamic Clues

Generate clues with LLM at setup:
```netlogo
to-report generate-clue [treasure-location]
  let clue llm:chat (word
    "Create a cryptic clue hinting at location " treasure-location
    ". Be poetic and mysterious.")
  report clue
end
```

### 3. Agent Competition

Add competitive element:
```netlogo
treasure-hunters-own [
  ...
  treasure-greed  ; Higher = less willing to share
]

; In communicate-with:
if treasure-greed < 0.5 [
  ; Share knowledge
] else [
  ; Share partial knowledge or mislead
]
```

### 4. Multi-Treasure Hunt

Multiple treasures requiring different clue combinations:
```netlogo
globals [
  treasure-type  ; "golden-orb", "ancient-scroll", "crystal-gem"
]

; Each agent knows clues for different treasures
; Must figure out which clues go together
```

### 5. Memory Limits

Add forgetting mechanism:
```netlogo
to update-learned-facts
  ; Keep only last N facts
  if length learned-facts > memory-capacity [
    set learned-facts sublist learned-facts 1 (memory-capacity + 1)
  ]
end
```

### 6. Conversation History

Track specific conversations:
```netlogo
treasure-hunters-own [
  ...
  conversation-partners  ; List of agents talked to
]

; Use in prompts
llm:chat (word "You've talked to agents " conversation-partners "...")
```

## Debugging Tips

### Enable Verbose Logging

```netlogo
; In communicate-with
print (word "=== AGENT INTERACTION at tick " ticks " ===")
print (word "Hunter " who " meets Hunter " [who] of partner)
print (word "Location: (" pxcor ", " pycor ")")
print (word "LLM Response: " conversation-result)
```

### Visualize Internal State

```netlogo
; Add monitor for specific agent
ask turtle 0 [
  print (word "Confidence: " confidence-level)
  print (word "Goal: " current-goal)
  print (word "Learned: " learned-facts)
]
```

### Test LLM Directly

```netlogo
; In NetLogo command center
llm:set-provider "ollama"
llm:set-model "llama3.2:latest"
print llm:chat "Test message"
```

## Conclusion

This implementation demonstrates:
- **Multi-agent coordination** through LLM-mediated communication
- **Emergent problem-solving** from simple interaction rules
- **Spatial reasoning** combined with natural language understanding
- **Robust error handling** with fallback mechanisms
- **Rich visualization** showing internal agent states

The key insight: **Complex collective intelligence emerges from simple per-agent rules + powerful language understanding.**

## Further Resources

- [NetLogo Dictionary](https://ccl.northwestern.edu/netlogo/docs/dictionary.html)
- [LLM Extension API](../../docs/API-REFERENCE.md)
- [Multi-Agent Systems](https://www.cs.ox.ac.uk/people/michael.wooldridge/pubs/imas/)
- [Emergent Behavior in NetLogo](http://ccl.northwestern.edu/netlogo/models/community/)
