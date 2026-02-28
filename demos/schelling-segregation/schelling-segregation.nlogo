breed [reds red]
breed [blues blue]

to setup
  clear-all
  set-default-shape turtles "circle"
  configure-world
  seed-households
  reset-ticks
  refresh-plot
end

to go
  if settled? [ stop ]

  move-unhappy
  tick
  refresh-plot

  if settled? [ stop ]
end

to configure-world
  ;; Resize the world so the requested agent count and vacancy rate stay aligned.
  let occupancy-rate max (list 0.05 ((100 - empty-rate) / 100))
  let needed-patches ceiling (num-agents / occupancy-rate)
  let side-length ceiling (sqrt needed-patches)

  if side-length mod 2 = 0 [
    set side-length side-length + 1
  ]

  let radius floor (side-length / 2)
  resize-world (- radius) radius (- radius) radius
  set-patch-size max (list 8 (floor (520 / side-length)))
  ask patches [ set pcolor gray + 3 ]
end

to seed-households
  let available-patches shuffle sort patches
  let red-count floor (num-agents / 2)
  let blue-count num-agents - red-count
  let red-patches sublist available-patches 0 red-count
  let blue-patches sublist available-patches red-count (red-count + blue-count)

  foreach red-patches [home ->
    create-reds 1 [
      move-to home
      set color red + 1
      set size 1.2
    ]
  ]

  foreach blue-patches [home ->
    create-blues 1 [
      move-to home
      set color blue + 1
      set size 1.2
    ]
  ]
end

to move-unhappy
  let open-patches patches with [not any? turtles-here]
  if not any? open-patches [ stop ]

  ask turtles with [not happy? self] [
    let destination one-of patches with [not any? turtles-here]
    if destination != nobody [
      move-to destination
    ]
  ]
end

to refresh-plot
  set-current-plot "Segregation Dynamics"
  set-current-plot-pen "segregation-index"
  plot segregation-index
  set-current-plot-pen "happy-percent"
  plot happy-percentage
end

to-report happy? [household]
  report similar-neighbor-percentage household >= similar-wanted
end

to-report similar-neighbor-percentage [household]
  let home [patch-here] of household
  let nearby turtles-on [neighbors] of home

  if not any? nearby [
    report 100
  ]

  let similar-neighbors count nearby with [breed = [breed] of household]
  report (100 * similar-neighbors / count nearby)
end

to-report segregation-index
  if not any? turtles [
    report 0
  ]

  report mean [similar-neighbor-percentage self] of turtles
end

to-report happy-count
  report count turtles with [happy? self]
end

to-report happy-percentage
  if not any? turtles [
    report 0
  ]

  report (100 * happy-count / count turtles)
end

to-report empty-patches
  report count patches with [not any? turtles-here]
end

to-report settled?
  report all-happy? or empty-patches = 0 or ticks >= 200
end

to-report all-happy?
  report happy-count = count turtles
end
@#$#@#$#@
GRAPHICS-WINDOW
215
10
695
491
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
15
90
48
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
15
180
48
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
15
65
195
98
num-agents
num-agents
100
900
400.0
50
1
NIL
HORIZONTAL

SLIDER
15
110
195
143
similar-wanted
similar-wanted
0
100
30.0
1
1
%
HORIZONTAL

SLIDER
15
155
195
188
empty-rate
empty-rate
5
40
40.0
1
1
%
HORIZONTAL

MONITOR
15
210
195
255
Segregation Index
segregation-index
2
1
11

MONITOR
15
265
195
310
Happy Count
happy-count
0
1
11

MONITOR
15
320
195
365
Empty Patches
empty-patches
0
1
11

PLOT
710
20
1110
265
Segregation Dynamics
time
count / percent
0.0
200.0
0.0
100.0
true
true
"" ""
PENS
"segregation-index" 1.0 0 -2674135 true "" ""
"happy-percent" 1.0 0 -13345367 true "" ""

TEXTBOX
710
285
1110
420
Mild local preferences can generate strongly segregated neighborhoods.\nTry the validated default: 30% tolerance with 40% empty patches settles near 80% similar neighbors.
13
0.0
1

@#$#@#$#@
## WHAT IS IT?

This is a standalone Schelling segregation model. Red and blue households only want a modest share of similar neighbors, but repeated relocation creates highly segregated neighborhoods.

## HOW IT WORKS

1. `setup` resizes the world to match the requested population and vacancy rate.
2. Half of the households start red, half blue, on random patches.
3. Each household checks the eight neighboring patches and asks whether the percentage of similar neighbors meets `similar-wanted`.
4. Unhappy households move to random empty patches.
5. The run stops when every household is happy or when it reaches 200 ticks.

## THINGS TO NOTICE

- The `segregation-index` usually rises much higher than `similar-wanted`.
- At the validated defaults, a 30% tolerance still settles into a world where roughly 80% of neighboring households are similar.
- More empty space speeds up sorting because unhappy households can move more easily.

## BEHAVIORSPACE

Import `BehaviorSpace/sweep.xml` to sweep `similar-wanted` from 10% through 50%.
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
NetLogo 7.0.0
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
