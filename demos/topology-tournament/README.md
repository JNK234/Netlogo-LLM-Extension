# Demo 1: Topology Tournament

This demo compares how quickly three communication structures coordinate a shared decision:
- `mesh`: everyone connected to everyone
- `hierarchy`: tree-like command structure
- `chain`: linear neighbor-to-neighbor communication

Each topology has its own NetLogo breed and its own coordinator decision each tick.

## Hypothesis

Given equal team size and identical starting beliefs:
- `mesh` should converge fastest because information can propagate in one hop.
- `hierarchy` should converge in the middle because coordination is centralized but bottlenecked by parent-child edges.
- `chain` should converge slowest because influence can only move locally along the line.

## How It Works

1. `setup` builds three groups (`mesh-agents`, `hierarchy-agents`, `chain-agents`) and their topology-specific links.
2. Agents are seeded with mixed initial belief tokens (`COLLECT`, `EXPLORE`, `STABILIZE`).
3. On each `go` tick, each topology invokes:
   - `llm:chat-with-template "demos/topology-tournament/coordinator-template.yaml" ...`
4. The LLM returns one structured action (`HOLD`, `MAJORITY_PUSH`, `PAIR_SWAP`, `SPLIT_REBALANCE`, `BROADCAST_MAJORITY`).
5. The action is applied to that topology's agents.
6. Convergence time is recorded per topology when all agents in that topology share one belief.

## Why NetLogo + Python

- NetLogo is used for agent-based topology simulation, repeatable scheduling (`ticks`), and direct LLM extension integration.
- Python unit tests provide fast static validation in CI without requiring NetLogo GUI/headless runtime.
- This pairing gives quick feedback for model structure while keeping simulation logic in NetLogo.

## Files

- `topology-tournament.nlogo`: main simulation model
- `coordinator-template.yaml`: coordinator prompt contract
- `config.txt`: provider/model/runtime settings
- `tests/test_topology_tournament.py`: unit tests for model/template/config structure

## Run Instructions

1. Add a real API key in `demos/topology-tournament/config.txt`.
2. Open `demos/topology-tournament/topology-tournament.nlogo` in NetLogo.
3. Click `Setup`, then `Go`.
4. Watch convergence monitors:
   - `convergence-time "mesh"`
   - `convergence-time "hierarchy"`
   - `convergence-time "chain"`
   - `winner-topology`

## Test Instructions

From repository root:

```bash
python3 -m unittest discover demos/topology-tournament/tests -p "test_*.py"
```
