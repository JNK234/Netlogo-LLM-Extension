# Demo 1: Emergent Object Discovery (Game of Life)

This demo validates **Paradox 1** from Finzi et al. (2026):

> Deterministic micro-rules can expose extractable macro-structure to a computationally bounded observer.

## Research Link

- Paper: *From Entropy to Epiplexity: Rethinking Information for Computationally Bounded Intelligence* (Finzi, Qiu, Jiang, Izmailov, Kolter, Wilson, 2026)
- arXiv: https://arxiv.org/pdf/2601.03220
- Related notes:
  - `From Entropy to Epiplexity (Finzi et al 2026)`
  - `Epiplexity Paper — NetLogo Demo Concepts (using llm extension).md`
  - `NetLogo Demo Ideas — Index (LLM extension).md`

## What the Model Does

- Runs Conway's Game of Life on a `50x50` grid.
- Seeds known motifs (glider, blinker, block) plus light random background activity.
- Uses one LLM observer with bounded perception (`5x5` local window).
- Each tick the observer:
  1. Labels the local window (`llm:choose`) with one label from:
     - `empty`, `stable`, `oscillator`, `glider-like`, `chaotic`, `unknown`
  2. Predicts next macro event (`llm:chat-with-template`) from:
     - `remain-empty`, `remain-stable`, `oscillation-continues`, `glider-shifts`, `pattern-intensifies`, `pattern-decays`
- Compares label and prediction against hand-coded local ground truth.

## Memory Conditions

- **Bounded**: clears LLM history every tick (`llm:clear-history`).
- **Persistent**: keeps history across ticks.

Hypothesis: persistent memory increases prediction accuracy on the same deterministic system.

## Files

- `game_of_life.nlogo`: NetLogo model.
- `config.txt`: provider/model settings for `llm:load-config`.
- `templates/pattern_label.yaml`: canonical prompt text for label categories (mirrored into `llm:choose` prompt builder in NetLogo code).
- `templates/macro_predict.yaml`: macro-prediction template (used directly).
- `results/`: CSV output + analysis artifacts.
- `tests/test_demo.py`: validation + analysis harness.

## Run Instructions

1. Ensure the extension and provider config are valid.
2. Open `game_of_life.nlogo` in NetLogo.
3. Set `config.txt` API key/provider values.
4. Run either:
   - `run-episode-bounded`
   - `run-episode-persistent`
   - `run-comparison` (recommended)

Output CSVs are written to `results/`.

CSV schema includes:
- `tick`, `observer_x`, `observer_y`, `window_pattern`
- `llm_label`, `llm_prediction`
- `label_accuracy`, `prediction_accuracy`, `memory_mode`
- `llm_provider`, `llm_model`

## Automated Validation

From repo root:

```bash
python3 demos/epiplexity-01-emergent-objects/tests/test_demo.py --strict
```

To overwrite offline baseline artifacts deterministically:

```bash
python3 demos/epiplexity-01-emergent-objects/tests/test_demo.py --strict --refresh-baseline
```

Notes:
- If live NetLogo integration is configured with `pyNetLogo`, set:
  - `EPIPLEXITY_RUN_NETLOGO=1`
  - `NETLOGO_HOME=/path/to/NetLogo`
- Otherwise the harness validates/generates deterministic baseline CSVs for offline analysis.

## Expected Interpretation

- Label accuracy should be broadly similar between modes (local recognition).
- Prediction accuracy should be higher in persistent mode.
- This supports the claim that temporal memory enables extraction/reuse of emergent structure from deterministic dynamics.
