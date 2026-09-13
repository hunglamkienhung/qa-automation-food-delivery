# Performance tests (Locust)

Load tests for the **mini-eats** service — the performance counterpart to the
functional BDD suite. They drive the same REST API the four apps use (customer,
merchant, driver, admin) under concurrency, validating every response so a wrong
status is a failure, not just a slow success.

## Run

```bash
pip install -r perf/requirements.txt
bash perf/run.sh                 # 40 users, spawn 10/s, 30s, against a fresh mini-eats
bash perf/run.sh 100 20 60s      # heavier: 100 users, 60s
```

`run.sh` seeds a fresh service and runs Locust headless. An interactive web UI
(charts, live control) is available too:

```bash
( cd services/mini-eats && MINI_EATS_DB=/tmp/mini-eats-perf/mini-eats.db bash serve.sh up )
locust -f perf/locustfile.py --host http://127.0.0.1:8130      # then open http://localhost:8089
```

## The traffic model

Three user classes, weighted to a realistic mix:

| Class | Weight | What it does |
|---|---|---|
| `Diner` | 6 | Browses `/restaurants` and a menu; sometimes places an order and tracks it. |
| `Operator` | 2 | Runs one order the whole way — merchant `accept → prepare → ready`, driver `assign → pickup → deliver`. |
| `Admin` | 1 | Polls `/admin/overview`. |

## The pass/fail gate

The locustfile's `quitting` hook exits **non-zero** when a run breaches either
threshold, so `run.sh` doubles as a CI performance gate:

- error ratio > `PERF_MAX_FAIL_RATIO` (default `0.01` — 1%)
- p95 latency > `PERF_MAX_P95_MS` (default `750` ms)

Override them per environment, e.g. `PERF_MAX_P95_MS=400 bash perf/run.sh`.

A local baseline (40 users, 30s, warm SQLite on a laptop) lands around
**300+ req/s, 0 failures, p95 well under 100 ms** — the whole point of an
integer-money, single-file store with no network hops in the hot path.
