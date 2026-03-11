# Topology Tournament

**MARBLE paper replication**: Demonstrates that mesh topology > hierarchy > chain for multi-agent LLM coordination.

Based on: [MARBLE (2503.01935)](https://arxiv.org/abs/2503.01935)

## How It Works

Three groups of agents, each with a different communication topology, race to converge on a goal:

| Topology | Info Visibility | Noise | Expected Performance |
|----------|----------------|-------|---------------------|
| **Mesh** | Coordinator sees ALL agents | Low (0.1) | Fastest |
| **Hierarchy** | Coordinator sees ~75% via tree | Medium (0.3) | Middle |
| **Chain** | Coordinator sees ~30% via chain | High (0.6) | Slowest |

Each tick, a coordinator agent per topology calls `llm:chat-with-template` to decide the group's collective action. Better topology → better information → better decisions → faster convergence.

## Setup

1. Copy `llm/` extension folder next to this model (or install globally)
2. Edit `config.txt` with your API key:
   ```
   provider=openai
   model=gpt-4o-mini
   api_key=sk-YOUR-KEY-HERE
   temperature=0.3
   ```
3. Open `topology-tournament.nlogo` in NetLogo 7.0+

## Required Interface Widgets

Create these in the NetLogo Interface tab:

- **Slider** `num-agents`: min=5, max=100, default=30, increment=5
- **Slider** `max-ticks`: min=50, max=500, default=200, increment=50
- **Button** `setup`: calls `setup`
- **Button** `go`: calls `go` (forever)
- **Plot** "Average Distance to Goal" with 3 pens:
  - "mesh" (blue): `plot mesh-avg-distance`
  - "hierarchy" (red): `plot hierarchy-avg-distance`
  - "chain" (yellow): `plot chain-avg-distance`
- **Monitors**: `mesh-convergence-tick`, `hierarchy-convergence-tick`, `chain-convergence-tick`

## BehaviorSpace

Import `behaviorspace-config.xml` or create experiment with:
- Variable: `num-agents` ∈ {10, 30, 50, 100}
- Metrics: convergence ticks and LLM calls per topology
- 3 repetitions per configuration

## Analysis

```bash
python analyze-results.py results.csv
```

Generates `topology-tournament-results.png` — line chart of convergence time by topology and agent count.

## Key Design Decisions (Bronze)

- **Information asymmetry** is the core mechanism: mesh coordinators see 100% of agents, hierarchy ~75%, chain ~30%
- **Noise factor** in movement models the quality of coordination: mesh=0.1, hierarchy=0.3, chain=0.6
- **One LLM call per topology per tick** (coordinator only) — keeps costs manageable
- Actions: `move-toward-goal`, `spread-then-converge`, `follow-leader`, `random-walk`
