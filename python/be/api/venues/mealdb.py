"""TheMealDB's public JSON API. Mirror of node/be/api/venues/mealdb.js.
urllib only. Answers HTTP 200 with JSON; an unknown lookup/search returns
{"meals": null}. A transport failure, a 5xx/429/403, or a non-JSON body is
MealDbUnreachable (grades Blocked). Ids arrive as strings; to_id coerces them.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request

BASE = os.environ.get("MEALDB_API_URL", "https://www.themealdb.com/api/json/v1/1").rstrip("/")
USER_AGENT = "qa-automation-food-delivery/1.0 (read-only invariants)"
TIMEOUT = 25


class MealDbUnreachable(Exception):
    pass


def request(path):
    req = urllib.request.Request(BASE + path, headers={"user-agent": USER_AGENT, "accept": "application/json"}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as res:
            status, text = res.status, res.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as err:
        if err.code >= 500 or err.code in (429, 403):
            raise MealDbUnreachable(f"GET {path} -- HTTP {err.code}") from err
        status, text = err.code, err.read().decode("utf-8", "replace")
    except (urllib.error.URLError, TimeoutError, OSError) as err:
        raise MealDbUnreachable(f"GET {path} -- {err}") from err
    try:
        body = json.loads(text)
    except json.JSONDecodeError:
        body = None
    if not isinstance(body, dict):
        raise MealDbUnreachable(f"GET {path} -- expected JSON, got " + " ".join(text[:40].split()) + "…")
    return {"httpStatus": status, "body": body}


def categories():
    return request("/categories.php")


def list_category_names():
    return request("/list.php?c=list")


def list_areas():
    return request("/list.php?a=list")


def filter_by_category(cat):
    return request("/filter.php?c=" + urllib.parse.quote(cat))


def lookup(meal_id):
    return request("/lookup.php?i=" + urllib.parse.quote(str(meal_id)))


def search_by_name(term):
    return request("/search.php?s=" + urllib.parse.quote(term))


def search_by_letter(letter):
    return request("/search.php?f=" + urllib.parse.quote(letter))


def to_id(v):
    try:
        return int(str(v))
    except (TypeError, ValueError):
        return None


def ingredients(meal):
    out = []
    for i in range(1, 21):
        v = meal.get(f"strIngredient{i}")
        if v and str(v).strip():
            out.append(str(v).strip())
    return out


def is_http_url(s):
    return re.match(r"^https?://\S+$", str(s or "")) is not None
