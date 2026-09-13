"""Page objects for the mini-eats app surfaces. Mirror of node/fe/ui/pages/eats.js.
Reads by label; a page that never loads raises ScreenNotReady (grades Blocked)."""

from __future__ import annotations

import os

BASE = os.environ.get("MINI_EATS_URL", "http://127.0.0.1:8130").rstrip("/")


class ScreenNotReady(Exception):
    pass


class EatsPage:
    def __init__(self, page) -> None:
        self.page = page
        self.base = BASE

    def open(self, path):
        try:
            self.page.goto(self.base + path, wait_until="domcontentloaded", timeout=15000)
        except Exception as err:  # noqa: BLE001
            raise ScreenNotReady(f"mini-eats page {path} did not load: {err}") from err

    def restaurants(self):
        try:
            self.page.wait_for_selector("ul.restaurants li.restaurant", timeout=15000)
        except Exception as err:  # noqa: BLE001
            raise ScreenNotReady("home never rendered") from err
        return self.page.eval_on_selector_all("ul.restaurants li.restaurant", """els => els.map(el => ({
            id: Number(el.getAttribute('data-id')),
            name: el.querySelector('a') ? el.querySelector('a').textContent.trim() : '',
            href: el.querySelector('a') ? el.querySelector('a').getAttribute('href') : '',
        }))""")

    def menu(self):
        try:
            self.page.wait_for_selector("ul.menu li.item", timeout=15000)
        except Exception as err:  # noqa: BLE001
            raise ScreenNotReady("menu never rendered") from err
        return self.page.eval_on_selector_all("ul.menu li.item", """els => els.map(el => ({
            id: Number(el.getAttribute('data-id')),
            name: el.querySelector('.name') ? el.querySelector('.name').textContent.trim() : '',
            priceText: el.querySelector('.price') ? el.querySelector('.price').textContent.trim() : '',
            statusText: el.querySelector('.status') ? el.querySelector('.status').textContent.trim() : '',
        }))""")

    def order(self):
        try:
            self.page.wait_for_selector("h1.order-id", timeout=15000)
        except Exception as err:  # noqa: BLE001
            raise ScreenNotReady("order page never rendered") from err
        return {"idText": self.page.eval_on_selector("h1.order-id", "e => e.textContent.trim()"), "statusText": self.page.eval_on_selector(".status", "e => e.textContent.trim()"), "totalText": self.page.eval_on_selector(".total", "e => e.textContent.trim()")}

    def board(self):
        try:
            self.page.wait_for_selector("ul.orders", timeout=15000)
        except Exception as err:  # noqa: BLE001
            raise ScreenNotReady("merchant board never rendered") from err
        return self.page.eval_on_selector_all("ul.orders li.order", """els => els.map(el => ({
            id: Number(el.getAttribute('data-id')),
            statusText: el.querySelector('.status') ? el.querySelector('.status').textContent.trim() : '',
            totalText: el.querySelector('.total') ? el.querySelector('.total').textContent.trim() : '',
        }))""")

    def offers(self):
        try:
            self.page.wait_for_selector("ul.offers", timeout=15000)
        except Exception as err:  # noqa: BLE001
            raise ScreenNotReady("driver board never rendered") from err
        return self.page.eval_on_selector_all("ul.offers li.offer", """els => els.map(el => ({
            id: Number(el.getAttribute('data-id')),
            totalText: el.querySelector('.total') ? el.querySelector('.total').textContent.trim() : '',
            feeText: el.querySelector('.fee') ? el.querySelector('.fee').textContent.trim() : '',
        }))""")

    def admin(self):
        try:
            self.page.wait_for_selector("ul.counts", timeout=15000)
        except Exception as err:  # noqa: BLE001
            raise ScreenNotReady("admin page never rendered") from err
        revenue_text = self.page.eval_on_selector(".revenue", "e => e.textContent.trim()")
        counts = self.page.eval_on_selector_all("ul.counts li.count", """els => els.map(el => ({
            status: el.getAttribute('data-status'),
            n: el.querySelector('.n') ? el.querySelector('.n').textContent.trim() : '',
        }))""")
        return {"revenueText": revenue_text, "counts": counts}
