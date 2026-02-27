; ABOUTME: Test harness for comparing provider behavior on the same task.
; ABOUTME: Produces side-by-side latency, estimated cost, and quality summaries.

extensions [llm]

globals [
  ready-providers
  benchmark-results      ; [provider model run-id prompt response latency-ms estimated-cost-usd quality-score]
]

to setup
  clear-all
  set benchmark-results []

  carefully [
    llm:load-config "config-multi-provider.txt"
    print "Loaded config-multi-provider.txt."
  ] [
    print (word "Config load failed: " error-message)
    print "Update config-multi-provider.txt and try setup again."
  ]

  set ready-providers (sort llm:providers)
  print (word "Ready providers: " ready-providers)

  if empty? ready-providers [
    print "No ready providers detected."
    print "Configure at least one provider API key or run Ollama locally."
    stop
  ]

  reset-ticks
end

to run-benchmark
  if empty? ready-providers [
    print "Run setup first."
    stop
  ]

  if benchmark-task = "" [
    print "Enter a benchmark task before running."
    stop
  ]

  set benchmark-results []
  let total-runs (max (list 1 (round runs-per-provider)))
  print ""
  print (word "=== Running benchmark: " total-runs " runs/provider ===")
  print (word "Task: " benchmark-task)

  let run-id 1
  while [run-id <= total-runs] [
    print ""
    print (word "Run " run-id "/" total-runs)

    foreach ready-providers [ provider-name ->
      run-single-task provider-name benchmark-task run-id
    ]

    if include-choose-test? [
      run-choose-task run-id
    ]

    set run-id run-id + 1
    tick
  ]

  print ""
  print "=== Benchmark complete ==="
  show-summary
end

to run-single-task [provider-name prompt-text run-id]
  carefully [
    llm:set-provider provider-name
    let model-name (get-default-model provider-name)
    llm:set-model model-name
    llm:clear-history

    reset-timer
    let response llm:chat prompt-text
    let latency-ms precision (timer * 1000) 0
    let estimated-cost-usd estimate-cost-usd provider-name prompt-text response
    let quality-score score-response prompt-text response

    set benchmark-results lput
      (list provider-name model-name run-id prompt-text response latency-ms estimated-cost-usd quality-score)
      benchmark-results

    print (word "  [" provider-name "/" model-name "] latency=" latency-ms
      "ms cost=$" estimated-cost-usd " quality=" quality-score)
  ] [
    print (word "  [" provider-name "] ERROR: " error-message)
    set benchmark-results lput
      (list provider-name "n/a" run-id prompt-text (word "ERROR: " error-message) 0 0 0)
      benchmark-results
  ]
end

to run-choose-task [run-id]
  let choose-prompt "Pick one direction for next turtle move."
  let options ["north" "south" "east" "west"]

  foreach ready-providers [ provider-name ->
    carefully [
      llm:set-provider provider-name
      llm:set-model (get-default-model provider-name)
      llm:clear-history

      reset-timer
      let chosen llm:choose choose-prompt options
      let latency-ms precision (timer * 1000) 0
      let quality-score ifelse-value (member? chosen options) [1] [0]

      set benchmark-results lput
        (list provider-name (get-default-model provider-name) run-id
          (word "CHOOSE:" choose-prompt) chosen latency-ms 0 quality-score)
        benchmark-results

      print (word "  [" provider-name "] choose=" chosen " latency=" latency-ms "ms")
    ] [
      print (word "  [" provider-name "] choose ERROR: " error-message)
    ]
  ]
end

to show-summary
  print ""
  print "Provider summary (chat task only):"

  foreach ready-providers [ provider-name ->
    let provider-rows filter [ r -> (item 0 r = provider-name) and (not (contains-text? (item 3 r) "CHOOSE:")) ] benchmark-results
    if not empty? provider-rows [
      let avg-latency precision (mean (map [ r -> item 5 r ] provider-rows)) 1
      let avg-cost precision (mean (map [ r -> item 6 r ] provider-rows)) 6
      let avg-quality precision (mean (map [ r -> item 7 r ] provider-rows)) 2
      let sample (truncate-string (item 4 (last provider-rows)) 80)

      print (word "  " provider-name
        " | latency-ms=" avg-latency
        " | est-cost-usd=" avg-cost
        " | quality=" avg-quality
        " | runs=" (length provider-rows))
      print (word "    sample: " sample)
    ]
  ]

  if include-choose-test? [
    print ""
    print "Choose summary:"
    foreach ready-providers [ provider-name ->
      let choose-rows filter [ r -> (item 0 r = provider-name) and (contains-text? (item 3 r) "CHOOSE:") ] benchmark-results
      if not empty? choose-rows [
        let valid-rate precision (mean (map [ r -> item 7 r ] choose-rows)) 2
        print (word "  " provider-name " | valid-choice-rate=" valid-rate " | n=" (length choose-rows))
      ]
    ]
  ]
end

to show-provider-status
  print ""
  print "=== Provider Status ==="
  foreach llm:provider-status [ info ->
    print (word "  " info)
  ]
  print (word "Ready providers: " ready-providers)
  let active llm:active
  print (word "Active: " (item 0 active) " / " (item 1 active))
end

to-report get-default-model [provider-name]
  if provider-name = "openai"    [ report "gpt-4o-mini" ]
  if provider-name = "anthropic" [ report "claude-3-5-haiku-latest" ]
  if provider-name = "gemini"    [ report "gemini-2.0-flash" ]
  if provider-name = "ollama"    [ report "llama3.2" ]
  report "unknown"
end

to-report contains-text? [haystack needle]
  report position needle haystack != false
end

to-report truncate-string [s max-len]
  ifelse length s > max-len [
    report (word substring s 0 max-len "...")
  ] [
    report s
  ]
end

to-report estimate-tokens [text]
  report max (list 1 (round (length text / 4)))
end

to-report provider-pricing [provider-name]
  if provider-name = "openai"    [ report (list 0.00015 0.0006) ]
  if provider-name = "anthropic" [ report (list 0.00025 0.00125) ]
  if provider-name = "gemini"    [ report (list 0.000075 0.0003) ]
  if provider-name = "ollama"    [ report (list 0 0) ]
  report (list 0 0)
end

to-report estimate-cost-usd [provider-name prompt-text response]
  let pricing provider-pricing provider-name
  let in-rate item 0 pricing
  let out-rate item 1 pricing
  let in-tokens estimate-tokens prompt-text
  let out-tokens estimate-tokens response
  report precision (((in-tokens / 1000) * in-rate) + ((out-tokens / 1000) * out-rate)) 6
end

to-report score-response [prompt-text response]
  let p lowercase prompt-text
  let r lowercase response

  if contains-text? p "2+2" [
    ifelse contains-text? r "4" [ report 1 ] [ report 0 ]
  ]

  if contains-text? p "capital of france" [
    ifelse contains-text? r "paris" [ report 1 ] [ report 0 ]
  ]

  ifelse length response > 0 [ report 1 ] [ report 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
420
10
657
248
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
-8
8
-8
8
0
0
1
ticks
30.0

BUTTON
15
10
100
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
110
10
245
43
Run Benchmark
run-benchmark
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
255
10
390
43
Show Summary
show-summary
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
205
195
238
Provider Status
show-provider-status
NIL
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
55
275
88
runs-per-provider
runs-per-provider
1
5
2.0
1
1
NIL
HORIZONTAL

SWITCH
15
95
210
128
include-choose-test?
include-choose-test?
1
1
-1000

INPUTBOX
15
140
405
198
benchmark-task
What is 2+2? Answer with just the number.
1
0
String

TEXTBOX
15
250
405
355
Harness runs the same task against all ready providers.\nUse this to compare latency, estimated cost, and quality.\n1. Set config-multi-provider.txt\n2. Click Setup\n3. Adjust runs-per-provider and task\n4. Run Benchmark then Show Summary
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

A focused harness for provider-to-provider benchmarking on the same task.

## HOW TO USE IT

1. Edit `config-multi-provider.txt` in this folder.
2. Click **setup**.
3. Set **runs-per-provider** and `benchmark-task`.
4. Click **Run Benchmark**.
5. Use **Show Summary** for aggregate metrics.

## OUTPUT METRICS

- `latency-ms`: wall-clock request duration per run.
- `est-cost-usd`: estimated USD based on token heuristics and per-provider rates.
- `quality`: quick heuristic score in [0, 1] (task-dependent).

@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

square
false
0
Rectangle -7500403 true true 30 30 270 270

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99
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
