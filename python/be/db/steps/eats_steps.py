"""Steps for be-minieats-db.feature and the shared "drive the service" Givens.
Mirror of node/be/db/steps/eats.steps.js -- a plugin module.

Isolation is by delta, not reset. The lifecycle is a state machine audited in
order_events; on delivery the money owed is posted to a ledger that sums to the
order total. All quantities are ints, so plain {int:d} parsers suffice.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from pytest_bdd import given, parsers, then, when

from be.api.venues.minieats import ApiUnreachable, MiniEats
from be.db.store import DbUnreachable, Store, throwaway

eats = MiniEats()
UNREACHABLE = (DbUnreachable, ApiUnreachable)
SEED = Path(__file__).resolve().parents[4] / "services" / "mini-eats" / "db" / "seed.sql"


@pytest.fixture(autouse=True)
def eats_scenario(request, qa):
    if request.node.get_closest_marker("minieats") is None:
        yield
        return
    qa.store = None
    qa.eats = eats
    qa.buyer = None
    qa.cart_token = None
    qa.order_id = None
    qa.noted = {}
    qa.last = None
    qa.api = None
    qa.tmp = None
    yield
    if qa.tmp is not None:
        qa.tmp.close()
    if qa.store is not None:
        qa.store.close()


def act(qa, fn):
    if qa.source_error:
        return None
    try:
        return fn()
    except UNREACHABLE as err:
        qa.source_error = str(err)
        return None


def check(qa, description, fn):
    if qa.source_error:
        qa.unobservable(description, "the source could not be reached -- " + qa.source_error)
        return
    try:
        passed, detail = fn()
    except UNREACHABLE as err:
        qa.unobservable(description, str(err))
        return
    qa.check(description, passed, detail)


def order_of(qa):
    return qa.last["body"] if qa.last and qa.last.get("status") == 201 else None


# ---------------------------------------------------------------- Background


@given("the store is open and the service is reachable")
def store_open(qa):
    if qa.source_error:
        return
    try:
        qa.store = Store()
    except DbUnreachable as err:
        qa.source_error = str(err)
        return
    r = act(qa, lambda: eats.get("/restaurants"))
    if qa.source_error:
        return
    if not r or r["status"] != 200:
        qa.source_error = "mini-eats did not answer /restaurants"
    qa.evidence("storeFile", str(qa.store.file))


# ---------------------------------------------------------------- drive the service


@given(parsers.parse("a customer with a cart at restaurant {rid:d}"))
def customer_with_cart(qa, rid):
    def go():
        qa.buyer = eats.new_customer()
        qa.cart_token = eats.open_cart(qa.buyer["token"], rid)
    act(qa, go)


def add_to_cart(qa, qty, iid):
    def go():
        r = eats.add_item(qa.buyer["token"], qa.cart_token, iid, qty)
        if r["status"] != 200:
            raise RuntimeError("add item failed: " + str(r["status"]) + " " + r["text"])
    act(qa, go)


@given(parsers.parse("the cart holds {qty:d} of item {iid:d}"))
def cart_holds(qa, qty, iid):
    add_to_cart(qa, qty, iid)


@given(parsers.parse("the cart holds {q1:d} of item {i1:d} and {q2:d} of item {i2:d}"))
def cart_holds2(qa, q1, i1, q2, i2):
    add_to_cart(qa, q1, i1)
    add_to_cart(qa, q2, i2)


@given(parsers.parse("the cart holds {q1:d} of item {i1:d} and {q2:d} of item {i2:d} and {q3:d} of item {i3:d}"))
def cart_holds3(qa, q1, i1, q2, i2, q3, i3):
    add_to_cart(qa, q1, i1)
    add_to_cart(qa, q2, i2)
    add_to_cart(qa, q3, i3)


@given(parsers.parse("the stock of item {iid:d} is noted"))
def note_stock(qa, iid):
    if qa.store:
        qa.noted[f"stock.{iid}"] = qa.store.get("SELECT stock FROM menu_items WHERE id = ?", iid)["stock"]


@given("the order count is noted")
def note_orders(qa):
    if qa.store:
        qa.noted["orders"] = qa.store.count("orders")


def do_checkout(qa, body):
    def go():
        qa.last = eats.checkout(qa.buyer["token"], {"cart_token": qa.cart_token, **body})
        qa.api = qa.last
        if qa.last["status"] == 201:
            qa.order_id = qa.last["body"]["id"]
        return qa.last
    return act(qa, go)


@when("the customer checks out")
def checks_out(qa):
    do_checkout(qa, {})


@when(parsers.parse('the customer checks out with idempotency key "{key}"'))
def checks_out_key(qa, key):
    qa.noted["firstOrder"] = do_checkout(qa, {"idempotency_key": key})


@when(parsers.parse('the customer checks out again with idempotency key "{key}"'))
def checks_out_key2(qa, key):
    qa.noted["secondOrder"] = do_checkout(qa, {"idempotency_key": key})


@when(parsers.parse("the customer tries to order {qty:d} of item {iid:d}"))
def tries_order(qa, qty, iid):
    def go():
        r = eats.add_item(qa.buyer["token"], qa.cart_token, iid, qty)
        qa.last = eats.checkout(qa.buyer["token"], {"cart_token": qa.cart_token}) if r["status"] == 200 else r
        qa.api = qa.last
    act(qa, go)


def place_order(qa, rid, lines):
    def go():
        qa.buyer = eats.new_customer()
        cart = eats.open_cart(qa.buyer["token"], rid)
        qa.cart_token = cart
        for qty, iid in lines:
            a = eats.add_item(qa.buyer["token"], cart, iid, qty)
            if a["status"] != 200:
                raise RuntimeError("add item: " + a["text"])
        qa.last = eats.checkout(qa.buyer["token"], {"cart_token": cart})
        if qa.last["status"] != 201:
            raise RuntimeError("checkout: " + qa.last["text"])
        qa.order_id = qa.last["body"]["id"]
    act(qa, go)


@given(parsers.parse("a placed order of {qty:d} of item {iid:d} at restaurant {rid:d}"))
def placed_order(qa, qty, iid, rid):
    place_order(qa, rid, [(qty, iid)])


@given(parsers.parse("a delivered order of {qty:d} of item {iid:d} at restaurant {rid:d}"))
def delivered_order(qa, qty, iid, rid):
    place_order(qa, rid, [(qty, iid)])

    def go():
        oid = qa.order_id
        for step, tok in [("accept", eats.seed_merchant), ("prepare", eats.seed_merchant), ("ready", eats.seed_merchant), ("assign", eats.seed_driver), ("pickup", eats.seed_driver), ("deliver", eats.seed_driver)]:
            r = eats.post(f"/orders/{oid}/{step}", token=tok) if tok else eats.post(f"/orders/{oid}/{step}")
            if r["status"] != 200:
                raise RuntimeError(step + " failed: " + str(r["status"]) + " " + r["text"])
    act(qa, go)


@when("the merchant accepts the order")
def merchant_accepts(qa):
    def go():
        qa.last = eats.post(f"/orders/{qa.order_id}/accept", token=eats.seed_merchant)
        qa.api = qa.last
    act(qa, go)


@when("the merchant rejects the order")
def merchant_rejects(qa):
    def go():
        qa.last = eats.post(f"/orders/{qa.order_id}/reject", token=eats.seed_merchant)
        qa.api = qa.last
    act(qa, go)


@when("the customer cancels the order")
def customer_cancels(qa):
    def go():
        qa.last = eats.post(f"/orders/{qa.order_id}/cancel", token=qa.buyer["token"])
        qa.api = qa.last
    act(qa, go)


# ---------------------------------------------------------------- schema (throwaway)


@then(parsers.re(r"the store has tables (?P<lst>.+)"))
def store_has_tables(qa, lst):
    want = [t.strip() for t in lst.split(",")]

    def ev():
        have = qa.store.tables()
        missing = [t for t in want if t not in have]
        return (not missing, "missing " + ", ".join(missing) if missing else f"{len(have)} tables")
    check(qa, "store has the documented tables", ev)


@given("a throwaway database with the schema applied")
def throwaway_db(qa):
    qa.tmp = throwaway()
    qa.tmp.execute("INSERT INTO restaurants (id, name, cuisine, commission_bps, active) VALUES (1, 'R', 'C', 2000, 1)")
    qa.tmp.execute("INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (1, 1, 'M', 'Cat', 100, 10, 1)")
    qa.tmp.execute("INSERT INTO customers (id, name, token, created_at) VALUES (1, 'C', 'ctok', 1)")
    qa.tmp.execute("INSERT INTO drivers (id, name, token, status, created_at) VALUES (1, 'D', 'dtok', 'available', 1)")
    qa.tmp.execute("INSERT INTO carts (id, token, customer_id, restaurant_id, status, created_at) VALUES (1, 't', 1, 1, 'open', 1)")
    qa.tmp.execute("INSERT INTO orders (id, customer_id, restaurant_id, subtotal_cents, delivery_fee_cents, total_cents, created_at) VALUES (1, 1, 1, 100, 300, 400, 1)")


@given("a throwaway database with the schema and seed applied")
def throwaway_seeded(qa):
    qa.tmp = throwaway()
    qa.tmp.executescript(SEED.read_text(encoding="utf-8"))


def _fails(db, sql, params, needle):
    import sqlite3
    try:
        db.execute(sql, params)
        return (False, "insert succeeded")
    except sqlite3.Error as err:
        return (needle in str(err), str(err))


@then("inserting two menu items with the same name on one restaurant fails on the second")
def menu_name_unique(qa):
    def ev():
        a = _fails(qa.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (2,1,'DUP','C',1,1,1)", (), "\0")
        if a[1] != "insert succeeded":
            return (False, "first: " + a[1])
        return _fails(qa.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (3,1,'DUP','C',1,1,1)", (), "UNIQUE constraint failed: menu_items.restaurant_id, menu_items.name")
    qa.observe("menu name UNIQUE per restaurant", ev)


@then("inserting an order_items row for a missing order fails a FOREIGN KEY")
def oi_order_fk(qa):
    qa.observe("order_items.order_id FK", lambda: _fails(qa.tmp, "INSERT INTO order_items (order_id, menu_item_id, qty, price_cents) VALUES (999,1,1,1)", (), "FOREIGN KEY constraint failed"))


@then("inserting an order_items row for a missing menu item fails a FOREIGN KEY")
def oi_item_fk(qa):
    qa.observe("order_items.menu_item_id FK", lambda: _fails(qa.tmp, "INSERT INTO order_items (order_id, menu_item_id, qty, price_cents) VALUES (1,999,1,1)", (), "FOREIGN KEY constraint failed"))


@then("inserting a menu item with negative price fails a CHECK")
def neg_price(qa):
    qa.observe("price_cents >= 0", lambda: _fails(qa.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (4,1,'N1','C',-1,1,1)", (), "CHECK constraint failed"))


@then("inserting a menu item with negative stock fails a CHECK")
def neg_stock(qa):
    qa.observe("stock >= 0", lambda: _fails(qa.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (5,1,'N2','C',1,-1,1)", (), "CHECK constraint failed"))


@then("inserting a cart item with zero quantity fails a CHECK")
def zero_qty(qa):
    qa.observe("qty > 0", lambda: _fails(qa.tmp, "INSERT INTO cart_items (cart_id, menu_item_id, qty) VALUES (1,1,0)", (), "CHECK constraint failed"))


@then(parsers.parse('inserting an order with status "{status}" fails a CHECK'))
def bad_order_status(qa, status):
    qa.observe("order status CHECK", lambda: _fails(qa.tmp, "INSERT INTO orders (id, customer_id, restaurant_id, subtotal_cents, delivery_fee_cents, total_cents, status, created_at) VALUES (2,1,1,100,300,400,?,1)", (status,), "CHECK constraint failed"))


@then(parsers.parse('inserting an order event with actor "{actor}" fails a CHECK'))
def bad_actor(qa, actor):
    qa.observe("order_events actor CHECK", lambda: _fails(qa.tmp, "INSERT INTO order_events (order_id, from_status, to_status, actor, created_at) VALUES (1,NULL,?,?,1)", ("placed", actor), "CHECK constraint failed"))


@then("inserting a ledger row with zero delta fails a CHECK")
def ledger_zero(qa):
    qa.observe("ledger delta <> 0", lambda: _fails(qa.tmp, "INSERT INTO ledger (party_type, party_id, delta_cents, reason, order_id, created_at) VALUES ('platform',NULL,0,'commission',1,1)", (), "CHECK constraint failed"))


@then(parsers.parse('inserting a ledger row with reason "{reason}" fails a CHECK'))
def ledger_reason(qa, reason):
    qa.observe("ledger reason CHECK", lambda: _fails(qa.tmp, "INSERT INTO ledger (party_type, party_id, delta_cents, reason, order_id, created_at) VALUES (?,NULL,10,?,1,1)", ("platform", reason), "CHECK constraint failed"))


@then(parsers.parse('inserting a ledger row with party type "{party}" fails a CHECK'))
def ledger_party(qa, party):
    qa.observe("ledger party_type CHECK", lambda: _fails(qa.tmp, "INSERT INTO ledger (party_type, party_id, delta_cents, reason, order_id, created_at) VALUES (?,NULL,10,?,1,1)", (party, "commission"), "CHECK constraint failed"))


@then(parsers.parse('inserting a driver with status "{status}" fails a CHECK'))
def bad_driver_status(qa, status):
    qa.observe("driver status CHECK", lambda: _fails(qa.tmp, "INSERT INTO drivers (id, name, token, status, created_at) VALUES (2,'X','t2',?,1)", (status,), "CHECK constraint failed"))


@then("inserting a restaurant with commission over 100 percent fails a CHECK")
def bad_commission(qa):
    qa.observe("commission_bps <= 10000", lambda: _fails(qa.tmp, "INSERT INTO restaurants (id, name, cuisine, commission_bps, active) VALUES (2,'X','Y',10001,1)", (), "CHECK constraint failed"))


@then("applying the seed again changes no row counts")
def seed_idempotent(qa):
    def ev():
        tabs = ["restaurants", "menu_items", "drivers"]
        before = [qa.tmp.execute("SELECT COUNT(*) FROM " + t).fetchone()[0] for t in tabs]
        qa.tmp.executescript(SEED.read_text(encoding="utf-8"))
        after = [qa.tmp.execute("SELECT COUNT(*) FROM " + t).fetchone()[0] for t in tabs]
        return (before == after, f"before {before}, after {after}")
    qa.observe("seed idempotent", ev)


# ---------------------------------------------------------------- checkout <-> rows


@then("the order total equals its subtotal plus the delivery fee")
def total_eq_sub_plus_fee(qa):
    def ev():
        o = order_of(qa)
        if not o:
            return (False, "no order: " + json.dumps(qa.last and qa.last.get("body")))
        row = qa.store.get("SELECT * FROM orders WHERE id = ?", o["id"])
        return (row["total_cents"] == row["subtotal_cents"] + row["delivery_fee_cents"] and row["total_cents"] == o["total_cents"], f"sub {row['subtotal_cents']} + fee {row['delivery_fee_cents']} = {row['total_cents']}")
    check(qa, "total == subtotal + delivery fee", ev)


@then("each order line price equals the menu item's price at order time")
def line_price(qa):
    def ev():
        lines = qa.store.all("SELECT * FROM order_items WHERE order_id = ?", qa.order_id)
        bad = [it for it in lines if it["price_cents"] != qa.store.get("SELECT price_cents FROM menu_items WHERE id = ?", it["menu_item_id"])["price_cents"]]
        return (len(lines) > 0 and not bad, json.dumps(bad) if bad else f"{len(lines)} lines match")
    check(qa, "order line price == menu price", ev)


@then(parsers.parse("the stock of item {iid:d} fell by {d:d}"))
def stock_fell(qa, iid, d):
    check(qa, f"stock of {iid} fell by {d}", lambda: ((lambda now: (qa.noted[f"stock.{iid}"] - now == d, f"before {qa.noted[f'stock.{iid}']}, now {now}"))(qa.store.get("SELECT stock FROM menu_items WHERE id = ?", iid)["stock"])))


@then(parsers.parse('the checkout is refused with code "{code}"'))
def checkout_refused(qa, code):
    qa.observe("checkout refused: " + code, lambda: (bool(qa.last and qa.last.get("status", 0) >= 400 and qa.last.get("body") and qa.last["body"].get("code") == code), (str(qa.last.get("status")) + " " + json.dumps(qa.last.get("body"))) if qa.last else "no response"))


@then(parsers.parse("the stock of item {iid:d} is unchanged"))
def stock_unchanged(qa, iid):
    check(qa, f"stock of {iid} unchanged", lambda: ((lambda now: (now == qa.noted[f"stock.{iid}"], f"before {qa.noted[f'stock.{iid}']}, now {now}"))(qa.store.get("SELECT stock FROM menu_items WHERE id = ?", iid)["stock"])))


@then(parsers.parse("the stock of item {iid:d} is unchanged from the note"))
def stock_back_to_note(qa, iid):
    check(qa, f"stock of {iid} back to note", lambda: ((lambda now: (now == qa.noted[f"stock.{iid}"], f"note {qa.noted[f'stock.{iid}']}, now {now}"))(qa.store.get("SELECT stock FROM menu_items WHERE id = ?", iid)["stock"])))


@then("no new order was created")
def no_new_order(qa):
    check(qa, "order count unchanged", lambda: ((lambda n: (n == qa.noted["orders"], f"before {qa.noted['orders']}, now {n}"))(qa.store.count("orders"))))


@then(parsers.parse('the cart row status is "{status}"'))
def cart_status(qa, status):
    check(qa, "cart status " + status, lambda: ((lambda c: (bool(c) and c["status"] == status, c["status"] if c else "no cart"))(qa.store.get("SELECT status FROM carts WHERE token = ?", qa.cart_token))))


@then("the order's customer is the buyer")
def order_customer(qa):
    def ev():
        o = order_of(qa)
        row = qa.store.get("SELECT customer_id FROM orders WHERE id = ?", o["id"])
        return (row["customer_id"] == qa.buyer["id"], f"order {row['customer_id']}, buyer {qa.buyer['id']}")
    check(qa, "order.customer_id == buyer", ev)


@then(parsers.parse("the order has {n:d} order lines"))
def order_lines(qa, n):
    check(qa, f"order has {n} lines", lambda: ((lambda c: (c == n, f"lines {c}"))(qa.store.count("order_items", "WHERE order_id = ?", order_of(qa)["id"]))))


# ---------------------------------------------------------------- the state machine


@then(parsers.parse('the order status row is "{status}"'))
def order_status_row(qa, status):
    check(qa, "order status row " + status, lambda: ((lambda o: (bool(o) and o["status"] == status, o["status"] if o else "no order"))(qa.store.get("SELECT status FROM orders WHERE id = ?", qa.order_id))))


@then("the order's first event is placed by the customer")
def first_event(qa):
    def ev():
        evs = qa.store.events(qa.order_id)
        e = evs[0] if evs else None
        return (bool(e) and e["from_status"] is None and e["to_status"] == "placed" and e["actor"] == "customer", f"{e['from_status']}->{e['to_status']} by {e['actor']}" if e else "no events")
    check(qa, "first event placed by customer", ev)


def _event_records(qa, frm, to, actor):
    def ev():
        e = next((x for x in qa.store.events(qa.order_id) if x["from_status"] == frm and x["to_status"] == to), None)
        return (bool(e) and e["actor"] == actor, f"by {e['actor']}" if e else "no such event")
    check(qa, f"event {frm}->{to} by {actor}", ev)


@then("an event records placed to accepted by the merchant")
def ev_accepted(qa):
    _event_records(qa, "placed", "accepted", "merchant")


@then("an event records placed to rejected by the merchant")
def ev_rejected(qa):
    _event_records(qa, "placed", "rejected", "merchant")


@then("an event records placed to cancelled by the customer")
def ev_cancelled(qa):
    _event_records(qa, "placed", "cancelled", "customer")


@then("the order's events run placed, accepted, preparing, ready, assigned, picked_up, delivered")
def lifecycle_seq(qa):
    def ev():
        seq = [e["to_status"] for e in qa.store.events(qa.order_id)]
        want = ["placed", "accepted", "preparing", "ready", "assigned", "picked_up", "delivered"]
        return (seq == want, " -> ".join(seq))
    check(qa, "lifecycle events in order", ev)


@then("each event names the actor responsible for that transition")
def lifecycle_actors(qa):
    def ev():
        by_to = {e["to_status"]: e["actor"] for e in qa.store.events(qa.order_id)}
        want = {"placed": "customer", "accepted": "merchant", "preparing": "merchant", "ready": "merchant", "assigned": "driver", "picked_up": "driver", "delivered": "driver"}
        bad = [(to, a) for to, a in want.items() if by_to.get(to) != a]
        return (not bad, "mismatch " + json.dumps(bad) if bad else json.dumps(by_to))
    check(qa, "events name the right actors", ev)


# ---------------------------------------------------------------- the ledger


@then("the restaurant's payout equals the subtotal minus commission")
def restaurant_payout(qa):
    def ev():
        o = qa.store.get("SELECT * FROM orders WHERE id = ?", qa.order_id)
        r = qa.store.get("SELECT commission_bps FROM restaurants WHERE id = ?", o["restaurant_id"])
        commission = o["subtotal_cents"] * r["commission_bps"] // 10000
        row = next((l for l in qa.store.ledger(qa.order_id) if l["party_type"] == "restaurant" and l["reason"] == "payout"), None)
        return (bool(row) and row["delta_cents"] == o["subtotal_cents"] - commission, f"payout {row['delta_cents']}, expected {o['subtotal_cents'] - commission}" if row else "no payout row")
    check(qa, "restaurant payout == subtotal - commission", ev)


@then("the driver's ledger credit equals the delivery fee")
def driver_credit(qa):
    def ev():
        o = qa.store.get("SELECT * FROM orders WHERE id = ?", qa.order_id)
        row = next((l for l in qa.store.ledger(qa.order_id) if l["party_type"] == "driver" and l["reason"] == "delivery_fee"), None)
        return (bool(row) and row["delta_cents"] == o["delivery_fee_cents"], f"driver {row['delta_cents']}, fee {o['delivery_fee_cents']}" if row else "no driver row")
    check(qa, "driver credit == delivery fee", ev)


@then("the platform's ledger credit equals the commission")
def platform_credit(qa):
    def ev():
        o = qa.store.get("SELECT * FROM orders WHERE id = ?", qa.order_id)
        r = qa.store.get("SELECT commission_bps FROM restaurants WHERE id = ?", o["restaurant_id"])
        commission = o["subtotal_cents"] * r["commission_bps"] // 10000
        row = next((l for l in qa.store.ledger(qa.order_id) if l["party_type"] == "platform" and l["reason"] == "commission"), None)
        return (bool(row) and row["delta_cents"] == commission, f"platform {row['delta_cents']}, expected {commission}" if row else "no platform row")
    check(qa, "platform credit == commission", ev)


@then("the order's ledger credits sum to the order total")
def ledger_sum(qa):
    def ev():
        o = qa.store.get("SELECT total_cents FROM orders WHERE id = ?", qa.order_id)
        s = sum(l["delta_cents"] for l in qa.store.ledger(qa.order_id))
        return (s == o["total_cents"], f"ledger {s}, total {o['total_cents']}")
    check(qa, "ledger sum == total", ev)


@then("the order has no ledger rows")
def no_ledger(qa):
    check(qa, "no ledger rows", lambda: ((lambda n: (n == 0, f"{n} ledger rows"))(len(qa.store.ledger(qa.order_id)))))


# ---------------------------------------------------------------- idempotency and integrity


@then("exactly one new order was created")
def exactly_one(qa):
    check(qa, "exactly one new order", lambda: ((lambda n: (n == qa.noted["orders"] + 1, f"before {qa.noted['orders']}, now {n}"))(qa.store.count("orders"))))


@then("both checkouts returned the same order id")
def same_order_id(qa):
    def ev():
        a, b = qa.noted.get("firstOrder"), qa.noted.get("secondOrder")
        return (bool(a and b and a.get("body") and b.get("body") and a["body"]["id"] == b["body"]["id"]), f"first {a and a['body'].get('id')}, second {b and b['body'].get('id')}")
    qa.observe("idempotent replay returns same order", ev)


@then("no order_items row references a menu item missing from menu_items")
def no_orphan_line(qa):
    check(qa, "no orphan order line", lambda: ((lambda n: (n == 0, f"{n} orphans"))(qa.store.count("order_items oi", "WHERE NOT EXISTS (SELECT 1 FROM menu_items m WHERE m.id = oi.menu_item_id)"))))


@then("no orders row references a customer missing from customers")
def no_orphan_customer(qa):
    check(qa, "no orphan order->customer", lambda: ((lambda n: (n == 0, f"{n} orphans"))(qa.store.count("orders o", "WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.id = o.customer_id)"))))


@then("no orders row references a restaurant missing from restaurants")
def no_orphan_restaurant(qa):
    check(qa, "no orphan order->restaurant", lambda: ((lambda n: (n == 0, f"{n} orphans"))(qa.store.count("orders o", "WHERE NOT EXISTS (SELECT 1 FROM restaurants r WHERE r.id = o.restaurant_id)"))))
