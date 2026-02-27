; ABOUTME: Demonstrates provider sensitivity by comparing OpenAI, Anthropic, Gemini, and Ollama on the same prompts.
; ABOUTME: Includes runtime provider switching and side-by-side latency/cost/quality reporting.

extensions [llm]

globals [
  prompt-bank
  current-prompt-index
  comparison-results      ; [provider model prompt response length latency-ms estimated-cost-usd quality-score]
  ready-providers-list
  run-complete?
  active-provider
]

;; ===== SETUP =====

to setup
  clear-all
  set run-complete? false
  set comparison-results []
  set current-prompt-index 0
  set active-provider "none"

  carefully [
    llm:load-config "config-multi-provider.txt"
    print "Loaded config-multi-provider.txt."
  ] [
    print (word "Primary config load failed: " error-message)
    carefully [
      llm:load-config "config"
      print "Loaded fallback config."
    ] [
      print (word "Fallback config load failed: " error-message)
      print "Update config-multi-provider.txt with your provider keys."
    ]
  ]

  refresh-ready-providers
  if empty? ready-providers-list [
    print "WARNING: No providers are ready."
    print "Run llm:provider-help \"openai\" (or another provider) for setup guidance."
    stop
  ]

  set prompt-bank build-prompt-bank
  print (word "Loaded " length prompt-bank " prompts from category: " prompt-category)

  if not empty? ready-providers-list [
    activate-provider (first ready-providers-list)
  ]

  reset-ticks
end

to refresh-ready-providers
  set ready-providers-list sort llm:providers
  print (word "Ready providers: " ready-providers-list)
end

to-report build-prompt-bank
  if prompt-category = "factual" [
    report (list
      "What is the capital of France? Answer in one sentence."
      "Explain photosynthesis in two sentences."
      "What causes ocean tides? Answer briefly."
    )
  ]
  if prompt-category = "creative" [
    report (list
      "Write a haiku about a turtle crossing a road."
      "Invent a name for a cafe that serves only desserts. Give only the name."
      "Describe a sunset in exactly ten words."
    )
  ]
  if prompt-category = "reasoning" [
    report (list
      "If all roses are flowers and some flowers fade quickly, can we conclude all roses fade quickly? Explain in one sentence."
      "A bat and a ball cost $1.10. The bat costs $1 more than the ball. How much does the ball cost? Show your work briefly."
      "Is it possible to fold a piece of paper in half more than seven times? Answer briefly."
    )
  ]
  if prompt-category = "decision" [
    report (list
      "You find a wallet on the street with $200 and an ID. What do you do? Answer in one sentence."
      "You can save five strangers or one close friend. Which do you choose? Explain briefly."
      "Should a self-driving car prioritize passengers or pedestrians? State your position in one sentence."
    )
  ]
  report (list
    "What is the capital of France? Answer in one sentence."
    "Write a haiku about a turtle crossing a road."
    "A bat and a ball cost $1.10. The bat costs $1 more than the ball. How much does the ball cost?"
  )
end

;; ===== MAIN COMPARISON LOOP =====

to go
  if run-complete? [
    print "All prompts tested. Click 'show-results' for the full summary."
    stop
  ]

  if current-prompt-index >= length prompt-bank [
    set run-complete? true
    print "=== Comparison complete ==="
    print (word "Total result rows: " length comparison-results)
    show-results
    stop
  ]

  let current-prompt item current-prompt-index prompt-bank
  print ""
  print (word "=== Prompt " (current-prompt-index + 1) "/" length prompt-bank " ===")
  print (word "Prompt: " current-prompt)
  print ""

  foreach ready-providers-list [ provider-name ->
    run-single-provider provider-name current-prompt
  ]

  set current-prompt-index current-prompt-index + 1
  tick
end

to run-single-provider [provider-name current-prompt]
  carefully [
    llm:set-provider provider-name
    let model-name get-default-model provider-name
    llm:set-model model-name
    llm:clear-history

    reset-timer
    let response llm:chat current-prompt
    let latency-ms precision (timer * 1000) 0
    let resp-length length response
    let estimated-cost-usd estimate-cost-usd provider-name current-prompt response
    let quality-score score-response current-prompt response

    let result (list provider-name model-name current-prompt response resp-length latency-ms estimated-cost-usd quality-score)
    set comparison-results lput result comparison-results

    print (word "  [" provider-name "/" model-name "] len=" resp-length
           " latency=" latency-ms "ms est-cost=$" estimated-cost-usd " quality=" quality-score)
    print (word "    " truncate-string response 120)
  ] [
    print (word "  [" provider-name "] ERROR: " error-message)
    let failed-result (list provider-name "n/a" current-prompt (word "ERROR: " error-message) 0 0 0 0)
    set comparison-results lput failed-result comparison-results
  ]
end

to-report get-default-model [provider-name]
  if provider-name = "openai"    [ report "gpt-4o-mini" ]
  if provider-name = "anthropic" [ report "claude-3-5-haiku-latest" ]
  if provider-name = "gemini"    [ report "gemini-2.0-flash" ]
  if provider-name = "ollama"    [ report "llama3.2" ]
  report "unknown"
end

;; ===== RUNTIME PROVIDER SWITCHING =====

to activate-provider [provider-name]
  carefully [
    llm:set-provider provider-name
    llm:set-model (get-default-model provider-name)
    set active-provider provider-name
    print (word "Active provider set to: " provider-name " / " (get-default-model provider-name))
  ] [
    print (word "Provider switch failed for " provider-name ": " error-message)
  ]
end

to use-openai
  activate-provider "openai"
end

to use-anthropic
  activate-provider "anthropic"
end

to use-gemini
  activate-provider "gemini"
end

to use-ollama
  activate-provider "ollama"
end

to cycle-provider
  if empty? ready-providers-list [
    print "No ready providers to cycle."
    stop
  ]
  let idx position active-provider ready-providers-list
  if idx = false [
    activate-provider (first ready-providers-list)
    stop
  ]
  let next-idx ((idx + 1) mod (length ready-providers-list))
  activate-provider (item next-idx ready-providers-list)
end

;; ===== RESULTS DISPLAY =====

to show-results
  print ""
  print "==============================================================="
  print "Provider Sensitivity Results"
  print "==============================================================="

  let prompt-idx 0
  foreach prompt-bank [ p ->
    print ""
    print (word "Prompt " (prompt-idx + 1) ": " truncate-string p 70)
    foreach comparison-results [ result ->
      let r-provider item 0 result
      let r-model item 1 result
      let r-prompt item 2 result
      let r-response item 3 result
      let r-length item 4 result
      let r-latency item 5 result
      let r-cost item 6 result
      let r-quality item 7 result
      if r-prompt = p [
        print (word "  - " r-provider " (" r-model ") len=" r-length
               " latency=" r-latency "ms cost=$" r-cost " quality=" r-quality)
        print (word "    " truncate-string r-response 100)
      ]
    ]
    set prompt-idx prompt-idx + 1
  ]

  print ""
  print "Summary by provider (avg over successful responses):"
  foreach ready-providers-list [ provider-name ->
    let provider-results filter [ r -> item 0 r = provider-name and item 4 r > 0 ] comparison-results
    if not empty? provider-results [
      let avg-len precision (mean map [ r -> item 4 r ] provider-results) 1
      let avg-latency precision (mean map [ r -> item 5 r ] provider-results) 1
      let avg-cost precision (mean map [ r -> item 6 r ] provider-results) 6
      let avg-quality precision (mean map [ r -> item 7 r ] provider-results) 2
      print (word "  " provider-name
        " | length=" avg-len
        " | latency-ms=" avg-latency
        " | est-cost-usd=" avg-cost
        " | quality=" avg-quality
        " | n=" length provider-results)
    ]
  ]
end

;; ===== CHOOSE COMPARISON =====

to compare-choose
  let choose-prompt "You are a turtle in a simulation. Which direction should you move?"
  let choices ["north" "south" "east" "west"]

  print ""
  print "=== llm:choose Comparison ==="
  print (word "Prompt: " choose-prompt)
  print (word "Choices: " choices)
  print ""

  foreach ready-providers-list [ provider-name ->
    carefully [
      llm:set-provider provider-name
      llm:set-model (get-default-model provider-name)
      llm:clear-history
      reset-timer
      let chosen llm:choose choose-prompt choices
      let latency-ms precision (timer * 1000) 0
      print (word "  " provider-name " chose: " chosen " (" latency-ms "ms)")
    ] [
      print (word "  " provider-name " ERROR: " error-message)
    ]
  ]
  print ""
end

;; ===== SINGLE PROMPT QUICK TEST =====

to compare-single
  if custom-prompt = "" or custom-prompt = "Type a prompt here..." [
    print "Enter a prompt in the input box first."
    stop
  ]

  print ""
  print "=== Custom Prompt Comparison ==="
  print (word "Prompt: " custom-prompt)
  print ""

  foreach ready-providers-list [ provider-name ->
    run-single-provider provider-name custom-prompt
  ]
end

;; ===== PROVIDER STATUS =====

to show-provider-status
  print ""
  print "=== Provider Status ==="
  foreach llm:provider-status [ info ->
    print (word "  " info)
  ]
  print ""
  print (word "Ready:  " llm:providers)
  print (word "All:    " llm:providers-all)
  print (word "Active: " active-provider)
  let active llm:active
  print (word "Engine: " item 0 active " / " item 1 active)
end

;; ===== UTILITIES =====

to-report truncate-string [s max-len]
  ifelse length s > max-len [
    report (word substring s 0 max-len "...")
  ] [
    report s
  ]
end

to-report contains-text? [haystack needle]
  report position needle haystack != false
end

to-report estimate-tokens [text]
  report max (list 1 (round (length text / 4)))
end

to-report provider-pricing [provider-name]
  ; Approximate USD costs per 1K tokens [input output].
  if provider-name = "openai"    [ report (list 0.00015 0.0006) ]
  if provider-name = "anthropic" [ report (list 0.00025 0.00125) ]
  if provider-name = "gemini"    [ report (list 0.000075 0.0003) ]
  if provider-name = "ollama"    [ report (list 0 0) ]
  report (list 0 0)
end

to-report estimate-cost-usd [provider-name prompt response]
  let pricing provider-pricing provider-name
  let in-rate item 0 pricing
  let out-rate item 1 pricing
  let in-tokens estimate-tokens prompt
  let out-tokens estimate-tokens response
  let total-cost ((in-tokens / 1000) * in-rate) + ((out-tokens / 1000) * out-rate)
  report precision total-cost 6
end

to-report score-response [prompt response]
  ; Simple heuristic quality score in [0,1] for quick provider comparison.
  let p lowercase prompt
  let r lowercase response
  let checks 0
  let hits 0

  if contains-text? p "capital of france" [
    set checks checks + 1
    if contains-text? r "paris" [ set hits hits + 1 ]
  ]
  if contains-text? p "photosynthesis" [
    set checks checks + 1
    if ((contains-text? r "sunlight") or (contains-text? r "chlorophyll")) [ set hits hits + 1 ]
  ]
  if contains-text? p "ocean tides" [
    set checks checks + 1
    if contains-text? r "moon" [ set hits hits + 1 ]
  ]
  if contains-text? p "bat and a ball" [
    set checks checks + 1
    if ((contains-text? r "0.05") or (contains-text? r "5 cents") or (contains-text? r "five cents")) [ set hits hits + 1 ]
  ]
  if contains-text? p "wallet" [
    set checks checks + 1
    if ((contains-text? r "return") or (contains-text? r "owner")) [ set hits hits + 1 ]
  ]

  if checks = 0 [
    ifelse length response > 0 [ report 1 ] [ report 0 ]
  ]

  report precision (hits / checks) 2
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
195
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
205
10
290
43
go-all
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

CHOOSER
15
55
195
100
prompt-category
prompt-category
"factual" "creative" "reasoning" "decision"
0

BUTTON
15
115
195
148
Show Results
show-results
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
160
195
193
Compare Choose
compare-choose
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

BUTTON
205
55
335
88
Use OpenAI
use-openai
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
205
90
335
123
Use Anthropic
use-anthropic
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
205
125
335
158
Use Gemini
use-gemini
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
205
160
335
193
Use Ollama
use-ollama
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
205
195
335
228
Cycle Provider
cycle-provider
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
15
250
405
310
custom-prompt
Type a prompt here...
1
0
String

BUTTON
15
320
195
353
Compare Custom
compare-single
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
365
405
460
Provider Sensitivity Demo\nSwitch providers at runtime and compare quality, latency, and estimated cost.\n1. Configure keys in config-multi-provider.txt\n2. Click SETUP, then use provider buttons to switch\n3. Run GO / GO-ALL for side-by-side comparisons\n4. Use Compare Choose and Compare Custom for focused checks
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

A demo that compares how different LLM providers (OpenAI, Anthropic, Gemini, Ollama) respond to the same prompt. Reveals differences in style, length, reasoning, and decision-making across providers.

## HOW IT WORKS

The model maintains a bank of test prompts organized by category (factual, creative, reasoning, decision). On each tick it sends the next prompt to every ready provider and records response length, latency, estimated cost, and a heuristic quality score.

The interface also supports runtime provider switching with dedicated buttons (`Use OpenAI`, `Use Anthropic`, `Use Gemini`, `Use Ollama`, `Cycle Provider`).

## HOW TO USE IT

1. Edit `config-multi-provider.txt` with API keys for the providers you want to compare
2. Click **setup** to load configuration and detect ready providers
3. Use provider buttons to switch active provider at runtime if desired
4. Select a **prompt-category** from the chooser
5. Click **go** (single step) or **go-all** (run through all prompts)
6. Click **Show Results** to inspect quality, latency, cost, and response differences
7. Use **Compare Choose** to test constrained decisions across providers
8. Type a custom prompt in the input box and click **Compare Custom**

## THINGS TO NOTICE

- Response length varies significantly across providers
- Latency and estimated cost can move independently from quality
- Creative prompts usually show the most stylistic divergence
- Reasoning prompts reveal different error patterns and confidence styles
- `llm:choose` can expose directional bias between providers/models

## THINGS TO TRY

- Run the same category multiple times to observe consistency
- Compare a local Ollama model against cloud providers
- Use custom prompts to test domain-specific sensitivity
- Compare an inexpensive fast model against a slower stronger model

## EXTENDING THE MODEL

- Replace heuristic quality scoring with rubric-based evaluation prompts
- Add export to CSV for plotting cost/latency/quality tradeoffs
- Add a turtle-per-provider visualization
- Add repeated trials and confidence intervals for each metric
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
