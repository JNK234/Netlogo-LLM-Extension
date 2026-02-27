; ABOUTME: Provider comparison tests for Demo 3 (Provider Sensitivity).
; ABOUTME: Validates provider discovery, switching, same-task comparisons, and metric capture.

extensions [llm]

globals [
  tests-run
  tests-passed
  tests-failed
  ready-providers
]

to setup
  clear-all
  set tests-run 0
  set tests-passed 0
  set tests-failed 0
  set ready-providers []

  carefully [
    llm:load-config "../config-multi-provider.txt"
    print "Loaded ../config-multi-provider.txt"
  ] [
    print (word "Config load warning: " error-message)
    carefully [
      llm:load-config "../config"
      print "Loaded fallback ../config"
    ] [
      print (word "Fallback config warning: " error-message)
    ]
  ]

  set ready-providers (sort llm:providers)
  print (word "Ready providers for tests: " ready-providers)
  print ""
end

to run-all-tests
  setup

  test-provider-discovery
  test-provider-switching

  ifelse not empty? ready-providers [
    test-metric-capture
    test-same-task-comparison
    test-choose-valid-option
  ] [
    print "SKIP live tests: no ready providers"
  ]

  print ""
  print "=== Test Results ==="
  print (word "Passed: " tests-passed)
  print (word "Failed: " tests-failed)
  print (word "Total:  " tests-run)
end

; ---------- Assertions ----------

to assert-true [condition test-name]
  set tests-run tests-run + 1
  ifelse condition [
    set tests-passed tests-passed + 1
    print (word "  PASS: " test-name)
  ] [
    set tests-failed tests-failed + 1
    print (word "  FAIL: " test-name)
  ]
end

to assert-equal [actual expected test-name]
  set tests-run tests-run + 1
  ifelse actual = expected [
    set tests-passed tests-passed + 1
    print (word "  PASS: " test-name)
  ] [
    set tests-failed tests-failed + 1
    print (word "  FAIL: " test-name " (expected=" expected ", got=" actual ")")
  ]
end

; ---------- Tests ----------

to test-provider-discovery
  print "-- test-provider-discovery --"
  let all-providers llm:providers-all
  assert-equal (length all-providers) 4 "providers-all returns 4 providers"
  assert-true (member? "openai" all-providers) "openai listed"
  assert-true (member? "anthropic" all-providers) "anthropic listed"
  assert-true (member? "gemini" all-providers) "gemini listed"
  assert-true (member? "ollama" all-providers) "ollama listed"
  assert-true (length ready-providers <= length all-providers) "ready <= all"
end

to test-provider-switching
  print "-- test-provider-switching --"
  foreach ready-providers [ provider-name ->
    carefully [
      llm:set-provider provider-name
      llm:set-model (get-default-model provider-name)
      let active llm:active
      assert-equal (item 0 active) provider-name (word "switch to " provider-name)
    ] [
      assert-true false (word "switch to " provider-name " failed: " error-message)
    ]
  ]
end

to test-metric-capture
  print "-- test-metric-capture --"
  let provider-name first ready-providers

  carefully [
    llm:set-provider provider-name
    llm:set-model (get-default-model provider-name)
    llm:clear-history

    let prompt "Reply with exactly: OK"
    reset-timer
    let response llm:chat prompt
    let latency-ms precision (timer * 1000) 0
    let estimated-cost estimate-cost-usd provider-name prompt response

    assert-true (latency-ms >= 0) (word provider-name " latency captured")
    assert-true (estimated-cost >= 0) (word provider-name " cost estimate captured")
    assert-true (length response > 0) (word provider-name " response non-empty")
  ] [
    assert-true false (word "metric capture failed for " provider-name ": " error-message)
  ]
end

to test-same-task-comparison
  print "-- test-same-task-comparison --"

  if length ready-providers < 2 [
    print "  SKIP: requires at least 2 ready providers"
    stop
  ]

  let prompt "What is 2+2? Answer with only the number."
  let responses []

  foreach ready-providers [ provider-name ->
    carefully [
      llm:set-provider provider-name
      llm:set-model (get-default-model provider-name)
      llm:clear-history
      let response llm:chat prompt
      set responses lput (list provider-name response) responses
    ] [
      print (word "  INFO: " provider-name " error: " error-message)
    ]
  ]

  assert-true (length responses >= 2) "received responses from 2+ providers"

  foreach responses [ row ->
    let provider-name item 0 row
    let response item 1 row
    assert-true (length response > 0) (word provider-name " returned non-empty response")
    assert-true (contains-text? (lowercase response) "4") (word provider-name " answered 2+2 correctly")
  ]
end

to test-choose-valid-option
  print "-- test-choose-valid-option --"

  let provider-name first ready-providers
  let options ["north" "south" "east" "west"]

  carefully [
    llm:set-provider provider-name
    llm:set-model (get-default-model provider-name)
    llm:clear-history
    let choice llm:choose "Pick one direction" options
    assert-true (member? choice options) (word provider-name " choose returns valid option")
  ] [
    assert-true false (word provider-name " choose failed: " error-message)
  ]
end

; ---------- Utility Reporters ----------

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
260
43
Run All Tests
run-all-tests
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
15
55
405
145
Provider comparison tests\n1. Configure ../config-multi-provider.txt\n2. Click Setup then Run All Tests\n3. Live checks run only for ready providers
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

Automated provider comparison checks for Demo 3.

## COVERAGE

- Provider discovery (`llm:providers`, `llm:providers-all`)
- Runtime provider switching
- Same-task responses across providers
- Latency and cost estimation capture
- `llm:choose` option validity

## HOW TO RUN

1. Open this model in NetLogo.
2. Click **Setup**.
3. Click **Run All Tests**.
4. Review PASS/FAIL output in Command Center.

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
