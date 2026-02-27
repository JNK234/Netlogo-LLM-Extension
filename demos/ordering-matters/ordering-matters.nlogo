;; ABOUTME: Demonstrates that rule execution ORDER affects emergent agent behavior.
;; ABOUTME: Three groups apply identical rules (sense/move/share) in different orders.

extensions [llm]

globals [
  group-a-food          ;; cumulative food collected by Group A
  group-b-food          ;; cumulative food collected by Group B
  group-c-food          ;; cumulative food collected by Group C
  tick-data             ;; list of per-tick metric rows for CSV export
]

turtles-own [
  group                 ;; "A", "B", or "C"
  sensed-food-x         ;; x coordinate of nearest sensed food
  sensed-food-y         ;; y coordinate of nearest sensed food
  has-sensed?           ;; true if food was detected this tick
  shared-info           ;; text received via LLM communication
  food-collected        ;; individual food counter
  agent-energy          ;; energy remaining (decreases with movement)
]

patches-own [
  has-food?             ;; whether this patch currently has food
]

;; ─────────────────────────────────────────────────────────────
;; SETUP
;; ─────────────────────────────────────────────────────────────

to setup
  clear-all

  if use-llm? [
    llm:load-config "demos/ordering-matters/config"
  ]

  ;; Scatter food patches
  ask n-of food-count patches [
    set has-food? true
    set pcolor green
  ]

  ;; Divide agents evenly into three groups
  let group-size floor (num-agents / 3)

  ;; Group A: sense → move → share (red circles)
  create-turtles group-size [
    set group "A"
    set color red
    set shape "circle"
    setxy random-xcor random-ycor
    init-agent
  ]

  ;; Group B: share → sense → move (blue squares)
  create-turtles group-size [
    set group "B"
    set color blue
    set shape "square"
    setxy random-xcor random-ycor
    init-agent
  ]

  ;; Group C: move → share → sense (lime triangles)
  create-turtles group-size [
    set group "C"
    set color green + 2
    set shape "triangle"
    setxy random-xcor random-ycor
    init-agent
  ]

  set tick-data []
  reset-ticks
end

to init-agent
  set sensed-food-x 0
  set sensed-food-y 0
  set has-sensed? false
  set shared-info "none"
  set food-collected 0
  set agent-energy 100
end

;; ─────────────────────────────────────────────────────────────
;; MAIN LOOP
;; ─────────────────────────────────────────────────────────────

to go
  if not any? patches with [has-food?] and not respawn-food? [ stop ]

  ;; Each group applies the SAME three rules in a DIFFERENT order.
  ;; This is the core demonstration: ordering matters.

  ;; Group A: sense → move → share
  ask turtles with [group = "A"] [
    rule-sense
    rule-move
    rule-share
    try-collect-food
  ]

  ;; Group B: share → sense → move
  ask turtles with [group = "B"] [
    rule-share
    rule-sense
    rule-move
    try-collect-food
  ]

  ;; Group C: move → share → sense
  ask turtles with [group = "C"] [
    rule-move
    rule-share
    rule-sense
    try-collect-food
  ]

  update-metrics

  ;; Periodic food respawn
  if respawn-food? and ticks mod respawn-interval = 0 and ticks > 0 [
    let available patches with [not has-food?]
    let spawn-count min (list food-count count available)
    ask n-of spawn-count available [
      set has-food? true
      set pcolor green
    ]
  ]

  tick
end

;; ─────────────────────────────────────────────────────────────
;; THE THREE RULES (identical logic, order varies by group)
;; ─────────────────────────────────────────────────────────────

to rule-sense
  ;; Detect nearest food within sensor-range
  let nearby-food patches in-radius sensor-range with [has-food?]
  ifelse any? nearby-food [
    let target min-one-of nearby-food [distance myself]
    set sensed-food-x [pxcor] of target
    set sensed-food-y [pycor] of target
    set has-sensed? true
  ] [
    set has-sensed? false
  ]
end

to rule-move
  ;; Move toward food if sensed, use shared info if available, else wander
  ifelse has-sensed? [
    facexy sensed-food-x sensed-food-y
    fd min (list speed distance (patch sensed-food-x sensed-food-y))
  ] [
    ifelse shared-info != "none" and shared-info != "" [
      let angle extract-heading shared-info
      if angle != -1 [ set heading angle ]
      fd speed
    ] [
      rt random 90 - 45
      fd speed
    ]
  ]
  set agent-energy agent-energy - 1
end

to rule-share
  ;; Communicate food knowledge with nearby agents via LLM (or simple mode)
  if ticks mod share-interval != 0 [ stop ]

  let neighbors other turtles in-radius comm-range
  if not any? neighbors [ stop ]

  let nearest min-one-of neighbors [distance myself]

  ifelse use-llm? [
    ;; Build context message
    let my-info build-info-string
    let prompt (word "You are a foraging agent. " my-info
      " Advise a nearby agent in one short sentence. "
      "Include a compass heading (0-360) if you know where food is.")
    let response llm:chat prompt
    ask nearest [ set shared-info response ]
  ] [
    ;; Simple mode: share raw coordinates
    ifelse has-sensed? [
      ask nearest [
        set shared-info (word sensed-food-x " " sensed-food-y)
      ]
    ] [
      ask nearest [ set shared-info "none" ]
    ]
  ]
end

;; ─────────────────────────────────────────────────────────────
;; HELPERS
;; ─────────────────────────────────────────────────────────────

to try-collect-food
  if [has-food?] of patch-here [
    set food-collected food-collected + 1
    ask patch-here [
      set has-food? false
      set pcolor black
    ]
  ]
end

to-report build-info-string
  ifelse has-sensed? [
    report (word "I see food at (" sensed-food-x "," sensed-food-y
      "). I am at (" round xcor "," round ycor ").")
  ] [
    report (word "I see no food nearby. I am at ("
      round xcor "," round ycor ").")
  ]
end

to-report extract-heading [text]
  ;; Parse a numeric heading (0-360) from text
  if text = "" or text = "none" [ report -1 ]
  let result -1
  let i 0
  while [i < length text - 1] [
    let ch item i text
    if is-digit? ch [
      let num-str (word ch)
      let j i + 1
      while [j < length text and is-digit? item j text] [
        set num-str (word num-str item j text)
        set j j + 1
      ]
      let num read-from-string num-str
      if num >= 0 and num <= 360 [ set result num ]
    ]
    set i i + 1
  ]
  report result
end

to-report is-digit? [ch]
  report member? (word ch) ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9"]
end

;; ─────────────────────────────────────────────────────────────
;; METRICS & EXPORT
;; ─────────────────────────────────────────────────────────────

to update-metrics
  set group-a-food sum [food-collected] of turtles with [group = "A"]
  set group-b-food sum [food-collected] of turtles with [group = "B"]
  set group-c-food sum [food-collected] of turtles with [group = "C"]

  let row (list ticks group-a-food group-b-food group-c-food
    safe-mean "A" safe-mean "B" safe-mean "C")
  set tick-data lput row tick-data
end

to-report safe-mean [grp]
  let agents turtles with [group = grp]
  ifelse any? agents [ report mean [agent-energy] of agents ] [ report 0 ]
end

to export-data
  let filename "ordering-matters-output.csv"
  carefully [
    file-open filename
    file-print "tick,group_a_food,group_b_food,group_c_food,group_a_energy,group_b_energy,group_c_energy"
    foreach tick-data [ row ->
      file-print (word item 0 row "," item 1 row "," item 2 row ","
        item 3 row "," item 4 row "," item 5 row "," item 6 row)
    ]
    file-close
    output-print (word "Exported " length tick-data " rows to " filename)
  ] [
    output-print (word "Export failed: " error-message)
  ]
end

to infer-rules
  ;; Use LLM template to infer rule orderings from behavioral data
  if not use-llm? [
    output-print "Enable use-llm? to run rule inference."
    stop
  ]

  let a-data (word "Food: " group-a-food
    ", Energy: " precision safe-mean "A" 1
    ", Cluster: " precision cluster-spread "A" 2)
  let b-data (word "Food: " group-b-food
    ", Energy: " precision safe-mean "B" 1
    ", Cluster: " precision cluster-spread "B" 2)
  let c-data (word "Food: " group-c-food
    ", Energy: " precision safe-mean "C" 1
    ", Cluster: " precision cluster-spread "C" 2)

  let result llm:chat-with-template
    "demos/ordering-matters/rule-inference-template.yaml"
    (list
      (list "tick_count" (word ticks))
      (list "food_density" (word food-count))
      (list "group_a_data" a-data)
      (list "group_b_data" b-data)
      (list "group_c_data" c-data))

  output-print "=== Rule Ordering Inference ==="
  output-print result
end

to-report cluster-spread [grp]
  ;; Average pairwise distance between agents in a group (lower = more clustered)
  let agents turtles with [group = grp]
  if count agents < 2 [ report 0 ]
  let total-dist 0
  let pairs 0
  ask agents [
    ask other agents [
      set total-dist total-dist + distance myself
      set pairs pairs + 1
    ]
  ]
  ifelse pairs > 0 [ report total-dist / pairs ] [ report 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
380
10
818
449
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
10
45
80
78
NIL
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
90
45
155
78
go
go
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
165
45
255
78
go-forever
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
10
10
180
43
num-agents
num-agents
3
60
18.0
3
1
NIL
HORIZONTAL

SLIDER
190
10
370
43
food-count
food-count
10
200
80.0
10
1
NIL
HORIZONTAL

SLIDER
10
85
180
118
sensor-range
sensor-range
1
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
190
85
370
118
speed
speed
0.5
3
1.0
0.5
1
NIL
HORIZONTAL

SLIDER
10
125
180
158
comm-range
comm-range
1
15
6.0
1
1
NIL
HORIZONTAL

SLIDER
190
125
370
158
share-interval
share-interval
1
20
5.0
1
1
ticks
HORIZONTAL

SWITCH
10
165
130
198
use-llm?
use-llm?
1
1
-1000

SWITCH
140
165
280
198
respawn-food?
respawn-food?
0
1
-1000

SLIDER
10
205
180
238
respawn-interval
respawn-interval
5
50
20.0
5
1
ticks
HORIZONTAL

MONITOR
10
250
130
295
A food
group-a-food
0
1
11

MONITOR
140
250
260
295
B food
group-b-food
0
1
11

MONITOR
270
250
370
295
C food
group-c-food
0
1
11

BUTTON
10
305
130
338
export-data
export-data
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
140
305
260
338
infer-rules
infer-rules
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
10
345
370
520
Food Collection
tick
food
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"A: sense-move-share" 1.0 0 -2674135 true "" "plot group-a-food"
"B: share-sense-move" 1.0 0 -13345367 true "" "plot group-b-food"
"C: move-share-sense" 1.0 0 -8732573 true "" "plot group-c-food"

OUTPUT
10
530
370
670
12

@#$#@#$#@
## WHAT IS IT?

This model demonstrates that the **order** in which agents execute identical rules produces different emergent behaviors. Three groups of foraging agents each apply the same three rules — SENSE, MOVE, and SHARE — but in different sequences.

## HOW IT WORKS

Each tick, agents execute three rules:

- **SENSE**: Detect food patches within `sensor-range`
- **MOVE**: Navigate toward food (if sensed), follow shared advice, or wander
- **SHARE**: Communicate food locations with nearby agents (via LLM or simple coordinates)

The groups differ only in execution order:
- **Group A** (red): sense → move → share
- **Group B** (blue): share → sense → move
- **Group C** (green): move → share → sense

## HOW TO USE IT

1. Configure `config.txt` with your LLM provider (or disable `use-llm?`)
2. Click **setup** to initialize agents and food
3. Click **go-forever** to run the simulation
4. Compare food collection rates across groups in the plot
5. Click **export-data** to save CSV for `analysis.py`
6. Click **infer-rules** to have the LLM analyze behavior patterns

## THINGS TO NOTICE

- Group A (sense-first) typically finds food most efficiently
- Group B (share-first) tends to cluster, sharing outdated information
- Group C (move-first) wastes energy moving before sensing

## THINGS TO TRY

- Toggle `use-llm?` to compare LLM communication vs. simple coordinate sharing
- Vary `sensor-range` and `comm-range` to change the relative value of sensing vs sharing
- Increase `share-interval` to reduce communication frequency

## EXTENDING THE MODEL

- Add a fourth ordering (e.g., sense → share → move)
- Let agents evolve their ordering over time
- Add obstacles or predators to make ordering trade-offs sharper

## CREDITS AND REFERENCES

Part of the NetLogo LLM Extension demo collection.
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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
<experiment name="ordering-comparison" repetitions="10" runMetricsEveryStep="true">
<setup>setup</setup>
<go>go</go>
<timeLimit steps="200"/>
<metric>group-a-food</metric>
<metric>group-b-food</metric>
<metric>group-c-food</metric>
<metric>safe-mean "A"</metric>
<metric>safe-mean "B"</metric>
<metric>safe-mean "C"</metric>
</experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 0 150 0 0 150 300
@#$#@#$#@
1
@#$#@#$#@
