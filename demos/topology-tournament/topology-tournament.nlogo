extensions [llm]

breed [mesh-agents mesh-agent]
breed [hierarchy-agents hierarchy-agent]
breed [chain-agents chain-agent]
undirected-link-breed [topology-links topology-link]

globals [
  llm-ready?
  tournament-running?
  topology-order
  convergence-times
  winner-topology
  belief-options
]

turtles-own [
  belief
  topology-name
  last-coordinator-action
]

to setup
  clear-all

  set llm-ready? false
  set tournament-running? true
  set topology-order ["mesh" "hierarchy" "chain"]
  set convergence-times (list -1 -1 -1)
  set winner-topology "pending"
  set belief-options ["COLLECT" "EXPLORE" "STABILIZE"]

  load-llm-config
  build-topologies
  seed-beliefs

  reset-ticks
end

to load-llm-config
  carefully [
    llm:load-config llm-config-path
    set llm-ready? true
  ] [
    print (word "LLM config load failed: " error-message)
    print "Falling back to deterministic coordinator policy."
    set llm-ready? false
  ]
end

to build-topologies
  build-mesh-topology
  build-hierarchy-topology
  build-chain-topology

  ask topology-links [
    set color gray - 2
    set thickness 0.1
  ]
end

to build-mesh-topology
  create-mesh-agents agents-per-topology [
    set topology-name "mesh"
    set shape "circle"
    set color blue + 1
    set size 1.3
    set last-coordinator-action "INIT"
  ]

  layout-circle mesh-agents 6
  ask mesh-agents [
    set xcor xcor - 16
    set ycor ycor + 8
  ]

  let ordered sort mesh-agents
  let i 0
  while [i < length ordered] [
    let source item i ordered
    let j (i + 1)
    while [j < length ordered] [
      let target item j ordered
      ask source [ create-topology-link-with target ]
      set j j + 1
    ]
    set i i + 1
  ]
end

to build-hierarchy-topology
  create-hierarchy-agents agents-per-topology [
    set topology-name "hierarchy"
    set shape "triangle"
    set color green + 1
    set size 1.4
    set last-coordinator-action "INIT"
  ]

  let ordered sort hierarchy-agents
  let i 0
  while [i < length ordered] [
    let level floor (ln (i + 1) / ln 2)
    let first-at-level ((2 ^ level) - 1)
    let level-position (i - first-at-level)
    let level-width (2 ^ level)
    let x-offset (level-position - ((level-width - 1) / 2)) * 3
    let y-offset 14 - (level * 4)

    ask item i ordered [
      setxy x-offset y-offset
    ]

    if i > 0 [
      let parent-index floor ((i - 1) / 2)
      let parent-node item parent-index ordered
      ask item i ordered [ create-topology-link-with parent-node ]
    ]

    set i i + 1
  ]
end

to build-chain-topology
  create-chain-agents agents-per-topology [
    set topology-name "chain"
    set shape "square"
    set color orange + 1
    set size 1.3
    set last-coordinator-action "INIT"
  ]

  let ordered sort chain-agents
  let spacing 2.8
  let start-x (16 - ((agents-per-topology - 1) * spacing / 2))

  let i 0
  while [i < length ordered] [
    ask item i ordered [
      setxy (start-x + (i * spacing)) -12
    ]

    if i > 0 [
      let prev-node item (i - 1) ordered
      ask item i ordered [ create-topology-link-with prev-node ]
    ]

    set i i + 1
  ]
end

to seed-beliefs
  assign-beliefs mesh-agents 0
  assign-beliefs hierarchy-agents 1
  assign-beliefs chain-agents 2

  ask turtles [
    set label (word topology-name ":" belief)
    set label-color white
  ]
end

to assign-beliefs [group shift]
  let ordered sort group
  let i 0
  while [i < length ordered] [
    let slot ((i + shift) mod length belief-options)
    ask item i ordered [
      set belief item slot belief-options
    ]
    set i i + 1
  ]
end

to go
  if not tournament-running? [ stop ]

  coordinate-topology "mesh" mesh-agents
  coordinate-topology "hierarchy" hierarchy-agents
  coordinate-topology "chain" chain-agents

  update-tournament-state
  tick
end

to coordinate-topology [name group]
  let idx topology-index name
  if item idx convergence-times != -1 [ stop ]

  if converged? group [
    set convergence-times replace-item idx convergence-times ticks
    stop
  ]

  let majority majority-belief group
  let action "MAJORITY_PUSH"

  if llm-ready? [
    carefully [
      let response llm:chat-with-template "demos/topology-tournament/coordinator-template.yaml" (list
        (list "topology" name)
        (list "tick" ticks)
        (list "agent_count" count group)
        (list "belief_summary" belief-summary group)
        (list "majority_belief" majority)
      )
      set action parse-action response
    ] [
      set action "MAJORITY_PUSH"
    ]
  ]

  apply-coordinator-action action group majority

  ask group [
    set last-coordinator-action action
    set label (word topology-name ":" belief)
  ]

  if converged? group [
    set convergence-times replace-item idx convergence-times ticks
  ]
end

to apply-coordinator-action [action group majority]
  if action = "HOLD" [ stop ]

  if action = "PAIR_SWAP" [
    if count group > 1 [
      let selected-pair n-of 2 group
      let selected-belief [belief] of one-of selected-pair
      ask selected-pair [ set belief selected-belief ]
    ]
    stop
  ]

  if action = "SPLIT_REBALANCE" [
    let alternate next-belief majority
    let ordered sort group
    let halfway floor (length ordered / 2)
    let i 0
    while [i < length ordered] [
      let node item i ordered
      ifelse i < halfway
      [ ask node [ set belief majority ] ]
      [ ask node [ set belief alternate ] ]
      set i i + 1
    ]
    stop
  ]

  if action = "BROADCAST_MAJORITY" [
    ask group [ set belief majority ]
    stop
  ]

  let dissenters group with [belief != majority]
  if any? dissenters [
    ask one-of dissenters [ set belief majority ]
  ]
end

to-report parse-action [response]
  if not is-string? response [ report "MAJORITY_PUSH" ]

  let normalized uppercase response

  if position "ACTION:BROADCAST_MAJORITY" normalized != false [ report "BROADCAST_MAJORITY" ]
  if position "ACTION:MAJORITY_PUSH" normalized != false [ report "MAJORITY_PUSH" ]
  if position "ACTION:PAIR_SWAP" normalized != false [ report "PAIR_SWAP" ]
  if position "ACTION:SPLIT_REBALANCE" normalized != false [ report "SPLIT_REBALANCE" ]
  if position "ACTION:HOLD" normalized != false [ report "HOLD" ]

  report "MAJORITY_PUSH"
end

to-report converged? [group]
  if not any? group [ report false ]
  report (length remove-duplicates [belief] of group) = 1
end

to-report majority-belief [group]
  let best-belief first belief-options
  let best-count -1

  foreach belief-options [candidate ->
    let candidate-count count group with [belief = candidate]
    if candidate-count > best-count [
      set best-belief candidate
      set best-count candidate-count
    ]
  ]

  report best-belief
end

to-report belief-summary [group]
  let chunks []
  foreach belief-options [candidate ->
    set chunks lput (word candidate ":" count group with [belief = candidate]) chunks
  ]
  report reduce [[left right] -> word left ", " right] chunks
end

to-report next-belief [current]
  let idx position current belief-options
  if idx = false [ report first belief-options ]
  report item ((idx + 1) mod length belief-options) belief-options
end

to update-tournament-state
  if all? convergence-times [value -> value >= 0] [
    set tournament-running? false
    set winner-topology fastest-topology
    stop
  ]

  if ticks >= max-ticks [
    set tournament-running? false
    set winner-topology fastest-topology
  ]
end

to-report fastest-topology
  let best-name "none"
  let best-time (max-ticks + 1)
  let i 0

  while [i < length topology-order] [
    let result item i convergence-times
    if result != -1 and result < best-time [
      set best-time result
      set best-name item i topology-order
    ]
    set i i + 1
  ]

  report best-name
end

to-report topology-index [name]
  if name = "mesh" [ report 0 ]
  if name = "hierarchy" [ report 1 ]
  report 2
end

to-report agreement-pct [group]
  if not any? group [ report 0 ]
  let majority majority-belief group
  report 100 * (count group with [belief = majority]) / count group
end

to-report convergence-time [name]
  report item (topology-index name) convergence-times
end

to-report status-summary
  report (word
    "mesh=" convergence-time "mesh"
    " hierarchy=" convergence-time "hierarchy"
    " chain=" convergence-time "chain"
    " winner=" winner-topology
  )
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
820
620
-1
-1
12.0
1
10
1
1
1
0
0
0
1
-25
25
-25
25
0
0
1
ticks
30.0

BUTTON
15
10
195
43
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
15
50
195
83
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
110
195
143
agents-per-topology
agents-per-topology
3
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
15
150
195
183
max-ticks
max-ticks
20
400
150.0
1
1
NIL
HORIZONTAL

INPUTBOX
15
195
195
255
llm-config-path
demos/topology-tournament/config.txt
1
0
String

MONITOR
15
270
195
315
Winner
winner-topology
17
1
11

MONITOR
15
320
195
365
Status
status-summary
17
1
11

MONITOR
15
370
195
403
Mesh Convergence
convergence-time "mesh"
0
1
11

MONITOR
15
407
195
440
Hierarchy Convergence
convergence-time "hierarchy"
0
1
11

MONITOR
15
444
195
477
Chain Convergence
convergence-time "chain"
0
1
11

PLOT
830
10
1110
200
Agreement by Topology
Ticks
Agreement %
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"mesh" 1.0 0 -13345367 true "" "plot agreement-pct mesh-agents"
"hierarchy" 1.0 0 -10899396 true "" "plot agreement-pct hierarchy-agents"
"chain" 1.0 0 -955883 true "" "plot agreement-pct chain-agents"

@#$#@#$#@
## WHAT IS IT?

This demo compares three communication topologies for collective coordination:
mesh, hierarchy, and chain.

Each topology has its own breed of agents. Every tick, each topology calls one
LLM coordinator via `llm:chat-with-template` to decide a collective action.
Convergence time is measured as the first tick where all agents in a topology
hold the same belief token.

## HOW TO USE IT

1. Set `llm-config-path` to a valid config file.
2. Click `Setup`.
3. Click `Go`.
4. Watch convergence monitors and the agreement plot.

## OUTPUT

- `convergence-time "mesh"`
- `convergence-time "hierarchy"`
- `convergence-time "chain"`
- `winner-topology`

@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300

square
false
0
Rectangle -7500403 true true 30 30 270 270

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

@#$#@#$#@
NetLogo 7.0.0-beta2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
