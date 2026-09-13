#!/usr/bin/env bash
# Seed a fresh mini-eats, then run the food-delivery BE tiers (DB + API + live
# TheMealDB) for one stack. No browser.
set -euo pipefail
STACK="${1:-node}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export MINI_EATS_DB="${MINI_EATS_DB:-/tmp/mini-eats/mini-eats.db}"
( cd services/mini-eats && bash serve.sh up )
if [ "$STACK" = node ]; then
  ( cd node && npm install --no-audit --no-fund )
  ( cd node && QA_DOMAIN_ROOT=.. npx cucumber-js --tags "@be" )
  ( cd node && QA_DOMAIN_ROOT=.. npx qa-report )
else
  python -m venv .venv-ci && . .venv-ci/bin/activate
  ( cd python && pip install -q -r requirements.txt )
  ( cd python && QA_DOMAIN_ROOT=.. python -m pytest -m "be" -q ) || true
  ( cd python && QA_DOMAIN_ROOT=.. qa-report )
fi
