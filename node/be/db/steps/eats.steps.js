'use strict';

const { Given, When, Then, Before, After } = require('@cucumber/cucumber');
const { Store, DbUnreachable, throwaway } = require('../store');
const { MiniEats, ApiUnreachable } = require('../../api/venues/minieats');

/**
 * Steps for features/be-minieats-db.feature, plus the shared "drive the
 * service" Givens that be-minieats-api.feature reuses.
 *
 * Isolation is by delta, not by reset: each scenario notes the baseline it
 * cares about (an item's stock, the order count), drives the API to change it,
 * and asserts the change. Fresh customers, carts and orders mean those rows
 * never collide between scenarios.
 */

const eats = new MiniEats();
const UNREACHABLE = [DbUnreachable, ApiUnreachable];

Before({ tags: '@minieats' }, function () {
  this.store = null;
  this.eats = eats;
  this.buyer = null;
  this.cartToken = null;
  this.orderId = null;
  this.noted = {};
  this.last = null;      // last order/api response
  this.tmp = null;
  this.api = null;       // last HTTP response (minieats-api tier)
});

After({ tags: '@minieats' }, function () {
  if (this.tmp) { try { this.tmp.close(); } catch { /* fine */ } }
  if (this.store) this.store.close();
});

// ---------------------------------------------------------------- helpers

async function act(world, fn) {
  if (world.sourceError) return undefined;
  try { return await fn(); } catch (err) {
    if (UNREACHABLE.some((C) => err instanceof C)) { world.sourceError = err.message; return undefined; }
    throw err;
  }
}
async function check(world, description, fn) {
  if (world.sourceError) { world.unobservable(description, 'the source could not be reached -- ' + world.sourceError); return; }
  let r;
  try { r = await fn(); } catch (err) { if (UNREACHABLE.some((C) => err instanceof C)) { world.unobservable(description, err.message); return; } throw err; }
  world.check(description, r.passed, r.detail);
}
const j = (v) => JSON.stringify(v);

// ---------------------------------------------------------------- Background

Given('the store is open and the service is reachable', { timeout: 30_000 }, async function () {
  if (this.sourceError) return;
  try { this.store = new Store(); } catch (err) { if (err instanceof DbUnreachable) { this.sourceError = err.message; return; } throw err; }
  const r = await act(this, () => eats.get('/restaurants'));
  if (this.sourceError) return;
  if (!r || r.status !== 200) this.sourceError = 'mini-eats did not answer /restaurants: ' + (r ? r.status : 'no response');
  this.evidence('storeFile', this.store.file);
});

// ---------------------------------------------------------------- drive the service (shared with @api)

Given('a customer with a cart at restaurant {int}', { timeout: 30_000 }, async function (rid) {
  await act(this, async () => { this.buyer = await eats.newCustomer(); this.cartToken = await eats.openCart(this.buyer.token, rid); });
});

async function addToCart(world, qty, iid) {
  await act(world, async () => { const r = await eats.addItem(world.buyer.token, world.cartToken, iid, qty); if (r.status !== 200) throw new Error('add item failed: ' + r.status + ' ' + r.text); });
}
Given('the cart holds {int} of item {int}', { timeout: 30_000 }, async function (qty, iid) { await addToCart(this, qty, iid); });
Given('the cart holds {int} of item {int} and {int} of item {int}', { timeout: 30_000 }, async function (q1, i1, q2, i2) { await addToCart(this, q1, i1); await addToCart(this, q2, i2); });
Given('the cart holds {int} of item {int} and {int} of item {int} and {int} of item {int}', { timeout: 30_000 }, async function (q1, i1, q2, i2, q3, i3) { await addToCart(this, q1, i1); await addToCart(this, q2, i2); await addToCart(this, q3, i3); });

Given('the stock of item {int} is noted', function (iid) { if (this.store) this.noted['stock.' + iid] = this.store.get('SELECT stock FROM menu_items WHERE id = ?', iid).stock; });
Given('the order count is noted', function () { if (this.store) this.noted.orders = this.store.count('orders'); });

async function doCheckout(world, body) {
  return act(world, async () => { world.last = await eats.checkout(world.buyer.token, { cart_token: world.cartToken, ...body }); world.api = world.last; if (world.last.status === 201) world.orderId = world.last.body.id; return world.last; });
}
When('the customer checks out', { timeout: 30_000 }, async function () { await doCheckout(this, {}); });
When('the customer checks out with idempotency key {string}', { timeout: 30_000 }, async function (key) { this.noted.firstOrder = await doCheckout(this, { idempotency_key: key }); });
When('the customer checks out again with idempotency key {string}', { timeout: 30_000 }, async function (key) { this.noted.secondOrder = await doCheckout(this, { idempotency_key: key }); });
When('the customer tries to order {int} of item {int}', { timeout: 30_000 }, async function (qty, iid) {
  await act(this, async () => { const r = await eats.addItem(this.buyer.token, this.cartToken, iid, qty); this.last = r.status === 200 ? await eats.checkout(this.buyer.token, { cart_token: this.cartToken }) : r; this.api = this.last; });
});

// one-shot placed / delivered orders (used by the state-machine and ledger scenarios)
async function placeOrder(world, rid, lines) {
  await act(world, async () => {
    world.buyer = await eats.newCustomer();
    const cart = await eats.openCart(world.buyer.token, rid);
    world.cartToken = cart;
    for (const [qty, iid] of lines) { const a = await eats.addItem(world.buyer.token, cart, iid, qty); if (a.status !== 200) throw new Error('add item: ' + a.text); }
    world.last = await eats.checkout(world.buyer.token, { cart_token: cart });
    if (world.last.status !== 201) throw new Error('checkout: ' + world.last.text);
    world.orderId = world.last.body.id;
  });
}
Given('a placed order of {int} of item {int} at restaurant {int}', { timeout: 60_000 }, async function (qty, iid, rid) { await placeOrder(this, rid, [[qty, iid]]); });
Given('a delivered order of {int} of item {int} at restaurant {int}', { timeout: 90_000 }, async function (qty, iid, rid) {
  await placeOrder(this, rid, [[qty, iid]]);
  await act(this, async () => {
    const id = this.orderId;
    for (const [step, tok] of [['accept', eats.seedMerchant], ['prepare', eats.seedMerchant], ['ready', eats.seedMerchant], ['assign', eats.seedDriver], ['pickup', eats.seedDriver], ['deliver', eats.seedDriver]]) {
      const r = await eats.post(`/orders/${id}/${step}`, undefined, tok ? { token: tok } : {});
      if (r.status !== 200) throw new Error(step + ' failed: ' + r.status + ' ' + r.text);
    }
  });
});

When('the merchant accepts the order', { timeout: 30_000 }, async function () { await act(this, async () => { this.last = await eats.post(`/orders/${this.orderId}/accept`, undefined, { token: eats.seedMerchant }); this.api = this.last; }); });
When('the merchant rejects the order', { timeout: 30_000 }, async function () { await act(this, async () => { this.last = await eats.post(`/orders/${this.orderId}/reject`, undefined, { token: eats.seedMerchant }); this.api = this.last; }); });
When('the customer cancels the order', { timeout: 30_000 }, async function () { await act(this, async () => { this.last = await eats.post(`/orders/${this.orderId}/cancel`, undefined, { token: this.buyer.token }); this.api = this.last; }); });

function order(world) { return world.last && world.last.body && world.last.status === 201 ? world.last.body : null; }

// ---------------------------------------------------------------- schema (throwaway)

Then('the store has tables {}', async function (list) {
  const want = list.split(/,\s*/);
  await check(this, 'store has the documented tables', () => { const have = this.store.tables(); const missing = want.filter((t) => !have.includes(t)); return { passed: missing.length === 0, detail: missing.length ? 'missing ' + missing.join(', ') : have.length + ' tables' }; });
});

Given('a throwaway database with the schema applied', function () {
  this.tmp = throwaway();
  this.tmp.exec("INSERT INTO restaurants (id, name, cuisine, commission_bps, active) VALUES (1, 'R', 'C', 2000, 1)");
  this.tmp.exec("INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (1, 1, 'M', 'Cat', 100, 10, 1)");
  this.tmp.exec("INSERT INTO customers (id, name, token, created_at) VALUES (1, 'C', 'ctok', 1)");
  this.tmp.exec("INSERT INTO drivers (id, name, token, status, created_at) VALUES (1, 'D', 'dtok', 'available', 1)");
  this.tmp.exec("INSERT INTO carts (id, token, customer_id, restaurant_id, status, created_at) VALUES (1, 't', 1, 1, 'open', 1)");
  this.tmp.exec("INSERT INTO orders (id, customer_id, restaurant_id, subtotal_cents, delivery_fee_cents, total_cents, created_at) VALUES (1, 1, 1, 100, 300, 400, 1)");
});
Given('a throwaway database with the schema and seed applied', function () {
  const fs = require('fs'); const path = require('path');
  this.tmp = throwaway();
  this.tmp.exec(fs.readFileSync(path.join(__dirname, '..', '..', '..', '..', 'services', 'mini-eats', 'db', 'seed.sql'), 'utf8'));
});

function fails(db, sql, params, re) {
  try { db.prepare(sql).run(...params); return { passed: false, detail: 'insert succeeded' }; } catch (err) { return { passed: re.test(err.message), detail: err.message }; }
}
Then('inserting two menu items with the same name on one restaurant fails on the second', function () {
  this.observe('menu name UNIQUE per restaurant', () => { const a = fails(this.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (2, 1, 'DUP', 'C', 1, 1, 1)", [], /never/); if (a.detail !== 'insert succeeded') return { passed: false, detail: 'first: ' + a.detail }; return fails(this.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (3, 1, 'DUP', 'C', 1, 1, 1)", [], /UNIQUE constraint failed: menu_items\.restaurant_id, menu_items\.name/); });
});
Then('inserting an order_items row for a missing order fails a FOREIGN KEY', function () {
  this.observe('order_items.order_id FK', () => fails(this.tmp, 'INSERT INTO order_items (order_id, menu_item_id, qty, price_cents) VALUES (999, 1, 1, 1)', [], /FOREIGN KEY constraint failed/));
});
Then('inserting an order_items row for a missing menu item fails a FOREIGN KEY', function () {
  this.observe('order_items.menu_item_id FK', () => fails(this.tmp, 'INSERT INTO order_items (order_id, menu_item_id, qty, price_cents) VALUES (1, 999, 1, 1)', [], /FOREIGN KEY constraint failed/));
});
Then('inserting a menu item with negative price fails a CHECK', function () {
  this.observe('price_cents >= 0', () => fails(this.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (4, 1, 'N1', 'C', -1, 1, 1)", [], /CHECK constraint failed/));
});
Then('inserting a menu item with negative stock fails a CHECK', function () {
  this.observe('stock >= 0', () => fails(this.tmp, "INSERT INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES (5, 1, 'N2', 'C', 1, -1, 1)", [], /CHECK constraint failed/));
});
Then('inserting a cart item with zero quantity fails a CHECK', function () {
  this.observe('qty > 0', () => fails(this.tmp, 'INSERT INTO cart_items (cart_id, menu_item_id, qty) VALUES (1, 1, 0)', [], /CHECK constraint failed/));
});
Then('inserting an order with status {string} fails a CHECK', function (status) {
  this.observe('order status CHECK', () => fails(this.tmp, 'INSERT INTO orders (id, customer_id, restaurant_id, subtotal_cents, delivery_fee_cents, total_cents, status, created_at) VALUES (2, 1, 1, 100, 300, 400, ?, 1)', [status], /CHECK constraint failed/));
});
Then('inserting an order event with actor {string} fails a CHECK', function (actor) {
  this.observe('order_events actor CHECK', () => fails(this.tmp, 'INSERT INTO order_events (order_id, from_status, to_status, actor, created_at) VALUES (1, NULL, ?, ?, 1)', ['placed', actor], /CHECK constraint failed/));
});
Then('inserting a ledger row with zero delta fails a CHECK', function () {
  this.observe('ledger delta <> 0', () => fails(this.tmp, "INSERT INTO ledger (party_type, party_id, delta_cents, reason, order_id, created_at) VALUES ('platform', NULL, 0, 'commission', 1, 1)", [], /CHECK constraint failed/));
});
Then('inserting a ledger row with reason {string} fails a CHECK', function (reason) {
  this.observe('ledger reason CHECK', () => fails(this.tmp, 'INSERT INTO ledger (party_type, party_id, delta_cents, reason, order_id, created_at) VALUES (?, NULL, 10, ?, 1, 1)', ['platform', reason], /CHECK constraint failed/));
});
Then('inserting a ledger row with party type {string} fails a CHECK', function (party) {
  this.observe('ledger party_type CHECK', () => fails(this.tmp, 'INSERT INTO ledger (party_type, party_id, delta_cents, reason, order_id, created_at) VALUES (?, NULL, 10, ?, 1, 1)', [party, 'commission'], /CHECK constraint failed/));
});
Then('inserting a driver with status {string} fails a CHECK', function (status) {
  this.observe('driver status CHECK', () => fails(this.tmp, 'INSERT INTO drivers (id, name, token, status, created_at) VALUES (2, \'X\', \'t2\', ?, 1)', [status], /CHECK constraint failed/));
});
Then('inserting a restaurant with commission over 100 percent fails a CHECK', function () {
  this.observe('commission_bps <= 10000', () => fails(this.tmp, "INSERT INTO restaurants (id, name, cuisine, commission_bps, active) VALUES (2, 'X', 'Y', 10001, 1)", [], /CHECK constraint failed/));
});
Then('applying the seed again changes no row counts', function () {
  const fs = require('fs'); const path = require('path');
  this.observe('seed idempotent', () => {
    const tables = ['restaurants', 'menu_items', 'drivers'];
    const before = tables.map((t) => this.tmp.prepare('SELECT COUNT(*) AS n FROM ' + t).get().n);
    this.tmp.exec(fs.readFileSync(path.join(__dirname, '..', '..', '..', '..', 'services', 'mini-eats', 'db', 'seed.sql'), 'utf8'));
    const after = tables.map((t) => this.tmp.prepare('SELECT COUNT(*) AS n FROM ' + t).get().n);
    return { passed: j(before) === j(after), detail: 'before ' + j(before) + ', after ' + j(after) };
  });
});

// ---------------------------------------------------------------- checkout <-> rows

Then('the order total equals its subtotal plus the delivery fee', async function () {
  await check(this, 'total == subtotal + delivery fee', () => { const o = order(this); if (!o) return { passed: false, detail: 'no order: ' + j(this.last && this.last.body) }; const row = this.store.get('SELECT * FROM orders WHERE id = ?', o.id); return { passed: row.total_cents === row.subtotal_cents + row.delivery_fee_cents && row.total_cents === o.total_cents, detail: `sub ${row.subtotal_cents} + fee ${row.delivery_fee_cents} = ${row.total_cents}` }; });
});
Then('each order line price equals the menu item\'s price at order time', async function () {
  await check(this, 'order line price == menu price', () => { const id = this.orderId; const lines = this.store.all('SELECT * FROM order_items WHERE order_id = ?', id); const bad = lines.filter((it) => { const m = this.store.get('SELECT price_cents FROM menu_items WHERE id = ?', it.menu_item_id); return it.price_cents !== m.price_cents; }); return { passed: lines.length > 0 && bad.length === 0, detail: bad.length ? j(bad) : lines.length + ' lines match' }; });
});
Then('the stock of item {int} fell by {int}', async function (iid, d) {
  await check(this, `stock of ${iid} fell by ${d}`, () => { const now = this.store.get('SELECT stock FROM menu_items WHERE id = ?', iid).stock; return { passed: this.noted['stock.' + iid] - now === d, detail: `before ${this.noted['stock.' + iid]}, now ${now}` }; });
});
Then('the checkout is refused with code {string}', function (code) {
  this.observe('checkout refused: ' + code, () => ({ passed: !!(this.last && this.last.status >= 400 && this.last.body && this.last.body.code === code), detail: this.last ? this.last.status + ' ' + j(this.last.body) : 'no response' }));
});
Then('the stock of item {int} is unchanged', async function (iid) {
  await check(this, `stock of ${iid} unchanged`, () => { const now = this.store.get('SELECT stock FROM menu_items WHERE id = ?', iid).stock; return { passed: now === this.noted['stock.' + iid], detail: `before ${this.noted['stock.' + iid]}, now ${now}` }; });
});
Then('the stock of item {int} is unchanged from the note', async function (iid) {
  await check(this, `stock of ${iid} back to note`, () => { const now = this.store.get('SELECT stock FROM menu_items WHERE id = ?', iid).stock; return { passed: now === this.noted['stock.' + iid], detail: `note ${this.noted['stock.' + iid]}, now ${now}` }; });
});
Then('no new order was created', async function () {
  await check(this, 'order count unchanged', () => { const n = this.store.count('orders'); return { passed: n === this.noted.orders, detail: `before ${this.noted.orders}, now ${n}` }; });
});
Then('the cart row status is {string}', async function (status) {
  await check(this, 'cart status ' + status, () => { const c = this.store.get('SELECT status FROM carts WHERE token = ?', this.cartToken); return { passed: !!c && c.status === status, detail: c ? c.status : 'no cart' }; });
});
Then('the order\'s customer is the buyer', async function () {
  await check(this, 'order.customer_id == buyer', () => { const o = order(this); const row = this.store.get('SELECT customer_id FROM orders WHERE id = ?', o.id); return { passed: row.customer_id === this.buyer.id, detail: `order ${row.customer_id}, buyer ${this.buyer.id}` }; });
});
Then('the order has {int} order lines', async function (n) {
  await check(this, `order has ${n} lines`, () => { const o = order(this); const c = this.store.count('order_items', 'WHERE order_id = ?', o.id); return { passed: c === n, detail: 'lines ' + c }; });
});

// ---------------------------------------------------------------- the state machine

Then('the order status row is {string}', async function (status) {
  await check(this, 'order status row ' + status, () => { const o = this.store.get('SELECT status FROM orders WHERE id = ?', this.orderId); return { passed: !!o && o.status === status, detail: o ? o.status : 'no order' }; });
});
Then('the order\'s first event is placed by the customer', async function () {
  await check(this, 'first event placed by customer', () => { const ev = this.store.events(this.orderId)[0]; return { passed: !!ev && ev.from_status === null && ev.to_status === 'placed' && ev.actor === 'customer', detail: ev ? `${ev.from_status}->${ev.to_status} by ${ev.actor}` : 'no events' }; });
});
Then('an event records placed to accepted by the merchant', async function () { await eventRecords(this, 'placed', 'accepted', 'merchant'); });
Then('an event records placed to rejected by the merchant', async function () { await eventRecords(this, 'placed', 'rejected', 'merchant'); });
Then('an event records placed to cancelled by the customer', async function () { await eventRecords(this, 'placed', 'cancelled', 'customer'); });
async function eventRecords(world, from, to, actor) {
  await check(world, `event ${from}->${to} by ${actor}`, () => { const ev = world.store.events(world.orderId).find((e) => e.from_status === from && e.to_status === to); return { passed: !!ev && ev.actor === actor, detail: ev ? `by ${ev.actor}` : 'no such event' }; });
}
Then('the order\'s events run placed, accepted, preparing, ready, assigned, picked_up, delivered', async function () {
  await check(this, 'lifecycle events in order', () => { const seq = this.store.events(this.orderId).map((e) => e.to_status); const want = ['placed', 'accepted', 'preparing', 'ready', 'assigned', 'picked_up', 'delivered']; return { passed: j(seq) === j(want), detail: seq.join(' -> ') }; });
});
Then('each event names the actor responsible for that transition', async function () {
  await check(this, 'events name the right actors', () => {
    const byTo = Object.fromEntries(this.store.events(this.orderId).map((e) => [e.to_status, e.actor]));
    const want = { placed: 'customer', accepted: 'merchant', preparing: 'merchant', ready: 'merchant', assigned: 'driver', picked_up: 'driver', delivered: 'driver' };
    const bad = Object.entries(want).filter(([to, actor]) => byTo[to] !== actor);
    return { passed: bad.length === 0, detail: bad.length ? 'mismatch ' + j(bad) : j(byTo) };
  });
});

// ---------------------------------------------------------------- the ledger

Then('the restaurant\'s payout equals the subtotal minus commission', async function () {
  await check(this, 'restaurant payout == subtotal - commission', () => {
    const o = this.store.get('SELECT * FROM orders WHERE id = ?', this.orderId);
    const r = this.store.get('SELECT commission_bps FROM restaurants WHERE id = ?', o.restaurant_id);
    const commission = Math.floor((o.subtotal_cents * r.commission_bps) / 10000);
    const row = this.store.ledger(this.orderId).find((l) => l.party_type === 'restaurant' && l.reason === 'payout');
    return { passed: !!row && row.delta_cents === o.subtotal_cents - commission, detail: row ? `payout ${row.delta_cents}, expected ${o.subtotal_cents - commission}` : 'no payout row' };
  });
});
Then('the driver\'s ledger credit equals the delivery fee', async function () {
  await check(this, 'driver credit == delivery fee', () => { const o = this.store.get('SELECT * FROM orders WHERE id = ?', this.orderId); const row = this.store.ledger(this.orderId).find((l) => l.party_type === 'driver' && l.reason === 'delivery_fee'); return { passed: !!row && row.delta_cents === o.delivery_fee_cents, detail: row ? `driver ${row.delta_cents}, fee ${o.delivery_fee_cents}` : 'no driver row' }; });
});
Then('the platform\'s ledger credit equals the commission', async function () {
  await check(this, 'platform credit == commission', () => {
    const o = this.store.get('SELECT * FROM orders WHERE id = ?', this.orderId);
    const r = this.store.get('SELECT commission_bps FROM restaurants WHERE id = ?', o.restaurant_id);
    const commission = Math.floor((o.subtotal_cents * r.commission_bps) / 10000);
    const row = this.store.ledger(this.orderId).find((l) => l.party_type === 'platform' && l.reason === 'commission');
    return { passed: !!row && row.delta_cents === commission, detail: row ? `platform ${row.delta_cents}, expected ${commission}` : 'no platform row' };
  });
});
Then('the order\'s ledger credits sum to the order total', async function () {
  await check(this, 'ledger sum == total', () => { const o = this.store.get('SELECT total_cents FROM orders WHERE id = ?', this.orderId); const sum = this.store.ledger(this.orderId).reduce((s, l) => s + l.delta_cents, 0); return { passed: sum === o.total_cents, detail: `ledger ${sum}, total ${o.total_cents}` }; });
});
Then('the order has no ledger rows', async function () {
  await check(this, 'no ledger rows', () => { const n = this.store.ledger(this.orderId).length; return { passed: n === 0, detail: n + ' ledger rows' }; });
});

// ---------------------------------------------------------------- idempotency and integrity

Then('exactly one new order was created', async function () {
  await check(this, 'exactly one new order', () => { const n = this.store.count('orders'); return { passed: n === this.noted.orders + 1, detail: `before ${this.noted.orders}, now ${n}` }; });
});
Then('both checkouts returned the same order id', async function () {
  this.observe('idempotent replay returns same order', () => { const a = this.noted.firstOrder, b = this.noted.secondOrder; return { passed: !!(a && b && a.body && b.body && a.body.id === b.body.id), detail: `first ${a && a.body && a.body.id}, second ${b && b.body && b.body.id}` }; });
});
Then('no order_items row references a menu item missing from menu_items', async function () {
  await check(this, 'no orphan order line', () => { const n = this.store.count('order_items oi', 'WHERE NOT EXISTS (SELECT 1 FROM menu_items m WHERE m.id = oi.menu_item_id)'); return { passed: n === 0, detail: `${n} orphans` }; });
});
Then('no orders row references a customer missing from customers', async function () {
  await check(this, 'no orphan order->customer', () => { const n = this.store.count('orders o', 'WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.id = o.customer_id)'); return { passed: n === 0, detail: `${n} orphans` }; });
});
Then('no orders row references a restaurant missing from restaurants', async function () {
  await check(this, 'no orphan order->restaurant', () => { const n = this.store.count('orders o', 'WHERE NOT EXISTS (SELECT 1 FROM restaurants r WHERE r.id = o.restaurant_id)'); return { passed: n === 0, detail: `${n} orphans` }; });
});
