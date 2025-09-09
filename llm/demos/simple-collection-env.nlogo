extensions [ py table fp rnd ]

__includes [
  "env_utils/evolution.nls"
  "env_utils/logging.nls"
  "env_utils/prompt_config.nls"
  "config/simple-collection-config.nls"
]

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

to setup-params
  if use-config-file? [
    carefully [
      run word "setup-params-" config-file
    ] [
      user-message word config-file " is not a valid config file."
    ]
  ]
end

to-report get-additional-params
  report (list
    list "num-food-sources" num-food-sources
    list "init-rule" init-rule
    list "init-pseudocode" init-pseudocode
  )
end

to setup-llm-agents
  create-llm-agents num-llm-agents [
    set color red
    setxy random-xcor random-ycor
    set rule init-rule
    set parent-id "na"
    set parent-rule "na"
    set pseudocode init-pseudocode
    set parent-pseudocode "na"
    init-agent-params ;; Init with zero energy
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

to setup
  clear-all

  py:setup py:python
  py:run "import os"
  py:run "import sys"
  py:run "from pathlib import Path"
  py:run "sys.path.append(os.path.dirname(os.path.abspath('..')))"
  py:run "from src.mutation.mutate_code import mutate_code"

  set init-rule "lt random 20 rt random 20 fd 1"
  set init-pseudocode "Take left turn randomly within 0-20 degrees, then take right turn randomly within 0-20 degrees and move forward 1"

  set generation-stats []
  set error-log []
  set best-rule-fitness 0

  spawn-food num-food-sources
  setup-llm-agents
  setup-params
  if logging? [ setup-logger get-additional-params ]
  write-prompt-config prompt-type prompt-name
  reset-ticks
end

;;; Go Procedures

to go
  do-plotting
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
      " | Lifetime: " lifetime
      " | Food Collected: " food-collected
      " | Input: " input
      " | Error: " error-message
    )
    if ticks mod ticks-per-generation = 1 [
      if verbose? [ print error-info ]
      set error-log lput error-info error-log
    ]
  ]
end

to evolve-agents
  if ticks >= 1 and ticks mod ticks-per-generation = 0 [
    print word "\nGeneration: " generation

    let parents select-agents
    let kill-num length parents

    let kill-dict agent-dict min-n-of kill-num llm-agents [fitness]
    let best-dict agent-dict turtle-set parents
    let new-agent-ids []

    foreach parents [ parent ->
      ask parent [
        let my-parent-id who
        let my-rule rule
        let my-pseudocode pseudocode
        hatch 1 [
          set parent-id my-parent-id
          set parent-rule my-rule
          set parent-pseudocode my-pseudocode
          set rule mutate-rule
          init-agent-params
          set new-agent-ids lput who new-agent-ids
        ]
      ]
    ]

    ask min-n-of kill-num llm-agents with [not member? who new-agent-ids] [fitness] [ die ]

    let new-dict agent-dict llm-agents with [member? who new-agent-ids]
    update-generation-stats
    log-metrics (list best-dict new-dict kill-dict)
    set error-log []

    ask llm-agents [
      set food-collected 0
      set energy 0
    ]
  ]
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
  if count food-sources < num-food-sources [
    spawn-food (num-food-sources - count food-sources)
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

to-report get-generation-metrics
  let keys ["generation" "best rule" "mean fitness" "best fitness" "mean food" "error log"]
  let values ifelse-value any? llm-agents [
    (list
      generation
      best-rule
      mean-fitness
      max [fitness] of llm-agents
      mean [food-collected] of llm-agents
      error-log)
  ] [
    (list generation "na" 0 0 0 [])
  ]
  report fp:zip keys values
end

;;; Plotting

to do-plotting
  if ticks mod ticks-per-generation = 0 [
    set-current-plot "Mean Energy of Agents"
    set-current-plot-pen "Mean Energy"
    plotxy generation mean-fitness
    set-current-plot-pen "Max Energy"
    plotxy generation max [energy] of llm-agents
  ]
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
1
1
1
ticks
30.0

BUTTON
20
190
90
223
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
100
190
170
223
NIL
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
20
20
195
53
num-llm-agents
num-llm-agents
0
25
10.0
1
1
NIL
HORIZONTAL

SLIDER
20
60
195
93
num-food-sources
num-food-sources
0
100
30.0
1
1
NIL
HORIZONTAL

SWITCH
20
240
195
273
llm-mutation?
llm-mutation?
0
1
-1000

PLOT
680
60
1090
350
Mean Energy of Agents
generation
energy
0.0
5.0
0.0
10.0
true
true
"" ""
PENS
"Mean Energy" 1.0 0 -817084 true "" ""
"Max Energy" 1.0 0 -13345367 true "" ""

SLIDER
20
100
195
133
ticks-per-generation
ticks-per-generation
1
2000
500.0
1
1
NIL
HORIZONTAL

MONITOR
680
10
757
55
NIL
generation
17
1
11

CHOOSER
20
320
195
365
llm-type
llm-type
"groq" "claude" "deepseek" "gpt-4o"
0

SWITCH
20
140
195
173
logging?
logging?
0
1
-1000

SWITCH
20
280
195
313
text-based-evolution
text-based-evolution
1
1
-1000

INPUTBOX
20
370
195
430
experiment-name
texttest
1
0
String

CHOOSER
20
470
195
515
selection
selection
"tournament" "fitness-prop"
0

SLIDER
20
520
195
553
num-parents
num-parents
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
20
560
195
593
tournament-size
tournament-size
0
50
8.0
1
1
NIL
HORIZONTAL

SLIDER
20
600
195
633
selection-pressure
selection-pressure
0
1
0.8
0.01
1
NIL
HORIZONTAL

SWITCH
210
470
385
503
use-config-file?
use-config-file?
1
1
-1000

INPUTBOX
210
510
385
570
config-file
default
1
0
String

SWITCH
400
470
575
503
verbose?
verbose?
1
1
-1000

INPUTBOX
400
510
629
570
prompt-type
collection_simple
1
0
String

INPUTBOX
635
510
864
570
prompt-name
one_shot_code_wcomments
1
0
String

CHOOSER
635
575
862
620
prompt-name
prompt-name
"zero_shot_code" "one_shot_code" "two_shot_code" "zero_shot_code_wcomments" "one_shot_code_wcomments" "two_shot_code_wcomments"
4

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="test-exp" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;bspacetest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;claude&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="one-shot-code-exp" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;bspacetest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;claude&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="two-shot-code-exp" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;two_shot_code_exp_opt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="zero-shot-code-exp" repetitions="6" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;zero_shot_code_exp_groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="zero-shot-code-wcomments-exp" repetitions="6" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;zero_shot_code_wcomments_exp&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="one-shot-code-wcomments-exp" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;one_shot_code_wcomments_exp&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="two-shot-code-wcomments-exp" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;two_shot_code_wcomments_exp&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="zero-shot-pseudocode-exp" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;zero_shot_pseudocode_exp&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="one-shot-pseudocode-exp" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;one_shot_pseudocode_exp&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="two-shot-pseudocode-exp" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150000"/>
    <metric>generation</metric>
    <metric>mean-fitness</metric>
    <metric>max [fitness] of llm-agents</metric>
    <metric>best-rule-fitness</metric>
    <metric>best-rule</metric>
    <runMetricsCondition>ticks mod ticks-per-generation = 0</runMetricsCondition>
    <enumeratedValueSet variable="tournament-size">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-llm-agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection-pressure">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-config-file?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="logging?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-parents">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="config-file">
      <value value="&quot;default&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-generation">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="text-based-evolution">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-sources">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-name">
      <value value="&quot;two_shot_pseudocode_exp&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selection">
      <value value="&quot;tournament&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="llm-type">
      <value value="&quot;groq&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
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
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
