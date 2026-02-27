# Demo 2: Crisis Triage with Tiered Intelligence Coordination

This demo models a municipal crisis desk where incidents are triaged by an LLM, routed to one of three response tiers, and dynamically escalated when capacity or risk changes.

## What it demonstrates

- Tiered responders: `basic`, `expert`, `coordinator`
- LLM-driven severity assessment via `triage-template.yaml`
- LLM-assisted dispatch recommendation via `dispatcher-template.yaml`
- Capacity-aware fallback routing when a preferred tier is saturated
- Coordinator-triggered escalation for risky or critical in-flight cases
- Automatic heuristic fallback if LLM config/provider is unavailable

## Deliverables

- `crisis-triage.nlogo`: NetLogo simulation model
- `triage-template.yaml`: Severity prompt template
- `dispatcher-template.yaml`: Routing prompt template
- `config.txt`: LLM extension configuration
- `tests/`: Automated validation tests

## Model architecture

### Agent tiers

- `basic-agents`
  - Highest volume, low-complexity workload
  - Lower completion probability for hard cases
- `expert-agents`
  - Moderate/high severity handling
  - Better completion rates on difficult incidents
- `coordinators`
  - Critical incidents and system-level balancing
  - Reassign risky cases from lower tiers

### Incident lifecycle

1. New incident is created (`queue-state = "new"`)
2. Triage step classifies severity (`low/moderate/high/critical`)
3. Dispatch step chooses preferred tier and applies capacity fallback
4. Case is processed by assigned tier
5. Coordinator may reassign active risky cases
6. Resolved incidents are counted per tier

## Files and paths

All files for this demo live in:

`demos/crisis-triage/`

The NetLogo model loads these by relative path:

- `demos/crisis-triage/config.txt`
- `demos/crisis-triage/triage-template.yaml`
- `demos/crisis-triage/dispatcher-template.yaml`

## Run instructions

1. Ensure NetLogo has the `llm` extension available.
2. Configure provider settings in `config.txt`.
3. Open `crisis-triage.nlogo` in NetLogo.
4. Click `setup`.
5. Click `go`.
6. Optionally click `new-case` to inject additional incidents.

## LLM behavior

- Severity is requested using strict output formatting:
  - `SEVERITY: LOW|MODERATE|HIGH|CRITICAL`
- Routing is requested using strict output formatting:
  - `ROUTE: BASIC|EXPERT|COORDINATOR`
- Parser logic in the model extracts these tags and falls back safely when missing.

## Heuristic fallback mode

If LLM config fails to load or provider calls fail:

- `llm-ready?` monitor is `false`
- Severity uses keyword-driven deterministic rules
- Routing uses severity-to-tier defaults + capacity fallback

This keeps the simulation functional offline.

## Test suite

Tests are static validations that do not call external APIs.

Run from repository root:

```bash
python -m unittest discover -s demos/crisis-triage/tests -p "test_*.py" -v
```

Coverage includes:

- Required files present
- NetLogo model includes tiered breeds and key procedures
- Model references both YAML templates and config
- Template variables match model substitution keys
- Config includes required LLM keys
- README contains usage, architecture, and test instructions
