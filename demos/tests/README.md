# Manual Integration Tests (Live Providers)

This directory contains the NetLogo model used for manual, live-provider integration checks.

## Purpose

Use this suite to validate external integration behavior:
- real API credentials
- network connectivity
- provider endpoint compatibility
- provider-specific runtime issues (timeouts, auth failures, model availability)

This suite is not part of default `sbt test`.

## Files

- `tests.nlogox` - Manual test model
- `config.txt.example` - Template with placeholders for all 6 providers
- `config.txt` - Local config used by the model (gitignored, create from template)

## Prerequisites

1. Build and install the extension
2. Create a local config from the template:
   ```
   cp config.txt.example config.txt
   ```
   Then edit `config.txt`, set `provider=` to your chosen provider, and replace the matching `*_api_key=REPLACE_ME` line with a real key. Or run Ollama locally for a no-key option.
3. Ensure network access for cloud providers

## How To Run

1. Open `tests.nlogox` in NetLogo
2. The model loads `config.txt`
3. Run test procedures from the Command Center/buttons

## Relationship To Automated Tests

- Automated tests (`sbt test`) are deterministic and API-free.
- This model is for manual integration verification against real providers.

Run both for release confidence:
1. `sbt test`
2. `demos/tests/tests.nlogox` manual checks
