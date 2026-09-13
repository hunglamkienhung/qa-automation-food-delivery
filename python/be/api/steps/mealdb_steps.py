"""Steps for be-mealdb-api.feature. Mirror of node/be/api/steps/mealdb.steps.js
-- a plugin module. HTTPS against TheMealDB's public API; its documents are
stashed on qa.meal and asserted for the API's own invariants. A transport
failure is MealDbUnreachable and grades Blocked.
"""

from __future__ import annotations

import pytest
from pytest_bdd import parsers, then, when

from be.api.venues import mealdb

UNREACHABLE = (mealdb.MealDbUnreachable,)


@pytest.fixture(autouse=True)
def mealdb_scenario(request, qa):
    if request.node.get_closest_marker("mealdb") is None:
        yield
        return
    qa.meal = {}
    yield


def fetch_or(qa, key, fn):
    if getattr(qa, "meal", None) is None:
        qa.meal = {}

    def go():
        qa.meal[key] = fn()
    qa.fetch_or_block(UNREACHABLE, go)


def looked_meal(qa):
    lk = qa.meal.get("looked")
    return lk[0] if lk else None


# ---------------------------------------------------------------- fetches


@when("the meal categories are fetched")
def categories_fetched(qa):
    fetch_or(qa, "categories", lambda: mealdb.categories()["body"]["categories"])


@when("the meal categories are fetched again")
def categories_again(qa):
    fetch_or(qa, "categories2", lambda: mealdb.categories()["body"]["categories"])


@when(parsers.parse('meals are filtered by category "{cat}"'))
def filtered(qa, cat):
    fetch_or(qa, "filtered", lambda: mealdb.filter_by_category(cat)["body"]["meals"])


@when(parsers.parse("the meal with id {mid:d} is looked up"))
def looked_up(qa, mid):
    fetch_or(qa, "looked", lambda: mealdb.lookup(mid)["body"]["meals"])


@when("the first filtered meal is looked up")
def first_filtered_looked(qa):
    fetch_or(qa, "looked", lambda: mealdb.lookup(qa.meal["filtered"][0]["idMeal"])["body"]["meals"])


@when(parsers.parse('meals are searched by name "{term}"'))
def searched_name(qa, term):
    fetch_or(qa, "search", lambda: mealdb.search_by_name(term)["body"]["meals"])


@when(parsers.parse('meals are searched by first letter "{letter}"'))
def searched_letter(qa, letter):
    fetch_or(qa, "search", lambda: mealdb.search_by_letter(letter)["body"]["meals"])


@when("the meal category names are listed")
def category_names(qa):
    fetch_or(qa, "catNames", lambda: mealdb.list_category_names()["body"]["meals"])


@when("the meal areas are listed")
def areas_listed(qa):
    fetch_or(qa, "areas", lambda: mealdb.list_areas()["body"]["meals"])


# ---------------------------------------------------------------- categories


@then(parsers.parse("there are at least {n:d} categories"))
def at_least_categories(qa, n):
    qa.observe(f"at least {n} categories", lambda: (len(qa.meal["categories"]) >= n, f"{len(qa.meal['categories'])} categories"))


@then("every category has an id and a name")
def category_id_name(qa):
    qa.observe("category id + name", lambda: ((lambda bad: (not bad, f"{len(bad)} incomplete"))([c for c in qa.meal["categories"] if not c.get("idCategory") or not c.get("strCategory")])))


@then("no category id appears more than once")
def category_ids_unique(qa):
    def ev():
        ids = [c["idCategory"] for c in qa.meal["categories"]]
        dup = [v for i, v in enumerate(ids) if ids.index(v) != i]
        return (not dup, "dup" if dup else f"{len(ids)} unique")
    qa.observe("category ids unique", ev)


@then("every category name is non-empty when trimmed")
def category_names_trimmed(qa):
    qa.observe("category names trimmed", lambda: ((lambda bad: (not bad, f"{len(bad)} empty"))([c for c in qa.meal["categories"] if not str(c["strCategory"]).strip()])))


@then("every category thumbnail is an http URL")
def category_thumbs(qa):
    qa.observe("category thumbs are URLs", lambda: ((lambda bad: (not bad, "all URLs" if not bad else "bad"))([c for c in qa.meal["categories"] if not mealdb.is_http_url(c.get("strCategoryThumb"))])))


@then("both category reads return the same ids")
def stable_categories(qa):
    def ev():
        a = sorted(c["idCategory"] for c in qa.meal["categories"])
        b = sorted(c["idCategory"] for c in qa.meal["categories2"])
        return (a == b, f"first {len(a)}, second {len(b)}")
    qa.observe("stable category ids", ev)


# ---------------------------------------------------------------- filtered meals


@then("the filtered meals are non-empty")
def filtered_non_empty(qa):
    qa.observe("filtered non-empty", lambda: (isinstance(qa.meal.get("filtered"), list) and len(qa.meal["filtered"]) > 0, f"{len(qa.meal.get('filtered') or [])} meals"))


@then("every filtered meal has an id, a name and a thumbnail")
def filtered_complete(qa):
    def ev():
        meals = qa.meal.get("filtered") or []
        bad = [m for m in meals if not m.get("idMeal") or not m.get("strMeal") or not mealdb.is_http_url(m.get("strMealThumb"))]
        return (not bad and len(meals) > 0, f"{len(bad)} incomplete")
    qa.observe("filtered meals complete", ev)


@then("no filtered meal id appears more than once")
def filtered_ids_unique(qa):
    def ev():
        ids = [m["idMeal"] for m in (qa.meal.get("filtered") or [])]
        dup = [v for i, v in enumerate(ids) if ids.index(v) != i]
        return (not dup, "dup" if dup else f"{len(ids)} unique")
    qa.observe("filtered ids unique", ev)


@then("every filtered meal id is a positive integer")
def filtered_ids_positive(qa):
    def ev():
        bad = [m for m in (qa.meal.get("filtered") or []) if mealdb.to_id(m.get("idMeal")) is None or mealdb.to_id(m.get("idMeal")) <= 0]
        return (not bad, f"{len(bad)} bad")
    qa.observe("filtered ids positive ints", ev)


@then("every filtered meal thumbnail is an http URL")
def filtered_thumbs(qa):
    qa.observe("filtered thumbs are URLs", lambda: ((lambda bad: (not bad, f"{len(bad)} non-URL"))([m for m in (qa.meal.get("filtered") or []) if not mealdb.is_http_url(m.get("strMealThumb"))])))


# ---------------------------------------------------------------- lookup


@then(parsers.parse("the looked-up meal has id {mid:d}"))
def looked_id(qa, mid):
    def ev():
        m = looked_meal(qa)
        return (bool(m) and mealdb.to_id(m.get("idMeal")) == mid, f"idMeal {m['idMeal']}" if m else "no meal")
    qa.observe(f"looked-up id {mid}", ev)


@then("the looked-up meal has instructions, a category and an area")
def looked_details(qa):
    def ev():
        m = looked_meal(qa)
        return (bool(m) and bool(str(m.get("strInstructions") or "").strip()) and bool(m.get("strCategory")) and bool(m.get("strArea")), f"cat {m.get('strCategory')}, area {m.get('strArea')}" if m else "no meal")
    qa.observe("meal has instructions/category/area", ev)


@then("the looked-up meal lists at least one ingredient")
def looked_ingredient(qa):
    def ev():
        m = looked_meal(qa)
        ing = mealdb.ingredients(m) if m else []
        return (len(ing) > 0, f"{len(ing)} ingredients")
    qa.observe("meal lists an ingredient", ev)


@then(parsers.parse('the looked-up meal reports category "{cat}"'))
def looked_category(qa, cat):
    def ev():
        m = looked_meal(qa)
        return (bool(m) and m.get("strCategory") == cat, f"category {m.get('strCategory')}" if m else "no meal")
    qa.observe(f"looked-up category {cat}", ev)


# ---------------------------------------------------------------- search / no result


@then("no meal is returned")
def no_meal(qa):
    def ev():
        meals = qa.meal["looked"] if "looked" in qa.meal else qa.meal.get("search")
        return (meals is None or (isinstance(meals, list) and len(meals) == 0), "null" if meals is None else f"{len(meals or [])} meals")
    qa.observe("no meal returned", ev)


@then(parsers.parse('a meal named "{name}" is returned'))
def meal_named(qa, name):
    def ev():
        meals = qa.meal.get("search") or []
        return (any(m["strMeal"] == name for m in meals), " | ".join(m["strMeal"] for m in meals[:3]))
    qa.observe("meal named " + name, ev)


@then(parsers.parse('every returned meal name starts with "{letter}"'))
def names_start_with(qa, letter):
    def ev():
        meals = qa.meal.get("search") or []
        bad = [m for m in meals if not str(m["strMeal"]).lower().startswith(letter.lower())]
        return (len(meals) > 0 and not bad, ",".join(m["strMeal"] for m in bad[:3]) if bad else f"{len(meals)} start with {letter}")
    qa.observe("names start with " + letter, ev)


@then("at least one meal is returned")
def at_least_one_meal(qa):
    qa.observe("at least one meal", lambda: ((lambda meals: (len(meals) > 0, f"{len(meals)} meals"))(qa.meal.get("search") or [])))


# ---------------------------------------------------------------- lists


@then("every listed category name is a known category")
def listed_names_known(qa):
    def ev():
        known = {c["strCategory"] for c in qa.meal["categories"]}
        bad = [r for r in (qa.meal.get("catNames") or []) if r["strCategory"] not in known]
        return (not bad and len(qa.meal.get("catNames") or []) > 0, "stray" if bad else "subset")
    qa.observe("listed names subset categories", ev)


@then("the area list is non-empty")
def area_non_empty(qa):
    qa.observe("area list non-empty", lambda: (isinstance(qa.meal.get("areas"), list) and len(qa.meal["areas"]) > 0, f"{len(qa.meal.get('areas') or [])} areas"))
