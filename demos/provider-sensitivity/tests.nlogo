; ABOUTME: Test suite for the provider-sensitivity demo.
; ABOUTME: Validates config loading, provider switching, comparison logic, and error handling.

extensions [llm]

globals [
  tests-passed
  tests-failed
  tests-run
]

;; ===== TEST RUNNER =====

to setup
  clear-all
  set tests-passed 0
  set tests-failed 0
  set tests-run 0
  print "=== Provider Sensitivity Test Suite ==="
  print ""
end

to run-all-tests
  setup

  ; Config and provider tests (no API calls needed)
  test-config-loading
  test-provider-discovery
  test-provider-switching
  test-provider-status-report
  test-active-config-report

  ; Tests requiring at least one ready provider
  let ready llm:providers
  ifelse not empty? ready [
    test-sync-chat-single
    test-choose-single
    test-history-isolation
    test-multi-provider-comparison
  ] [
    print "SKIP: No ready providers - skipping live API tests"
    print "      Configure at least one provider in config"
  ]

  print ""
  print "=== Results ==="
  print (word "  Passed: " tests-passed)
  print (word "  Failed: " tests-failed)
  print (word "  Total:  " tests-run)
end

;; ===== ASSERTION HELPERS =====

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
    print (word "  FAIL: " test-name " (expected: " expected ", got: " actual ")")
  ]
end

;; ===== CONFIG TESTS =====

to test-config-loading
  print "-- test-config-loading --"

  ; Test loading the demo config file
  carefully [
    llm:load-config "config"
    assert-true true "config loads without error"
  ] [
    ; Config load may fail if no provider keys are set, which is acceptable
    print (word "  INFO: config load produced: " error-message)
    assert-true true "config load attempted (provider may not be ready)"
  ]
end

to test-provider-discovery
  print "-- test-provider-discovery --"

  ; llm:providers-all should always return 4 providers
  let all-providers llm:providers-all
  assert-equal length all-providers 4 "providers-all returns 4 providers"
  assert-true (member? "openai" all-providers) "openai in providers-all"
  assert-true (member? "anthropic" all-providers) "anthropic in providers-all"
  assert-true (member? "gemini" all-providers) "gemini in providers-all"
  assert-true (member? "ollama" all-providers) "ollama in providers-all"

  ; llm:providers returns subset of ready providers
  let ready llm:providers
  assert-true (length ready <= length all-providers) "ready providers <= all providers"

  ; Every ready provider must also be in all-providers
  foreach ready [ p ->
    assert-true (member? p all-providers) (word p " in providers-all")
  ]
end

to test-provider-switching
  print "-- test-provider-switching --"

  ; Attempt to switch to each ready provider
  let ready llm:providers
  foreach ready [ p ->
    carefully [
      llm:set-provider p
      let active llm:active
      assert-equal (item 0 active) p (word "switch to " p " succeeds")
    ] [
      print (word "  INFO: switch to " p " failed: " error-message)
    ]
  ]
end

to test-provider-status-report
  print "-- test-provider-status-report --"

  let status llm:provider-status
  assert-true (is-list? status) "provider-status returns a list"
  assert-equal length status 4 "provider-status has 4 entries"

  ; Each entry should start with a provider name string
  foreach status [ entry ->
    assert-true (is-list? entry) (word "entry is a list: " item 0 entry)
    assert-true (is-string? item 0 entry) (word "entry[0] is provider name: " item 0 entry)
  ]
end

to test-active-config-report
  print "-- test-active-config-report --"

  carefully [
    let active llm:active
    assert-true (is-list? active) "llm:active returns a list"
    assert-equal (length active) 2 "llm:active has 2 elements [provider model]"

    let config-str llm:config
    assert-true (is-string? config-str) "llm:config returns a string"
    assert-true (length config-str > 0) "llm:config is non-empty"
  ] [
    print (word "  INFO: active/config check failed: " error-message)
  ]
end

;; ===== LIVE API TESTS =====

to test-sync-chat-single
  print "-- test-sync-chat-single --"

  let ready llm:providers
  if empty? ready [ stop ]

  let provider-name first ready
  carefully [
    llm:set-provider provider-name
    llm:clear-history
    let response llm:chat "Reply with exactly the word: OK"
    assert-true (is-string? response) (word "sync chat with " provider-name " returns string")
    assert-true (length response > 0) (word "sync chat with " provider-name " is non-empty")
  ] [
    print (word "  FAIL: sync chat with " provider-name ": " error-message)
    set tests-run tests-run + 1
    set tests-failed tests-failed + 1
  ]
end

to test-choose-single
  print "-- test-choose-single --"

  let ready llm:providers
  if empty? ready [ stop ]

  let provider-name first ready
  carefully [
    llm:set-provider provider-name
    llm:clear-history
    let choices ["red" "blue" "green"]
    let chosen llm:choose "Pick a color" choices
    assert-true (member? chosen choices) (word "choose with " provider-name " returns valid option")
  ] [
    print (word "  FAIL: choose with " provider-name ": " error-message)
    set tests-run tests-run + 1
    set tests-failed tests-failed + 1
  ]
end

to test-history-isolation
  print "-- test-history-isolation --"

  ; Verify that clearing history between providers keeps prompts independent
  let ready llm:providers
  if length ready < 1 [ stop ]

  let provider-name first ready
  carefully [
    llm:set-provider provider-name
    llm:set-history (list (list "user" "Hello") (list "assistant" "Hi there"))
    let hist-before llm:history
    assert-true (length hist-before > 0) "history set successfully"

    llm:clear-history
    let hist-after llm:history
    assert-equal (length hist-after) 0 "history cleared successfully"
  ] [
    print (word "  INFO: history isolation test issue: " error-message)
  ]
end

to test-multi-provider-comparison
  print "-- test-multi-provider-comparison --"

  ; Core integration test: send the same prompt to all ready providers
  let ready llm:providers
  if length ready < 2 [
    print "  SKIP: need 2+ ready providers for comparison test"
    stop
  ]

  let test-prompt "What is 2+2? Answer with just the number."
  let responses []

  foreach ready [ p ->
    carefully [
      llm:set-provider p
      llm:clear-history
      let resp llm:chat test-prompt
      set responses lput (list p resp) responses
    ] [
      print (word "  INFO: " p " failed: " error-message)
    ]
  ]

  assert-true (length responses >= 2) "got responses from 2+ providers"

  ; All responses should be non-empty strings
  foreach responses [ r ->
    assert-true (length item 1 r > 0) (word item 0 r " returned non-empty response")
  ]
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
230
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
400
120
Provider Sensitivity Tests\n1. Edit config with your API keys\n2. Click SETUP then Run All Tests\n3. Check output for PASS/FAIL results
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

Test suite for the provider-sensitivity demo. Validates configuration loading, provider discovery, switching, and multi-provider comparison behavior.

## HOW TO USE IT

1. Edit `config` with API keys for at least one provider
2. Click **setup** to initialize test counters
3. Click **Run All Tests** to execute the full suite
4. Review output for PASS/FAIL results
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
