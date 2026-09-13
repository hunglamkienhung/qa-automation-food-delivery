'use strict';

const { Given, When, Then, Before } = require('@cucumber/cucumber');
const mealdb = require('../venues/mealdb');

/**
 * Steps for features/be-mealdb-api.feature. HTTPS against TheMealDB's public
 * API. Its documents (categories, filtered meals, a looked-up meal) are stashed
 * on this.meal and asserted for the API's own invariants. A transport failure
 * is MealDbUnreachable and grades Blocked.
 */

const UNREACHABLE = [mealdb.MealDbUnreachable];

Before({ tags: '@mealdb' }, function () { this.meal = {}; });

async function fetchOr(world, key, fn) {
  await world.fetchOrBlock(UNREACHABLE, async () => { world.meal[key] = await fn(); });
}
function obs(world, description, evaluate) { world.observe(description, evaluate); }
const lookedMeal = (world) => (world.meal.looked && world.meal.looked[0]) || null;

// ---------------------------------------------------------------- fetches

When('the meal categories are fetched', { timeout: 30_000 }, async function () { await fetchOr(this, 'categories', async () => (await mealdb.categories()).body.categories); });
When('the meal categories are fetched again', { timeout: 30_000 }, async function () { await fetchOr(this, 'categories2', async () => (await mealdb.categories()).body.categories); });
When('meals are filtered by category {string}', { timeout: 30_000 }, async function (cat) { await fetchOr(this, 'filtered', async () => (await mealdb.filterByCategory(cat)).body.meals); });
When('the meal with id {int} is looked up', { timeout: 30_000 }, async function (id) { await fetchOr(this, 'looked', async () => (await mealdb.lookup(id)).body.meals); });
When('the first filtered meal is looked up', { timeout: 30_000 }, async function () { await fetchOr(this, 'looked', async () => { const id = this.meal.filtered[0].idMeal; return (await mealdb.lookup(id)).body.meals; }); });
When('meals are searched by name {string}', { timeout: 30_000 }, async function (term) { await fetchOr(this, 'search', async () => (await mealdb.searchByName(term)).body.meals); });
When('meals are searched by first letter {string}', { timeout: 30_000 }, async function (letter) { await fetchOr(this, 'search', async () => (await mealdb.searchByLetter(letter)).body.meals); });
When('the meal category names are listed', { timeout: 30_000 }, async function () { await fetchOr(this, 'catNames', async () => (await mealdb.listCategoryNames()).body.meals); });
When('the meal areas are listed', { timeout: 30_000 }, async function () { await fetchOr(this, 'areas', async () => (await mealdb.listAreas()).body.meals); });

// ---------------------------------------------------------------- categories

Then('there are at least {int} categories', function (n) { obs(this, 'at least ' + n + ' categories', () => ({ passed: this.meal.categories.length >= n, detail: this.meal.categories.length + ' categories' })); });
Then('every category has an id and a name', function () { obs(this, 'category id + name', () => { const bad = this.meal.categories.filter((c) => !c.idCategory || !c.strCategory); return { passed: bad.length === 0, detail: bad.length + ' incomplete' }; }); });
Then('no category id appears more than once', function () { obs(this, 'category ids unique', () => { const ids = this.meal.categories.map((c) => c.idCategory); const dup = ids.filter((v, i) => ids.indexOf(v) !== i); return { passed: dup.length === 0, detail: dup.length ? 'dup ' + dup.slice(0, 3).join(',') : ids.length + ' unique' }; }); });
Then('every category name is non-empty when trimmed', function () { obs(this, 'category names trimmed', () => { const bad = this.meal.categories.filter((c) => !String(c.strCategory).trim()); return { passed: bad.length === 0, detail: bad.length + ' empty' }; }); });
Then('every category thumbnail is an http URL', function () { obs(this, 'category thumbs are URLs', () => { const bad = this.meal.categories.filter((c) => !mealdb.isHttpUrl(c.strCategoryThumb)); return { passed: bad.length === 0, detail: bad.length ? bad.slice(0, 2).map((c) => c.strCategoryThumb).join(',') : 'all URLs' }; }); });
Then('both category reads return the same ids', function () { obs(this, 'stable category ids', () => { const a = this.meal.categories.map((c) => c.idCategory).sort(); const b = this.meal.categories2.map((c) => c.idCategory).sort(); return { passed: JSON.stringify(a) === JSON.stringify(b), detail: `first ${a.length}, second ${b.length}` }; }); });

// ---------------------------------------------------------------- filtered meals

Then('the filtered meals are non-empty', function () { obs(this, 'filtered non-empty', () => ({ passed: Array.isArray(this.meal.filtered) && this.meal.filtered.length > 0, detail: (this.meal.filtered || []).length + ' meals' })); });
Then('every filtered meal has an id, a name and a thumbnail', function () { obs(this, 'filtered meals complete', () => { const bad = (this.meal.filtered || []).filter((m) => !m.idMeal || !m.strMeal || !mealdb.isHttpUrl(m.strMealThumb)); return { passed: bad.length === 0 && (this.meal.filtered || []).length > 0, detail: bad.length + ' incomplete' }; }); });
Then('no filtered meal id appears more than once', function () { obs(this, 'filtered ids unique', () => { const ids = (this.meal.filtered || []).map((m) => m.idMeal); const dup = ids.filter((v, i) => ids.indexOf(v) !== i); return { passed: dup.length === 0, detail: dup.length ? 'dup ' + dup.slice(0, 3).join(',') : ids.length + ' unique' }; }); });
Then('every filtered meal id is a positive integer', function () { obs(this, 'filtered ids positive ints', () => { const bad = (this.meal.filtered || []).filter((m) => { const n = mealdb.toId(m.idMeal); return !Number.isInteger(n) || n <= 0; }); return { passed: bad.length === 0, detail: bad.length + ' bad' }; }); });
Then('every filtered meal thumbnail is an http URL', function () { obs(this, 'filtered thumbs are URLs', () => { const bad = (this.meal.filtered || []).filter((m) => !mealdb.isHttpUrl(m.strMealThumb)); return { passed: bad.length === 0, detail: bad.length + ' non-URL' }; }); });

// ---------------------------------------------------------------- lookup

Then('the looked-up meal has id {int}', function (id) { obs(this, 'looked-up id ' + id, () => { const m = lookedMeal(this); return { passed: !!m && mealdb.toId(m.idMeal) === id, detail: m ? 'idMeal ' + m.idMeal : 'no meal' }; }); });
Then('the looked-up meal has instructions, a category and an area', function () { obs(this, 'meal has instructions/category/area', () => { const m = lookedMeal(this); return { passed: !!m && !!String(m.strInstructions || '').trim() && !!m.strCategory && !!m.strArea, detail: m ? `cat ${m.strCategory}, area ${m.strArea}` : 'no meal' }; }); });
Then('the looked-up meal lists at least one ingredient', function () { obs(this, 'meal lists an ingredient', () => { const m = lookedMeal(this); const ing = m ? mealdb.ingredients(m) : []; return { passed: ing.length > 0, detail: ing.length + ' ingredients' }; }); });
Then('the looked-up meal reports category {string}', function (cat) { obs(this, 'looked-up category ' + cat, () => { const m = lookedMeal(this); return { passed: !!m && m.strCategory === cat, detail: m ? 'category ' + m.strCategory : 'no meal' }; }); });

// ---------------------------------------------------------------- search / no result

Then('no meal is returned', function () { obs(this, 'no meal returned', () => { const meals = this.meal.looked !== undefined ? this.meal.looked : this.meal.search; return { passed: meals === null || (Array.isArray(meals) && meals.length === 0), detail: meals === null ? 'null' : (meals || []).length + ' meals' }; }); });
Then('a meal named {string} is returned', function (name) { obs(this, 'meal named ' + name, () => { const meals = this.meal.search || []; return { passed: meals.some((m) => m.strMeal === name), detail: meals.map((m) => m.strMeal).slice(0, 3).join(' | ') }; }); });
Then('every returned meal name starts with {string}', function (letter) { obs(this, 'names start with ' + letter, () => { const meals = this.meal.search || []; const bad = meals.filter((m) => !String(m.strMeal).toLowerCase().startsWith(letter.toLowerCase())); return { passed: meals.length > 0 && bad.length === 0, detail: bad.length ? bad.slice(0, 3).map((m) => m.strMeal).join(',') : meals.length + ' start with ' + letter }; }); });
Then('at least one meal is returned', function () { obs(this, 'at least one meal', () => { const meals = this.meal.search || []; return { passed: meals.length > 0, detail: meals.length + ' meals' }; }); });

// ---------------------------------------------------------------- lists

Then('every listed category name is a known category', function () { obs(this, 'listed names ⊆ categories', () => { const known = new Set(this.meal.categories.map((c) => c.strCategory)); const bad = (this.meal.catNames || []).filter((r) => !known.has(r.strCategory)); return { passed: bad.length === 0 && (this.meal.catNames || []).length > 0, detail: bad.length ? 'stray ' + bad.slice(0, 3).map((r) => r.strCategory).join(',') : 'subset' }; }); });
Then('the area list is non-empty', function () { obs(this, 'area list non-empty', () => ({ passed: Array.isArray(this.meal.areas) && this.meal.areas.length > 0, detail: (this.meal.areas || []).length + ' areas' })); });
