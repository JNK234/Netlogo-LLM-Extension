# Demo 3: Provider Sensitivity

Compare OpenAI, Anthropic, Gemini, and Ollama on the same prompts from NetLogo.

## Demo Artifacts

- `provider-sensitivity.nlogo`: Main interactive demo with runtime provider switching.
- `test-harness.nlogo`: Same-task benchmark harness with repeated runs.
- `config-multi-provider.txt`: Multi-provider config template.
- `tests/`: Provider comparison tests (`provider-comparison-tests.nlogo`).

## What This Demo Compares

For each provider/model pair, the demo records:

- `quality`: heuristic task score in `[0,1]` (prompt-dependent).
- `latency-ms`: wall-clock response time measured in NetLogo.
- `est-cost-usd`: approximate token-based cost estimate.
- `length`: response character count.

## Setup

1. Open `config-multi-provider.txt`.
2. Fill API keys for cloud providers you want to benchmark.
3. For Ollama, run `ollama serve` and pull the target model (for example `ollama pull llama3.2`).
4. Open either `provider-sensitivity.nlogo` or `test-harness.nlogo` in NetLogo 6.3+.

## Run the Main Demo (`provider-sensitivity.nlogo`)

1. Click **setup**.
2. Use runtime buttons to switch active provider:
   - **Use OpenAI**
   - **Use Anthropic**
   - **Use Gemini**
   - **Use Ollama**
   - **Cycle Provider**
3. Choose a prompt category.
4. Click **go** or **go-all**.
5. Click **Show Results** for side-by-side summary output.

## Run the Benchmark Harness (`test-harness.nlogo`)

Use this model when you need repeatable same-task comparisons.

1. Click **setup**.
2. Set `benchmark-task` to one task used for all providers.
3. Set `runs-per-provider`.
4. Optionally enable `include-choose-test?`.
5. Click **Run Benchmark**.
6. Click **Show Summary**.

## Compare Results: Cost, Latency, Quality

Use these checks when reading summary output:

1. Latency-first: pick providers with the lowest `latency-ms` for real-time agent loops.
2. Cost-first: compare `est-cost-usd` across the same task and run count.
3. Quality floor: reject providers below your minimum quality threshold.
4. Pareto choice: among providers meeting quality floor, pick the cheapest/fastest.

## Testing

Open `tests/provider-comparison-tests.nlogo` and run **Run All Tests**.

Coverage includes:

- provider discovery (`llm:providers`, `llm:providers-all`)
- runtime provider switching
- same-task response comparison
- metric capture (latency and estimated cost)
- `llm:choose` validity checks

## Notes

- Cost values are estimates based on token heuristics and static per-provider pricing assumptions.
- Quality scoring is heuristic by design; tune scoring logic for your domain tasks.
- Providers without valid keys/connectivity are automatically skipped by ready-provider checks.
