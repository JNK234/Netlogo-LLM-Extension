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
- `config.txt` - Local config used by the model

## Prerequisites

1. Build and install the extension
2. Configure valid credentials in `config.txt` for cloud providers, or run Ollama locally
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
