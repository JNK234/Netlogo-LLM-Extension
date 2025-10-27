# Treasure Hunt Simulation - Complete Usage Guide

## Quick Start

### Step 1: Install Requirements

1. **NetLogo 7.0+**: Download from https://ccl.northwestern.edu/netlogo/
2. **LLM Extension**: Build and install (see main README)
3. **LLM Provider**: Choose one option:

   **Option A: Ollama (Recommended for beginners)**
   ```bash
   # Install Ollama from https://ollama.ai
   # Then download a model:
   ollama pull llama3.2
   ```

   **Option B: OpenAI**
   - Get API key from https://platform.openai.com
   - Update `demos/config` with your key

   **Option C: Claude/Gemini**
   - Get API key from respective providers
   - Update `demos/config` with your key

### Step 2: Configure LLM Provider

Edit `demos/config` file:

```ini
# For Ollama (FREE, no API key):
provider=ollama
model=llama3.2:latest

# For OpenAI (requires API key):
#provider=openai
#api_key=sk-your-key-here
#model=gpt-4o-mini
```

### Step 3: Run the Simulation

1. Open `hunter-model.nlogox` or `new-model.nlogox` in NetLogo
2. Click **Setup** button
3. Click **Go** button
4. Watch the magic unfold!

---

## Understanding the Simulation

### The Story

Five AI agents are trapped in a maze. Each possesses only ONE clue about a hidden treasure:

1. **Agent 0**: "The treasure is golden and round like the sun"
2. **Agent 1**: "Look where two main paths cross each other"
3. **Agent 2**: "The special place has coordinates that add up to exactly 15"
4. **Agent 3**: "It only appears when all clues are combined"
5. **Agent 4**: "Find the spot furthest from any wall"

**No single agent can find the treasure alone.** They must:
- Explore the maze using different strategies
- Meet other agents within communication range
- Share knowledge through LLM-powered conversations
- Synthesize insights collaboratively
- Build collective confidence
- Discover the treasure location together

### The Four Acts

**Act I: Initialization**
- Maze is generated using recursive backtracking algorithm
- 5 agents spawn at random locations
- Each receives their unique knowledge fragment
- Exploration strategies are assigned (random, methodical, or wall-follower)

**Act II: Exploration & Communication**
- Agents wander through maze leaving colored trails
- When agents meet (within communication range):
  - Golden glow effect spreads
  - LLM facilitates knowledge exchange
  - Both agents synthesize new insights
  - Confidence levels increase

**Act III: Goal Formation**
- Agents with sufficient learned facts (>1) and confidence (>0.3) analyze their situation
- LLM helps choose next goal:
  - `explore-more`: Keep searching
  - `find-center`: Move toward maze center
  - `find-crossing`: Seek path intersections
  - `search-systematically`: Check current location
  - `gather-more-info`: Find more agents

**Act IV: Treasure Manifestation**
- Agent with high confidence (>threshold) at promising location attempts manifestation
- Collects ALL knowledge from ALL agents
- LLM synthesizes complete treasure description
- Treasure appears as pulsating golden orb
- Celebration effects activate

---

## Interface Controls

### Setup Controls

**num-hunters** (slider: 2-10, default: 5)
- Number of treasure-hunting agents
- More agents = faster knowledge spread, but more crowded

**communication-range** (slider: 1-5, default: 2)
- Distance agents can communicate
- Larger = faster spread, but less realistic
- Smaller = more challenging, requires more meetings

**confidence-threshold** (slider: 0.5-1.0, default: 0.7)
- Minimum confidence to attempt treasure manifestation
- Higher = agents must gather more knowledge
- Lower = faster discovery, but less certain

**default-strategy** (chooser: random/methodical/wall-follower/mixed)
- `random`: Agents move randomly through maze
- `methodical`: Prefer unexplored areas
- `wall-follower`: Follow walls using right-hand rule
- `mixed`: Each agent gets random strategy (recommended)

**llm-config-file** (input: string, default: "demos/config")
- Path to LLM configuration file
- Can use relative or absolute path

**show-trails?** (switch: on/off)
- Display colored agent movement trails
- Beautiful but can clutter visualization

**show-communications?** (switch: on/off)
- Display golden glow when agents communicate
- Shows knowledge transfer visually

### Action Buttons

**setup**
- Generate new maze
- Create agents with knowledge fragments
- Reset all variables

**go**
- Run simulation continuously
- Agents explore, communicate, discover

**go-once**
- Step through one tick at a time
- Useful for debugging

### Monitors

**Treasure Status**
- "Still searching..." or treasure description when found

**Active Hunters**
- Number of agents currently in simulation

**Ticks**
- Time steps elapsed

**Agent Knowledge**
- Summary of each agent's initial clue

### Plots

**Agent Confidence** (blue line)
- Shows average confidence over time
- Should increase as agents communicate
- Plateaus when knowledge spread saturates

**Knowledge Graph** (black line)
- Total learned facts accumulated by all agents
- Exponential growth during active communication phase
- Indicates knowledge spreading efficiency

---

## How It Works (Technical)

### LLM Integration

The simulation uses three types of LLM interactions:

**1. Knowledge Synthesis (llm:chat)**
```netlogo
llm:chat (word combined-info
  ". What can we conclude about finding a treasure? Give me new insights.")
```
- Agents share their clues
- LLM synthesizes new understanding
- Both agents learn the same insight

**2. Goal Selection (llm:choose)**
```netlogo
llm:choose situation-summary possible-goals
```
- Agent describes current situation
- LLM picks best goal from predefined options
- Forces structured decision-making

**3. Treasure Description (llm:chat)**
```netlogo
llm:chat (word "Based on all our clues: " combined-knowledge
  ". What exactly is the treasure and what does it look like?")
```
- Combines all clues from all agents
- LLM creates coherent treasure description
- Poetic synthesis of collective knowledge

### Per-Agent Memory

Each agent maintains separate conversation history:
- Prevents knowledge leakage between agents
- Enables unique perspectives
- LLM builds context over multiple conversations
- Automatically cleaned up when agents disappear

### Emergent Behavior

No hardcoded solutions! Treasure discovery emerges from:
- Random maze generation (different each run)
- Independent agent exploration
- Organic meeting patterns
- LLM-synthesized insights
- Collective confidence building

Same code, different outcomes each time!

---

## Troubleshooting

### "Could not load config file"

**Problem**: Config file not found or invalid path

**Solutions**:
1. Check file exists: `demos/config`
2. Use absolute path in `llm-config-file` input
3. Verify file format (key=value pairs)

### "LLM call failed"

**Problem**: Cannot connect to LLM provider

**For Ollama**:
```bash
# Check if Ollama is running:
curl http://localhost:11434/api/tags

# If not, start Ollama and pull model:
ollama serve
ollama pull llama3.2
```

**For Cloud Providers (OpenAI/Claude/Gemini)**:
1. Verify API key is correct
2. Check internet connection
3. Verify API quota/credits available
4. Increase `timeout_seconds` in config

### Agents Not Communicating

**Problem**: No golden glow effects, no knowledge spread

**Solutions**:
1. Increase `communication-range` (try 3-4)
2. Add more agents (`num-hunters` = 7-10)
3. Enable `show-communications?` to verify
4. Check console output for LLM errors

### Treasure Never Appears

**Problem**: Agents explore but never manifest treasure

**Solutions**:
1. Lower `confidence-threshold` (try 0.6)
2. Increase `communication-range` for more meetings
3. Wait longer (may take 500-1000 ticks)
4. Check LLM is responding (watch console output)
5. Verify LLM timeout is sufficient (increase to 60s)

### Simulation Runs Too Slowly

**Problem**: Each tick takes very long

**Solutions**:
1. Use faster LLM model (Ollama llama3.2, or GPT-4o-mini)
2. Reduce `max_tokens` in config (try 200)
3. Reduce `num-hunters` (try 3-4)
4. Disable `show-trails?` for less rendering
5. Consider using `llm:chat-async` for parallel calls

### LLM Responses Are Poor Quality

**Problem**: Agents make illogical decisions, nonsensical insights

**Solutions**:
1. Use better model (GPT-4o, Claude 3.5 Sonnet, or Gemini 1.5 Pro)
2. Adjust `temperature` (try 0.5 for more focused responses)
3. Increase `max_tokens` (try 500-750)
4. Check prompt engineering in code

---

## Experiments to Try

### Experiment 1: Communication Patterns
- Set `communication-range` to 1 (very close)
- Set `num-hunters` to 10 (many agents)
- Watch how long it takes for knowledge to spread
- Compare to `communication-range` = 5

### Experiment 2: Exploration Strategies
- Set `default-strategy` to each option individually
- Measure time to treasure discovery
- Which strategy is most efficient? Why?

### Experiment 3: Confidence Threshold
- Run with `confidence-threshold` = 0.5 (low)
- Run with `confidence-threshold` = 0.9 (high)
- Does higher threshold lead to better treasure descriptions?

### Experiment 4: LLM Comparison
- Run same scenario with Ollama llama3.2
- Run with GPT-4o-mini
- Run with Claude 3.5 Sonnet
- Compare quality of knowledge synthesis

### Experiment 5: Agent Population
- Try with 2 agents (minimal)
- Try with 10 agents (crowded)
- What's the optimal number for fastest discovery?

### Experiment 6: Maze Complexity
- Modify `maze-width` and `maze-height` in code
- Try 11x11 (small), 21x21 (default), 31x31 (large)
- How does maze size affect discovery time?

---

## Advanced Customization

### Adding New Knowledge Fragments

Edit `assign-knowledge-fragment` in code:

```netlogo
to-report assign-knowledge-fragment
  let fragments [
    "The treasure is golden and round like the sun"
    "Look where two main paths cross each other"
    "Your new clue here"
    "Another new clue here"
  ]
  let my-index who mod length fragments
  report item my-index fragments
end
```

### Customizing LLM Prompts

**Knowledge Synthesis** (line ~426):
```netlogo
set conversation-result llm:chat (word
  "You are a treasure hunter sharing clues. " combined-info
  ". What can we conclude? Be concise and insightful.")
```

**Goal Selection** (line ~466):
```netlogo
set current-goal llm:choose (word
  "You are a treasure hunter. " situation-summary
  " What should you do next?") possible-goals
```

**Treasure Description** (line ~552):
```netlogo
let treasure-description llm:chat (word
  "As a mystical narrator, describe the treasure: " combined-knowledge
  ". Paint a vivid picture in 2-3 sentences.")
```

### Adding Agent Personalities

Add to `treasure-hunters-own`:
```netlogo
treasure-hunters-own [
  ...
  personality  ; "curious", "cautious", "analytical"
]
```

Modify prompts to include personality:
```netlogo
llm:chat (word "You are a " personality " treasure hunter. " ...)
```

### Performance Optimization

Use async for parallel LLM calls:
```netlogo
let response llm:chat-async (word combined-info "...")
; Do other work here
let result runresult response  ; Wait for result when needed
```

---

## Educational Applications

### Computer Science Concepts
- **Distributed Systems**: Agents with partial knowledge
- **Emergent Behavior**: Complex outcomes from simple rules
- **AI Integration**: LLMs as reasoning engines
- **Multi-Agent Systems**: Communication protocols
- **Graph Traversal**: Maze navigation algorithms

### Cognitive Science
- **Collective Intelligence**: Group problem-solving
- **Knowledge Transfer**: Communication effectiveness
- **Confidence Building**: Epistemic certainty
- **Spatial Reasoning**: Location-based puzzles

### Classroom Activities
1. **Predict outcomes**: Which configuration finds treasure fastest?
2. **Design clues**: Create new knowledge fragments that work together
3. **Compare strategies**: Analyze exploration algorithm efficiency
4. **LLM comparison**: Test different AI models' reasoning
5. **Modify rules**: What if agents could forget? Or mislead?

---

## Credits

This simulation demonstrates:
- **NetLogo**: Agent-based modeling platform
- **LLM Extension**: Multi-provider AI integration
- **Collective Intelligence**: Emergent group problem-solving
- **Narrative Computation**: Story-driven simulation design

Developed as part of the NetLogo LLM Extension project.

## Further Reading

- [NetLogo Documentation](https://ccl.northwestern.edu/netlogo/docs/)
- [LLM Extension API Reference](../../docs/API-REFERENCE.md)
- [Multi-Agent Systems](https://en.wikipedia.org/wiki/Multi-agent_system)
- [Collective Intelligence](https://en.wikipedia.org/wiki/Collective_intelligence)
- [Emergent Behavior](https://en.wikipedia.org/wiki/Emergence)
