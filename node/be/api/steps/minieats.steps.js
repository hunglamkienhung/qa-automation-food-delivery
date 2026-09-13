'use strict';

const { Given, When, Then } = require('@cucumber/cucumber');
const { MiniEats, ApiUnreachable } = require('../venues/minieats');
const { DbUnreachable } = require('../../db/store');

/**
 * Steps for features/be-minieats-api.feature: the REST layer compared with the
 * rows it serves, across the customer, merchant, driver and admin apps. The
 * Background, the store, and many "drive the service" Givens (place an order,
 * advance it, cancel it) are shared from be/db/steps/eats.steps.js. `this.api`
 * / `this.last` is always the last response.
 */

const eats = new MiniEats();
const UNREACHABLE = [ApiUnreachable, DbUnreachable];
const j = (v) => JSON.stringify(v);
const money = (c) => '$' + (c / 100).toFixed(2);

async function send(world, method, path, opts = {}) {
  if (world.sourceError) return;
  try { world.api = await eats.request(method, path, opts); world.last = world.api; } catch (err) {
    if (err instanceof ApiUnreachable) { world.sourceError = err.message; return; }
    throw err;
  }
}
async function check(world, description, fn) {
  if (world.sourceError) { world.unobservable(description, 'the source could not be reached -- ' + world.sourceError); return; }
  let r;
  try { r = await fn(); } catch (err) { if (UNREACHABLE.some((C) => err instanceof C)) { world.unobservable(description, err.message); return; } throw err; }
  world.check(description, r.passed, r.detail);
}
function body(world) { return (world.api && world.api.body) || {}; }
function field(world, n) { return body(world)[n]; }
function resp(world) { return world.last && world.last.body ? world.last.body : {}; }

function menuRowView(store, row) {
  return { id: row.id, restaurant_id: row.restaurant_id, name: row.name, category: row.category, price_cents: row.price_cents, price: money(row.price_cents), stock: row.stock, available: !!row.available && row.stock > 0 };
}
function orderRowView(store, id) {
  const o = store.get('SELECT * FROM orders WHERE id = ?', id);
  if (!o) return null;
  const items = store.all('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', id).map((it) => ({ menu_item_id: it.menu_item_id, qty: it.qty, price_cents: it.price_cents }));
  return { id: o.id, customer_id: o.customer_id, restaurant_id: o.restaurant_id, driver_id: o.driver_id, subtotal_cents: o.subtotal_cents, delivery_fee_cents: o.delivery_fee_cents, total_cents: o.total_cents, status: o.status, items };
}

// ---------------------------------------------------------------- requests

When(/^GET (\/\S*)$/, { timeout: 30_000 }, async function (path) { await send(this, 'GET', path); });

Given('a registered customer', { timeout: 30_000 }, async function () {
  if (this.sourceError) return;
  try { this.buyer = await eats.newCustomer(); } catch (err) { if (err instanceof ApiUnreachable) this.sourceError = err.message; else throw err; }
});
When('a cart is opened at restaurant {int} with no token', { timeout: 30_000 }, async function (rid) { await send(this, 'POST', '/carts', { body: { restaurant_id: rid } }); });
When('the customer opens a cart at restaurant {int}', { timeout: 30_000 }, async function (rid) { await send(this, 'POST', '/carts', { token: this.buyer.token, body: { restaurant_id: rid } }); });

async function addItems(world, qty, iid) { await send(world, 'POST', `/carts/${world.cartToken}/items`, { token: world.buyer.token, body: { menu_item_id: iid, qty } }); }
When('{int} of item {int} are added to the cart', { timeout: 30_000 }, async function (qty, iid) { await addItems(this, qty, iid); });

When('checkout is posted with no token', { timeout: 30_000 }, async function () { await send(this, 'POST', '/orders', { body: { cart_token: this.cartToken } }); });
When('the order is fetched', { timeout: 30_000 }, async function () { await send(this, 'GET', '/orders/' + this.orderId); });

// merchant / driver / admin actions that are NOT already in the DB steps
When('the merchant prepares the order', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/prepare`); });
When('the merchant marks the order ready', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/ready`); });
Given('the merchant has accepted the order', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/accept`); });
Given('the order has been made ready', { timeout: 30_000 }, async function () { await driveToReady(this); });
Given('a ready order of {int} of item {int} at restaurant {int}', { timeout: 60_000 }, async function (qty, iid, rid) { await placeOrderApi(this, rid, [[qty, iid]]); await driveToReady(this); });
When('another customer tries to cancel the order', { timeout: 30_000 }, async function () { const other = await eats.newCustomer(); await send(this, 'POST', `/orders/${this.orderId}/cancel`, { token: other.token }); });

When('the driver reads the offers', { timeout: 30_000 }, async function () { await send(this, 'GET', '/offers', { token: eats.seedDriver }); });
When('the offers are read with no token', { timeout: 30_000 }, async function () { await send(this, 'GET', '/offers'); });
When('the driver assigns the order', { timeout: 30_000 }, async function () { if (!this.driver) this.driver = await eats.newDriver(); await send(this, 'POST', `/orders/${this.orderId}/assign`, { token: this.driver.token }); });
Given('a driver has assigned the order', { timeout: 30_000 }, async function () { this.driver = await eats.newDriver(); await send(this, 'POST', `/orders/${this.orderId}/assign`, { token: this.driver.token }); });
When('the driver picks up the order', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/pickup`, { token: this.driver.token }); });
When('the driver delivers the order', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/deliver`, { token: this.driver.token }); });
When('the assigned driver delivers the order', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/deliver`, { token: this.driver.token }); });
When('another driver assigns the order', { timeout: 30_000 }, async function () { const other = await eats.newDriver(); await send(this, 'POST', `/orders/${this.orderId}/assign`, { token: other.token }); });
When('another driver picks up the order', { timeout: 30_000 }, async function () { const other = await eats.newDriver(); await send(this, 'POST', `/orders/${this.orderId}/pickup`, { token: other.token }); });

When(/^GET \/admin\/overview with no token$/, { timeout: 30_000 }, async function () { await send(this, 'GET', '/admin/overview'); });
When('the admin reads the overview', { timeout: 30_000 }, async function () { await send(this, 'GET', '/admin/overview', { token: eats.adminToken }); });
When('the admin lists orders with status {string}', { timeout: 30_000 }, async function (status) { await send(this, 'GET', '/admin/orders?status=' + status, { token: eats.adminToken }); });
When('the admin deactivates restaurant {int}', { timeout: 30_000 }, async function (rid) { await send(this, 'PATCH', `/admin/restaurants/${rid}`, { token: eats.adminToken, body: { active: false } }); });
Given('the admin reactivates restaurant {int}', { timeout: 30_000 }, async function (rid) { await send(this, 'PATCH', `/admin/restaurants/${rid}`, { token: eats.adminToken, body: { active: true } }); });

// helpers used above (place + drive), local so as not to clash with the DB steps' one-shots
async function placeOrderApi(world, rid, lines) {
  if (world.sourceError) return;
  try {
    world.buyer = await eats.newCustomer();
    const cart = await eats.openCart(world.buyer.token, rid);
    world.cartToken = cart;
    for (const [qty, iid] of lines) { const a = await eats.addItem(world.buyer.token, cart, iid, qty); if (a.status !== 200) throw new Error('add item: ' + a.text); }
    const o = await eats.checkout(world.buyer.token, { cart_token: cart });
    if (o.status !== 201) throw new Error('checkout: ' + o.text);
    world.orderId = o.body.id; world.last = o; world.api = o;
  } catch (err) { if (err instanceof ApiUnreachable) world.sourceError = err.message; else throw err; }
}
async function driveToReady(world) {
  if (world.sourceError) return;
  for (const step of ['accept', 'prepare', 'ready']) {
    const r = await eats.post(`/orders/${world.orderId}/${step}`);
    if (r.status !== 200) throw new Error(step + ': ' + r.text);
  }
}

// ---------------------------------------------------------------- Then: status/shape

Then(/^the response status is (\d+)$/, async function (s) { await check(this, 'status ' + s, () => ({ passed: this.api.status === Number(s), detail: 'status ' + this.api.status + ' ' + (this.api.text || '').slice(0, 140) })); });
Then(/^the response is an error with code "([^"]*)"$/, async function (code) { await check(this, 'error code ' + code, () => { const b = body(this); return { passed: b.code === code && typeof b.error === 'string', detail: (this.api.text || '').slice(0, 140) }; }); });
Then('the response field {string} is true', async function (n) { await check(this, n + ' is true', () => ({ passed: field(this, n) === true, detail: n + ' = ' + j(field(this, n)) })); });

// ---------------------------------------------------------------- Then: restaurants / menu

Then('every restaurant in the response is active', async function () {
  await check(this, 'restaurants all active', () => { const rs = field(this, 'restaurants') || []; const bad = rs.filter((r) => { const row = this.store.get('SELECT active FROM restaurants WHERE id = ?', r.id); return !row || row.active !== 1; }); return { passed: rs.length > 0 && bad.length === 0, detail: bad.length ? 'inactive ' + bad.map((r) => r.id).join(',') : rs.length + ' active' }; });
});
Then('no inactive restaurant appears', async function () {
  await check(this, 'no inactive restaurant', () => { const ids = (field(this, 'restaurants') || []).map((r) => r.id); const inactive = this.store.all('SELECT id FROM restaurants WHERE active = 0').map((r) => r.id); const bad = ids.filter((id) => inactive.includes(id)); return { passed: bad.length === 0, detail: bad.length ? 'leaked ' + bad.join(',') : 'none' }; });
});
Then('every menu item in the response matches its row', async function () {
  await check(this, 'menu items match rows', () => { const bad = (field(this, 'menu') || []).filter((m) => { const row = this.store.get('SELECT * FROM menu_items WHERE id = ?', m.id); return !row || j(menuRowView(this.store, row)) !== j(m); }); return { passed: bad.length === 0 && (field(this, 'menu') || []).length > 0, detail: bad.length ? 'mismatch ' + j(bad.slice(0, 2)) : (field(this, 'menu') || []).length + ' match' }; });
});
Then('menu item {int} is reported unavailable', async function (iid) {
  await check(this, 'item ' + iid + ' unavailable', () => { const m = (field(this, 'menu') || []).find((x) => x.id === iid); return { passed: !!m && m.available === false, detail: m ? 'available=' + m.available : 'not on menu' }; });
});

// ---------------------------------------------------------------- Then: cart

Then('the cart holds {int} of item {int} priced from the row', async function (qty, iid) {
  await check(this, `cart holds ${qty}x${iid}`, () => { const it = (field(this, 'items') || []).find((x) => x.menu_item_id === iid); const row = this.store.get('SELECT price_cents FROM menu_items WHERE id = ?', iid); return { passed: !!it && it.qty === qty && it.price_cents === row.price_cents && it.line_cents === qty * row.price_cents, detail: it ? j(it) : 'no line' }; });
});
Then('the cart subtotal equals the sum of its line totals', async function () {
  await check(this, 'subtotal == Σ lines', () => { const items = field(this, 'items') || []; const sum = items.reduce((s, it) => s + it.line_cents, 0); return { passed: field(this, 'subtotal_cents') === sum, detail: `subtotal ${field(this, 'subtotal_cents')}, Σ ${sum}` }; });
});
Then('the cart has {int} lines', async function (n) { await check(this, 'cart has ' + n + ' lines', () => { const items = field(this, 'items') || []; return { passed: items.length === n, detail: items.length + ' lines' }; }); });

// ---------------------------------------------------------------- Then: orders

Then('the order in the response equals the stored order', async function () {
  await check(this, 'order == stored order', () => { const b = body(this); const row = orderRowView(this.store, b.id); return { passed: !!row && j({ ...b, idempotent_replay: undefined }) === j({ ...row, idempotent_replay: undefined }), detail: row ? 'api ' + j(b) : 'no order row' }; });
});
Then('the order total in the response equals its subtotal plus the delivery fee', async function () {
  await check(this, 'order total == subtotal + fee', () => { const b = body(this); return { passed: b.total_cents === b.subtotal_cents + b.delivery_fee_cents, detail: `sub ${b.subtotal_cents} + fee ${b.delivery_fee_cents} = ${b.total_cents}` }; });
});
Then('the order in the response reports status {string}', async function (status) {
  await check(this, 'response order status ' + status, () => { const b = resp(this); return { passed: b.status === status, detail: 'status ' + b.status + ' ' + (this.last.text || '').slice(0, 120) }; });
});
Then('the order in the response is assigned to the driver', async function () {
  await check(this, 'order assigned to driver', () => { const b = resp(this); return { passed: b.driver_id === this.driver.id, detail: `driver_id ${b.driver_id}, driver ${this.driver.id}` }; });
});
Then('the tracked order reports status {string}', async function (status) { await check(this, 'tracked status ' + status, () => { const b = body(this); return { passed: b.status === status, detail: 'status ' + b.status }; }); });
Then('the tracked order has an event to {string}', async function (to) { await check(this, 'tracked event to ' + to, () => { const evs = body(this).events || []; return { passed: evs.some((e) => e.to === to), detail: j(evs) }; }); });
Then('the second checkout is flagged an idempotent replay', async function () {
  this.observe('idempotent replay flagged', () => { const b = this.noted.secondOrder && this.noted.secondOrder.body; return { passed: !!b && b.idempotent_replay === true, detail: b ? 'flag ' + b.idempotent_replay : 'no second order' }; });
});

// ---------------------------------------------------------------- Then: offers / board

Then('the placed order is not among the offers', async function () { await check(this, 'placed not offered', () => { const ids = (field(this, 'offers') || []).map((o) => o.id); return { passed: !ids.includes(this.orderId), detail: 'offers ' + ids.join(',') }; }); });
Then('the ready order is among the offers', async function () { await check(this, 'ready is offered', () => { const ids = (field(this, 'offers') || []).map((o) => o.id); return { passed: ids.includes(this.orderId), detail: 'offers ' + ids.join(',') }; }); });
Then('the placed order appears on the restaurant\'s board', async function () { await check(this, 'order on board', () => { const ids = (field(this, 'orders') || []).map((o) => o.id); return { passed: ids.includes(this.orderId), detail: 'board ' + ids.join(',') }; }); });
Then('every order on the board reports status {string}', async function (status) { await check(this, 'board all ' + status, () => { const os = field(this, 'orders') || []; const bad = os.filter((o) => o.status !== status); return { passed: os.length > 0 && bad.length === 0, detail: bad.length ? 'off ' + bad.map((o) => o.status).join(',') : os.length + ' ' + status }; }); });
Then('every listed order reports status {string}', async function (status) { await check(this, 'admin list all ' + status, () => { const os = field(this, 'orders') || []; const bad = os.filter((o) => o.status !== status); return { passed: os.length > 0 && bad.length === 0, detail: bad.length ? 'off ' + bad.map((o) => o.status).join(',') : os.length + ' ' + status }; }); });

// ---------------------------------------------------------------- Then: admin overview

Then('the overview counts at least one delivered order', async function () { await check(this, 'delivered count >= 1', () => { const c = (field(this, 'orders_by_status') || {}).delivered || 0; return { passed: c >= 1, detail: 'delivered ' + c }; }); });
Then('the overview revenue is at least the order total', async function () { await check(this, 'revenue >= order total', () => { const o = this.store.get('SELECT total_cents FROM orders WHERE id = ?', this.orderId); return { passed: field(this, 'revenue_cents') >= o.total_cents, detail: `revenue ${field(this, 'revenue_cents')}, order ${o.total_cents}` }; }); });
Then('the overview revenue equals payouts plus commission plus delivery fees', async function () {
  await check(this, 'revenue == payout + commission + fees', () => { const rev = field(this, 'revenue_cents'); const sum = (field(this, 'payout_cents') || 0) + (field(this, 'commission_cents') || 0) + (field(this, 'delivery_fee_cents') || 0); return { passed: rev === sum, detail: `revenue ${rev}, parts ${sum}` }; });
});
Then('restaurant {int} is not in the response', async function (rid) { await check(this, rid + ' absent', () => { const ids = (field(this, 'restaurants') || []).map((r) => r.id); return { passed: !ids.includes(rid), detail: 'ids ' + ids.join(',') }; }); });
Then('restaurant {int} is in the response', async function (rid) { await check(this, rid + ' present', () => { const ids = (field(this, 'restaurants') || []).map((r) => r.id); return { passed: ids.includes(rid), detail: 'ids ' + ids.join(',') }; }); });
