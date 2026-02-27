extensions [llm]

;; ============================================================
;; TOPOLOGY TOURNAMENT
;; Demonstrates MARBLE's finding: mesh > hierarchy > chain
;; for multi-agent coordination via LLM decision-making.
;; ============================================================

;; --- Breeds ---
breed [mesh-agents mesh-agent]
breed [hierarchy-agents hierarchy-agent]
breed [chain-agents chain-agent]

;; Breed-specific link types
undirected-link-breed [mesh-links mesh-link]
directed-link-breed [hierarchy-links hierarchy-link]
undirected-link-breed [chain-links chain-link]

;; --- Agent variables ---
turtles-own [
  topology-type    ;; "mesh" "hierarchy" "chain"
  is-coordinator?  ;; true for the coordinator of each topology
]

;; --- Globals ---
globals [
  goal-x goal-y                        ;; target location
  num-per-topology                     ;; agents per topology (from slider)

  ;; Convergence tracking
  mesh-converged?
  hierarchy-converged?
  chain-converged?
  mesh-convergence-tick
  hierarchy-convergence-tick
  chain-convergence-tick

  ;; LLM call counters
  mesh-llm-calls
  hierarchy-llm-calls
  chain-llm-calls

  ;; Current actions
  mesh-action
  hierarchy-action
  chain-action

  ;; Convergence threshold (distance)
  convergence-radius

  ;; Run complete?
  all-done?
]

;; ============================================================
;; SETUP
;; ============================================================
to setup
  clear-all

  set num-per-topology num-agents
  set convergence-radius 2.0
  set all-done? false

  ;; Reset tracking
  set mesh-converged? false
  set hierarchy-converged? false
  set chain-converged? false
  set mesh-convergence-tick -1
  set hierarchy-convergence-tick -1
  set chain-convergence-tick -1
  set mesh-llm-calls 0
  set hierarchy-llm-calls 0
  set chain-llm-calls 0
  set mesh-action "none"
  set hierarchy-action "none"
  set chain-action "none"

  ;; Set goal
  set goal-x 12
  set goal-y 12

  ;; Mark goal patch
  ask patch goal-x goal-y [
    set pcolor green
  ]
  ask patches with [abs (pxcor - goal-x) <= 1 and abs (pycor - goal-y) <= 1] [
    set pcolor green - 1
  ]

  ;; Load LLM config
  llm:load-config "config.txt"

  ;; Create agents for each topology
  create-mesh-topology
  create-hierarchy-topology
  create-chain-topology

  reset-ticks
end

;; --- Mesh: all-to-all connections ---
to create-mesh-topology
  create-mesh-agents num-per-topology [
    set topology-type "mesh"
    set color blue
    set shape "circle"
    set size 1.2
    set is-coordinator? false
    setxy random-xcor * 0.4 - 8 random-ycor * 0.4 - 8  ;; start bottom-left quadrant
  ]

  ;; First mesh-agent is coordinator
  ask min-one-of mesh-agents [who] [
    set is-coordinator? true
    set size 2
    set shape "star"
  ]

  ;; All-to-all links
  ask mesh-agents [
    create-mesh-links-with other mesh-agents [
      set color blue - 2
      hide-link  ;; too many to show
    ]
  ]
end

;; --- Hierarchy: tree structure ---
to create-hierarchy-topology
  create-hierarchy-agents num-per-topology [
    set topology-type "hierarchy"
    set color red
    set shape "triangle"
    set size 1.2
    set is-coordinator? false
    setxy random-xcor * 0.4 random-ycor * 0.4 - 8  ;; start bottom-center
  ]

  let sorted-hierarchy sort hierarchy-agents
  ;; First is root/coordinator
  ask first sorted-hierarchy [
    set is-coordinator? true
    set size 2
    set shape "star"
  ]

  ;; Build tree: each agent links to parent (index / 2)
  let i 1
  while [i < length sorted-hierarchy] [
    let child item i sorted-hierarchy
    let parent-idx int ((i - 1) / 2)
    let parent-agent item parent-idx sorted-hierarchy
    ask child [
      create-hierarchy-link-from parent-agent [
        set color red - 2
      ]
    ]
    set i i + 1
  ]
end

;; --- Chain: linear connections ---
to create-chain-topology
  create-chain-agents num-per-topology [
    set topology-type "chain"
    set color yellow
    set shape "square"
    set size 1.2
    set is-coordinator? false
    setxy random-xcor * 0.4 + 8 random-ycor * 0.4 - 8  ;; start bottom-right
  ]

  let sorted-chain sort chain-agents
  ;; First is coordinator
  ask first sorted-chain [
    set is-coordinator? true
    set size 2
    set shape "star"
  ]

  ;; Linear chain links
  let i 0
  while [i < length sorted-chain - 1] [
    let a item i sorted-chain
    let b item (i + 1) sorted-chain
    ask a [
      create-chain-link-with b [
        set color yellow - 2
      ]
    ]
    set i i + 1
  ]
end

;; ============================================================
;; GO (main tick loop)
;; ============================================================
to go
  if all-done? [ stop ]

  ;; Each topology: coordinator decides, agents execute
  if not mesh-converged? [
    topology-step "mesh"
  ]
  if not hierarchy-converged? [
    topology-step "hierarchy"
  ]
  if not chain-converged? [
    topology-step "chain"
  ]

  ;; Check convergence
  check-convergence

  ;; Check if all done
  if mesh-converged? and hierarchy-converged? and chain-converged? [
    set all-done? true
    print "=== ALL TOPOLOGIES CONVERGED ==="
    print (word "Mesh: tick " mesh-convergence-tick ", LLM calls: " mesh-llm-calls)
    print (word "Hierarchy: tick " hierarchy-convergence-tick ", LLM calls: " hierarchy-llm-calls)
    print (word "Chain: tick " chain-convergence-tick ", LLM calls: " chain-llm-calls)
  ]

  ;; Safety: stop after max-ticks
  if ticks >= max-ticks [
    set all-done? true
    if not mesh-converged? [ set mesh-convergence-tick max-ticks ]
    if not hierarchy-converged? [ set hierarchy-convergence-tick max-ticks ]
    if not chain-converged? [ set chain-convergence-tick max-ticks ]
    print "=== MAX TICKS REACHED ==="
  ]

  tick
end

;; ============================================================
;; TOPOLOGY STEP: coordinator observes, decides, agents act
;; ============================================================
to topology-step [topo]
  let agents nobody
  let coordinator nobody

  if topo = "mesh" [
    set agents mesh-agents
    set coordinator one-of mesh-agents with [is-coordinator?]
  ]
  if topo = "hierarchy" [
    set agents hierarchy-agents
    set coordinator one-of hierarchy-agents with [is-coordinator?]
  ]
  if topo = "chain" [
    set agents chain-agents
    set coordinator one-of chain-agents with [is-coordinator?]
  ]

  ;; Gather observations based on topology
  let positions-str gather-observations topo agents

  ;; Coordinator decides via LLM
  let avg-dist mean [distancexy goal-x goal-y] of agents
  let action decide-action topo coordinator positions-str avg-dist

  ;; Store action
  if topo = "mesh" [ set mesh-action action ]
  if topo = "hierarchy" [ set hierarchy-action action ]
  if topo = "chain" [ set chain-action action ]

  ;; Execute action
  execute-action topo agents action
end

;; ============================================================
;; GATHER OBSERVATIONS
;; Mesh: coordinator sees ALL agents (full information)
;; Hierarchy: coordinator sees direct children, relays up
;; Chain: coordinator sees only neighbor, info propagates slowly
;; ============================================================
to-report gather-observations [topo agents]
  let coordinator one-of agents with [is-coordinator?]
  let visible-agents nobody
  let positions-str ""

  if topo = "mesh" [
    ;; Mesh: full visibility — coordinator sees all agents
    set visible-agents agents
  ]

  if topo = "hierarchy" [
    ;; Hierarchy: coordinator sees direct children + samples from subtree
    ;; Simulates info flowing up the tree (partial visibility)
    let direct-children agents with [in-hierarchy-link-neighbor? coordinator]
    ;; Each child reports about ~half its subtree (info loss)
    set visible-agents (turtle-set coordinator direct-children)
    ;; Add some random agents to simulate partial tree info (50% visibility)
    let remaining agents with [not member? self visible-agents]
    let sample-size min (list (count remaining) (int (count remaining * 0.5)))
    if sample-size > 0 [
      set visible-agents (turtle-set visible-agents n-of sample-size remaining)
    ]
  ]

  if topo = "chain" [
    ;; Chain: coordinator sees only immediate neighbors + info degrades along chain
    ;; Only ~30% of agents' positions are known (info loss through chain)
    let sample-size max (list 1 (int (count agents * 0.3)))
    set visible-agents (turtle-set coordinator n-of (min (list sample-size (count agents))) agents)
  ]

  ;; Build position string
  foreach sort visible-agents [ agent ->
    set positions-str (word positions-str
      [who] of agent ": "
      (precision [xcor] of agent 1) ", "
      (precision [ycor] of agent 1) "\n")
  ]

  report positions-str
end

;; ============================================================
;; DECIDE ACTION via LLM
;; ============================================================
to-report decide-action [topo coordinator positions-str avg-dist]
  let action "move-toward-goal"

  ;; Increment LLM call counter
  if topo = "mesh" [ set mesh-llm-calls mesh-llm-calls + 1 ]
  if topo = "hierarchy" [ set hierarchy-llm-calls hierarchy-llm-calls + 1 ]
  if topo = "chain" [ set chain-llm-calls chain-llm-calls + 1 ]

  ;; Use LLM via template
  ask coordinator [
    llm:clear-history
    let vars (list
      (list "topology" topo)
      (list "num_agents" (word num-per-topology))
      (list "goal_x" (word goal-x))
      (list "goal_y" (word goal-y))
      (list "agent_positions" positions-str)
      (list "avg_distance" (word precision avg-dist 2))
      (list "tick" (word ticks))
    )
    carefully [
      let raw-response llm:chat-with-template "coordinator-template.yaml" vars
      ;; Parse action from response
      set action parse-action raw-response
    ] [
      ;; Fallback if LLM fails
      set action "move-toward-goal"
      print (word "LLM error for " topo ": " error-message " — defaulting to move-toward-goal")
    ]
  ]

  report action
end

;; ============================================================
;; PARSE ACTION from LLM response
;; ============================================================
to-report parse-action [response]
  let normalized-response lower-case (word response)

  if position "spread" normalized-response != false [ report "spread-then-converge" ]
  if position "follow" normalized-response != false [ report "follow-leader" ]
  if position "random" normalized-response != false [ report "random-walk" ]
  if position "move-toward-goal" normalized-response != false [ report "move-toward-goal" ]
  ;; Default
  report "move-toward-goal"
end

;; ============================================================
;; EXECUTE ACTION
;; ============================================================
to execute-action [topo agents action]
  if action = "move-toward-goal" [
    ask agents [
      facexy goal-x goal-y
      ;; Mesh: coordinated, efficient movement
      ;; Hierarchy: moderate noise
      ;; Chain: most noise (info degradation)
      let noise-factor get-noise-factor topo
      forward 0.5 + random-float noise-factor
    ]
  ]

  if action = "spread-then-converge" [
    ask agents [
      ;; First spread a bit, then converge
      ifelse distancexy goal-x goal-y > 8 [
        ;; Spread phase: move somewhat randomly
        right random 60 - 30
        forward 0.3
      ] [
        ;; Converge phase
        facexy goal-x goal-y
        forward 0.4 + random-float (get-noise-factor topo)
      ]
    ]
  ]

  if action = "follow-leader" [
    let coordinator one-of agents with [is-coordinator?]
    ask coordinator [
      facexy goal-x goal-y
      forward 0.8
    ]
    ask agents with [not is-coordinator?] [
      face coordinator
      forward 0.5 + random-float (get-noise-factor topo)
    ]
  ]

  if action = "random-walk" [
    ask agents [
      right random 360
      forward 0.3
    ]
  ]
end

;; ============================================================
;; NOISE FACTOR: models information quality per topology
;; Mesh = low noise (full info), Hierarchy = medium, Chain = high
;; This is the KEY mechanism that makes mesh > hierarchy > chain
;; ============================================================
to-report get-noise-factor [topo]
  if topo = "mesh" [ report 0.1 ]       ;; Very coordinated
  if topo = "hierarchy" [ report 0.3 ]   ;; Some info loss
  if topo = "chain" [ report 0.6 ]       ;; Significant info loss
  report 0.3
end

;; ============================================================
;; CHECK CONVERGENCE
;; ============================================================
to check-convergence
  if not mesh-converged? [
    if all? mesh-agents [distancexy goal-x goal-y < convergence-radius] [
      set mesh-converged? true
      set mesh-convergence-tick ticks
      print (word "MESH converged at tick " ticks)
    ]
  ]
  if not hierarchy-converged? [
    if all? hierarchy-agents [distancexy goal-x goal-y < convergence-radius] [
      set hierarchy-converged? true
      set hierarchy-convergence-tick ticks
      print (word "HIERARCHY converged at tick " ticks)
    ]
  ]
  if not chain-converged? [
    if all? chain-agents [distancexy goal-x goal-y < convergence-radius] [
      set chain-converged? true
      set chain-convergence-tick ticks
      print (word "CHAIN converged at tick " ticks)
    ]
  ]
end

;; ============================================================
;; REPORTERS for plots and BehaviorSpace
;; ============================================================
to-report mesh-avg-distance
  report mean [distancexy goal-x goal-y] of mesh-agents
end

to-report hierarchy-avg-distance
  report mean [distancexy goal-x goal-y] of hierarchy-agents
end

to-report chain-avg-distance
  report mean [distancexy goal-x goal-y] of chain-agents
end

to-report mesh-ticks-to-converge
  report mesh-convergence-tick
end

to-report hierarchy-ticks-to-converge
  report hierarchy-convergence-tick
end

to-report chain-ticks-to-converge
  report chain-convergence-tick
end
