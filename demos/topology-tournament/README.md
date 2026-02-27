# Topology Tournament

Four teams of LLM-powered agents, each wired in a different network topology, race to reach consensus on a shared question. The tournament reveals how network structure shapes collective reasoning.

## Topologies

| Topology | Structure | Edges (n=5) | Character |
|----------|-----------|-------------|-----------|
| **Ring** | Each node connects to 2 neighbors | 5 | Sequential propagation; slow but fair |
| **Star** | One hub connects to all others | 4 | Centralized; hub is bottleneck or accelerator |
| **Mesh** | Every node connects to every other | 10 | Maximum connectivity; high communication load |
| **Tree** | Binary tree with root | 4 | Hierarchical; information flows through levels |

## Quick Start

1. **Configure LLM provider** — edit `demos/config` (or `config` in this folder)
2. **Open** `topology-tournament.nlogo` in NetLogo 7.0+
3. **Click Setup** to build the four team networks
4. **Click Run Round**, then **Go** to start

## Interface Controls

- `agents-per-team` — number of agents per topology (3–8)
- `communication-cooldown` — minimum ticks between conversations per agent
- `llm-config-path` — path to LLM configuration file

## How It Works

Each agent starts with a different belief about what quality is most important for success (efficiency, creativity, collaboration, etc.). Agents only communicate with their direct network neighbors. The LLM mediates each conversation — agents genuinely reason about their partner's argument and update their belief accordingly. The first team where a supermajority agrees on the same position wins the round.

## What to Watch

- **Consensus Progress** plot tracks agreement percentage per team over time
- **Average Confidence** plot shows how certain each team's agents become
- **Scores** monitor tallies cumulative round wins

## Experiments

- Run 10+ rounds with default settings to see which topology wins most often
- Increase `agents-per-team` to 8 — does mesh slow down? Does star hold up?
- Set `communication-cooldown` to 1 (fast) vs 10 (slow) — who benefits?
- Compare Ollama (local) vs OpenAI (cloud) for response quality differences

## Files

| File | Purpose |
|------|---------|
| `topology-tournament.nlogo` | Main NetLogo model |
| `coordinator-template.yaml` | LLM prompt template for consensus evaluation |
| `config` | LLM provider configuration (or use `demos/config`) |
| `README.md` | This file |

## Requirements

- NetLogo 7.0+
- NetLogo LLM Extension (see root BUILD.md)
- An LLM provider: Ollama (free, local), OpenAI, Anthropic, or Gemini

## Educational Value

- **Network Science**: how topology constrains information flow
- **Consensus Dynamics**: emergence of agreement from diverse starting positions
- **LLM-Agent Interaction**: AI-mediated reasoning in multi-agent systems
- **Comparative Analysis**: controlled experiments across network structures
