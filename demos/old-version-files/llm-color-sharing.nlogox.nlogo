extensions [llm table string]

globals [
  colors
]

turtles-own [
  name
  favorite-color
  last-message
  conversation-knowledge
]

undirected-link-breed [connections connection]

to setup
  clear-all
  
  ; Load LLM configuration
  llm:load-config "demos/config.txt"
  
  set-default-shape turtles "person"
  
  let names ["Alice" "Ben" "Cindy" "David" "Emily" "Frank"
    "Gina" "Harry" "Isabella" "Jack" "Katie" "Liam"
    "Maggie" "Noah" "Olivia" "Patrick" "Quinn" "Rachel"
    "Samuel" "Tracy" "Ursula" "Vanessa" "William" "Xander"
    "Yvette" "Zack"]
  
  set colors ["red" "blue" "green" "yellow" "orange" "purple"]
  
  create-turtles num-agents [
    fd 10
    set size 2
    set name item who names
    set favorite-color one-of colors
    set color runresult favorite-color
    set last-message ""
    set conversation-knowledge table:make
    
    ; Connect to nearby agents
    create-connections-with min-n-of 2 other turtles [distance myself]
  ]
  
  ; Initialize each agent with their personality and goal
  ask turtles [
    set label (word name ": " favorite-color)
    
    ; Set up initial conversation history with personality
    llm:set-history (list
      (list "system" (word 
        "You are " name " in a social network. "
        "Your favorite color is " favorite-color ". "
        "You are connected to: " (reduce [[s w] -> (word s ", " w)] [name] of link-neighbors) ". "
        "Your goal is to learn everyone's favorite colors through conversation. "
        "Be friendly and curious. Ask questions and share what you learn. "
        "Keep responses to 1-2 short sentences. "
        "When responding, format as JSON: {\"message\": \"your message\", \"learned\": {\"AgentName\": \"color\"}} "
        "Only include agents whose colors you've definitively learned in the 'learned' object."))
    )
  ]
  
  reset-ticks
end

to go
  ask turtles [
    ; Gather messages from neighbors
    let neighbor-messages ""
    ask link-neighbors with [last-message != ""] [
      set neighbor-messages (word neighbor-messages name ": " last-message "\n")
    ]
    
    ; Create prompt for this turn
    let current-prompt (word
      "Recent messages from your neighbors:\n" neighbor-messages
      "\nWhat would you like to say to learn more about everyone's favorite colors? "
      "Remember to respond in JSON format with 'message' and 'learned' fields.")
    
    ; Get LLM response
    carefully [
      let response llm:chat current-prompt
      
      ; Try to parse JSON response
      let parsed-response table:from-json response
      
      ; Extract message
      if table:has-key? parsed-response "message" [
        set last-message table:get parsed-response "message"
        set label word-wrap (word name ": " last-message) 25
      ]
      
      ; Update knowledge about other agents' colors
      if table:has-key? parsed-response "learned" [
        let learned-colors table:get parsed-response "learned"
        foreach table:to-list learned-colors [ color-pair ->
          table:put conversation-knowledge (first color-pair) (last color-pair)
        ]
      ]
      
    ] [
      ; Fallback if JSON parsing fails
      let response llm:chat current-prompt
      set last-message substring response 0 (min (list 50 (length response)))  ; Just take first part as message
      set label word-wrap (word name ": " last-message) 25
    ]
  ]
  
  ; Update visual indicators based on learned knowledge
  ask turtles [
    ; Count how many colors this agent has learned
    let known-colors table:length conversation-knowledge
    
    ; Adjust turtle size to show learning progress
    set size 2 + (known-colors * 0.3)
    
    ; Show knowledge in a tooltip or separate display
    if show-knowledge? [
      let knowledge-text ""
      foreach table:to-list conversation-knowledge [ pair ->
        set knowledge-text (word knowledge-text (first pair) ":" (last pair) " ")
      ]
      if knowledge-text != "" [
        set label (word name "\n" knowledge-text)
      ]
    ]
  ]
  
  tick
end

to-report word-wrap [str len]
  let line ""
  let wrapped ""
  foreach (string:split-on " " str) [ w ->
    if length line + length w > len [
      set wrapped (word wrapped "\n" line)
      set line ""
    ]
    set line string:trim (word line " " w)
  ]
  report string:trim (word wrapped "\n" line)
end

; Reporter to check if all agents have learned all colors
to-report all-knowledge-complete?
  let complete true
  ask turtles [
    ; Each agent should know about (num-agents - 1) other agents
    if table:length conversation-knowledge < (count turtles - 1) [
      set complete false
    ]
  ]
  report complete
end

; Display what each agent has learned
to show-agent-knowledge
  ask turtles [
    print (word name "'s knowledge:")
    foreach table:to-list conversation-knowledge [ pair ->
      print (word "  " (first pair) " likes " (last pair))
    ]
    print ""
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
383
10
1051
679
-1
-1
20.0
1
10
1
1
1
0
0
0
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
5
45
78
78
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
45
175
78
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

SLIDER
5
10
175
43
num-agents
num-agents
2
10
6.0
1
1
NIL
HORIZONTAL

SWITCH
200
10
350
43
show-knowledge?
show-knowledge?
1
1
-1000

BUTTON
200
50
350
83
Show Agent Knowledge
show-agent-knowledge
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
5
90
175
135
Agents Created
count turtles
17
1
11

MONITOR
200
90
350
135
Average Knowledge
mean [table:length conversation-knowledge] of turtles
2
1
11

TEXTBOX
5
145
375
225
This demo shows agents using LLM to learn each other's favorite colors through conversation. Each agent has a name, favorite color, and can talk to connected neighbors. They use the LLM extension to generate contextual responses and track what they learn about others.
11
0.0
1

TEXTBOX
5
235
375
285
Instructions:\n1. Click SETUP to create agents with random colors and connections\n2. Click GO to start conversations (agents will chat each tick)\n3. Toggle 'show-knowledge?' to see what each agent has learned\n4. Use 'Show Agent Knowledge' to print detailed learning to output
11
0.0
1
@#$#@#$#@
## WHAT IS IT?

This model demonstrates how NetLogo agents can use Large Language Models (LLMs) to engage in intelligent conversations and learn from each other. Each agent has a favorite color and tries to discover the favorite colors of all other agents in the network through natural conversation.

## HOW IT WORKS

1. **Agent Setup**: Each agent gets a name, favorite color, and connects to nearby agents
2. **LLM Integration**: Agents use the LLM extension to generate contextual, intelligent responses
3. **Learning Process**: Through conversation, agents track what they learn about others' preferences
4. **Memory Management**: Each agent maintains its own conversation history and knowledge base

The agents use structured JSON responses to separate their conversational messages from their internal knowledge tracking.

## HOW TO USE IT

1. **SETUP**: Creates agents with random names, colors, and network connections
2. **GO**: Runs one conversation round - each agent talks to neighbors
3. **num-agents**: Controls how many agents participate (2-10)
4. **show-knowledge?**: Toggle to display what each agent has learned
5. **Show Agent Knowledge**: Prints detailed learning information to the output area

## THINGS TO NOTICE

- Agents get larger as they learn more (size indicates knowledge)
- Different LLM providers may generate different conversation styles
- Some agents may be more effective at information gathering
- Network topology affects information flow speed

## THINGS TO TRY

- Change the number of agents and observe learning dynamics
- Try different LLM providers (OpenAI, Claude, Gemini, Ollama) in config.txt
- Modify the system prompt to create different agent personalities
- Add more colors or change the learning objective

## EXTENDING THE MODEL

- Add agent movement and dynamic network formation
- Implement different conversation strategies or personalities
- Track conversation efficiency metrics
- Add visual indicators for information flow
- Create specialized roles (gossips, introverts, etc.)

## NETLOGO FEATURES

- Uses the LLM extension for AI-powered agent behavior
- Demonstrates per-agent conversation memory
- Shows JSON parsing for structured LLM responses
- Integrates table extension for knowledge storage
- Uses link breeds for network visualization

## RELATED MODELS

- Communication networks in complex systems
- Information diffusion models
- Social learning simulations
- Multi-agent conversation systems

## CREDITS AND REFERENCES

This model demonstrates the NetLogo LLM Extension capabilities for creating intelligent, conversational agents in agent-based models.
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
