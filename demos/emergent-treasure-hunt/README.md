# Emergent Treasure Hunt Demo

## The Story

**"The Collective Mystery of the Lost Treasure"**

This NetLogo simulation tells the story of emergent collective intelligence through a treasure hunting adventure that unfolds in four dramatic acts:

### Act I: The Scattered Knowledge
Five treasure hunters find themselves lost in an ancient maze, each carrying only a fragment of the complete treasure mystery:
- *"The treasure is golden and round like the sun"*
- *"Look where two main paths cross each other"*
- *"The special place has coordinates that add up to exactly 15"*
- *"It only appears when all clues are combined"*
- *"Find the spot furthest from any wall"*

### Act II: The Wandering and Meetings
The hunters explore using different strategies, leaving colorful trails. When they meet, golden light spreads between them as they share knowledge through LLM-powered conversations. Their confidence grows visibly as they learn from each other.

### Act III: The Revelation
As collective understanding emerges, agents develop new goals and search strategies based on their synthesized knowledge, demonstrating collaborative problem-solving.

### Act IV: The Manifestation
When sufficient knowledge combines at the right location with enough confidence, the treasure materializes as a pulsating golden orb surrounded by dancing sparkles.

## The Deeper Meaning

This simulation demonstrates how **no single individual has the complete picture**, but through **communication, trust, and collective reasoning**, groups can solve mysteries impossible for individuals alone. It's a metaphor for scientific discovery, community problem-solving, and the power of shared knowledge.

## Visual Features

- **Agent Visualization**: Size and brightness increase with confidence level
- **Communication Effects**: Golden spreading patterns when agents meet and share knowledge
- **Treasure Animation**: Pulsating golden orb with radiating light and sparkle effects
- **Trail System**: Colorful paths showing each agent's unique exploration journey
- **Maze Environment**: Procedurally generated using recursive backtracking algorithm

## Technical Implementation

- **LLM Integration**: Uses the NetLogo LLM extension for intelligent agent conversations
- **Emergent Behavior**: No hardcoded solutions - treasure discovery emerges from agent interactions
- **Multi-Provider Support**: Works with OpenAI, Claude, Gemini, or Ollama
- **Safe Navigation**: Robust movement system prevents agents from getting stuck
- **Visual Storytelling**: Rich graphical feedback system shows the narrative unfolding

## Files

- `hunter-model.nlogox` - Enhanced simulation model (recommended)
- `new-model.nlogox` - Alternative model version
- `README.md` - This overview document
- `USAGE_GUIDE.md` - Complete step-by-step usage instructions
- `IMPLEMENTATION.md` - Technical implementation details
- `interface-widgets.md` - Widget configuration reference

## Requirements

- NetLogo 7.0+
- NetLogo LLM Extension (see main README for build instructions)
- LLM provider - choose one:
  - **Ollama** (recommended, free, local) - https://ollama.ai
  - **OpenAI** (GPT-4, requires API key)
  - **Anthropic Claude** (requires API key)
  - **Google Gemini** (requires API key)

## Quick Start

1. **Install an LLM provider** (Ollama is easiest):
   ```bash
   # Install Ollama, then:
   ollama pull llama3.2
   ```

2. **Configure the extension**: Edit `demos/config` file with your provider settings

3. **Run the simulation**:
   - Open `hunter-model.nlogox` in NetLogo
   - Click "Setup"
   - Click "Go"
   - Watch the treasure hunt unfold!

4. **Read the guides**:
   - **[USAGE_GUIDE.md](./USAGE_GUIDE.md)** - Complete instructions, troubleshooting, experiments
   - **[IMPLEMENTATION.md](./IMPLEMENTATION.md)** - Technical architecture, code walkthrough

## Educational Value

This demo illustrates key concepts in:
- **Collective Intelligence**: How groups solve problems no individual can
- **Emergent Behavior**: Complex outcomes from simple interactions
- **Knowledge Sharing**: The power of communication and collaboration
- **AI-Mediated Problem Solving**: Using LLMs to enhance agent reasoning
- **Spatial Problem Solving**: Navigation and location-based puzzles
