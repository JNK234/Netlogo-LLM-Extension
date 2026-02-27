# Demo 5: Ordering Matters

This demo tests whether LLM rule learning depends on **trajectory row ordering**.

The same underlying trajectory log is shown to the LLM in three views:
- `forward`: chronological order
- `reversed`: reverse chronological order
- `shuffled`: random permutation

The LLM is asked to infer the behavioral rule that generated the trajectories.
`analysis.py` then measures how much inferred rules diverge across orderings.

## Files

- `ordering-matters.nlogo`: NetLogo simulation + ordering/inference/export workflow
- `rule-inference-template.yaml`: prompt template used for rule inference
- `config.txt`: LLM provider settings
- `analysis.py`: rule-divergence analysis + JSON/plot output
- `tests/test_analysis.py`: validation for loader/scoring/report/plot logic
- `results/`: sample inference data, summaries, and plot outputs

## Model Workflow

1. `setup`
- Initializes food and agents.
- Agents follow one hidden policy: seek food, avoid local crowding, preserve momentum.

2. `go` / `go-forever`
- Runs simulation and logs trajectory rows: `tick, agent, x, y, heading, energy, food`.

3. `infer-rules`
- Builds 3 trajectory presentations: forward/reversed/shuffled.
- Sends each to the same YAML template.
- Stores one inferred rule per ordering.

4. `export-data`
- Writes trajectories to `results/<run>-trajectories.csv`.
- Writes inferred rules to `results/<run>-inference.csv`.

## Configure LLM

Edit `config.txt` and choose one provider block.

Default file includes examples for:
- OpenAI
- Anthropic
- Gemini
- Ollama

If you disable `use-llm?` in NetLogo, inference uses a deterministic baseline text (useful for dry runs).

## Analysis

Run analysis on any exported inference CSV:

```bash
cd demos/ordering-matters
python3 analysis.py results/sample-inference.csv \
  --json results/analysis-summary.json \
  --plot results/rule-similarity.png
```

### Metrics

- `jaccard`: token overlap of normalized inferred rules
- `sequence`: string-order similarity (SequenceMatcher)
- `combined`: mean of jaccard + sequence
- `order_dependency_score`: `1 - average(combined_pairwise_similarity)`

Interpretation:
- Higher `order_dependency_score` => stronger dependence on ordering
- `is_order_sensitive` is true when score exceeds threshold (`--threshold`, default `0.35`)

## Tests

```bash
cd demos/ordering-matters
python3 -m pytest tests -q
```

## Suggested Experiment Protocol

1. Run 20+ simulation seeds.
2. Export one inference CSV per run.
3. Analyze each run via `analysis.py`.
4. Aggregate `order_dependency_score` distributions.
5. Compare across model families (e.g., GPT/Claude/Gemini/Ollama).

## Notes

- This demo measures **inference sensitivity**, not simulator sensitivity.
- Forward/reversed/shuffled use identical trajectory content; only row order changes.
