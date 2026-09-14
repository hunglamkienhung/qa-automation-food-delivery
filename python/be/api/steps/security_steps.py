"""Steps for be-minieats-security.feature. Mirror of
node/be/api/steps/security.steps.js -- a plugin module. These probe the API's
authorization boundaries (no token, wrong actor, forged token, a resource that
is not yours). Background, store, and order-setup Givens (a placed order, a
registered customer) are shared from the other @minieats steps.
"""

from __future__ import annotations

import json

from pytest_bdd import parsers, then, when

from be.api.venues.minieats import ApiUnreachable, MiniEats
from be.db.store import DbUnreachable

eats = MiniEats()
UNREACHABLE = (ApiUnreachable, DbUnreachable)
FORGED = "cust_forged000000000000000000"


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


# ---------------------------------------------------------------- merchant gate


@when("the order is accepted with no token")
def accept_no_token(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/accept")


@when("the order is accepted with a forged token")
def accept_forged(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/accept", token=FORGED)


@when("a merchant who owns no restaurant accepts the order")
def other_merchant_accepts(qa):
    other = eats.new_merchant()
    send(qa, "POST", f"/orders/{qa.order_id}/accept", token=other["token"])


@when("the customer tries to accept the order")
def customer_accepts(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/accept", token=qa.buyer["token"])


@when("a driver tries to accept the order")
def driver_accepts(qa):
    send(qa, "POST", f"/orders/{qa.order_id}/accept", token=eats.seed_driver)


# ---------------------------------------------------------------- board


@when(parsers.parse("the admin reads restaurant {rid:d}'s board"))
def admin_reads_board(qa, rid):
    send(qa, "GET", f"/restaurants/{rid}/orders", token=eats.admin_token)


# ---------------------------------------------------------------- cross-role / forged / tampered


@when("the admin overview is read with the customer's token")
def admin_overview_customer(qa):
    send(qa, "GET", "/admin/overview", token=qa.buyer["token"])


@when("the offers are read with the customer's token")
def offers_customer(qa):
    send(qa, "GET", "/offers", token=qa.buyer["token"])


@when("the admin overview is read with a token that extends the admin token")
def admin_overview_tampered(qa):
    send(qa, "GET", "/admin/overview", token=eats.admin_token + "x")


@when("a cart is opened with a forged token")
def cart_forged(qa):
    send(qa, "POST", "/carts", token=FORGED, body={"restaurant_id": 1})


# ---------------------------------------------------------------- onboarding / secret hygiene


@when("a merchant registers")
def merchant_registers(qa):
    send(qa, "POST", "/merchants", body={"name": "Sec Merchant"})


@then("the response carries a token")
def response_has_token(qa):
    def ev():
        t = (qa.api.get("body") or {}).get("token")
        return (isinstance(t, str) and len(t) > 0, "token present" if t else "absent")
    check(qa, "response carries a token", ev)


@then("the order response body contains no bearer token")
def no_bearer_leak(qa):
    def ev():
        text = json.dumps((qa.last or {}).get("body") or {})
        leaks = [p for p in ("cust_", "drv_", "mch_", "cart_", eats.admin_token) if p in text]
        return (not leaks, "leaked " + ",".join(leaks) if leaks else "clean")
    check(qa, "no bearer token leaked", ev)
