# Treasure Hunt Simulation - Project Summary

## Overview

This document summarizes the **Emergent Treasure Hunt** simulation, a sophisticated multi-agent AI system demonstrating collective intelligence through LLM-powered collaboration in NetLogo.

## What It Is

Five AI agents are trapped in a procedurally-generated maze. Each agent possesses only ONE clue about a hidden treasure's location and nature. No single agent can find the treasure alone. Through exploration, chance meetings, and LLM-mediated conversations, they must:

1. **Share their fragmentary knowledge**
2. **Synthesize collective understanding**
3. **Build confidence in their conclusions**
4. **Discover the treasure location**
5. **Manifest the treasure through unified knowledge**

## Key Features

### 🤖 AI-Powered Agent Communication
- Each agent maintains independent conversation history
- Natural language knowledge exchange via `llm:chat`
- Emergent insights beyond simple clue combination
- Supports OpenAI, Claude, Gemini, and Ollama

### 🧩 Emergent Problem-Solving
- No hardcoded solutions
- Treasure location discovered through agent collaboration
- Different outcome each run due to:
  - Random maze generation
  - Random agent spawning
  - Stochastic exploration
  - LLM response variability

### 🎨 Rich Visualization
- **Agent size/brightness** increases with confidence
- **Golden glow effects** when agents meet and communicate
- **Colored trails** showing each agent's exploration path
- **Pulsating treasure** with radiating light and sparkles
- **Real-time plots** tracking confidence and knowledge accumulation

### 🧠 Intelligent Behavior
- Three exploration strategies: random, methodical, wall-follower
- Goal-driven behavior: explore, find-center, find-crossing, search-systematically
- LLM-based decision making for goals and location assessment
- Adaptive confidence building

## Implementation Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    NetLogo Simulation                         │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Agent 0    │  │  Agent 1    │  │  Agent 2    │         │
│  │  Clue:      │  │  Clue:      │  │  Clue:      │   ...   │
│  │  "golden    │  │  "paths     │  │  "sum=15"   │         │
│  │   & round"  │  │   cross"    │  │             │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                 │                 │                 │
│         └────────┬────────┴────────┬────────┘                │
│                  │                 │                          │
│                  ▼                 ▼                          │
│         ┌────────────────────────────────┐                  │
│         │   LLM Extension Framework      │                  │
│         │   - Per-agent message history  │                  │
│         │   - llm:chat (synthesis)       │                  │
│         │   - llm:choose (selection)     │                  │
│         │   - Provider abstraction       │                  │
│         └────────────┬───────────────────┘                  │
└──────────────────────┼──────────────────────────────────────┘
                       │
          ┌────────────┴──────────────┐
          │                            │
    ┌─────▼──────┐              ┌─────▼──────┐
    │  Cloud LLM │              │   Ollama   │
    │  Providers │      OR      │   (Local)  │
    │  GPT/Claude│              │  llama3.2  │
    └────────────┘              └────────────┘
```

## The Five Knowledge Fragments

Each agent receives ONE clue:

1. **Agent 0**: "The treasure is golden and round like the sun"
2. **Agent 1**: "Look where two main paths cross each other"
3. **Agent 2**: "The special place has coordinates that add up to exactly 15"
4. **Agent 3**: "It only appears when all clues are combined"
5. **Agent 4**: "Find the spot furthest from any wall"

Only by combining these clues through LLM-synthesized conversations can the agents:
- Understand the treasure's **appearance** (golden, round, sun-like)
- Determine the **location type** (path crossing)
- Calculate the **specific coordinates** (x + y = 15)
- Recognize the **manifestation condition** (collective knowledge required)
- Apply the **spatial constraint** (distance from walls)

## How Collective Intelligence Emerges

### Phase 1: Independent Exploration (Ticks 0-100)
- Agents wander randomly using different strategies
- No knowledge sharing yet
- Confidence = 0 for all agents
- Exploration marks patches as "visited"

### Phase 2: Chance Encounters (Ticks 100-300)
- Agents occasionally meet within communication range
- First conversations exchange base clues
- LLM synthesizes initial insights
- Confidence begins to increase
- Knowledge spreads like an epidemic

### Phase 3: Accelerating Understanding (Ticks 300-600)
- Agents now carry synthesized insights from multiple sources
- Second-order knowledge sharing (A→B, B→C means C learns from A indirectly)
- Goals shift from "explore" to "find-crossing" or "find-center"
- Confidence accelerates exponentially
- Visual effects intensify (larger, brighter agents)

### Phase 4: Convergence & Discovery (Ticks 600+)
- High-confidence agents actively search specific locations
- Multiple agents may attempt manifestation at promising spots
- LLM validates location based on accumulated knowledge
- First agent with sufficient knowledge + confidence + correct location succeeds
- Treasure manifests with celebration effects

## Technical Highlights

### LLM Integration Patterns

**Pattern 1: Knowledge Synthesis**
```netlogo
let result llm:chat (word
  "I know: " my-clues
  ". Partner knows: " partner-clues
  ". What can we conclude about the treasure?")
```
- Both agents learn the synthesis
- Creates emergent insights
- Builds collective understanding

**Pattern 2: Constrained Selection**
```netlogo
let goal llm:choose situation-description [
  "explore-more"
  "find-center"
  "find-crossing"
  "search-systematically"
]
```
- Forces structured decision-making
- Prevents hallucination
- Guarantees valid action

**Pattern 3: Location Validation**
```netlogo
let assessment llm:choose location-info [
  "yes-likely"
  "no-unlikely"
  "need-more-info"
]
```
- LLM evaluates if current location matches clues
- Combines spatial reasoning with NL understanding
- Prevents premature treasure manifestation

### Per-Agent Memory Management

Each agent maintains separate conversation history:
```
Agent 0 history: ["golden and round", "Synthesis: might be a coin", ...]
Agent 1 history: ["paths cross", "Synthesis: look for intersections", ...]
Agent 2 history: ["sum=15", "Synthesis: check coordinates", ...]
```

This enables:
- **Unique perspectives**: Same clue, different contexts
- **Independent reasoning**: No cross-contamination
- **Realistic communication**: Agents build on their own experience
- **Efficient cleanup**: WeakHashMap removes history when agents die

### Maze Generation Algorithm

Uses **Recursive Backtracking** for perfect mazes:
1. Start with all walls
2. Carve passages from (1,1)
3. Recursively visit unvisited neighbors
4. Add meeting areas (3 open spaces)
5. Add complexity (5 random path connections)

Result: Challenging maze with guaranteed path between any two points.

## Performance Optimization

### Minimizing LLM Calls

**Communication cooldown**: 5 ticks between conversations
**Goal analysis threshold**: Only when confidence > 0.3 and learned-facts > 1
**Location checking**: Only when goal = "search-systematically"

Typical simulation: ~50-100 LLM calls total over 1000 ticks

### Token Efficiency

**Concise prompts**: Only essential context included
**max_tokens=500**: Limits response length
**Summarization**: Long histories compressed

### Fallback Mechanisms

Every LLM call has graceful degradation:
```netlogo
carefully [
  ; Try LLM operation
] [
  ; Use simple heuristic if fails
]
```

Ensures simulation never crashes due to:
- API timeouts
- Rate limits
- Network issues
- Invalid responses

## Files Structure

```
demos/emergent-treasure-hunt/
├── README.md                  # Overview and quick start
├── USAGE_GUIDE.md            # Complete user manual (troubleshooting, experiments)
├── IMPLEMENTATION.md         # Technical architecture and code walkthrough
├── interface-widgets.md      # Widget configuration reference
├── hunter-model.nlogox       # Main simulation (recommended)
└── new-model.nlogox          # Alternative version

demos/
└── config                     # LLM provider configuration
```

## Configuration

Edit `demos/config` to choose your LLM provider:

**Ollama (Free, Local, Recommended)**
```ini
provider=ollama
model=llama3.2:latest
base_url=http://localhost:11434
```

**OpenAI (Cloud)**
```ini
provider=openai
api_key=sk-your-key-here
model=gpt-4o-mini
```

**Claude (Cloud)**
```ini
provider=anthropic
api_key=sk-ant-your-key-here
model=claude-3-5-sonnet-20241022
```

**Gemini (Cloud)**
```ini
provider=gemini
api_key=your-key-here
model=gemini-1.5-flash
```

## Running the Simulation

### Prerequisites
1. NetLogo 7.0+ installed
2. LLM Extension built and installed (see main README)
3. LLM provider configured (Ollama is easiest)

### Steps
1. Open `demos/emergent-treasure-hunt/hunter-model.nlogox`
2. Click **Setup** button (generates maze, creates agents)
3. Click **Go** button (starts simulation)
4. Watch as agents:
   - Explore the maze
   - Meet and communicate (golden glow)
   - Build confidence (grow larger/brighter)
   - Discover the treasure (pulsating golden orb)

### Expected Timeline
- **100-300 ticks**: First agent meetings
- **300-600 ticks**: Knowledge spreading phase
- **600-1000 ticks**: Treasure discovery (typical)
- **1000+ ticks**: Rare, indicates configuration issues

## Educational Value

### Computer Science Concepts
- **Multi-agent systems**: Coordination without central control
- **Distributed problem-solving**: No agent has complete information
- **Emergent behavior**: Complex outcomes from simple rules
- **AI integration**: LLMs as reasoning engines
- **Graph algorithms**: Maze generation and navigation

### Cognitive Science
- **Collective intelligence**: Groups solving problems individuals cannot
- **Knowledge transfer**: Communication effectiveness
- **Epistemic certainty**: Confidence building
- **Spatial reasoning**: Location-based puzzle solving

### Software Engineering
- **Error handling**: Graceful degradation with fallbacks
- **API integration**: Multiple provider support
- **State management**: Per-agent conversation history
- **Visualization**: Real-time feedback systems

## Experimental Variations

### Modify Communication Range
```netlogo
; Set to 1: Very limited, slower knowledge spread
; Set to 5: Very broad, faster discovery
communication-range = 2  ; Default
```

### Adjust Confidence Threshold
```netlogo
; Set to 0.5: Faster but less certain discovery
; Set to 0.9: Slower but more thorough
confidence-threshold = 0.7  ; Default
```

### Change Agent Count
```netlogo
; 2 agents: Minimal, very slow
; 5 agents: Default, balanced
; 10 agents: Fast, crowded
num-hunters = 5
```

### Try Different Strategies
- **random**: Unbiased exploration
- **methodical**: Prefers unexplored areas
- **wall-follower**: Systematic coverage
- **mixed**: Each agent different (default)

## Success Metrics

### Knowledge Spread Rate
Plot shows total learned facts over time:
- **Slow rise**: Poor communication (increase range)
- **Exponential rise**: Healthy spread
- **Plateau**: All agents have shared maximum knowledge

### Confidence Trajectory
Plot shows average confidence over time:
- **Stuck at 0**: Agents not meeting (increase range/count)
- **Linear rise**: Steady knowledge accumulation
- **Steep rise then plateau**: Approaching discovery

### Discovery Time
Time to treasure manifestation:
- **< 500 ticks**: Very fast (check if too easy)
- **500-1000 ticks**: Normal range
- **> 1500 ticks**: Slow (check configuration)

## Common Issues & Solutions

### "Could not load config file"
**Solution**: Verify `demos/config` exists, use absolute path

### "LLM call failed"
**Solution**: Check provider is running (Ollama) or API key valid

### Agents not communicating
**Solution**: Increase `communication-range` or `num-hunters`

### Treasure never appears
**Solution**: Lower `confidence-threshold`, increase timeout in config

### Simulation too slow
**Solution**: Use Ollama or GPT-4o-mini, reduce `max_tokens`, fewer agents

## Future Enhancements

### Agent Personalities
Add traits: curious, cautious, analytical
Modify LLM prompts based on personality

### Dynamic Clue Generation
Use LLM to create new clues each run

### Competitive Agents
Add greed parameter: willing to mislead others

### Multiple Treasures
Different clue sets lead to different treasures

### Forgetting Mechanism
Agents forget old facts, requiring refresh

### Conversation Logging
Track who talked to whom, analyze social network

## Conclusion

The Treasure Hunt simulation demonstrates that **sophisticated collective intelligence can emerge from simple per-agent rules combined with powerful language understanding**.

Key insights:
1. **No single agent succeeds alone** - collaboration is essential
2. **LLMs enable rich reasoning** - not just clue concatenation
3. **Emergent behavior is unpredictable** - different every time
4. **Visualization matters** - seeing the story unfold enhances understanding
5. **Robust design** - fallbacks ensure it always works

This is not just a demo—it's a template for building complex AI multi-agent systems with NetLogo.

## Documentation Quick Links

- **[README.md](demos/emergent-treasure-hunt/README.md)** - Overview
- **[USAGE_GUIDE.md](demos/emergent-treasure-hunt/USAGE_GUIDE.md)** - Complete instructions
- **[IMPLEMENTATION.md](demos/emergent-treasure-hunt/IMPLEMENTATION.md)** - Technical details
- **[Main LLM Extension Docs](docs/API-REFERENCE.md)** - API reference

## Getting Help

1. Read the USAGE_GUIDE.md for troubleshooting
2. Check the IMPLEMENTATION.md for technical details
3. Review the main LLM Extension documentation
4. Open an issue on GitHub

---

**Ready to explore collective intelligence? Open NetLogo and let the treasure hunt begin!**
