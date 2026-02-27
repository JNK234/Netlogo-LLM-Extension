extensions [ llm ]

globals [
  llm-ready?
  config-path
  triage-template-path
  dispatcher-template-path
  processed-basic
  processed-expert
  processed-coordinator
  escalated-count
  seeded-crises
  case-arrival-probability
]

breed [cases case]
breed [basic-agents basic-agent]
breed [expert-agents expert-agent]
breed [coordinators coordinator]

turtles-own [
  tier
  capacity
  current-load
  processed-count
]

cases-own [
  incident-summary
  reported-impact
  severity-band
  severity-score
  queue-state
  assigned-tier
  assigned-agent
  handling-notes
  created-at
]

to setup
  clear-all
  set config-path "demos/crisis-triage/config.txt"
  set triage-template-path "demos/crisis-triage/triage-template.yaml"
  set dispatcher-template-path "demos/crisis-triage/dispatcher-template.yaml"

  set processed-basic 0
  set processed-expert 0
  set processed-coordinator 0
  set escalated-count 0

  set seeded-crises 12
  set case-arrival-probability 0.25

  setup-llm
  setup-responders
  create-initial-cases seeded-crises
  reset-ticks
end

to setup-llm
  set llm-ready? false
  carefully [
    if file-exists? config-path [
      llm:load-config config-path
      set llm-ready? true
    ]
  ] [
    set llm-ready? false
    print (word "LLM setup fallback to heuristic triage: " error-message)
  ]
end

to setup-responders
  create-basic-agents 7 [
    set tier "basic"
    set capacity 2
    set current-load 0
    set processed-count 0
    set color 57
    set size 1.6
    set shape "circle"
    setxy (-13 + random-float 6) (-12 + random-float 24)
  ]

  create-expert-agents 4 [
    set tier "expert"
    set capacity 2
    set current-load 0
    set processed-count 0
    set color 15
    set size 1.8
    set shape "circle"
    setxy (-3 + random-float 6) (-12 + random-float 24)
  ]

  create-coordinators 2 [
    set tier "coordinator"
    set capacity 3
    set current-load 0
    set processed-count 0
    set color 105
    set size 2.1
    set shape "circle"
    setxy (8 + random-float 6) (-12 + random-float 24)
  ]
end

to create-initial-cases [n]
  repeat n [ spawn-random-case ]
end

to spawn-random-case
  let incident-bank (list
    (list "Server room smoke alarm" "Power instability in two hospital wings")
    (list "Water main rupture" "Transit junction flooded during rush hour")
    (list "School bus collision" "Multiple injuries and blocked arterial road")
    (list "Warehouse fire flare-up" "Toxic plume reported near residential area")
    (list "Regional telecom outage" "Emergency call latency above safe threshold")
    (list "Chemical lab leak" "Evacuation radius requested by fire command")
    (list "Bridge vibration alert" "Potential structural failure during peak traffic")
    (list "Heat wave brownout" "Critical care equipment on backup power")
    (list "Subway security incident" "Crowd panic and platform injuries")
    (list "Data center cooling loss" "City payment systems offline")
  )

  let picked one-of incident-bank
  create-cases 1 [
    set tier "case"
    set capacity 0
    set current-load 0
    set processed-count 0

    set incident-summary item 0 picked
    set reported-impact item 1 picked
    set severity-band "unassessed"
    set severity-score -1
    set queue-state "new"
    set assigned-tier "none"
    set assigned-agent nobody
    set handling-notes ""
    set created-at ticks

    set color yellow
    set size 1.3
    set shape "circle"
    setxy (random-xcor) (max-pycor - random-float 6)
  ]
end

to go
  if random-float 1 < case-arrival-probability [
    spawn-random-case
  ]

  triage-new-cases
  route-triaged-cases
  coordinator-rebalance
  process-assigned-cases

  tick
end

to triage-new-cases
  ask cases with [queue-state = "new"] [
    perform-triage
  ]
end

to perform-triage
  let llm-response ""

  if llm-ready? [
    carefully [
      set llm-response llm:chat-with-template triage-template-path (list
        ["incident" incident-summary]
        ["impact" reported-impact]
        ["elapsed_ticks" (word ticks)]
        ["known_context" "Municipal crisis operations center with three response tiers"]
      )
    ] [
      set llm-response ""
    ]
  ]

  if llm-response = "" [
    set llm-response heuristic-severity-report incident-summary reported-impact
  ]

  set severity-band extract-severity-label llm-response incident-summary reported-impact
  set severity-score severity-score-from-band severity-band
  set queue-state "triaged"
  set handling-notes (word "TRIAGE " llm-response)
  set color color-for-band severity-band
end

to-report heuristic-severity-report [summary impact]
  let merged (word summary " " impact)

  if (position "collision" merged != false)
     or (position "toxic" merged != false)
     or (position "evacuation" merged != false)
     or (position "critical care" merged != false)
     or (position "structural" merged != false) [
    report "SEVERITY: CRITICAL"
  ]

  if (position "fire" merged != false)
     or (position "outage" merged != false)
     or (position "flooded" merged != false)
     or (position "injuries" merged != false) [
    report "SEVERITY: HIGH"
  ]

  report "SEVERITY: MODERATE"
end

to-report extract-severity-label [assessment summary impact]
  let text (word assessment " " summary " " impact)

  if (position "CRITICAL" text != false) or (position "critical" text != false) [
    report "critical"
  ]

  if (position "HIGH" text != false) or (position "high" text != false) [
    report "high"
  ]

  if (position "MODERATE" text != false) or (position "moderate" text != false) [
    report "moderate"
  ]

  if (position "LOW" text != false) or (position "low" text != false) [
    report "low"
  ]

  report "moderate"
end

to-report severity-score-from-band [band]
  if band = "low" [ report 25 ]
  if band = "moderate" [ report 55 ]
  if band = "high" [ report 80 ]
  report 95
end

to route-triaged-cases
  let queue sort-by [[a b] -> [severity-score] of a > [severity-score] of b] (sort (cases with [queue-state = "triaged"]))
  foreach queue [ queued-case ->
    dispatch-case queued-case
  ]
end

to dispatch-case [target-case]
  let preferred-tier dispatch-recommendation target-case
  let final-tier available-tier preferred-tier

  if final-tier = "hold" [
    ask target-case [
      set handling-notes (word handling-notes " | waiting-capacity")
    ]
    stop
  ]

  let worker select-worker final-tier
  if worker = nobody [ stop ]

  if final-tier != preferred-tier [
    set escalated-count escalated-count + 1
  ]

  ask worker [
    set current-load current-load + 1
  ]

  ask target-case [
    set queue-state "assigned"
    set assigned-tier final-tier
    set assigned-agent worker
    set color color-for-tier final-tier
    set handling-notes (word handling-notes " | routed:" final-tier)
    set ycor ycor - 4
  ]
end

to-report dispatch-recommendation [target-case]
  let default-tier severity-to-default-tier [severity-band] of target-case

  if not llm-ready? [
    report default-tier
  ]

  let llm-response ""
  carefully [
    set llm-response llm:chat-with-template dispatcher-template-path (list
      ["severity" [severity-band] of target-case]
      ["incident" [incident-summary] of target-case]
      ["basic_load" (word count cases with [queue-state = "assigned" and assigned-tier = "basic"])]
      ["expert_load" (word count cases with [queue-state = "assigned" and assigned-tier = "expert"])]
      ["coordinator_load" (word count cases with [queue-state = "assigned" and assigned-tier = "coordinator"])]
    )
  ] [
    set llm-response ""
  ]

  if llm-response = "" [ report default-tier ]

  let chosen extract-route-label llm-response
  if chosen = "unknown" [ report default-tier ]
  report chosen
end

to-report extract-route-label [response]
  if (position "COORDINATOR" response != false) or (position "coordinator" response != false) [
    report "coordinator"
  ]

  if (position "EXPERT" response != false) or (position "expert" response != false) [
    report "expert"
  ]

  if (position "BASIC" response != false) or (position "basic" response != false) [
    report "basic"
  ]

  report "unknown"
end

to-report severity-to-default-tier [band]
  if band = "low" [ report "basic" ]
  if band = "moderate" [ report "expert" ]
  if band = "high" [ report "expert" ]
  report "coordinator"
end

to-report available-tier [preferred-tier]
  if preferred-tier = "basic" [
    if any? basic-agents with [current-load < capacity] [ report "basic" ]
    if any? expert-agents with [current-load < capacity] [ report "expert" ]
    if any? coordinators with [current-load < capacity] [ report "coordinator" ]
    report "hold"
  ]

  if preferred-tier = "expert" [
    if any? expert-agents with [current-load < capacity] [ report "expert" ]
    if any? coordinators with [current-load < capacity] [ report "coordinator" ]
    if any? basic-agents with [current-load < capacity] [ report "basic" ]
    report "hold"
  ]

  if any? coordinators with [current-load < capacity] [ report "coordinator" ]
  if any? expert-agents with [current-load < capacity] [ report "expert" ]
  report "hold"
end

to-report select-worker [tier-name]
  if tier-name = "basic" [
    if any? basic-agents with [current-load < capacity] [
      report min-one-of basic-agents with [current-load < capacity] [current-load]
    ]
  ]

  if tier-name = "expert" [
    if any? expert-agents with [current-load < capacity] [
      report min-one-of expert-agents with [current-load < capacity] [current-load]
    ]
  ]

  if tier-name = "coordinator" [
    if any? coordinators with [current-load < capacity] [
      report min-one-of coordinators with [current-load < capacity] [current-load]
    ]
  ]

  report nobody
end

to coordinator-rebalance
  if not any? coordinators [ stop ]

  let risky-basic one-of cases with [
    queue-state = "assigned" and
    assigned-tier = "basic" and
    severity-score >= 70
  ]
  if risky-basic != nobody [
    reassign-case risky-basic "expert" "risk escalation"
  ]

  let critical-expert one-of cases with [
    queue-state = "assigned" and
    assigned-tier = "expert" and
    severity-score >= 90
  ]
  if critical-expert != nobody [
    reassign-case critical-expert "coordinator" "critical escalation"
  ]
end

to reassign-case [target-case new-tier reason]
  if [assigned-tier] of target-case = new-tier [ stop ]

  let new-worker select-worker new-tier
  if new-worker = nobody [ stop ]

  let old-worker [assigned-agent] of target-case
  if old-worker != nobody [
    ask old-worker [
      set current-load max (list 0 (current-load - 1))
    ]
  ]

  ask new-worker [
    set current-load current-load + 1
  ]

  ask target-case [
    set assigned-tier new-tier
    set assigned-agent new-worker
    set color color-for-tier new-tier
    set handling-notes (word handling-notes " | coordinator-reassign:" reason)
  ]

  set escalated-count escalated-count + 1
end

to process-assigned-cases
  ask cases with [queue-state = "assigned"] [
    let completion completion-chance assigned-tier severity-band
    if random-float 1 < completion [
      finalize-case self
    ]
  ]
end

to-report completion-chance [tier-name band]
  if tier-name = "basic" [ report 0.12 ]
  if tier-name = "expert" [
    if band = "high" [ report 0.27 ]
    if band = "critical" [ report 0.2 ]
    report 0.22
  ]

  if band = "critical" [ report 0.34 ]
  report 0.28
end

to finalize-case [target-case]
  let tier-name [assigned-tier] of target-case
  let worker [assigned-agent] of target-case

  if worker != nobody [
    ask worker [
      set current-load max (list 0 (current-load - 1))
      set processed-count processed-count + 1
    ]
  ]

  if tier-name = "basic" [
    set processed-basic processed-basic + 1
  ]
  if tier-name = "expert" [
    set processed-expert processed-expert + 1
  ]
  if tier-name = "coordinator" [
    set processed-coordinator processed-coordinator + 1
  ]

  ask target-case [
    set queue-state "resolved"
    set color 7
    set assigned-agent nobody
    set ycor min-pycor + random-float 3
    set label word "resolved " severity-band
  ]
end

to-report color-for-band [band]
  if band = "low" [ report 45 ]
  if band = "moderate" [ report 25 ]
  if band = "high" [ report 15 ]
  report 125
end

to-report color-for-tier [tier-name]
  if tier-name = "basic" [ report 57 ]
  if tier-name = "expert" [ report 15 ]
  report 105
end

@#$#@#$#@
GRAPHICS-WINDOW
230
10
747
528
-1
-1
15.0
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
20
88
53
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
96
20
164
53
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

BUTTON
20
60
164
93
new-case
spawn-random-case
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
20
110
163
155
LLM Active
llm-ready?
17
1
11

MONITOR
20
160
164
205
New Queue
count cases with [queue-state = "new"]
17
1
11

MONITOR
20
210
164
255
Triaged Queue
count cases with [queue-state = "triaged"]
17
1
11

MONITOR
20
260
164
305
Assigned Queue
count cases with [queue-state = "assigned"]
17
1
11

MONITOR
20
310
164
355
Escalations
escalated-count
17
1
11

MONITOR
20
360
164
405
Done by Basic
processed-basic
17
1
11

MONITOR
20
410
164
455
Done by Expert
processed-expert
17
1
11

MONITOR
20
460
164
505
Done by Coordinator
processed-coordinator
17
1
11

@#$#@#$#@
## Crisis Triage with Tiered Intelligence Coordination

This demo simulates emergency incident flow through three responder tiers:

1. Basic agents handle low complexity cases.
2. Expert agents handle moderate and high severity cases.
3. Coordinators handle critical cases and rebalance misrouted overload.

Each new incident is triaged with `llm:chat-with-template` using `triage-template.yaml`.
Routing then uses `dispatcher-template.yaml` and capacity-aware fallback logic.

### Run

1. Update `demos/crisis-triage/config.txt` with your provider + credentials.
2. Click `setup`.
3. Click `go`.
4. Use `new-case` to inject incidents manually.

If LLM config is unavailable, the model automatically uses deterministic heuristic triage.
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
