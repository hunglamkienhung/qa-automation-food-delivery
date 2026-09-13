'use strict';

const { Given, When, Then } = require('@cucumber/cucumber');
const { EatsPage, ScreenNotReady } = require('../pages/eats');
const { MiniEats, ApiUnreachable } = require('../../../be/api/venues/minieats');

/**
 * Steps for features/fe-minieats.feature -- the only steps in this domain that
 * drive a browser. The comparison figures come from the store (this.store,
 * opened by the @minieats Before hook) and the API, so the FE branch checks the
 * four app screens against the same rows the BE branch reads. The order-setup
 * Givens (a placed / ready / delivered order) are shared from the be steps.
 */

const eats = new MiniEats();
const money = (c) => '$' + (c / 100).toFixed(2);

Given('the home page is open', { timeout: 90_000 }, async function () {
  this.eatsPage = new EatsPage(this.page);
  await this.fetchOrBlock([ScreenNotReady], async () => { await this.eatsPage.open('/'); this.screen.restaurants = await this.eatsPage.restaurants(); });
});

async function screen(world, description, fn) {
  if (world.sourceError) { world.unobservable(description, 'the source could not be reached -- ' + world.sourceError); return; }
  let r;
  try { r = await fn(); } catch (err) { if (err instanceof ScreenNotReady || err instanceof ApiUnreachable) { world.unobservable(description, err.message); return; } throw err; }
  world.check(description, r.passed, r.detail);
}
function activeRestaurants(world) { return world.store.all('SELECT * FROM restaurants WHERE active = 1 ORDER BY id'); }

// ---------------------------------------------------------------- navigation

When('the menu for restaurant {int} is opened', { timeout: 90_000 }, async function (rid) {
  await this.fetchOrBlock([ScreenNotReady], async () => { await this.eatsPage.open('/restaurant/' + rid); this.screen.menu = await this.eatsPage.menu().catch(() => null); });
});
When('the order page is opened', { timeout: 90_000 }, async function () {
  await this.fetchOrBlock([ScreenNotReady], async () => { await this.eatsPage.open('/order/' + this.orderId); this.screen.order = await this.eatsPage.order().catch(() => null); });
});
When('the order page for {int} is opened', { timeout: 90_000 }, async function (id) {
  await this.fetchOrBlock([ScreenNotReady], async () => { await this.eatsPage.open('/order/' + id); this.screen.order = await this.eatsPage.order().catch(() => null); });
});
When('the merchant board for restaurant {int} is opened', { timeout: 90_000 }, async function (rid) {
  await this.fetchOrBlock([ScreenNotReady], async () => { await this.eatsPage.open('/merchant/' + rid); this.screen.board = await this.eatsPage.board().catch(() => null); });
});
When('the driver board is opened', { timeout: 90_000 }, async function () {
  await this.fetchOrBlock([ScreenNotReady], async () => { await this.eatsPage.open('/driver/1'); this.screen.offers = await this.eatsPage.offers().catch(() => null); });
});
When('the admin page is opened', { timeout: 90_000 }, async function () {
  await this.fetchOrBlock([ScreenNotReady], async () => { await this.eatsPage.open('/admin'); this.screen.admin = await this.eatsPage.admin().catch(() => null); });
});

// ---------------------------------------------------------------- home Thens

Then('the home page lists the active restaurants, once each', async function () {
  await screen(this, 'home == active restaurants', async () => { const ids = this.screen.restaurants.map((r) => r.id).sort((a, b) => a - b); const want = activeRestaurants(this).map((r) => r.id); return { passed: JSON.stringify(ids) === JSON.stringify(want), detail: `screen ${ids.length}, active ${want.length}` }; });
});
Then('the home page does not list restaurant {int}', async function (rid) {
  await screen(this, 'home excludes ' + rid, async () => ({ passed: !this.screen.restaurants.some((r) => r.id === rid), detail: 'ids ' + this.screen.restaurants.map((r) => r.id).join(',') }));
});
Then('each home row links to its restaurant page', async function () {
  await screen(this, 'home rows link to restaurants', async () => { const bad = this.screen.restaurants.filter((r) => r.href !== '/restaurant/' + r.id); return { passed: bad.length === 0 && this.screen.restaurants.length > 0, detail: bad.length ? JSON.stringify(bad.slice(0, 2)) : this.screen.restaurants.length + ' links' }; });
});
Then('the home page shows at least one restaurant', async function () {
  await screen(this, 'home non-empty', async () => ({ passed: this.screen.restaurants.length > 0, detail: this.screen.restaurants.length + ' restaurants' }));
});

// ---------------------------------------------------------------- menu Thens

Then('every menu price on screen equals the item row', async function () {
  await screen(this, 'menu prices == rows', async () => { if (!this.screen.menu) return { passed: false, detail: 'no menu' }; const bad = this.screen.menu.filter((m) => { const row = this.store.get('SELECT price_cents FROM menu_items WHERE id = ?', m.id); return !row || m.priceText !== money(row.price_cents); }); return { passed: bad.length === 0 && this.screen.menu.length > 0, detail: bad.length ? JSON.stringify(bad.slice(0, 2)) : this.screen.menu.length + ' prices match' }; });
});
Then('every menu name on screen equals the item row', async function () {
  await screen(this, 'menu names == rows', async () => { if (!this.screen.menu) return { passed: false, detail: 'no menu' }; const bad = this.screen.menu.filter((m) => { const row = this.store.get('SELECT name FROM menu_items WHERE id = ?', m.id); return !row || m.name !== row.name; }); return { passed: bad.length === 0, detail: bad.length ? JSON.stringify(bad.slice(0, 2)) : 'names match' }; });
});
Then('menu item {int} is shown unavailable', async function (iid) {
  await screen(this, 'item ' + iid + ' unavailable', async () => { const m = (this.screen.menu || []).find((x) => x.id === iid); return { passed: !!m && /unavailable/i.test(m.statusText), detail: m ? m.statusText : 'not on menu' }; });
});
Then('menu item {int} is shown available', async function (iid) {
  await screen(this, 'item ' + iid + ' available', async () => { const m = (this.screen.menu || []).find((x) => x.id === iid); return { passed: !!m && /^available$/i.test(m.statusText), detail: m ? m.statusText : 'not on menu' }; });
});
Then('every menu price on screen is a dollar amount', async function () {
  await screen(this, 'menu prices are dollar amounts', async () => { const bad = (this.screen.menu || []).filter((m) => !/^\$\d+\.\d{2}$/.test(m.priceText)); return { passed: bad.length === 0 && (this.screen.menu || []).length > 0, detail: bad.length ? bad.map((m) => m.priceText).join(',') : 'all dollar amounts' }; });
});
Then('the page reports not found', async function () {
  await screen(this, 'page not found', async () => { const txt = await this.page.textContent('body'); return { passed: /no such/i.test(txt), detail: txt.slice(0, 60) }; });
});

// ---------------------------------------------------------------- order page Thens

Then('the order page total equals the stored order total', async function () {
  await screen(this, 'order page total == stored', async () => { const o = this.screen.order; const row = this.store.get('SELECT total_cents FROM orders WHERE id = ?', this.orderId); return { passed: !!o && o.totalText === money(row.total_cents), detail: o ? o.totalText + ' vs ' + money(row.total_cents) : 'no order page' }; });
});
Then('the order page shows the order id and status {string}', async function (status) {
  await screen(this, 'order page id + status', async () => { const o = this.screen.order; return { passed: !!o && o.idText.includes(String(this.orderId)) && o.statusText === status, detail: o ? o.idText + ' / ' + o.statusText : 'no order page' }; });
});
Then('the order page total is shown as a dollar amount', async function () {
  await screen(this, 'order page total format', async () => ({ passed: !!this.screen.order && /^\$\d+\.\d{2}$/.test(this.screen.order.totalText), detail: this.screen.order ? this.screen.order.totalText : 'no page' }));
});
Then('the order page shows status {string}', async function (status) {
  await screen(this, 'order page status ' + status, async () => ({ passed: !!this.screen.order && this.screen.order.statusText === status, detail: this.screen.order ? this.screen.order.statusText : 'no page' }));
});

// ---------------------------------------------------------------- merchant board Thens

Then('the placed order appears on the merchant board with status {string}', async function (status) {
  await screen(this, 'order on merchant board', async () => { const row = (this.screen.board || []).find((o) => o.id === this.orderId); return { passed: !!row && row.statusText === status, detail: row ? row.statusText : 'not on board' }; });
});
Then('every order total on the board is a dollar amount', async function () {
  await screen(this, 'board totals are dollar amounts', async () => { const bad = (this.screen.board || []).filter((o) => !/^\$\d+\.\d{2}$/.test(o.totalText)); return { passed: bad.length === 0 && (this.screen.board || []).length > 0, detail: bad.length ? bad.map((o) => o.totalText).join(',') : 'all dollar amounts' }; });
});

// ---------------------------------------------------------------- driver board Thens

Then('the ready order is offered on the driver board', async function () {
  await screen(this, 'ready order offered', async () => { const ids = (this.screen.offers || []).map((o) => o.id); return { passed: ids.includes(this.orderId), detail: 'offers ' + ids.join(',') }; });
});
Then('the driver board offer count equals the API offer count', async function () {
  await screen(this, 'offer count == API', async () => { const r = await eats.get('/offers', { token: eats.seedDriver }); const api = (r.body.offers || []).length; return { passed: (this.screen.offers || []).length === api, detail: `screen ${(this.screen.offers || []).length}, api ${api}` }; });
});
Then('every offered fee on the board is a dollar amount', async function () {
  await screen(this, 'offer fees are dollar amounts', async () => { const bad = (this.screen.offers || []).filter((o) => !/^\$\d+\.\d{2}$/.test(o.feeText)); return { passed: bad.length === 0 && (this.screen.offers || []).length > 0, detail: bad.length ? bad.map((o) => o.feeText).join(',') : 'all dollar amounts' }; });
});

// ---------------------------------------------------------------- admin Thens

Then('the admin revenue is shown as a dollar amount', async function () {
  await screen(this, 'admin revenue format', async () => ({ passed: !!this.screen.admin && /^\$\d+\.\d{2}$/.test(this.screen.admin.revenueText), detail: this.screen.admin ? this.screen.admin.revenueText : 'no page' }));
});
Then('the admin page shows at least one delivered order', async function () {
  await screen(this, 'admin delivered >= 1', async () => { const row = (this.screen.admin && this.screen.admin.counts || []).find((c) => c.status === 'delivered'); return { passed: !!row && Number(row.n) >= 1, detail: row ? 'delivered ' + row.n : 'no delivered count' }; });
});
Then('every admin status count is a non-negative integer', async function () {
  await screen(this, 'admin counts are non-negative ints', async () => { const counts = (this.screen.admin && this.screen.admin.counts) || []; const bad = counts.filter((c) => !/^\d+$/.test(c.n) || Number(c.n) < 0); return { passed: bad.length === 0 && counts.length > 0, detail: bad.length ? JSON.stringify(bad) : counts.length + ' counts' }; });
});
