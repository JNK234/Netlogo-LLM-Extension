extensions [ llm csv ]

breed [ observers observer ]

patches-own [
  alive?
  next-alive?
]

globals [
  grid-size
  window-radius
  history-length
  episode-length
  observer-moving?
  observer-step-size

  label-choices
  event-choices
  glider-pattern-hashes

  run-memory-mode
  label-history-buffer

  bounded-results-file
  persistent-results-file
  combined-results-file
  active-provider
  active-model

  label-correct-count
  prediction-correct-count
]

to setup
  clear-all
  setup-defaults
  setup-world
  seed-initial-patterns
  setup-observer
  load-llm-configuration
  refresh-patch-colors
  reset-ticks
end

to setup-defaults
  random-seed 260103220

  set grid-size 50
  set window-radius 2
  set history-length 10
  set episode-length 50

  set observer-moving? false
  set observer-step-size 1

  set label-choices ["empty" "stable" "oscillator" "glider-like" "chaotic" "unknown"]
  set event-choices ["remain-empty" "remain-stable" "oscillation-continues" "glider-shifts" "pattern-intensifies" "pattern-decays"]

  set glider-pattern-hashes [
    "..X/X.X/.XX"
    ".X./..X/XXX"
    ".X./X../XXX"
    ".XX/X.X/..X"
    "X../X.X/XX."
    "XX./X.X/X.."
    "XXX/..X/.X."
    "XXX/X../.X."
  ]

  set bounded-results-file "results/bounded-output.csv"
  set persistent-results-file "results/persistent-output.csv"
  set combined-results-file "results/demo-output.csv"

  set run-memory-mode "persistent"
  set label-history-buffer []
  set label-correct-count 0
  set prediction-correct-count 0
  set active-provider "unknown"
  set active-model "unknown"
end

to setup-world
  resize-world 0 (grid-size - 1) 0 (grid-size - 1)
  ask patches [
    set alive? false
    set next-alive? false
    set pcolor black
  ]
end

to seed-initial-patterns
  place-glider 10 10
  place-blinker 30 30
  place-block 20 20

  ask patches [
    if random-float 1.0 < 0.05 [
      set alive? true
    ]
  ]
end

to setup-observer
  create-observers 1 [
    setxy (floor (grid-size / 2)) (floor (grid-size / 2))
    set shape "circle"
    set color yellow
    set size 1.5
    set label "observer"
  ]
end

to load-llm-configuration
  carefully [
    llm:load-config "config.txt"
  ] [
    print (word "LLM config load warning: " error-message)
  ]
  capture-active-model
end

to capture-active-model
  carefully [
    let active llm:active
    if is-list? active [
      if length active >= 2 [
        set active-provider item 0 active
        set active-model item 1 active
      ]
    ]
  ] [
    print (word "LLM active model warning: " error-message)
  ]
end

to go
  update-gol
  if observer-moving? [
    move-observer
  ]
  refresh-patch-colors
  tick
end

to update-gol
  compute-next-state
  apply-next-state
end

to compute-next-state
  ask patches [
    let live-neighbors count neighbors with [ alive? ]
    ifelse alive? [
      set next-alive? ((live-neighbors = 2) or (live-neighbors = 3))
    ] [
      set next-alive? (live-neighbors = 3)
    ]
  ]
end

to apply-next-state
  ask patches [
    set alive? next-alive?
  ]
end

to refresh-patch-colors
  ask patches [
    ifelse alive? [
      set pcolor white
    ] [
      set pcolor black
    ]
  ]
end

to move-observer
  ask observers [
    rt one-of [0 90 180 270]
    fd observer-step-size
  ]
end

to place-glider [x y]
  set-alive-cell (x + 1) y
  set-alive-cell (x + 2) (y + 1)
  set-alive-cell x (y + 2)
  set-alive-cell (x + 1) (y + 2)
  set-alive-cell (x + 2) (y + 2)
end

to place-blinker [x y]
  set-alive-cell (x - 1) y
  set-alive-cell x y
  set-alive-cell (x + 1) y
end

to place-block [x y]
  set-alive-cell x y
  set-alive-cell (x + 1) y
  set-alive-cell x (y + 1)
  set-alive-cell (x + 1) (y + 1)
end

to set-alive-cell [x y]
  let px wrap-coordinate x min-pxcor max-pxcor
  let py wrap-coordinate y min-pycor max-pycor
  ask patch px py [
    set alive? true
  ]
end

to-report wrap-coordinate [value lo hi]
  let span (hi - lo + 1)
  report lo + (((value - lo) mod span + span) mod span)
end

to-report current-window-rows
  let ox round [xcor] of one-of observers
  let oy round [ycor] of one-of observers
  report window-rows-at ox oy false
end

to-report next-window-rows
  let ox round [xcor] of one-of observers
  let oy round [ycor] of one-of observers
  report window-rows-at ox oy true
end

to-report observe-window
  report rows-to-ascii current-window-rows
end

to-report window-rows-at [cx cy use-next-state?]
  let rows []
  let y-offset (- window-radius)
  while [ y-offset <= window-radius ] [
    let row ""
    let x-offset (- window-radius)
    while [ x-offset <= window-radius ] [
      let px wrap-coordinate (cx + x-offset) min-pxcor max-pxcor
      let py wrap-coordinate (cy + y-offset) min-pycor max-pycor
      let target patch px py
      let is-live false
      ifelse use-next-state? [
        set is-live [next-alive?] of target
      ] [
        set is-live [alive?] of target
      ]
      set row word row (ifelse-value is-live ["X"] ["."])
      set x-offset x-offset + 1
    ]
    set rows lput row rows
    set y-offset y-offset + 1
  ]
  report rows
end

to-report rows-to-ascii [rows]
  if empty? rows [
    report ""
  ]
  let text first rows
  foreach but-first rows [row ->
    set text (word text "\n" row)
  ]
  report text
end

to-report rows-to-hash [rows]
  if empty? rows [
    report ""
  ]
  let text first rows
  foreach but-first rows [row ->
    set text (word text "/" row)
  ]
  report text
end

to-report llm-label-pattern [window-grid]
  let prompt (build-pattern-label-prompt window-grid)
  let raw (llm-choose-safe prompt label-choices "unknown")
  report normalize-choice raw label-choices "unknown"
end

to-report build-pattern-label-prompt [window-grid]
  ; llm:choose does not take a template file argument directly.
  ; Keep this prompt synchronized with templates/pattern_label.yaml.
  let choices-text (choices-as-lines label-choices)
  report (word
    "=== GAME OF LIFE WINDOW ===\n"
    window-grid
    "\n\n"
    "=== CATEGORIES ===\n"
    "empty: all cells are dead\n"
    "stable: static object (for example a block)\n"
    "oscillator: periodic shape (for example a blinker)\n"
    "glider-like: moving five-cell motif or translated motif\n"
    "chaotic: active but not clearly one known object\n"
    "unknown: insufficient evidence\n\n"
    "=== CHOICES ===\n"
    choices-text
    "\n\n"
    "Respond with exactly one label from the choices."
  )
end

to-report llm-predict-next [window-grid current-label]
  let vars (list
    (list "label_history" format-label-history)
    (list "current_label" current-label)
    (list "current_window" window-grid)
    (list "choices" (choices-as-lines event-choices))
  )
  let raw (llm-chat-template-safe "templates/macro_predict.yaml" vars "pattern-decays")
  report normalize-choice raw event-choices "pattern-decays"
end

to-report llm-choose-safe [prompt choices fallback]
  let result fallback
  carefully [
    set result llm:choose prompt choices
  ] [
    print (word "llm:choose warning: " error-message)
  ]
  report result
end

to-report llm-chat-template-safe [template-file variables fallback]
  let result fallback
  carefully [
    set result llm:chat-with-template template-file variables
  ] [
    print (word "llm:chat-with-template warning: " error-message)
  ]
  report result
end

to-report normalize-choice [raw-response choices fallback]
  if raw-response = nobody [
    report fallback
  ]

  let response lower-case (word raw-response)
  let matched ""
  foreach choices [choice ->
    if matched = "" [
      let lowered-choice lower-case choice
      if (position lowered-choice response != false) or (position response lowered-choice != false) [
        set matched choice
      ]
    ]
  ]

  if matched != "" [
    report matched
  ]

  let parsed-number -1
  carefully [
    let maybe-number read-from-string response
    if is-number? maybe-number [
      set parsed-number floor maybe-number
    ]
  ] [ ]

  if (parsed-number >= 1) and (parsed-number <= length choices) [
    report item (parsed-number - 1) choices
  ]

  report fallback
end

to-report choices-as-lines [choices]
  if empty? choices [
    report ""
  ]
  let text ""
  foreach choices [choice ->
    ifelse text = "" [
      set text (word "- " choice)
    ] [
      set text (word text "\n- " choice)
    ]
  ]
  report text
end

to update-label-history [tick-id label-value]
  let entry (word "tick " tick-id ": " label-value)

  ifelse run-memory-mode = "bounded" [
    set label-history-buffer (list entry)
  ] [
    set label-history-buffer lput entry label-history-buffer
    if length label-history-buffer > history-length [
      set label-history-buffer sublist label-history-buffer (length label-history-buffer - history-length) (length label-history-buffer)
    ]
  ]
end

to-report format-label-history
  if empty? label-history-buffer [
    report "none"
  ]

  let text first label-history-buffer
  foreach but-first label-history-buffer [entry ->
    set text (word text "\n" entry)
  ]
  report text
end

to-report classify-window [rows]
  let alive-count count-live-in-rows rows

  if alive-count = 0 [
    report "empty"
  ]
  if has-block? rows [
    report "stable"
  ]
  if has-blinker? rows [
    report "oscillator"
  ]
  if has-glider-shape? rows [
    report "glider-like"
  ]
  if alive-count < 3 [
    report "unknown"
  ]

  report "chaotic"
end

to-report count-live-in-rows [rows]
  let total 0
  foreach rows [row ->
    let idx 0
    while [ idx < length row ] [
      if substring row idx (idx + 1) = "X" [
        set total total + 1
      ]
      set idx idx + 1
    ]
  ]
  report total
end

to-report has-block? [rows]
  let y 0
  while [ y <= 3 ] [
    let x 0
    while [ x <= 3 ] [
      if (cell-at rows x y = "X") and
         (cell-at rows (x + 1) y = "X") and
         (cell-at rows x (y + 1) = "X") and
         (cell-at rows (x + 1) (y + 1) = "X") [
        report true
      ]
      set x x + 1
    ]
    set y y + 1
  ]
  report false
end

to-report has-blinker? [rows]
  report has-horizontal-triple? rows or has-vertical-triple? rows
end

to-report has-horizontal-triple? [rows]
  let y 0
  while [ y < length rows ] [
    let row item y rows
    let x 0
    while [ x <= (length row - 3) ] [
      if (substring row x (x + 1) = "X") and
         (substring row (x + 1) (x + 2) = "X") and
         (substring row (x + 2) (x + 3) = "X") [
        report true
      ]
      set x x + 1
    ]
    set y y + 1
  ]
  report false
end

to-report has-vertical-triple? [rows]
  let x 0
  while [ x < length (first rows) ] [
    let y 0
    while [ y <= (length rows - 3) ] [
      if (cell-at rows x y = "X") and
         (cell-at rows x (y + 1) = "X") and
         (cell-at rows x (y + 2) = "X") [
        report true
      ]
      set y y + 1
    ]
    set x x + 1
  ]
  report false
end

to-report has-glider-shape? [rows]
  let y 0
  while [ y <= 2 ] [
    let x 0
    while [ x <= 2 ] [
      if member? (subgrid-hash rows x y) glider-pattern-hashes [
        report true
      ]
      set x x + 1
    ]
    set y y + 1
  ]
  report false
end

to-report subgrid-hash [rows start-x start-y]
  let pieces []
  let y start-y
  while [ y < start-y + 3 ] [
    let row ""
    let x start-x
    while [ x < start-x + 3 ] [
      set row (word row (cell-at rows x y))
      set x x + 1
    ]
    set pieces lput row pieces
    set y y + 1
  ]
  report rows-to-hash pieces
end

to-report cell-at [rows x y]
  report substring (item y rows) x (x + 1)
end

to-report derive-next-event [current-label current-live current-hash next-label next-live next-hash]
  if (current-label = "empty") and (next-live = 0) [
    report "remain-empty"
  ]

  if (current-label = "stable") and (current-hash = next-hash) [
    report "remain-stable"
  ]

  if (current-label = "oscillator") and (next-label = "oscillator") and (current-hash != next-hash) [
    report "oscillation-continues"
  ]

  if (current-label = "glider-like") and (next-label = "glider-like") and (current-hash != next-hash) [
    report "glider-shifts"
  ]

  if next-live > current-live [
    report "pattern-intensifies"
  ]

  report "pattern-decays"
end

to run-episode-bounded
  run-episode "bounded" episode-length bounded-results-file false
end

to run-episode-persistent
  run-episode "persistent" episode-length persistent-results-file false
end

to run-comparison
  initialize-output-file combined-results-file
  run-episode "bounded" episode-length bounded-results-file true
  run-episode "persistent" episode-length persistent-results-file true
  analyze-results
end

to run-episode [memory-mode max-ticks output-file log-combined?]
  set run-memory-mode memory-mode
  setup
  set run-memory-mode memory-mode

  set label-history-buffer []
  set label-correct-count 0
  set prediction-correct-count 0
  llm:clear-history

  initialize-output-file output-file

  repeat max-ticks [
    update-gol
    if observer-moving? [
      move-observer
    ]
    refresh-patch-colors

    let current-rows current-window-rows
    let current-grid observe-window
    let current-hash rows-to-hash current-rows
    let current-label-truth classify-window current-rows
    let current-live-count count-live-in-rows current-rows

    let llm-label llm-label-pattern current-grid
    let label-accuracy ifelse-value (llm-label = current-label-truth) [1] [0]

    update-label-history ticks llm-label
    let llm-prediction llm-predict-next current-grid llm-label

    compute-next-state
    let next-rows next-window-rows
    let next-label-truth classify-window next-rows
    let next-live-count count-live-in-rows next-rows
    let next-hash rows-to-hash next-rows

    let true-event derive-next-event current-label-truth current-live-count current-hash next-label-truth next-live-count next-hash
    let prediction-accuracy ifelse-value (llm-prediction = true-event) [1] [0]

    set label-correct-count label-correct-count + label-accuracy
    set prediction-correct-count prediction-correct-count + prediction-accuracy

    let ox round [xcor] of one-of observers
    let oy round [ycor] of one-of observers

    let row (list
      ticks
      ox
      oy
      current-hash
      llm-label
      llm-prediction
      label-accuracy
      prediction-accuracy
      run-memory-mode
      active-provider
      active-model
    )

    append-output-row output-file row
    if log-combined? [
      append-output-row combined-results-file row
    ]

    if run-memory-mode = "bounded" [
      llm:clear-history
      set label-history-buffer []
    ]

    tick
  ]

  print-run-summary memory-mode max-ticks
end

to initialize-output-file [path]
  if file-exists? path [
    file-delete path
  ]
  file-open path
  file-print csv:to-row [
    "tick"
    "observer_x"
    "observer_y"
    "window_pattern"
    "llm_label"
    "llm_prediction"
    "label_accuracy"
    "prediction_accuracy"
    "memory_mode"
    "llm_provider"
    "llm_model"
  ]
  file-close
end

to append-output-row [path row]
  file-open path
  file-print csv:to-row row
  file-close
end

to print-run-summary [memory-mode max-ticks]
  if max-ticks <= 0 [
    stop
  ]

  let label-acc label-correct-count / max-ticks
  let pred-acc prediction-correct-count / max-ticks

  print (word "[" memory-mode "] label accuracy: " precision label-acc 3)
  print (word "[" memory-mode "] prediction accuracy: " precision pred-acc 3)
end

to analyze-results
  let bounded-data load-results-data bounded-results-file
  let persistent-data load-results-data persistent-results-file

  if empty? bounded-data [
    print "No bounded results found. Run run-episode-bounded first."
    stop
  ]

  if empty? persistent-data [
    print "No persistent results found. Run run-episode-persistent first."
    stop
  ]

  let bounded-label-accuracy mean-column bounded-data 6
  let bounded-prediction-accuracy mean-column bounded-data 7
  let persistent-label-accuracy mean-column persistent-data 6
  let persistent-prediction-accuracy mean-column persistent-data 7

  print "=== Epiplexity Demo 1: Analysis Summary ==="
  print (word "Bounded label accuracy: " precision bounded-label-accuracy 3)
  print (word "Bounded prediction accuracy: " precision bounded-prediction-accuracy 3)
  print (word "Persistent label accuracy: " precision persistent-label-accuracy 3)
  print (word "Persistent prediction accuracy: " precision persistent-prediction-accuracy 3)
  print (word "Prediction lift (persistent - bounded): " precision (persistent-prediction-accuracy - bounded-prediction-accuracy) 3)
end

to-report load-results-data [path]
  if not file-exists? path [
    report []
  ]

  let rows csv:from-file path
  if empty? rows [
    report []
  ]

  report but-first rows
end

to-report mean-column [rows idx]
  if empty? rows [
    report 0
  ]

  let values map [row -> read-number-safe (item idx row)] rows
  report mean values
end

to-report read-number-safe [value]
  if is-number? value [
    report value
  ]

  let parsed 0
  carefully [
    let maybe-number read-from-string (word value)
    if is-number? maybe-number [
      set parsed maybe-number
    ]
  ] [ ]
  report parsed
end

to test-llm
  let sample-window (rows-to-ascii current-window-rows)
  let label (llm-label-pattern sample-window)
  let prediction (llm-predict-next sample-window label)
  print (word "Sample label: " label)
  print (word "Sample prediction: " prediction)
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
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
0
0
1
ticks
30.0

BUTTON
15
10
92
43
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
105
10
175
43
NIL
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
15
55
175
88
Run Bounded Episode
run-episode-bounded
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
100
175
133
Run Persistent Episode
run-episode-persistent
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
145
175
178
Run Comparison
run-comparison
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
190
175
223
Analyze Results
analyze-results
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
235
175
268
Test LLM
test-llm
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
15
280
175
313
observer-moving?
observer-moving?
0
1
-1000

TEXTBOX
15
325
200
420
Epiplexity Demo 1:\n1. SETUP initializes Game of Life + observer\n2. Run bounded vs persistent episodes\n3. Compare prediction lift in results/*.csv\n4. Use analyze-results for quick summary
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

Demo 1 for epiplexity research: emergent object discovery in Conway's Game of Life using a bounded LLM observer.

This model operationalizes Paradox 1 from Finzi et al. (2026): deterministic micro-rules can expose new, extractable macro-structure to a computationally bounded observer.

## HOW IT WORKS

1. The world runs deterministic Game of Life updates.
2. A single observer reads only a 5x5 local window.
3. The observer labels the local pattern via `llm:choose`.
4. The observer predicts the next macro event via `llm:chat-with-template`.
5. The run logs per-tick metrics to CSV.

## MEMORY MODES

- `run-episode-bounded`: clears LLM history every tick (Markovian observer).
- `run-episode-persistent`: keeps history across ticks (non-Markovian observer).
- `run-comparison`: runs both and prints a summary.

## OUTPUT FILES

- `results/bounded-output.csv`
- `results/persistent-output.csv`
- `results/demo-output.csv` (combined)

Each row logs:
`tick, observer_x, observer_y, window_pattern, llm_label, llm_prediction, label_accuracy, prediction_accuracy, memory_mode, llm_provider, llm_model`

## EXPECTED RESULT

Persistent-memory runs should achieve higher prediction accuracy than bounded-memory runs while keeping comparable label accuracy.

## REFERENCES

- Finzi et al. (2026), "From Entropy to Epiplexity"
- arXiv: https://arxiv.org/pdf/2601.03220
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
