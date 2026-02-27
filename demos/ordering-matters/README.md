# Ordering Matters Demo

Demonstrates that applying identical rules in different orders produces measurably different emergent behavior in agent-based models.

## Concept

Three groups of foraging agents each have the same three behavioral rules:

| Rule | Description |
|------|-------------|
| **SENSE** | Detect nearest food within sensor range |
| **MOVE** | Navigate toward food, follow advice, or random walk |
| **SHARE** | Communicate food locations with nearby agents |

The groups differ **only** in execution order:

| Group | Color | Order | Tendency |
|-------|-------|-------|----------|
| A | Red circles | sense → move → share | Reacts to own observations first |
| B | Blue squares | share → sense → move | Communicates before acting |
| C | Green triangles | move → share → sense | Acts impulsively, reflects later |

## Files

| File | Purpose |
|------|---------|
| `ordering-matters.nlogo` | NetLogo model with interface and BehaviorSpace experiment |
| `rule-inference-template.yaml` | LLM prompt template for inferring rule orderings from data |
| `config` | LLM provider configuration (OpenAI, Anthropic, Gemini, Ollama) |
| `analysis.py` | Python script to analyze exported simulation data |
| `tests/test_analysis.py` | Pytest suite for the analysis script |

## Quick Start

1. Edit `config` with your LLM provider credentials (or disable `use-llm?` in the model)
2. Open `ordering-matters.nlogo` in NetLogo 6.4+
3. Click **setup** then **go-forever**
4. Watch the plot diverge as rule ordering drives different outcomes
5. Click **export-data** to save CSV, then analyze:

```bash
python3 analysis.py ordering-matters-output.csv --plot results.png
```

## Running Without LLM

The model works without any LLM provider. Turn off the `use-llm?` switch and agents will share raw coordinates instead of natural-language messages. This mode is useful for fast batch experiments via BehaviorSpace.

## Analysis

The `analysis.py` script reads exported CSV data and produces:

- Per-group metrics (food collected, food rate, energy efficiency)
- Pairwise effect sizes between groups
- Summary report identifying the best-performing ordering
- Optional comparison plot (`--plot output.png`)

### Running Tests

```bash
cd demos/ordering-matters
python3 -m pytest tests/ -v
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `num-agents` | 18 | Total agents (divided into 3 equal groups) |
| `food-count` | 80 | Initial food patches |
| `sensor-range` | 4 | How far agents can detect food |
| `speed` | 1.0 | Distance agents move per tick |
| `comm-range` | 6 | Range for sharing information |
| `share-interval` | 5 | Ticks between communication attempts |
| `respawn-food?` | on | Whether food regenerates periodically |
| `respawn-interval` | 20 | Ticks between food respawn waves |
