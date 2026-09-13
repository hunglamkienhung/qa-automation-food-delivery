'use strict';

/**
 * TheMealDB's public JSON API: themealdb.com/api/json/v1/1. No key, read-only.
 *
 * It answers HTTP 200 with a JSON body; an unknown lookup or search returns
 * `{"meals": null}`, which the steps read as "no meal". A transport failure, a
 * 5xx/429/403, or a non-JSON body (a challenge page from some runner IPs) is
 * MealDbUnreachable, which grades Blocked -- the catalogue being unreachable is
 * not the catalogue being wrong.
 *
 * Ids arrive as strings ("52772"); `toId` coerces them so a step can assert an
 * integer invariant.
 */

const BASE = (process.env.MEALDB_API_URL || 'https://www.themealdb.com/api/json/v1/1').replace(/\/+$/, '');
const USER_AGENT = 'qa-automation-food-delivery/1.0 (read-only invariants)';
const TIMEOUT_MS = 25_000;

class MealDbUnreachable extends Error {}

async function request(path) {
  const init = { method: 'GET', headers: { 'user-agent': USER_AGENT, accept: 'application/json' }, signal: AbortSignal.timeout(TIMEOUT_MS) };
  let res;
  try { res = await fetch(BASE + path, init); } catch (err) {
    throw new MealDbUnreachable('GET ' + path + ' -- ' + (err.cause && err.cause.code ? err.cause.code : (err.name || err.message)));
  }
  const text = await res.text();
  if (res.status >= 500 || res.status === 429 || res.status === 403) throw new MealDbUnreachable('GET ' + path + ' -- HTTP ' + res.status);
  let body; try { body = JSON.parse(text); } catch { body = null; }
  if (body === null || typeof body !== 'object') throw new MealDbUnreachable('GET ' + path + ' -- expected JSON, got ' + text.slice(0, 40).replace(/\s+/g, ' ') + '…');
  return { httpStatus: res.status, body };
}

const categories = () => request('/categories.php');
const listCategoryNames = () => request('/list.php?c=list');
const listAreas = () => request('/list.php?a=list');
const filterByCategory = (cat) => request('/filter.php?c=' + encodeURIComponent(cat));
const lookup = (id) => request('/lookup.php?i=' + encodeURIComponent(id));
const searchByName = (term) => request('/search.php?s=' + encodeURIComponent(term));
const searchByLetter = (letter) => request('/search.php?f=' + encodeURIComponent(letter));

/** Coerce an id ("52772" or 52772) to an integer, or NaN. */
function toId(v) { return Number.parseInt(String(v), 10); }
/** The non-empty ingredients of a full meal document (strIngredient1..20). */
function ingredients(meal) {
  const out = [];
  for (let i = 1; i <= 20; i++) { const v = meal['strIngredient' + i]; if (v && String(v).trim()) out.push(String(v).trim()); }
  return out;
}
const isHttpUrl = (s) => /^https?:\/\/\S+$/.test(String(s || ''));

module.exports = { BASE, MealDbUnreachable, request, categories, listCategoryNames, listAreas, filterByCategory, lookup, searchByName, searchByLetter, toId, ingredients, isHttpUrl };
