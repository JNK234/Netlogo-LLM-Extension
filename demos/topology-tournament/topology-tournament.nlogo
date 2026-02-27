; ABOUTME: Topology tournament where teams of LLM agents in different network structures race to consensus
; ABOUTME: Compares ring, star, mesh, and tree topologies on information propagation speed

extensions [llm]

globals [
  ; Team layout offsets (each team occupies a quadrant)
  team-offsets        ; list of [x y] center positions for each team
  topology-names      ; list of topology type names
  team-colors         ; colors for each team
  consensus-reached   ; list tracking which teams reached consensus
  round-winner        ; who of the winning team's first agent (or nobody)
  tournament-running? ; whether the tournament is in progress
  tick-limit          ; max ticks before declaring a draw
  round-number        ; current round counter
  team-scores         ; cumulative scores across rounds
  consensus-threshold ; fraction of agents that must agree for consensus
]

breed [nodes node]

nodes-own [
  team-id             ; which team (0-3) this node belongs to
  node-name           ; display name
  belief              ; current belief string (the agent's position)
  confidence          ; how confident the agent is (0-1)
  initial-fragment    ; the partial info this agent started with
  last-talked-tick    ; tick of last conversation
  topology-type       ; ring, star, mesh, or tree
  is-hub?             ; true if this is the hub in a star topology
]

undirected-link-breed [edges edge]

edges-own [
  team-link-id        ; which team this edge belongs to
]

;; ============================================================
;; SETUP
;; ============================================================

to setup
  clear-all

  ; Load LLM configuration
  carefully [
    llm:load-config llm-config-path
  ] [
    print (word "Config load failed: " error-message ". Using Ollama defaults.")
    llm:set-provider "ollama"
    llm:set-model "llama3.2:latest"
  ]

  ; Initialize globals
  set topology-names ["ring" "star" "mesh" "tree"]
  set team-colors [red blue green orange]
  set team-offsets [[-12 12] [12 12] [-12 -12] [12 -12]]
  set consensus-reached [false false false false]
  set round-winner nobody
  set tournament-running? false
  set tick-limit 200
  set round-number 0
  set team-scores [0 0 0 0]
  set consensus-threshold 0.8

  ; Build each team's network
  build-team 0 "ring"
  build-team 1 "star"
  build-team 2 "mesh"
  build-team 3 "tree"

  ; Assign initial knowledge fragments to all agents
  assign-fragments

  ; Label setup
  ask nodes [
    set label (word node-name)
    set label-color white
  ]

  reset-ticks
  print "=== TOPOLOGY TOURNAMENT READY ==="
  print (word "Teams: " topology-names)
  print (word "Agents per team: " agents-per-team)
  print "Click 'Run Round' to start a round."
end

;; ============================================================
;; TEAM BUILDING
;; ============================================================

to build-team [tid topo]
  let center item tid team-offsets
  let cx first center
  let cy last center
  let tcolor item tid team-colors

  ; Create nodes for this team in a circle layout
  let angle-step 360 / agents-per-team
  let radius 6

  create-nodes agents-per-team [
    set team-id tid
    set topology-type topo
    set is-hub? false
    set belief ""
    set confidence 0
    set last-talked-tick -10
    set node-name (word first topo "-" (who mod agents-per-team))

    ; Place in a circle around the team center
    let my-index (who mod agents-per-team)
    let angle my-index * angle-step
    setxy (cx + radius * sin angle) (cy + radius * cos angle)

    set color tcolor
    set shape "circle"
    set size 1.5
  ]

  ; Get this team's agents
  let team-nodes nodes with [team-id = tid]

  ; Wire edges based on topology type
  if topo = "ring" [ wire-ring team-nodes tid ]
  if topo = "star" [ wire-star team-nodes tid ]
  if topo = "mesh" [ wire-mesh team-nodes tid ]
  if topo = "tree" [ wire-tree team-nodes tid ]
end

to wire-ring [team-nodes tid]
  ; Each node connects to its two neighbors in the ring
  let sorted-nodes sort-on [who] team-nodes
  let n length sorted-nodes
  let i 0
  while [i < n] [
    let current item i sorted-nodes
    let next-node item ((i + 1) mod n) sorted-nodes
    ask current [
      create-edge-with next-node [
        set team-link-id tid
        set color item tid team-colors - 2
      ]
    ]
    set i i + 1
  ]
end

to wire-star [team-nodes tid]
  ; First node is the hub, all others connect to it
  let sorted-nodes sort-on [who] team-nodes
  let hub first sorted-nodes
  ask hub [
    set is-hub? true
    set shape "star"
    set size 2
  ]
  foreach but-first sorted-nodes [ spoke ->
    ask hub [
      create-edge-with spoke [
        set team-link-id tid
        set color item tid team-colors - 2
      ]
    ]
  ]
end

to wire-mesh [team-nodes tid]
  ; Every node connects to every other node (complete graph)
  ask team-nodes [
    let me self
    ask other team-nodes [
      if not edge-neighbor? me [
        create-edge-with me [
          set team-link-id tid
          set color item tid team-colors - 2
        ]
      ]
    ]
  ]
end

to wire-tree [team-nodes tid]
  ; Binary tree: node i connects to nodes 2i+1 and 2i+2
  let sorted-nodes sort-on [who] team-nodes
  let n length sorted-nodes

  ; Mark root
  ask first sorted-nodes [
    set is-hub? true
    set shape "triangle"
    set size 2
  ]

  let i 0
  while [i < n] [
    let parent-node item i sorted-nodes
    let left-idx (2 * i + 1)
    let right-idx (2 * i + 2)
    if left-idx < n [
      ask parent-node [
        create-edge-with item left-idx sorted-nodes [
          set team-link-id tid
          set color item tid team-colors - 2
        ]
      ]
    ]
    if right-idx < n [
      ask parent-node [
        create-edge-with item right-idx sorted-nodes [
          set team-link-id tid
          set color item tid team-colors - 2
        ]
      ]
    ]
    set i i + 1
  ]
end

;; ============================================================
;; KNOWLEDGE ASSIGNMENT
;; ============================================================

to assign-fragments
  ; Each team debates the same question but agents start with different positions
  let positions (list
    "Position A: efficiency is most important for success"
    "Position B: creativity is most important for success"
    "Position C: collaboration is most important for success"
    "Position D: persistence is most important for success"
    "Position E: adaptability is most important for success"
    "Position F: knowledge is most important for success"
    "Position G: empathy is most important for success"
    "Position H: courage is most important for success"
  )

  ; Assign each agent a different starting position
  ask nodes [
    let my-index (who mod agents-per-team)
    set initial-fragment item (my-index mod length positions) positions
    set belief initial-fragment
    set confidence 0.3 + random-float 0.2

    ; Set up LLM context with the agent's role
    llm:set-history (list
      (list "system" (word
        "You are a participant in a group discussion within a " topology-type " network. "
        "Your name is " node-name ". "
        "You start with this belief: " initial-fragment ". "
        "Through discussion with your network neighbors, try to reach a group consensus. "
        "Be open to persuasion but also advocate for your position. "
        "When you respond, state your CURRENT position clearly in one sentence."
      ))
    )
  ]
end

;; ============================================================
;; MAIN LOOP
;; ============================================================

to run-round
  ; Start a new round
  set round-number round-number + 1
  set tournament-running? true
  set consensus-reached [false false false false]
  set round-winner nobody

  ; Reset beliefs for new round
  assign-fragments

  print (word "=== ROUND " round-number " START ===")
  reset-ticks
end

to go
  if not tournament-running? [ stop ]

  ; Each tick, agents talk to a random connected neighbor
  ask nodes [
    if (ticks - last-talked-tick) >= communication-cooldown [
      let my-neighbors edge-neighbors with [team-id = [team-id] of myself]
      if any? my-neighbors [
        let partner one-of my-neighbors
        discuss-with partner
        set last-talked-tick ticks
      ]
    ]
  ]

  ; Update visuals
  update-visuals

  ; Check for consensus in each team
  check-all-consensus

  ; Check if round is over
  if round-winner != nobody or ticks >= tick-limit [
    end-round
  ]

  tick
end

;; ============================================================
;; COMMUNICATION
;; ============================================================

to discuss-with [partner]
  ; Use LLM to have a conversation between two connected agents
  let my-belief belief
  let partner-belief [belief] of partner
  let my-name node-name
  let partner-name [node-name] of partner

  ; Build the discussion prompt
  let prompt (word
    "Your neighbor " partner-name " says: \"" partner-belief "\". "
    "Your current belief is: \"" my-belief "\". "
    "Consider their perspective. In one sentence, state what you now believe "
    "is most important for success. Start with: 'I believe...'"
  )

  ; Call LLM and update belief
  carefully [
    let response llm:chat prompt
    set belief response
    ; Increase confidence when beliefs converge
    if member? "believe" response [
      set confidence min (list 1.0 (confidence + 0.05))
    ]
  ] [
    ; LLM call failed, keep current belief
    print (word "LLM error for " node-name ": " error-message)
  ]

  ; Visual feedback for communication
  ask edge-with partner [
    set color yellow
    set thickness 0.3
  ]
end

;; ============================================================
;; CONSENSUS DETECTION
;; ============================================================

to check-all-consensus
  let tid 0
  while [tid < 4] [
    if not item tid consensus-reached [
      check-team-consensus tid
    ]
    set tid tid + 1
  ]
end

to check-team-consensus [tid]
  let team-nodes nodes with [team-id = tid]
  let beliefs-list [belief] of team-nodes

  ; Use LLM to evaluate if the team has reached consensus
  ; Simple heuristic: check if a majority share similar keywords
  let agreement-count 0
  let reference-belief first beliefs-list

  ; Count how many agents hold a similar belief to the first agent
  ask team-nodes [
    if approximately-agrees? belief reference-belief [
      set agreement-count agreement-count + 1
    ]
  ]

  let agreement-ratio agreement-count / count team-nodes

  if agreement-ratio >= consensus-threshold [
    set consensus-reached replace-item tid consensus-reached true
    if round-winner = nobody [
      set round-winner one-of team-nodes
      print (word "*** TEAM " item tid topology-names " reaches consensus at tick " ticks " ***")
    ]
  ]
end

to-report approximately-agrees? [belief1 belief2]
  ; Simple agreement check: do both beliefs share a key value keyword?
  let keywords ["efficiency" "creativity" "collaboration" "persistence"
                 "adaptability" "knowledge" "empathy" "courage"]
  let shared-keywords filter [kw -> member? kw belief1 and member? kw belief2] keywords
  report length shared-keywords > 0
end

;; ============================================================
;; ROUND MANAGEMENT
;; ============================================================

to end-round
  set tournament-running? false

  ifelse round-winner != nobody [
    let winning-team [team-id] of round-winner
    let winning-topo item winning-team topology-names
    let new-scores replace-item winning-team team-scores (item winning-team team-scores + 1)
    set team-scores new-scores
    print (word "=== ROUND " round-number " WINNER: " winning-topo " (tick " ticks ") ===")
  ] [
    print (word "=== ROUND " round-number " DRAW (tick limit " tick-limit " reached) ===")
  ]

  print (word "Scores: ring=" item 0 team-scores
              " star=" item 1 team-scores
              " mesh=" item 2 team-scores
              " tree=" item 3 team-scores)
  print "Click 'Run Round' for next round."
end

;; ============================================================
;; VISUALIZATION
;; ============================================================

to update-visuals
  ; Node size reflects confidence
  ask nodes [
    set size 1 + confidence
  ]

  ; Reset edge colors after communication flash
  ask edges [
    if color = yellow [
      set color item team-link-id team-colors - 2
      set thickness 0
    ]
  ]

  ; Team labels at centers
  let tid 0
  while [tid < 4] [
    let center item tid team-offsets
    let cx first center
    let cy last center
    ask patch cx (cy + 9) [
      set plabel item tid topology-names
      set plabel-color item tid team-colors
    ]
    ; Show consensus status
    if item tid consensus-reached [
      ask patch cx (cy + 8) [
        set plabel "CONSENSUS!"
        set plabel-color yellow
      ]
    ]
    set tid tid + 1
  ]
end

;; ============================================================
;; REPORTERS
;; ============================================================

to-report team-consensus-pct [tid]
  let team-nodes nodes with [team-id = tid]
  if not any? team-nodes [ report 0 ]
  let beliefs-list [belief] of team-nodes
  let reference-belief first beliefs-list
  let agreement-count 0
  ask team-nodes [
    if approximately-agrees? belief reference-belief [
      set agreement-count agreement-count + 1
    ]
  ]
  report (agreement-count / count team-nodes) * 100
end

to-report avg-confidence [tid]
  let team-nodes nodes with [team-id = tid]
  if not any? team-nodes [ report 0 ]
  report mean [confidence] of team-nodes
end

to-report score-display
  report (word
    "Ring: " item 0 team-scores
    "  Star: " item 1 team-scores
    "  Mesh: " item 2 team-scores
    "  Tree: " item 3 team-scores
  )
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
822
623
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
Run Round
run-round
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
90
195
123
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
140
195
173
agents-per-team
agents-per-team
3
8
5.0
1
1
NIL
HORIZONTAL

SLIDER
15
180
195
213
communication-cooldown
communication-cooldown
1
10
3.0
1
1
ticks
HORIZONTAL

INPUTBOX
15
220
195
280
llm-config-path
demos/config
1
0
String

MONITOR
15
290
100
335
Round
round-number
0
1
11

MONITOR
105
290
195
335
Tick
ticks
0
1
11

MONITOR
15
345
195
390
Scores
score-display
0
1
11

PLOT
830
10
1100
180
Consensus Progress
Ticks
Agreement %
0.0
50.0
0.0
100.0
true
true
"" ""
PENS
"ring" 1.0 0 -2674135 true "" "if any? nodes with [team-id = 0] [plot team-consensus-pct 0]"
"star" 1.0 0 -13345367 true "" "if any? nodes with [team-id = 1] [plot team-consensus-pct 1]"
"mesh" 1.0 0 -10899396 true "" "if any? nodes with [team-id = 2] [plot team-consensus-pct 2]"
"tree" 1.0 0 -955883 true "" "if any? nodes with [team-id = 3] [plot team-consensus-pct 3]"

PLOT
830
190
1100
360
Average Confidence
Ticks
Confidence
0.0
50.0
0.0
1.0
true
true
"" ""
PENS
"ring" 1.0 0 -2674135 true "" "if any? nodes with [team-id = 0] [plot avg-confidence 0]"
"star" 1.0 0 -13345367 true "" "if any? nodes with [team-id = 1] [plot avg-confidence 1]"
"mesh" 1.0 0 -10899396 true "" "if any? nodes with [team-id = 2] [plot avg-confidence 2]"
"tree" 1.0 0 -955883 true "" "if any? nodes with [team-id = 3] [plot avg-confidence 3]"

@#$#@#$#@
## WHAT IS IT?

Topology Tournament pits four teams of LLM-powered agents against each other, each arranged in a different network topology: **ring**, **star**, **mesh** (complete), and **tree**. Agents discuss a question with their network neighbors and the first team to reach consensus wins the round.

## HOW IT WORKS

Each agent starts with a different belief about what matters most for success. Agents can only communicate with direct network neighbors. An LLM mediates each conversation, allowing agents to genuinely reason about and respond to each other's arguments. The tournament measures which network structure enables the fastest consensus.

### Topologies

- **Ring**: Each agent connects to exactly 2 neighbors. Information must travel around the ring.
- **Star**: One central hub connects to all others. Hub becomes a bottleneck or accelerator.
- **Mesh**: Every agent connects to every other. Maximum connectivity, most communication overhead.
- **Tree**: Binary tree structure. Information flows up and down through parent-child relationships.

## HOW TO USE IT

1. Configure your LLM provider in the `llm-config-path` field
2. Click **Setup** to build the four team networks
3. Click **Run Round** to start a consensus round
4. Click **Go** to run the simulation
5. Watch the Consensus Progress plot to see which team converges first
6. Run multiple rounds to see cumulative scores

## THINGS TO NOTICE

- Star topology often converges fast because the hub acts as a central coordinator
- Mesh has the most connections but can be slow due to information overload
- Ring must propagate beliefs sequentially around the circle
- Tree balances between star's centralization and ring's distribution

## THINGS TO TRY

- Vary `agents-per-team` to see how team size affects each topology
- Change `communication-cooldown` to simulate fast vs. slow communication
- Run many rounds to see statistically significant topology advantages

## EXTENDING THE MODEL

- Add more topology types (small-world, scale-free)
- Implement different debate topics per round
- Add agent personality traits that affect persuadability
- Track which specific arguments win out across topologies

## CREDITS AND REFERENCES

Built with the NetLogo LLM Extension. Demonstrates network science concepts from:
- Watts & Strogatz (1998) - Small-world networks
- Barabási & Albert (1999) - Scale-free networks
- DeGroot (1974) - Consensus in social networks
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

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
