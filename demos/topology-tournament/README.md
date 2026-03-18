# Demo 1: Topology Tournament

This demo compares how quickly three communication structures reach consensus when each agent can only see its direct neighbors:
- `mesh`: everyone connected to everyone (degree n-1)
- `hierarchy`: tree-like parent-child structure (degree 1-3)
- `chain`: linear neighbor-to-neighbor communication (degree 1-2)

Each agent independently observes its `link-neighbors` and uses `llm:choose` to pick a belief. Topology genuinely constrains information flow — mesh agents see all peers, chain agents see at most two.

## Hypothesis

Inspired by the MARBLE paper (arXiv:2503.01935) on how network topology affects multi-agent LLM convergence:
- `mesh` should converge fastest because each agent sees all peers (degree n-1) — full information every tick.
- `hierarchy` should converge in the middle because agents near the root see more neighbors, but leaf agents see only their parent.
- `chain` should converge slowest because each agent sees at most 2 neighbors — information propagates one hop per tick.

## How It Works

1. `setup` builds three groups (`mesh-agents`, `hierarchy-agents`, `chain-agents`) and their topology-specific links.
2. Agents are seeded with mixed initial belief tokens (`COLLECT`, `EXPLORE`, `STABILIZE`).
3. Each tick uses **simultaneous update**: all agents snapshot their beliefs, then each unconverged agent:
   - Gathers its `link-neighbors`' snapshotted beliefs
   - **LLM mode**: calls `llm:set-history` with a per-agent system prompt, then `llm:choose` to pick from belief options
   - **Deterministic mode**: applies local majority rule (self + neighbors)
4. Convergence time is recorded per topology when all agents in that topology share one belief.

## Why Topology Matters

The key insight is that topology constrains what each agent can observe:
- **Mesh** agents have degree n-1: they see every other agent's belief, so majority information is immediately available.
- **Hierarchy** agents have degree 1-3: root sees all children, but leaf agents only see their parent.
- **Chain** agents have degree 1-2: endpoints see one neighbor, middle agents see two. Information must propagate hop-by-hop.

This means the same decision rule (local majority) produces different convergence speeds purely because of network structure.

## Files

- `topology-tournament.nlogox`: main simulation model (NetLogo 7.x XML format)
- `config.txt`: provider/model/runtime settings

## Widgets

| Widget | Purpose |
|--------|---------|
| **Setup** button | Initialize topologies and seed beliefs |
| **Go** button | Continuous execution (forever) |
| **Step** button | Single-tick execution |
| **agents-per-topology** slider | Number of agents per topology (3–12) |
| **max-ticks** slider | Maximum ticks before tournament ends (20–400) |
| **llm-config-path** input | Path to LLM config file |
| **use-llm?** switch | Toggle LLM vs deterministic per-agent mode |
| **LLM Status** monitor | Shows "Connected" or "Deterministic" |
| **Winner** monitor | Winning topology name |
| **Status** monitor | Summary of convergence times and winner |
| **Mesh/Hierarchy/Chain Convergence** monitors | Tick at which each topology converged |
| **Mesh/Hierarchy/Chain Agreement %** monitors | Real-time agreement percentage per topology |
| **Agreement by Topology** plot | Convergence curves over time |

## Run Instructions

1. Add a real API key in `demos/topology-tournament/config.txt`.
2. Open `demos/topology-tournament/topology-tournament.nlogox` in NetLogo 7.
3. Click `Setup`, then `Go` (or use `Step` for single-tick execution).
4. Toggle `use-llm?` to compare LLM-driven vs deterministic per-agent decisions.
5. Watch convergence monitors and the agreement plot.

