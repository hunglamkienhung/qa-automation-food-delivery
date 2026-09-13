"""The FE branch for the mini-eats app surfaces. Binds ../../features/fe-minieats.feature.
Mirror of node/fe/ui/steps/eats.steps.js. The `page` fixture is
pytest-playwright's; the comparison figures come from the store (opened by the
shared @minieats steps) and the API. The order-setup Givens (placed / ready /
delivered) are shared from the be steps.
"""

from __future__ import annotations

import json
import re

from pytest_bdd import given, parsers, scenarios, then, when

from be.api.venues.minieats import ApiUnreachable, MiniEats
from fe.ui.pages.eats import EatsPage, ScreenNotReady

scenarios("fe-minieats.feature")

eats = MiniEats()
UNREACHABLE = (ScreenNotReady, ApiUnreachable)


def money(c):
    return "$" + f"{c / 100:.2f}"


@given("the home page is open")
def home_open(page, qa):
    page.set_viewport_size({"width": 1440, "height": 900})
    qa.eats_page = EatsPage(page)

    def go():
        qa.eats_page.open("/")
        qa.screen["restaurants"] = qa.eats_page.restaurants()
    qa.fetch_or_block(UNREACHABLE, go)


def screen(qa, description, fn):
    if qa.source_error:
        qa.unobservable(description, "the source could not be reached -- " + qa.source_error)
        return
    try:
        passed, detail = fn()
    except UNREACHABLE as err:
        qa.unobservable(description, str(err))
        return
    qa.check(description, passed, detail)


def active_restaurants(qa):
    return qa.store.all("SELECT * FROM restaurants WHERE active = 1 ORDER BY id")


# ---------------------------------------------------------------- navigation


@when(parsers.parse("the menu for restaurant {rid:d} is opened"))
def open_menu(page, qa, rid):
    def go():
        qa.eats_page.open("/restaurant/" + str(rid))
        try:
            qa.screen["menu"] = qa.eats_page.menu()
        except ScreenNotReady:
            qa.screen["menu"] = None
    qa.fetch_or_block(UNREACHABLE, go)


@when("the order page is opened")
def open_order(page, qa):
    def go():
        qa.eats_page.open("/order/" + str(qa.order_id))
        try:
            qa.screen["order"] = qa.eats_page.order()
        except ScreenNotReady:
            qa.screen["order"] = None
    qa.fetch_or_block(UNREACHABLE, go)


@when(parsers.parse("the order page for {oid:d} is opened"))
def open_order_id(page, qa, oid):
    def go():
        qa.eats_page.open("/order/" + str(oid))
        try:
            qa.screen["order"] = qa.eats_page.order()
        except ScreenNotReady:
            qa.screen["order"] = None
    qa.fetch_or_block(UNREACHABLE, go)


@when(parsers.parse("the merchant board for restaurant {rid:d} is opened"))
def open_board(page, qa, rid):
    def go():
        qa.eats_page.open("/merchant/" + str(rid))
        try:
            qa.screen["board"] = qa.eats_page.board()
        except ScreenNotReady:
            qa.screen["board"] = None
    qa.fetch_or_block(UNREACHABLE, go)


@when("the driver board is opened")
def open_driver(page, qa):
    def go():
        qa.eats_page.open("/driver/1")
        try:
            qa.screen["offers"] = qa.eats_page.offers()
        except ScreenNotReady:
            qa.screen["offers"] = None
    qa.fetch_or_block(UNREACHABLE, go)


@when("the admin page is opened")
def open_admin(page, qa):
    def go():
        qa.eats_page.open("/admin")
        try:
            qa.screen["admin"] = qa.eats_page.admin()
        except ScreenNotReady:
            qa.screen["admin"] = None
    qa.fetch_or_block(UNREACHABLE, go)


# ---------------------------------------------------------------- home Thens


@then("the home page lists the active restaurants, once each")
def home_active(qa):
    def ev():
        ids = sorted(r["id"] for r in qa.screen["restaurants"])
        want = [r["id"] for r in active_restaurants(qa)]
        return (ids == want, f"screen {len(ids)}, active {len(want)}")
    screen(qa, "home == active restaurants", ev)


@then(parsers.parse("the home page does not list restaurant {rid:d}"))
def home_excludes(qa, rid):
    screen(qa, f"home excludes {rid}", lambda: (not any(r["id"] == rid for r in qa.screen["restaurants"]), "ids " + ",".join(str(r["id"]) for r in qa.screen["restaurants"])))


@then("each home row links to its restaurant page")
def home_links(qa):
    def ev():
        bad = [r for r in qa.screen["restaurants"] if r["href"] != "/restaurant/" + str(r["id"])]
        return (not bad and len(qa.screen["restaurants"]) > 0, json.dumps(bad[:2]) if bad else f"{len(qa.screen['restaurants'])} links")
    screen(qa, "home rows link to restaurants", ev)


@then("the home page shows at least one restaurant")
def home_non_empty(qa):
    screen(qa, "home non-empty", lambda: (len(qa.screen["restaurants"]) > 0, f"{len(qa.screen['restaurants'])} restaurants"))


# ---------------------------------------------------------------- menu Thens


@then("every menu price on screen equals the item row")
def menu_prices(qa):
    def ev():
        if not qa.screen.get("menu"):
            return (False, "no menu")
        bad = [m for m in qa.screen["menu"] if m["priceText"] != money(qa.store.get("SELECT price_cents FROM menu_items WHERE id = ?", m["id"])["price_cents"])]
        return (not bad and len(qa.screen["menu"]) > 0, json.dumps(bad[:2]) if bad else f"{len(qa.screen['menu'])} prices match")
    screen(qa, "menu prices == rows", ev)


@then("every menu name on screen equals the item row")
def menu_names(qa):
    def ev():
        if not qa.screen.get("menu"):
            return (False, "no menu")
        bad = [m for m in qa.screen["menu"] if m["name"] != qa.store.get("SELECT name FROM menu_items WHERE id = ?", m["id"])["name"]]
        return (not bad, json.dumps(bad[:2]) if bad else "names match")
    screen(qa, "menu names == rows", ev)


@then(parsers.parse("menu item {iid:d} is shown unavailable"))
def item_unavailable(qa, iid):
    def ev():
        m = next((x for x in (qa.screen.get("menu") or []) if x["id"] == iid), None)
        return (bool(m) and re.search(r"unavailable", m["statusText"], re.I) is not None, m["statusText"] if m else "not on menu")
    screen(qa, f"item {iid} unavailable", ev)


@then(parsers.parse("menu item {iid:d} is shown available"))
def item_available(qa, iid):
    def ev():
        m = next((x for x in (qa.screen.get("menu") or []) if x["id"] == iid), None)
        return (bool(m) and re.match(r"^available$", m["statusText"], re.I) is not None, m["statusText"] if m else "not on menu")
    screen(qa, f"item {iid} available", ev)


@then("every menu price on screen is a dollar amount")
def menu_prices_dollar(qa):
    screen(qa, "menu prices are dollar amounts", lambda: ((lambda bad: (not bad and len(qa.screen.get("menu") or []) > 0, ",".join(m["priceText"] for m in bad) if bad else "all dollar amounts"))([m for m in (qa.screen.get("menu") or []) if not re.match(r"^\$\d+\.\d{2}$", m["priceText"])])))


@then("the page reports not found")
def page_not_found(qa):
    def ev():
        txt = qa.eats_page.page.text_content("body")
        return (re.search(r"no such", txt, re.I) is not None, txt[:60])
    screen(qa, "page not found", ev)


# ---------------------------------------------------------------- order page Thens


@then("the order page total equals the stored order total")
def order_total(qa):
    def ev():
        o = qa.screen.get("order")
        row = qa.store.get("SELECT total_cents FROM orders WHERE id = ?", qa.order_id)
        return (bool(o) and o["totalText"] == money(row["total_cents"]), (o["totalText"] + " vs " + money(row["total_cents"])) if o else "no order page")
    screen(qa, "order page total == stored", ev)


@then(parsers.parse('the order page shows the order id and status "{status}"'))
def order_id_status(qa, status):
    def ev():
        o = qa.screen.get("order")
        return (bool(o) and str(qa.order_id) in o["idText"] and o["statusText"] == status, (o["idText"] + " / " + o["statusText"]) if o else "no order page")
    screen(qa, "order page id + status", ev)


@then("the order page total is shown as a dollar amount")
def order_total_format(qa):
    screen(qa, "order page total format", lambda: (bool(qa.screen.get("order")) and re.match(r"^\$\d+\.\d{2}$", qa.screen["order"]["totalText"]) is not None, qa.screen["order"]["totalText"] if qa.screen.get("order") else "no page"))


@then(parsers.parse('the order page shows status "{status}"'))
def order_status(qa, status):
    screen(qa, "order page status " + status, lambda: (bool(qa.screen.get("order")) and qa.screen["order"]["statusText"] == status, qa.screen["order"]["statusText"] if qa.screen.get("order") else "no page"))


# ---------------------------------------------------------------- merchant board Thens


@then(parsers.parse('the placed order appears on the merchant board with status "{status}"'))
def order_on_board(qa, status):
    def ev():
        row = next((o for o in (qa.screen.get("board") or []) if o["id"] == qa.order_id), None)
        return (bool(row) and row["statusText"] == status, row["statusText"] if row else "not on board")
    screen(qa, "order on merchant board", ev)


@then("every order total on the board is a dollar amount")
def board_totals(qa):
    screen(qa, "board totals are dollar amounts", lambda: ((lambda bad: (not bad and len(qa.screen.get("board") or []) > 0, ",".join(o["totalText"] for o in bad) if bad else "all dollar amounts"))([o for o in (qa.screen.get("board") or []) if not re.match(r"^\$\d+\.\d{2}$", o["totalText"])])))


# ---------------------------------------------------------------- driver board Thens


@then("the ready order is offered on the driver board")
def ready_offered(qa):
    screen(qa, "ready order offered", lambda: ((lambda ids: (qa.order_id in ids, "offers " + ",".join(map(str, ids))))([o["id"] for o in (qa.screen.get("offers") or [])])))


@then("the driver board offer count equals the API offer count")
def offer_count_api(qa):
    def ev():
        r = eats.get("/offers", token=eats.seed_driver)
        api = len(r["body"].get("offers") or [])
        return (len(qa.screen.get("offers") or []) == api, f"screen {len(qa.screen.get('offers') or [])}, api {api}")
    screen(qa, "offer count == API", ev)


@then("every offered fee on the board is a dollar amount")
def offer_fees(qa):
    screen(qa, "offer fees are dollar amounts", lambda: ((lambda bad: (not bad and len(qa.screen.get("offers") or []) > 0, ",".join(o["feeText"] for o in bad) if bad else "all dollar amounts"))([o for o in (qa.screen.get("offers") or []) if not re.match(r"^\$\d+\.\d{2}$", o["feeText"])])))


# ---------------------------------------------------------------- admin Thens


@then("the admin revenue is shown as a dollar amount")
def admin_revenue(qa):
    screen(qa, "admin revenue format", lambda: (bool(qa.screen.get("admin")) and re.match(r"^\$\d+\.\d{2}$", qa.screen["admin"]["revenueText"]) is not None, qa.screen["admin"]["revenueText"] if qa.screen.get("admin") else "no page"))


@then("the admin page shows at least one delivered order")
def admin_delivered(qa):
    def ev():
        counts = (qa.screen.get("admin") or {}).get("counts") or []
        row = next((c for c in counts if c["status"] == "delivered"), None)
        return (bool(row) and int(row["n"]) >= 1, ("delivered " + row["n"]) if row else "no delivered count")
    screen(qa, "admin delivered >= 1", ev)


@then("every admin status count is a non-negative integer")
def admin_counts_ints(qa):
    def ev():
        counts = (qa.screen.get("admin") or {}).get("counts") or []
        bad = [c for c in counts if not re.match(r"^\d+$", c["n"]) or int(c["n"]) < 0]
        return (not bad and len(counts) > 0, json.dumps(bad) if bad else f"{len(counts)} counts")
    screen(qa, "admin counts are non-negative ints", ev)
