breed [boids boid]

boids-own [
  vx
  vy
  next-vx
  next-vy
]

to setup
  clear-all
  set-default-shape boids "triangle"

  create-boids num-boids [
    set size 1.8
    set color 95 + random 10
    setxy random-xcor random-ycor

    let initial-heading random-float 360
    let initial-speed minimum-speed + random-float (max-speed - minimum-speed)

    set heading initial-heading
    set vx initial-speed * dx
    set vy initial-speed * dy
    set next-vx vx
    set next-vy vy
  ]

  reset-ticks
end

to go
  if not any? boids [ stop ]

  ask boids [
    calculate-next-velocity
  ]

  ask boids [
    apply-motion
  ]

  tick
end

to calculate-next-velocity  ;; turtle procedure
  let separation-force boids-separation
  let alignment-force boids-alignment
  let cohesion-force boids-cohesion

  let candidate-vx vx + item 0 separation-force + item 0 alignment-force + item 0 cohesion-force
  let candidate-vy vy + item 1 separation-force + item 1 alignment-force + item 1 cohesion-force
  let adjusted-velocity clamp-speed candidate-vx candidate-vy

  set next-vx item 0 adjusted-velocity
  set next-vy item 1 adjusted-velocity
end

to-report boids-separation  ;; turtle procedure
  let nearby-boids other boids in-radius separation-radius
  if not any? nearby-boids [
    report (list 0 0)
  ]

  ; Close neighbors contribute stronger repulsion than distant ones.
  let force-x sum [sin (towards myself) / ((distance myself + 0.05) ^ 2)] of nearby-boids
  let force-y sum [cos (towards myself) / ((distance myself + 0.05) ^ 2)] of nearby-boids

  report (list (force-x * separation-weight) (force-y * separation-weight))
end

to-report boids-alignment  ;; turtle procedure
  let nearby-boids other boids in-radius alignment-radius
  if not any? nearby-boids [
    report (list 0 0)
  ]

  let mean-vx mean [vx] of nearby-boids
  let mean-vy mean [vy] of nearby-boids

  report (list ((mean-vx - vx) * alignment-weight)
               ((mean-vy - vy) * alignment-weight))
end

to-report boids-cohesion  ;; turtle procedure
  let nearby-boids other boids in-radius cohesion-radius
  if not any? nearby-boids [
    report (list 0 0)
  ]

  ; Average the directions toward neighbors to pull the local flock together.
  let force-x mean [sin (towards myself + 180)] of nearby-boids
  let force-y mean [cos (towards myself + 180)] of nearby-boids

  report (list (force-x * cohesion-weight) (force-y * cohesion-weight))
end

to apply-motion  ;; turtle procedure
  set vx next-vx
  set vy next-vy
  set heading atan vx vy
  setxy (wrapped-x (xcor + vx)) (wrapped-y (ycor + vy))
end

to-report clamp-speed [candidate-vx candidate-vy]
  let speed vector-speed candidate-vx candidate-vy

  if speed = 0 [
    let random-heading random-float 360
    report (list (minimum-speed * sin random-heading)
                 (minimum-speed * cos random-heading))
  ]

  if speed > max-speed [
    let factor max-speed / speed
    report (list (candidate-vx * factor) (candidate-vy * factor))
  ]

  if speed < minimum-speed [
    let factor minimum-speed / speed
    report (list (candidate-vx * factor) (candidate-vy * factor))
  ]

  report (list candidate-vx candidate-vy)
end

to-report minimum-speed
  report max-speed * 0.35
end

to-report vector-speed [x-component y-component]
  report sqrt ((x-component * x-component) + (y-component * y-component))
end

to-report wrapped-x [candidate-x]
  let span (max-pxcor - min-pxcor + 1)
  if candidate-x > max-pxcor [ report candidate-x - span ]
  if candidate-x < min-pxcor [ report candidate-x + span ]
  report candidate-x
end

to-report wrapped-y [candidate-y]
  let span (max-pycor - min-pycor + 1)
  if candidate-y > max-pycor [ report candidate-y - span ]
  if candidate-y < min-pycor [ report candidate-y + span ]
  report candidate-y
end

to-report avg-speed
  if not any? boids [ report 0 ]
  report mean [vector-speed vx vy] of boids
end

to-report flock-size
  if not any? boids [ report 0 ]
  report max [count other boids in-radius cohesion-radius + 1] of boids
end

@#$#@#$#@
GRAPHICS-WINDOW
230
10
735
515
-1
-1
12.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
15
15
100
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
110
15
195
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
215
98
num-boids
num-boids
10
300
120.0
5
1
NIL
HORIZONTAL

SLIDER
15
105
215
138
max-speed
max-speed
0.2
3
1.4
0.1
1
NIL
HORIZONTAL

SLIDER
15
145
215
178
separation-radius
separation-radius
0.5
5
1.5
0.1
1
NIL
HORIZONTAL

SLIDER
15
185
215
218
alignment-radius
alignment-radius
1
12
5
0.5
1
NIL
HORIZONTAL

SLIDER
15
225
215
258
cohesion-radius
cohesion-radius
1
15
9
0.5
1
NIL
HORIZONTAL

SLIDER
15
265
215
298
separation-weight
separation-weight
0
3
1.2
0.1
1
NIL
HORIZONTAL

SLIDER
15
305
215
338
alignment-weight
alignment-weight
0
2
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
15
345
215
378
cohesion-weight
cohesion-weight
0
2
0.4
0.05
1
NIL
HORIZONTAL

MONITOR
15
395
110
440
avg-speed
avg-speed
2
1
11

MONITOR
120
395
215
440
flock-size
flock-size
0
1
11

@#$#@#$#@
## WHAT IS IT?

This model simulates a classic boids flock in NetLogo. Each boid follows local separation, alignment, and cohesion rules, and coordinated motion emerges without any leader.

## HOW IT WORKS

Each boid measures nearby flockmates within three configurable radii. Separation pushes away from close neighbors, alignment steers toward the local average velocity, and cohesion pulls toward nearby group centers.

## HOW TO USE IT

1. Set the sliders for population, speed, radii, and rule weights.
2. Click `setup`.
3. Click `go`.

## THINGS TO NOTICE

- Higher separation produces more spacing and more breakaway motion.
- Higher alignment produces smoother coordinated swarms.
- Higher cohesion pulls scattered boids into denser local flocks.
- With the default settings, you should see coordinated swarms, curved bands, and occasional V-like groupings.

## CREDITS AND REFERENCES

This model follows the classic boids idea introduced in Reynolds, C. W. (1986). "Flocks, herds and schools: A distributed behavioral model." SIGGRAPH '86.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

triangle
true
0
Polygon -7500403 true true 150 30 15 255 285 255

@#$#@#$#@
NetLogo 7.0.3
@#$#@#$#@
set num-boids 120
setup
repeat 200 [ go ]
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
0
@#$#@#$#@
