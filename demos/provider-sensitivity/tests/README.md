# Provider Comparison Tests

This folder contains Demo 3 tests focused on comparing LLM providers under the same prompt.

## Files

- `provider-comparison-tests.nlogo`: NetLogo test model for provider discovery, runtime switching, same-task comparison, and metric capture.

## Running

1. Open `provider-comparison-tests.nlogo` in NetLogo.
2. Ensure `../config-multi-provider.txt` contains provider credentials.
3. Click **Setup**.
4. Click **Run All Tests**.

## Notes

- Live API tests run only for providers returned by `llm:providers`.
- If no providers are ready, discovery tests still run and live checks are skipped.
- Cost checks validate estimation logic (`>= 0`) rather than billing APIs.
