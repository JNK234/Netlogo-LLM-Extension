# Crisis Triage Demo Tests

Run from repository root:

```bash
python -m unittest discover -s demos/crisis-triage/tests -p "test_*.py" -v
```

These tests validate:

- Presence of all required demo files
- NetLogo 7 `.nlogox` tiered-agent and triage/dispatch procedure structure
- LLM template variable consistency with model substitutions
- Config key completeness
- README documentation coverage
