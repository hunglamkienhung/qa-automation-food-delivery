"""Locust load test for the mini-eats service.

This is the performance counterpart to the functional BDD suite: the same REST
API the customer, merchant, driver and admin apps use, driven under concurrency.
The user classes model the real traffic mix -- lots of browsing, fewer orders,
a slice of full deliveries and admin reads -- and every request validates its
response so a wrong status counts as a failure, not just a slow success.

Run it headless with a pass/fail gate (see perf/run.sh):

    locust -f perf/locustfile.py --headless -u 40 -r 10 -t 30s \
        --host http://127.0.0.1:8130

The `quitting` hook fails the run (non-zero exit) if the error ratio or the p95
latency crosses the thresholds below, so it can gate a pipeline.
"""

from __future__ import annotations

import os
import random

from locust import HttpUser, between, events, task

# Pass/fail thresholds for the headless gate.
MAX_FAIL_RATIO = float(os.environ.get("PERF_MAX_FAIL_RATIO", "0.01"))   # 1%
MAX_P95_MS = float(os.environ.get("PERF_MAX_P95_MS", "750"))

ADMIN_TOKEN = os.environ.get("MINI_EATS_ADMIN_TOKEN", "admin-token")
SEED_DRIVER = "drv_seed_alex"
# Restaurant -> an in-stock, available menu item id (from the seed).
MENU = {1: [1, 2], 2: [5, 6, 7], 3: [8, 9, 10]}


def _post(client, path, name, token=None, json=None, expect=(200, 201)):
    headers = {"authorization": "Bearer " + token} if token else {}
    with client.post(path, json=json, headers=headers, name=name, catch_response=True) as r:
        if r.status_code in expect:
            r.success()
        else:
            r.failure(f"{r.status_code} {r.text[:80]}")
        return r


def _get(client, path, name, token=None):
    headers = {"authorization": "Bearer " + token} if token else {}
    with client.get(path, headers=headers, name=name, catch_response=True) as r:
        if r.status_code == 200:
            r.success()
        else:
            r.failure(f"{r.status_code} {r.text[:80]}")
        return r


class Diner(HttpUser):
    """A customer: mostly browses; sometimes orders and tracks it."""

    weight = 6
    wait_time = between(0.1, 0.5)

    @task(5)
    def browse(self):
        _get(self.client, "/restaurants", "GET /restaurants")
        rid = random.choice(list(MENU))
        _get(self.client, f"/restaurants/{rid}/menu", "GET /restaurants/[id]/menu")

    @task(2)
    def order_and_track(self):
        cust = _post(self.client, "/customers", "POST /customers", json={"name": "Load"})
        if cust.status_code != 201:
            return
        token = cust.json()["token"]
        rid = random.choice(list(MENU))
        cart = _post(self.client, "/carts", "POST /carts", token=token, json={"restaurant_id": rid})
        if cart.status_code != 201:
            return
        ct = cart.json()["token"]
        item = random.choice(MENU[rid])
        _post(self.client, f"/carts/{ct}/items", "POST /carts/[t]/items", token=token, json={"menu_item_id": item, "qty": random.randint(1, 3)})
        order = _post(self.client, "/orders", "POST /orders", token=token, json={"cart_token": ct})
        if order.status_code == 201:
            _get(self.client, f"/orders/{order.json()['id']}", "GET /orders/[id]")


class Operator(HttpUser):
    """A merchant + driver: takes an order the whole way to delivered."""

    weight = 2
    wait_time = between(0.2, 0.8)

    @task
    def full_delivery(self):
        cust = _post(self.client, "/customers", "POST /customers", json={"name": "Op"})
        if cust.status_code != 201:
            return
        token = cust.json()["token"]
        rid = random.choice(list(MENU))
        cart = _post(self.client, "/carts", "POST /carts", token=token, json={"restaurant_id": rid})
        if cart.status_code != 201:
            return
        ct = cart.json()["token"]
        _post(self.client, f"/carts/{ct}/items", "POST /carts/[t]/items", token=token, json={"menu_item_id": random.choice(MENU[rid]), "qty": 1})
        order = _post(self.client, "/orders", "POST /orders", token=token, json={"cart_token": ct})
        if order.status_code != 201:
            return
        oid = order.json()["id"]
        for step in ("accept", "prepare", "ready"):
            _post(self.client, f"/orders/{oid}/{step}", f"POST /orders/[id]/{step}")
        _post(self.client, f"/orders/{oid}/assign", "POST /orders/[id]/assign", token=SEED_DRIVER)
        _post(self.client, f"/orders/{oid}/pickup", "POST /orders/[id]/pickup", token=SEED_DRIVER)
        _post(self.client, f"/orders/{oid}/deliver", "POST /orders/[id]/deliver", token=SEED_DRIVER)


class Admin(HttpUser):
    """The admin dashboard polling its overview."""

    weight = 1
    wait_time = between(0.5, 1.5)

    @task
    def overview(self):
        _get(self.client, "/admin/overview", "GET /admin/overview", token=ADMIN_TOKEN)


@events.quitting.add_listener
def _gate(environment, **_kw):
    stats = environment.stats.total
    p95 = stats.get_response_time_percentile(0.95)
    fail_ratio = stats.fail_ratio
    print(f"\nperf gate: requests={stats.num_requests} fails={stats.num_failures} "
          f"fail_ratio={fail_ratio:.4f} p95={p95}ms rps={stats.total_rps:.1f}")
    reasons = []
    if stats.num_requests == 0:
        reasons.append("no requests were made")
    if fail_ratio > MAX_FAIL_RATIO:
        reasons.append(f"fail ratio {fail_ratio:.4f} > {MAX_FAIL_RATIO}")
    if p95 and p95 > MAX_P95_MS:
        reasons.append(f"p95 {p95}ms > {MAX_P95_MS}ms")
    if reasons:
        print("perf gate FAILED: " + "; ".join(reasons))
        environment.process_exit_code = 1
    else:
        print("perf gate PASSED")
        environment.process_exit_code = 0
