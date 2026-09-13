# qa-automation-food-delivery

![Pytest-BDD](https://img.shields.io/badge/Pytest--BDD-tests-0A9EDC?logo=pytest&logoColor=white)
![Cucumber](https://img.shields.io/badge/Cucumber-BDD-23D96C?logo=cucumber&logoColor=white)
![Playwright](https://img.shields.io/badge/Playwright-E2E-2EAD33?logo=playwright&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-store-003B57?logo=sqlite&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![Node](https://img.shields.io/badge/Node-24-5FA04E?logo=nodedotjs&logoColor=white)
[![CI](https://github.com/hunglamkienhung/qa-automation-food-delivery/actions/workflows/ci.yml/badge.svg)](https://github.com/hunglamkienhung/qa-automation-food-delivery/actions/workflows/ci.yml)

QA automation for a food-delivery domain, built as a working system rather than
a slideshow. One delivery platform — **four apps** (customer, merchant, driver,
admin) over one order lifecycle — tested at **every layer it has** (database,
API, and screen) by **two independent stacks** (Node with Cucumber, Python with
pytest-bdd) that read **one** shared set of Gherkin features and must return the
**same verdict for every case**.

Nothing here needs an account, a key, or a paid service. Clone it and it runs.

[Tiếng Việt](README.vi.md) · [Grading](docs/GRADING.md) ·
[Gherkin](docs/GHERKIN.md) · [Queue format](docs/QUEUE-FORMAT.md)

## The two systems under test

| System | Access | What it is |
|---|---|---|
| **mini-eats** | read + write, real DB | A small delivery platform in `services/mini-eats`: one SQLite file, Node standard library only, a REST API backing four apps, and small labelled HTML pages for Playwright. |
| **themealdb.com** | read-only, live | A live recipe API — the meals a restaurant might cook — which nobody here can tune to pass. |

**132 cases**, each with an immutable ID, run in **both** stacks and reconciled
case-by-case. Every layer the platform has is tested at that layer:

| Layer | Target | Cases | Where |
|---|---|---|---|
| DB | mini-eats SQLite, opened directly | 33 | `be/db` |
| API | mini-eats REST — the four apps + the lifecycle | 48 | `be/api` |
| API | TheMealDB public API | 25 | `be/api` |
| FE | mini-eats app surfaces (Playwright) | 26 | `fe/ui` |
| | **Total** | **132** | |

`mini-eats` is where the **write** paths live. An order runs a state machine —
`placed → accepted → preparing → ready → picked_up → delivered`, with
`cancelled`/`rejected` as exits from `placed` — whose transitions are gated by
**who** you are (a driver cannot accept, a merchant cannot deliver) and by
**what state** the order is in (nothing skips a step). Checkout is one
transaction that re-reads stock, refuses to oversell, captures the price at
order time, and is idempotent by key; every transition is audited in
`order_events`; and on delivery the money owed is posted to a `ledger` whose
three credits — the restaurant's payout (subtotal minus commission), the
driver's fee, the platform's commission — **sum to the order total**. The
schema enforces what a platform must not break: one driver per order,
non-negative stock and money, a commission that is a real fraction, a status
and an actor drawn from known sets.

## The two ideas worth a minute

**One Gherkin set, two stacks, one verdict.** `features/*.feature` are shared.
`node/` runs them with Cucumber; `python/` runs the same files with pytest-bdd.
A per-case disagreement is itself a finding — the grading logic is being read
differently in two places — and the build fails on it.

**Failed > Blocked > Passed, and an outage is never a failure.** A case is
Failed only when an observed proposition is wrong. When the live source
(TheMealDB, a down service) cannot be reached, the case is **Blocked**, never
Failed — so a flaky network can never masquerade as a broken kitchen. The CI
gate checks the *shape* of a run against `fixtures/expected-results.json`: it
fails both when a Passed turns Failed (a regression) and when a Failed turns
Passed (a check that stopped checking). See [docs/GRADING.md](docs/GRADING.md).

## Run in 30 seconds

The fastest thing that proves the machinery, needing nothing external:

```bash
# the shared grading core, both stacks
cd core/node && node --test "selftest/*.test.js"
cd ../python && pip install -e . && python -m pytest selftest -q
```

## Run the whole suite

Each step below is exactly what CI runs (`scripts/*.sh`), so it works by hand too.

```bash
# backend, one stack, no browser (seed mini-eats, then DB + API + TheMealDB)
bash scripts/run-be.sh node       # or: python

# the four app surfaces (installs a chromium browser)
bash scripts/run-fe.sh node       # or: python

# the whole suite, then verify the run's shape against the baseline
bash scripts/gate.sh node
```

By hand, one tier at a time:

```bash
( cd services/mini-eats && bash serve.sh up )    # fresh seeded service
cd node && QA_DOMAIN_ROOT=.. npx cucumber-js --tags "@be and @minieats"
```

Prerequisites: Node ≥ 22.13 (for `node:sqlite`) and Python ≥ 3.11. The FE
scripts install their own browser. A devcontainer with all of it is in
[.devcontainer/](.devcontainer/devcontainer.json).

## Layout

```
core/            one grading/queue/report/bugflow core, vendored into this repo
services/
  mini-eats/     SQLite + REST + HTML — the platform under test (four apps)
features/        one Gherkin set, shared by both stacks
fixtures/        testcases.json (IDs) · expected-results.json (shape)
node/  python/   the two stacks: be/{db,api} fe/ui
testcases/       catalogue generated from the features (never drifts)
scripts/         the exact commands CI runs; reproducible by hand
docs/            grading rules, Gherkin conventions, queue format
.github/workflows/ci.yml
```

## Notes

- The DB tier asserts on **deltas** (note the stock, act, check what changed),
  and every scenario spins up fresh customers, carts and orders, so scenarios
  are independent of run order without a per-scenario reset.
- The lifecycle is checked from three sides: the API tier drives the
  transitions and asserts the role gates and error codes; the DB tier reads the
  `order_events` audit and the delivery `ledger` directly; the FE tier reads the
  merchant board, the driver board and the admin overview and compares them with
  the same rows.
- The catalogue (`fixtures/testcases.json` and `testcases/TestCases.md`) is
  generated from the feature files by `testcases/build.js`, so it can never
  drift from what actually runs — CI checks it with `--check`.

## Honest scope

The live-source API tier (TheMealDB) depends on a third party that can be slow
or rate-limit; those cases are written to grade **Blocked**, not Failed, when
that happens. The self-written mini-eats service is fully deterministic and is
where the write paths, the state machine, the database and the harder
invariants are exercised.
