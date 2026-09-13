"""HTTP client for the mini-eats service. Mirror of node/be/api/venues/minieats.js.
urllib only. A transport failure is ApiUnreachable (grades Blocked); a 4xx/5xx
is an answer, often the one under test. The convenience methods drive the four
apps end to end so a step can set up whatever lifecycle state it asserts on.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request

BASE = os.environ.get("MINI_EATS_URL", "http://127.0.0.1:8130").rstrip("/")
ADMIN_TOKEN = os.environ.get("MINI_EATS_ADMIN_TOKEN", "admin-token")
SEED_DRIVER = "drv_seed_alex"


class ApiUnreachable(Exception):
    pass


class MiniEats:
    def __init__(self, base: str = BASE) -> None:
        self.base = base
        self.admin_token = ADMIN_TOKEN
        self.seed_driver = SEED_DRIVER

    def request(self, method, path, token=None, body=None, headers=None):
        h = dict(headers or {})
        if token:
            h["Authorization"] = "Bearer " + token
        data = None
        if body is not None:
            h["Content-Type"] = "application/json"
            data = json.dumps(body).encode()
        req = urllib.request.Request(self.base + path, data=data, headers=h, method=method)
        try:
            with urllib.request.urlopen(req, timeout=15) as res:
                status, text = res.status, res.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as err:
            status, text = err.code, err.read().decode("utf-8", "replace")
        except (urllib.error.URLError, TimeoutError, OSError) as err:
            raise ApiUnreachable(f"mini-eats at {self.base} did not answer {method} {path}: {err}") from err
        try:
            parsed = json.loads(text) if text else None
        except json.JSONDecodeError:
            parsed = None
        return {"status": status, "body": parsed, "text": text}

    def get(self, p, **kw):
        return self.request("GET", p, **kw)

    def post(self, p, body=None, **kw):
        return self.request("POST", p, body=body, **kw)

    def patch(self, p, body=None, **kw):
        return self.request("PATCH", p, body=body, **kw)

    def new_customer(self, name="Diner"):
        r = self.post("/customers", {"name": name})
        if r["status"] != 201:
            raise RuntimeError("create customer failed: HTTP " + str(r["status"]) + " " + r["text"])
        return r["body"]

    def new_driver(self, name="Courier"):
        r = self.post("/drivers", {"name": name})
        if r["status"] != 201:
            raise RuntimeError("create driver failed: HTTP " + str(r["status"]) + " " + r["text"])
        return r["body"]

    def open_cart(self, token, restaurant_id):
        r = self.post("/carts", {"restaurant_id": restaurant_id}, token=token)
        if r["status"] != 201:
            raise RuntimeError("open cart failed: HTTP " + str(r["status"]) + " " + r["text"])
        return r["body"]["token"]

    def add_item(self, token, cart_token, item_id, qty):
        return self.post(f"/carts/{cart_token}/items", {"menu_item_id": item_id, "qty": qty}, token=token)

    def checkout(self, token, body):
        return self.post("/orders", body, token=token)

    def place_delivered(self, restaurant_id, lines):
        cust = self.new_customer()
        cart = self.open_cart(cust["token"], restaurant_id)
        for qty, item_id in lines:
            a = self.add_item(cust["token"], cart, item_id, qty)
            if a["status"] != 200:
                raise RuntimeError("add item: " + a["text"])
        o = self.checkout(cust["token"], {"cart_token": cart})
        if o["status"] != 201:
            raise RuntimeError("checkout: " + o["text"])
        oid = o["body"]["id"]
        self.post(f"/orders/{oid}/accept")
        self.post(f"/orders/{oid}/prepare")
        self.post(f"/orders/{oid}/ready")
        self.post(f"/orders/{oid}/assign", token=self.seed_driver)
        self.post(f"/orders/{oid}/pickup", token=self.seed_driver)
        self.post(f"/orders/{oid}/deliver", token=self.seed_driver)
        return oid
