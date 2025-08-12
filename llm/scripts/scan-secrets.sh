#!/usr/bin/env bash
set -euo pipefail

# Simple secret scanner for API keys and tokens.
# Exits non-zero if suspicious strings are found.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

FILTER="(REPLACE_ME|your-.*key|example|config-reference|spec\.md)"
PATTERNS='sk-[A-Za-z0-9_-]{20,}|api_key=([^\n#]+)|Authorization: Bearer [A-Za-z0-9._-]{20,}'

MATCHES=$(grep -RInE \
  --exclude-dir .git \
  --exclude-dir target \
  --exclude-dir tmp \
  --exclude-dir tmp_scan \
  --exclude *scan-secrets.sh \
  --binary-files=without-match \
  "$PATTERNS" . || true)

SAFE=$(echo "$MATCHES" | grep -Ev "$FILTER" || true)

if [ -n "$SAFE" ]; then
  echo "Potential secrets detected:\n$SAFE" >&2
  echo "Abort commit. Replace with placeholders or move secrets to untracked config files." >&2
  exit 1
fi

echo "No secrets detected."
exit 0
