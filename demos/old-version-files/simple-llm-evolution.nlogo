extensions [ llm ]

globals [
  generation
  best-fitness
]

breed [agents agent]
breed [food-sources food-source]

agents-own [
  rule
  energy
]

to setup
  clear-all

  ; Setup LLM
  llm:load-config "config.txt"

  set generation 0
  set best-fitness 0

  ; Create agents with initial rule
  create-agents 10 [
    set color red
    setxy random-xcor random-ycor
    set rule "fd 1 rt random 45"
    set energy 0
  ]

  ; Create food sources
  create-food-sources 20 [
    set shape "circle"
    set color green
    set size 0.5
    setxy random-xcor random-ycor
  ]

  reset-ticks
end

to go
  ; Agents act
  ask agents [
    carefully [
      run rule
    ] [
      ; If rule fails, do nothing
    ]
    collect-food
  ]

  ; Evolution every 100 ticks
  if ticks mod 100 = 0 and ticks > 0 [
    evolve
  ]

  ; Replenish food
  if count food-sources < 20 [
    create-food-sources (20 - count food-sources) [
      set shape "circle"
      set color green
      set size 0.5
      setxy random-xcor random-ycor
    ]
  ]

  tick
end

to collect-food
  if any? food-sources-here [
    ask one-of food-sources-here [ die ]
    set energy energy + 1
  ]
end

to evolve
  set generation generation + 1
  print (word "Generation: " generation)

  ; Find best performers
  let top-agents max-n-of 3 agents [energy]

  ; Update best fitness
  if any? top-agents [
    let current-best max [energy] of top-agents
    if current-best > best-fitness [
      set best-fitness current-best
    ]
  ]

  ; Evolve worst performers
  let worst-agents min-n-of 3 agents [energy]

  ask worst-agents [
    ; Get a good rule to mutate
    let parent-rule [rule] of one-of top-agents
    set rule mutate-with-llm parent-rule
    set energy 0
  ]

  ; Reset all energies
  ask agents [ set energy 0 ]
end

to-report mutate-with-llm [current-rule]
  let prompt (word
    "Improve this NetLogo movement rule for food collection: " current-rule
    " Make it better at finding food. Use only: fd, bk, rt, lt, random. Keep it simple, one line.")

  let new-rule ""
  carefully [
    set new-rule llm:chat prompt
    ; Clean up response
    if length new-rule > 50 [
      set new-rule current-rule
    ]
  ] [
    ; Fallback if LLM fails
    set new-rule (word "fd " (1 + random 2) " rt random " (30 + random 60))
  ]

  report new-rule
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
30
30
100
63
setup
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
110
30
180
63
go
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

MONITOR
30
80
120
125
Generation
generation
0
1
11

MONITOR
130
80
220
125
Best Fitness
best-fitness
0
1
11

@#$#@#$#@
## Simple LLM Code Evolution

Red agents evolve movement rules using an LLM to collect green food.

1. Click SETUP
2. Click GO
3. Watch agents evolve better food-finding rules

Every 100 ticks, the worst agents get new rules evolved from the best agents using the LLM.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300
@#$#@#$#@
NetLogo 6.4.0
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
