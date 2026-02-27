;; ABOUTME: Tests whether LLM rule learning depends on trajectory ordering.
;; ABOUTME: The same agent trajectories are presented as forward, reversed, and shuffled.

extensions [llm]

globals [
  ;; UI-linked metrics (kept names to match existing widgets)
  group-a-food                 ;; forward ordering confidence (% if parsed)
  group-b-food                 ;; reversed ordering confidence (% if parsed)
  group-c-food                 ;; shuffled ordering confidence (% if parsed)

  food-collected-total         ;; total food collected by all agents
  run-label                    ;; short id for export files

  trajectory-log               ;; list of [tick who x y heading energy food-total]
  trajectory-forward           ;; trajectory text in chronological order
  trajectory-reversed          ;; trajectory text reversed in time
  trajectory-shuffled          ;; trajectory text randomly shuffled

  inferred-forward             ;; LLM inference text from forward trajectory order
  inferred-reversed            ;; LLM inference text from reversed trajectory order
  inferred-shuffled            ;; LLM inference text from shuffled trajectory order

  sample-size                  ;; max number of trajectory rows sent to prompt
]

turtles-own [
  agent-energy
  food-collected
]

patches-own [
  has-food?
]

;; -----------------------------------------------------------------------------
;; Setup / Simulation
;; -----------------------------------------------------------------------------

to setup
  clear-all

  set run-label (word "run-" (100000 + random 900000))
  set sample-size 240

  set group-a-food 0
  set group-b-food 0
  set group-c-food 0
  set food-collected-total 0

  set trajectory-log []
  set trajectory-forward ""
  set trajectory-reversed ""
  set trajectory-shuffled ""
  set inferred-forward ""
  set inferred-reversed ""
  set inferred-shuffled ""

  ask patches [
    set has-food? false
    set pcolor black
  ]

  seed-food

  create-turtles num-agents [
    set shape "circle"
    set color orange + 2
    set size 1.1
    setxy random-xcor random-ycor
    set heading random 360
    set agent-energy 100
    set food-collected 0
  ]

  if use-llm? [
    load-llm-config
  ]

  reset-ticks
end

to go
  ask turtles [
    hidden-behavior
    try-collect-food
  ]

  set food-collected-total sum [food-collected] of turtles

  if respawn-food? and ticks > 0 and ticks mod respawn-interval = 0 [
    respawn-food
  ]

  record-trajectories
  tick
end

to hidden-behavior
  ;; Hidden policy that we want the LLM to infer from observed motion:
  ;; 1) seek nearby food, 2) avoid crowding, 3) keep momentum with mild noise.

  let nearby-food patches in-radius sensor-range with [has-food?]
  if any? nearby-food [
    face min-one-of nearby-food [distance myself]
  ]

  let crowd other turtles in-radius max (list 1 (comm-range / 2))
  if any? crowd [
    rt 25 + random 20
  ]

  rt (random-float 16) - 8
  fd speed

  set agent-energy max (list 0 (agent-energy - (0.5 + speed * 0.4)))

  if agent-energy <= 0 [
    setxy random-xcor random-ycor
    set heading random 360
    set agent-energy 45
  ]
end

to try-collect-food
  if [has-food?] of patch-here [
    set food-collected food-collected + 1
    ask patch-here [
      set has-food? false
      set pcolor black
    ]
  ]
end

to seed-food
  ask n-of food-count patches [
    set has-food? true
    set pcolor green + 1
  ]
end

to respawn-food
  let candidates patches with [not has-food?]
  if any? candidates [
    ask n-of min (list food-count count candidates) candidates [
      set has-food? true
      set pcolor green + 1
    ]
  ]
end

to record-trajectories
  foreach sort turtles [ t ->
    ask t [
      set trajectory-log lput
        (list ticks who precision xcor 3 precision ycor 3 precision heading 2 precision agent-energy 2 food-collected)
        trajectory-log
    ]
  ]
end

;; -----------------------------------------------------------------------------
;; Ordering Construction + Inference
;; -----------------------------------------------------------------------------

to infer-rules
  if ticks = 0 [
    output-print "Run the simulation first (click go-forever for ~100 ticks)."
    stop
  ]

  build-trajectory-orderings

  if not use-llm? [
    set inferred-forward "LLM disabled. Hidden rule: seek food, avoid crowding, preserve momentum."
    set inferred-reversed inferred-forward
    set inferred-shuffled inferred-forward
    set group-a-food 0
    set group-b-food 0
    set group-c-food 0
    output-print "LLM disabled. Generated deterministic baseline text instead."
    stop
  ]

  let template-path resolve-template-path

  set inferred-forward run-inference "forward" trajectory-forward template-path
  set inferred-reversed run-inference "reversed" trajectory-reversed template-path
  set inferred-shuffled run-inference "shuffled" trajectory-shuffled template-path

  set group-a-food extract-confidence inferred-forward
  set group-b-food extract-confidence inferred-reversed
  set group-c-food extract-confidence inferred-shuffled

  output-print "=== Rule Inference By Ordering ==="
  output-print (word "FORWARD  : " inferred-forward)
  output-print (word "REVERSED : " inferred-reversed)
  output-print (word "SHUFFLED : " inferred-shuffled)
end

to build-trajectory-orderings
  if empty? trajectory-log [
    set trajectory-forward ""
    set trajectory-reversed ""
    set trajectory-shuffled ""
    stop
  ]

  let forward sort-by
    [[r1 r2] ->
      ifelse-value (item 0 r1 = item 0 r2)
        [item 1 r1 < item 1 r2]
        [item 0 r1 < item 0 r2]
    ]
    trajectory-log

  let reversed reverse forward

  random-seed 1776
  let shuffled shuffle forward

  set trajectory-forward format-trajectory forward
  set trajectory-reversed format-trajectory reversed
  set trajectory-shuffled format-trajectory shuffled
end

to-report format-trajectory [rows]
  let cap min (list sample-size length rows)
  let clipped sublist rows 0 cap

  let lines map [row ->
    (word
      "tick=" item 0 row
      " id=" item 1 row
      " x=" item 2 row
      " y=" item 3 row
      " heading=" item 4 row
      " energy=" item 5 row
      " food=" item 6 row)
  ] clipped

  report join-lines lines
end

to-report join-lines [lines]
  if empty? lines [ report "" ]
  let out item 0 lines
  foreach but-first lines [line ->
    set out (word out "\n" line)
  ]
  report out
end

to-report run-inference [ordering-label trajectory-text template-path]
  let params (list
    (list "ordering_label" ordering-label)
    (list "tick_count" (word ticks))
    (list "agent_count" (word count turtles))
    (list "food_count" (word food-count))
    (list "trajectory_text" trajectory-text)
  )

  let response ""
  carefully [
    set response llm:chat-with-template template-path params
  ] [
    set response (word "Inference failed: " error-message)
  ]
  report response
end

;; -----------------------------------------------------------------------------
;; Export + Utility
;; -----------------------------------------------------------------------------

to export-data
  build-trajectory-orderings
  export-trajectory-csv
  export-inference-csv
end

to export-trajectory-csv
  let filename (word "results/" run-label "-trajectories.csv")

  carefully [
    file-open filename
    file-print "ordering,tick,agent_id,x,y,heading,energy,food_collected"

    write-ordering-rows "forward" trajectory-forward
    write-ordering-rows "reversed" trajectory-reversed
    write-ordering-rows "shuffled" trajectory-shuffled

    file-close
    output-print (word "Exported trajectories to " filename)
  ] [
    output-print (word "Trajectory export failed: " error-message)
    carefully [ file-close ] [ ]
  ]
end

to write-ordering-rows [ordering text-block]
  if text-block = "" [ stop ]
  let lines split-lines text-block
  foreach lines [line ->
    let tick-value parse-number-after "tick=" line
    let id-value parse-number-after "id=" line
    let x-value parse-number-after "x=" line
    let y-value parse-number-after "y=" line
    let h-value parse-number-after "heading=" line
    let e-value parse-number-after "energy=" line
    let f-value parse-number-after "food=" line
    file-print (word ordering "," tick-value "," id-value "," x-value "," y-value "," h-value "," e-value "," f-value)
  ]
end

to export-inference-csv
  let filename (word "results/" run-label "-inference.csv")

  carefully [
    file-open filename
    file-print "ordering,inferred_rule,confidence"
    file-print (word "forward,\"" sanitize-csv inferred-forward "\"," group-a-food)
    file-print (word "reversed,\"" sanitize-csv inferred-reversed "\"," group-b-food)
    file-print (word "shuffled,\"" sanitize-csv inferred-shuffled "\"," group-c-food)
    file-close
    output-print (word "Exported inferences to " filename)
  ] [
    output-print (word "Inference export failed: " error-message)
    carefully [ file-close ] [ ]
  ]
end

to load-llm-config
  ifelse file-exists? "config.txt" [
    llm:load-config "config.txt"
  ] [
    llm:load-config "demos/ordering-matters/config.txt"
  ]
end

to-report resolve-template-path
  ifelse file-exists? "rule-inference-template.yaml" [
    report "rule-inference-template.yaml"
  ] [
    report "demos/ordering-matters/rule-inference-template.yaml"
  ]
end

to-report extract-confidence [text]
  ;; Attempts to parse a confidence value from model output.
  ;; Accepts either 0-1 values or percentages.
  let nums extract-all-numbers text
  if empty? nums [ report 0 ]

  let best 0
  foreach nums [n ->
    if n > 0 and n <= 1 [ set best max (list best (n * 100)) ]
    if n > 1 and n <= 100 [ set best max (list best n) ]
  ]
  report precision best 2
end

to-report sanitize-csv [text]
  report replace-all text "\"" "''"
end

to-report split-lines [text]
  if text = "" [ report [] ]

  let lines []
  let start 0
  let i 0
  while [i < length text] [
    if substring text i (i + 1) = "\n" [
      set lines lput (substring text start i) lines
      set start i + 1
    ]
    set i i + 1
  ]

  if start <= length text [
    set lines lput (substring text start length text) lines
  ]

  report filter [line -> line != ""] lines
end

to-report parse-number-after [token line]
  let p position token line
  if p = false [ report 0 ]

  let start p + length token
  let finish start

  while [finish < length line and not member? (substring line finish (finish + 1)) [" " ","]] [
    set finish finish + 1
  ]

  let s substring line start finish
  if s = "" [ report 0 ]
  report read-from-string s
end

to-report extract-all-numbers [text]
  let nums []
  let i 0
  while [i < length text] [
    let ch substring text i (i + 1)
    if member? ch ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9"] [
      let start i
      let j i
      while [j < length text and member? (substring text j (j + 1)) ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "."]] [
        set j j + 1
      ]
      set nums lput (read-from-string (substring text start j)) nums
      set i j
    ]
    set i i + 1
  ]
  report nums
end

to-report replace-all [text target replacement]
  if text = "" [ report "" ]
  let p position target text
  if p = false [ report text ]
  report (word
    (substring text 0 p)
    replacement
    (replace-all (substring text (p + length target) (length text)) target replacement))
end

;; Reporter retained for existing BehaviorSpace metric entries.
to-report safe-mean [ordering-code]
  if ordering-code = "A" [ report group-a-food ]
  if ordering-code = "B" [ report group-b-food ]
  if ordering-code = "C" [ report group-c-food ]
  report 0
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
forward conf
group-a-food
2
1
11

MONITOR
140
250
260
295
reversed conf
group-b-food
2
1
11

MONITOR
270
250
370
295
shuffled conf
group-c-food
2
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
Inference Confidence by Ordering
tick
confidence
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"forward" 1.0 0 -2674135 true "" "plot group-a-food"
"reversed" 1.0 0 -13345367 true "" "plot group-b-food"
"shuffled" 1.0 0 -8732573 true "" "plot group-c-food"

OUTPUT
10
530
370
670
12

@#$#@#$#@
## WHAT IS IT?

This demo tests whether a language model learns different behavioral rules from the **same trajectory data** when the rows are presented in different orders:

- forward (chronological)
- reversed (time reversed)
- shuffled (random permutation)

## HOW IT WORKS

1. Agents follow one hidden policy while foraging:
- seek nearby food
- avoid local crowding
- preserve momentum with small heading noise

2. The model records trajectories at each tick.

3. `infer-rules` serializes the trajectory log into three orderings and prompts an LLM with the same template for each ordering.

4. `export-data` writes:
- `results/<run>-trajectories.csv`
- `results/<run>-inference.csv`

## HOW TO USE IT

1. Configure `config.txt` (or disable `use-llm?`)
2. Click `setup`
3. Run `go-forever` for 100-200 ticks
4. Click `infer-rules`
5. Click `export-data`
6. Analyze exports with `analysis.py`

## WHY IT MATTERS

If inferred rules differ strongly between forward/reversed/shuffled views, rule learning is order-sensitive. This is a practical failure mode when using LLMs for inverse behavior modeling.

## CREDITS

Part of the AgentSwarm NetLogo LLM demos.
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
<experiment name="ordering-confidence" repetitions="5" runMetricsEveryStep="false">
<setup>setup</setup>
<go>repeat 150 [go]</go>
<metric>group-a-food</metric>
<metric>group-b-food</metric>
<metric>group-c-food</metric>
<metric>food-collected-total</metric>
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
