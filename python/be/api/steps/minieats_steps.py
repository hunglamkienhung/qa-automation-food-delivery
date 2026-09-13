"""Steps for be-minieats-api.feature: the REST layer vs the rows it serves,
across the customer, merchant, driver and admin apps. Mirror of
node/be/api/steps/minieats.steps.js -- a plugin module. Background, store, and
many "drive the service" Givens (place / advance / cancel an order) are shared
from eats_steps.py.
"""

from __future__ import annotations

import json

from pytest_bdd import given, parsers, then, when

from be.api.venues.minieats import ApiUnreachable, MiniEats
from be.db.store import DbUnreachable

eats = MiniEats()
UNREACHABLE = (ApiUnreachable, DbUnreachable)


def money(c):
    return "$" + f"{c / 100:.2f}"


def send(qa, method, path, **opts):
    if qa.source_error:
        return
    try:
        qa.api = eats.request(method, path, **opts)
        qa.last = qa.api
    except ApiUnreachable as err:
        qa.source_error = str(err)


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


def body(qa):
    return (qa.api or {}).get("body") or {}


def field(qa, n):
    return body(qa).get(n)


def resp(qa):
    return (qa.last or {}).get("body") or {}


def menu_row_view(row):
    return {"id": row["id"], "restaurant_id": row["restaurant_id"], "name": row["name"], "category": row["category"], "price_cents": row["price_cents"], "price": money(row["price_cents"]), "stock": row["stock"], "available": bool(row["available"]) and row["stock"] > 0}


def order_row_view(store, oid):
    o = store.get("SELECT * FROM orders WHERE id = ?", oid)
    if not o:
        return None
    items = [{"menu_item_id": it["menu_item_id"], "qty": it["qty"], "price_cents": it["price_cents"]} for it in store.all("SELECT * FROM order_items WHERE order_id = ? ORDER BY id", oid)]
    return {"id": o["id"], "customer_id": o["customer_id"], "restaurant_id": o["restaurant_id"], "driver_id": o["driver_id"], "subtotal_cents": o["subtotal_cents"], "delivery_fee_cents": o["delivery_fee_cents"], "total_cents": o["total_cents"], "status": o["status"], "items": items}


# ---------------------------------------------------------------- requests


@when(parsers.re(r"^GET (?P<path>/\S*)$"))
def get_path(qa, path):
    send(qa, "GET", path)


@given("a registered customer")
def registered_customer(qa):
    if qa.source_error:
        return
    try:
        qa.buyer = eats.new_customer()
    except ApiUnreachable as err:
        qa.source_error = str(err)


@when(parsers.parse("a cart is opened at restaurant {rid:d} with no token"))
def cart_no_token(qa, rid):
    send(qa, "POST", "/carts", body={"restaurant_id": rid})


@when(parsers.parse("the customer opens a cart at restaurant {rid:d}"))
def customer_opens_cart(qa, rid):
    send(qa, "POST", "/carts", token=qa.buyer["token"], body={"restaurant_id": rid})


def add_items(qa, qty, iid):
    send(qa, "POST", f"/carts/{qa.cart_token}/items", token=qa.buyer["token"], body={"menu_item_id": iid, "qty": qty})


@given(parsers.parse("{qty:d} of item {iid:d} are added to the cart"))
@when(parsers.parse("{qty:d} of item {iid:d} are added to the cart"))
def add_items_step(qa, qty, iid):
    add_items(qa, qty, iid)


@when("checkout is posted with no token")
def checkout_no_token(qa):
    send(qa, "POST", "/orders", body={"cart_token": qa.cart_token})


@when("the order is fetched")
def order_fetched(qa):
    send(qa, "GET", "/orders/" + str(qa.order_id))


@when("the merchant prepares the order")
def merchant_prepares(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/prepare")


@when("the merchant marks the order ready")
def merchant_ready(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/ready")


@given("the merchant has accepted the order")
def merchant_has_accepted(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/accept")


def drive_to_ready(qa):
    if qa.source_error:
        return
    for step in ("accept", "prepare", "ready"):
        r = eats.post(f"/orders/{qa.order_id}/{step}")
        if r["status"] != 200:
            raise RuntimeError(step + ": " + r["text"])


@given("the order has been made ready")
def order_made_ready(qa):
    drive_to_ready(qa)


def place_order_api(qa, rid, lines):
    if qa.source_error:
        return
    try:
        qa.buyer = eats.new_customer()
        cart = eats.open_cart(qa.buyer["token"], rid)
        qa.cart_token = cart
        for qty, iid in lines:
            a = eats.add_item(qa.buyer["token"], cart, iid, qty)
            if a["status"] != 200:
                raise RuntimeError("add item: " + a["text"])
        o = eats.checkout(qa.buyer["token"], {"cart_token": cart})
        if o["status"] != 201:
            raise RuntimeError("checkout: " + o["text"])
        qa.order_id = o["body"]["id"]
        qa.last = o
        qa.api = o
    except ApiUnreachable as err:
        qa.source_error = str(err)


@given(parsers.parse("a ready order of {qty:d} of item {iid:d} at restaurant {rid:d}"))
def ready_order(qa, qty, iid, rid):
    place_order_api(qa, rid, [(qty, iid)])
    drive_to_ready(qa)


@when("another customer tries to cancel the order")
def another_cancels(qa):
    other = eats.new_customer()
    send(qa, "POST", f"/orders/{qa.order_id}/cancel", token=other["token"])


@when("the driver reads the offers")
def driver_reads_offers(qa):
    send(qa, "GET", "/offers", token=eats.seed_driver)


@when("the offers are read with no token")
def offers_no_token(qa):
    send(qa, "GET", "/offers")


@when("the driver assigns the order")
def driver_assigns(qa):
    if not getattr(qa, "driver", None):
        qa.driver = eats.new_driver()
    send(qa, "POST", f"/orders/{qa.order_id}/assign", token=qa.driver["token"])


@given("a driver has assigned the order")
def driver_has_assigned(qa):
    qa.driver = eats.new_driver()
    send(qa, "POST", f"/orders/{qa.order_id}/assign", token=qa.driver["token"])


@when("the driver picks up the order")
def driver_picks_up(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/pickup", token=qa.driver["token"])


@when("the driver delivers the order")
def driver_delivers(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/deliver", token=qa.driver["token"])


@when("the assigned driver delivers the order")
def assigned_delivers(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/deliver", token=qa.driver["token"])


@when("another driver assigns the order")
def another_assigns(qa):
    other = eats.new_driver()
    send(qa, "POST", f"/orders/{qa.order_id}/assign", token=other["token"])


@when("another driver picks up the order")
def another_picks_up(qa):
    other = eats.new_driver()
    send(qa, "POST", f"/orders/{qa.order_id}/pickup", token=other["token"])


@when("GET /admin/overview with no token")
def admin_overview_no_token(qa):
    send(qa, "GET", "/admin/overview")


@when("the admin reads the overview")
def admin_reads_overview(qa):
    send(qa, "GET", "/admin/overview", token=eats.admin_token)


@when(parsers.parse('the admin lists orders with status "{status}"'))
def admin_lists_orders(qa, status):
    send(qa, "GET", "/admin/orders?status=" + status, token=eats.admin_token)


@given(parsers.parse("the admin deactivates restaurant {rid:d}"))
@when(parsers.parse("the admin deactivates restaurant {rid:d}"))
def admin_deactivates(qa, rid):
    send(qa, "PATCH", f"/admin/restaurants/{rid}", token=eats.admin_token, body={"active": False})


@given(parsers.parse("the admin reactivates restaurant {rid:d}"))
def admin_reactivates(qa, rid):
    send(qa, "PATCH", f"/admin/restaurants/{rid}", token=eats.admin_token, body={"active": True})


# ---------------------------------------------------------------- Then: status/shape


@then(parsers.re(r"^the response status is (?P<s>\d+)$"))
def response_status(qa, s):
    check(qa, "status " + s, lambda: (qa.api["status"] == int(s), f"status {qa.api['status']} {qa.api.get('text','')[:140]}"))


@then(parsers.re(r'^the response is an error with code "(?P<code>[^"]*)"$'))
def response_error(qa, code):
    check(qa, "error code " + code, lambda: (body(qa).get("code") == code and isinstance(body(qa).get("error"), str), qa.api.get("text", "")[:140]))


@then(parsers.parse('the response field "{n}" is true'))
def field_true(qa, n):
    check(qa, n + " is true", lambda: (field(qa, n) is True, f"{n} = {json.dumps(field(qa, n))}"))


# ---------------------------------------------------------------- Then: restaurants / menu


@then("every restaurant in the response is active")
def restaurants_active(qa):
    def ev():
        rs = field(qa, "restaurants") or []
        bad = [r for r in rs if (qa.store.get("SELECT active FROM restaurants WHERE id = ?", r["id"]) or {}).get("active") != 1]
        return (len(rs) > 0 and not bad, "inactive " + ",".join(str(r["id"]) for r in bad) if bad else f"{len(rs)} active")
    check(qa, "restaurants all active", ev)


@then("no inactive restaurant appears")
def no_inactive_restaurant(qa):
    def ev():
        ids = [r["id"] for r in (field(qa, "restaurants") or [])]
        inactive = [r["id"] for r in qa.store.all("SELECT id FROM restaurants WHERE active = 0")]
        bad = [i for i in ids if i in inactive]
        return (not bad, "leaked " + ",".join(map(str, bad)) if bad else "none")
    check(qa, "no inactive restaurant", ev)


@then("every menu item in the response matches its row")
def menu_matches(qa):
    def ev():
        menu = field(qa, "menu") or []
        bad = [m for m in menu if json.dumps(menu_row_view(qa.store.get("SELECT * FROM menu_items WHERE id = ?", m["id"])), sort_keys=True) != json.dumps(m, sort_keys=True)]
        return (not bad and len(menu) > 0, "mismatch" if bad else f"{len(menu)} match")
    check(qa, "menu items match rows", ev)


@then(parsers.parse("menu item {iid:d} is reported unavailable"))
def item_unavailable(qa, iid):
    def ev():
        m = next((x for x in (field(qa, "menu") or []) if x["id"] == iid), None)
        return (bool(m) and m["available"] is False, f"available={m['available']}" if m else "not on menu")
    check(qa, f"item {iid} unavailable", ev)


# ---------------------------------------------------------------- Then: cart


@then(parsers.parse("the cart holds {qty:d} of item {iid:d} priced from the row"))
def cart_holds_priced(qa, qty, iid):
    def ev():
        it = next((x for x in (field(qa, "items") or []) if x["menu_item_id"] == iid), None)
        row = qa.store.get("SELECT price_cents FROM menu_items WHERE id = ?", iid)
        return (bool(it) and it["qty"] == qty and it["price_cents"] == row["price_cents"] and it["line_cents"] == qty * row["price_cents"], json.dumps(it) if it else "no line")
    check(qa, f"cart holds {qty}x{iid}", ev)


@then("the cart subtotal equals the sum of its line totals")
def cart_subtotal_lines(qa):
    def ev():
        items = field(qa, "items") or []
        s = sum(it["line_cents"] for it in items)
        return (field(qa, "subtotal_cents") == s, f"subtotal {field(qa, 'subtotal_cents')}, sum {s}")
    check(qa, "subtotal == sum lines", ev)


@then(parsers.parse("the cart has {n:d} lines"))
def cart_lines(qa, n):
    check(qa, f"cart has {n} lines", lambda: ((lambda items: (len(items) == n, f"{len(items)} lines"))(field(qa, "items") or [])))


# ---------------------------------------------------------------- Then: orders


@then("the order in the response equals the stored order")
def order_equals_stored(qa):
    def ev():
        b = dict(body(qa))
        b.pop("idempotent_replay", None)
        row = order_row_view(qa.store, b.get("id"))
        return (bool(row) and json.dumps(b, sort_keys=True) == json.dumps(row, sort_keys=True), "api " + json.dumps(b) if row else "no order row")
    check(qa, "order == stored order", ev)


@then("the order total in the response equals its subtotal plus the delivery fee")
def order_total_sub_fee(qa):
    def ev():
        b = body(qa)
        return (b.get("total_cents") == b.get("subtotal_cents") + b.get("delivery_fee_cents"), f"sub {b.get('subtotal_cents')} + fee {b.get('delivery_fee_cents')} = {b.get('total_cents')}")
    check(qa, "order total == subtotal + fee", ev)


@then(parsers.parse('the order in the response reports status "{status}"'))
def response_order_status(qa, status):
    check(qa, "response order status " + status, lambda: (resp(qa).get("status") == status, f"status {resp(qa).get('status')} {(qa.last or {}).get('text','')[:120]}"))


@then("the order in the response is assigned to the driver")
def order_assigned(qa):
    check(qa, "order assigned to driver", lambda: (resp(qa).get("driver_id") == qa.driver["id"], f"driver_id {resp(qa).get('driver_id')}, driver {qa.driver['id']}"))


@then(parsers.parse('the tracked order reports status "{status}"'))
def tracked_status(qa, status):
    check(qa, "tracked status " + status, lambda: (body(qa).get("status") == status, f"status {body(qa).get('status')}"))


@then(parsers.parse('the tracked order has an event to "{to}"'))
def tracked_event(qa, to):
    check(qa, "tracked event to " + to, lambda: (any(e.get("to") == to for e in (body(qa).get("events") or [])), json.dumps(body(qa).get("events"))))


@then("the second checkout is flagged an idempotent replay")
def second_replay(qa):
    def ev():
        b = qa.noted.get("secondOrder") and qa.noted["secondOrder"].get("body")
        return (bool(b) and b.get("idempotent_replay") is True, f"flag {b.get('idempotent_replay')}" if b else "no second order")
    qa.observe("idempotent replay flagged", ev)


# ---------------------------------------------------------------- Then: offers / board


@then("the placed order is not among the offers")
def placed_not_offered(qa):
    check(qa, "placed not offered", lambda: ((lambda ids: (qa.order_id not in ids, "offers " + ",".join(map(str, ids))))([o["id"] for o in (field(qa, "offers") or [])])))


@then("the ready order is among the offers")
def ready_offered(qa):
    check(qa, "ready is offered", lambda: ((lambda ids: (qa.order_id in ids, "offers " + ",".join(map(str, ids))))([o["id"] for o in (field(qa, "offers") or [])])))


@then("the placed order appears on the restaurant's board")
def order_on_board(qa):
    check(qa, "order on board", lambda: ((lambda ids: (qa.order_id in ids, "board " + ",".join(map(str, ids))))([o["id"] for o in (field(qa, "orders") or [])])))


@then(parsers.parse('every order on the board reports status "{status}"'))
def board_all_status(qa, status):
    def ev():
        os_ = field(qa, "orders") or []
        bad = [o for o in os_ if o["status"] != status]
        return (len(os_) > 0 and not bad, "off " + ",".join(o["status"] for o in bad) if bad else f"{len(os_)} {status}")
    check(qa, "board all " + status, ev)


@then(parsers.parse('every listed order reports status "{status}"'))
def listed_all_status(qa, status):
    def ev():
        os_ = field(qa, "orders") or []
        bad = [o for o in os_ if o["status"] != status]
        return (len(os_) > 0 and not bad, "off " + ",".join(o["status"] for o in bad) if bad else f"{len(os_)} {status}")
    check(qa, "admin list all " + status, ev)


# ---------------------------------------------------------------- Then: admin overview


@then("the overview counts at least one delivered order")
def counts_delivered(qa):
    check(qa, "delivered count >= 1", lambda: ((lambda c: (c >= 1, f"delivered {c}"))((field(qa, "orders_by_status") or {}).get("delivered", 0))))


@then("the overview revenue is at least the order total")
def revenue_ge_total(qa):
    def ev():
        o = qa.store.get("SELECT total_cents FROM orders WHERE id = ?", qa.order_id)
        return (field(qa, "revenue_cents") >= o["total_cents"], f"revenue {field(qa, 'revenue_cents')}, order {o['total_cents']}")
    check(qa, "revenue >= order total", ev)


@then("the overview revenue equals payouts plus commission plus delivery fees")
def revenue_balances(qa):
    def ev():
        rev = field(qa, "revenue_cents")
        s = (field(qa, "payout_cents") or 0) + (field(qa, "commission_cents") or 0) + (field(qa, "delivery_fee_cents") or 0)
        return (rev == s, f"revenue {rev}, parts {s}")
    check(qa, "revenue == payout + commission + fees", ev)


@then(parsers.parse("restaurant {rid:d} is not in the response"))
def restaurant_absent(qa, rid):
    check(qa, f"{rid} absent", lambda: ((lambda ids: (rid not in ids, "ids " + ",".join(map(str, ids))))([r["id"] for r in (field(qa, "restaurants") or [])])))


@then(parsers.parse("restaurant {rid:d} is in the response"))
def restaurant_present(qa, rid):
    check(qa, f"{rid} present", lambda: ((lambda ids: (rid in ids, "ids " + ",".join(map(str, ids))))([r["id"] for r in (field(qa, "restaurants") or [])])))
