# Testing Guide

## Overview

The project uses two test layers:

1. Automated deterministic tests (`sbt test`)
2. Manual live-provider integration tests (`demos/tests/tests.nlogox`)

Use both, but for different goals.

## Automated Tests (Default)

Run:

```bash
sbt test
```

These tests:
- run in headless NetLogo using `TestLanguage`
- execute `tests.txt`
- require no API keys and no network access
- are deterministic and CI-friendly

### How API-free testing works

- `src/test/Tests.scala` installs a provider factory override before tests.
- The override injects `src/test/DeterministicTestProvider.scala`.
- That provider returns predictable in-memory responses instead of calling external APIs.
- After test execution, the override is removed.

### Core behavior covered

- Configuration primitives (`set-provider`, `set-api-key`, `load-config`, `active`, `config`)
- Provider metadata primitives (`providers`, `providers-all`, `provider-status`, `provider-help`, `list-models`)
- History primitives (`history`, `set-history`, `clear-history`)
- Chat flow (`chat`, `chat-async`, `runresult`)
- Choice flow (`choose`)
- Template flow (`chat-with-template`, variable substitution, history behavior)
- Per-agent history isolation

### Not covered by automated tests

- Real provider authentication validity
- Network timeouts/rate limits/provider outages
- Upstream API contract changes
- Model quality/correctness of generated content

## Manual Integration Tests (Live APIs)

Use `demos/tests/tests.nlogox` when you want to verify real providers end-to-end.

These tests do require:
- valid provider credentials for cloud providers, or
- a running Ollama server for local provider tests

Suggested usage:
- run automated tests first (`sbt test`)
- run manual integration checks before releases or when changing provider adapters

## Git Automation

### CI on every push and pull request

The repository includes `.github/workflows/ci.yml`.

It runs `sbt test` automatically on:
- every push
- every pull request

Recommended repository setting:
- enable branch protection and require the `Core Tests` check before merge

### Optional local push gate

The repository also includes `.githooks/pre-push` to run `sbt test` before each push.

Enable repository hooks once:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push
```

Temporarily skip local push-time tests:

```bash
SKIP_LOCAL_TESTS=1 git push
```

## Future Live Smoke Tests (API-based)

For cloud-provider smoke tests you will need real API keys in CI secrets.

Typical setup later:
- separate workflow (manual trigger and/or nightly schedule)
- secrets like `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`
- not required for normal PR merges (to avoid flaky/costly gating)
