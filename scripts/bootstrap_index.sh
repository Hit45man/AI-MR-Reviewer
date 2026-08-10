#!/usr/bin/env bash
# Trigger full RAG index after deploy.
set -euo pipefail
BASE_URL="${MR_REVIEWER_URL:-http://localhost:8080}"
curl -sfS -X POST "${BASE_URL}/index" | jq .
echo "Done. Ensure docs/naming-standard.md and docs/platform-standards.md are in a watched repo (or indexed) so standards appear in reviews."
