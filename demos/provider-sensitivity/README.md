# Demo 3: Provider Sensitivity — Telephone Game

A visual Telephone Game that reveals how different LLM providers drift when paraphrasing the same message through a chain.

## Demo Artifacts

- `provider-sensitivity.nlogox`: Telephone Game ABM demo.
- `config-multi-provider.txt`: Multi-provider config template.
- `tests/test_provider_sensitivity.py`: Python test suite.

## What This Demo Reveals

Each provider chain starts with the same seed message and paraphrases it through a sequence of turtles. The demo exposes:

- **Semantic drift rate**: How quickly meaning erodes across repeated paraphrasing.
- **Detail preservation**: Whether numbers, dates, and proper nouns survive.
- **Tone fidelity**: Whether hedging, metaphor, and balance are maintained.
- **Length behavior**: Whether responses grow, shrink, or stay stable over the chain.

## Setup

1. Open `config-multi-provider.txt` and fill in API keys for the providers you want.
2. For Ollama, run `ollama serve` and pull a model (e.g., `ollama pull llama3.2`).
3. Open `provider-sensitivity.nlogox` in NetLogo 7.0.3.

## Running the Demo

1. Choose a **message-type** (factual, nuanced, instructional, creative, controversial, or custom).
2. Set **chain-length** (3–10). Longer chains amplify drift.
3. Optionally enable **thinking-mode?** to see reasoning traces on one chain.
4. Click **setup** to create the parallel chains.
5. Click **step** to advance one position, or **go-all** to run through all positions.
6. Click **Show Results** for detailed text comparison in the output area.

## Thinking Mode

When `thinking-mode?` is enabled, the first provider's chain uses `llm:chat-with-thinking` instead of `llm:chat`. These turtles appear as stars and their reasoning traces are stored and displayed in the results output.

## Reading the Results

- **Color gradient**: Green = low drift from original, yellow = moderate, red = high.
- **Drift plot**: Shows Jaccard-based semantic drift at each chain position per provider.
- **Length plot**: Shows message character count at each position.
- **Output area**: Full text comparison with drift scores and thinking traces.

## Test Suite

```bash
python -m pytest demos/provider-sensitivity/tests/test_provider_sensitivity.py -v
```

## Notes

- Drift is measured using word-level Jaccard similarity (pure NetLogo, no external dependencies).
- Each paraphrase call uses `llm:clear-history` for stateless, independent prompting.
- Providers without valid keys are automatically skipped during setup.
