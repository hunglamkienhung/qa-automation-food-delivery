#!/usr/bin/env bash
# The four mini-eats app surfaces (customer, merchant, driver, admin), one
# stack, with a chromium browser. Blocks (never fails) when a screen is
# unavailable.
set -euo pipefail
STACK="${1:-node}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export MINI_EATS_DB="${MINI_EATS_DB:-/tmp/mini-eats/mini-eats.db}"
( cd services/mini-eats && bash serve.sh up )
if [ "$STACK" = node ]; then
  ( cd node && npm install --no-audit --no-fund )
  ( cd node && npx playwright install --with-deps chromium || npx playwright install chromium )
  ( cd node && QA_DOMAIN_ROOT=.. npx cucumber-js --tags "@fe" )
  ( cd node && QA_DOMAIN_ROOT=.. npx qa-report )
else
  python -m venv .venv-ci && . .venv-ci/bin/activate
  ( cd python && pip install -q -r requirements.txt )
  python -m playwright install --with-deps chromium || python -m playwright install chromium
  ( cd python && QA_DOMAIN_ROOT=.. python -m pytest -m "fe" -q ) || true
  ( cd python && QA_DOMAIN_ROOT=.. qa-report )
fi
