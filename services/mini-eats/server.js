#!/usr/bin/env node
'use strict';

const http = require('http');
const path = require('path');
const { URL } = require('url');
const { open } = require('./lib/db');
const H = require('./lib/http');

/**
 * mini-eats: a small food-delivery backend over one SQLite file. Node standard
 * library only. It serves four apps -- customer, merchant, driver, admin --
 * over one REST API and small labelled HTML pages for Playwright.
 *
 * The order lifecycle is a state machine: placed -> accepted -> preparing ->
 * ready -> picked_up -> delivered, with cancelled/rejected as terminal exits
 * from `placed`. Each transition is gated by the actor and the current status,
 * writes an order_events row, and (on delivery) posts the restaurant payout,
 * the driver's fee and the platform commission to a ledger that sums to the
 * order total.
 */

const cfg = {
  port: Number(process.env.MINI_EATS_PORT || 8130),
  dbFile: process.env.MINI_EATS_DB || path.join(__dirname, 'data', 'mini-eats.db'),
  adminToken: process.env.MINI_EATS_ADMIN_TOKEN || 'admin-token',
};
const DELIVERY_FEE = 300;   // flat, cents

const now = () => Math.floor(Date.now() / 1000);
const money = (c) => '$' + (c / 100).toFixed(2);

function json(res, status, body, extra = {}) { res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', ...extra }); res.end(JSON.stringify(body)); }
function html(res, status, body) { res.writeHead(status, { 'content-type': 'text/html; charset=utf-8' }); res.end('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' + body); }
function esc(s) { return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
function readBody(req) {
  return new Promise((resolve, reject) => {
    let d = '';
    req.on('data', (c) => { d += c; if (d.length > 65536) reject(new H.ApiError(413, 'too_large', 'body too large')); });
    req.on('end', () => { try { resolve(d ? JSON.parse(d) : {}); } catch { reject(new H.ApiError(400, 'bad_request', 'body is not JSON')); } });
  });
}

// The lifecycle: action -> { from, to, actor, restock? }.
const TRANSITIONS = {
  cancel: { from: 'placed', to: 'cancelled', actor: 'customer', restock: true },
  accept: { from: 'placed', to: 'accepted', actor: 'merchant' },
  reject: { from: 'placed', to: 'rejected', actor: 'merchant', restock: true },
  prepare: { from: 'accepted', to: 'preparing', actor: 'merchant' },
  ready: { from: 'preparing', to: 'ready', actor: 'merchant' },
  pickup: { from: 'ready', to: 'picked_up', actor: 'driver' },
  deliver: { from: 'picked_up', to: 'delivered', actor: 'driver' },
};

function main() {
  const db = open(cfg.dbFile);
  const q = {
    restaurants: db.prepare('SELECT * FROM restaurants WHERE active = 1 ORDER BY id'),
    restaurant: db.prepare('SELECT * FROM restaurants WHERE id = ?'),
    menu: db.prepare('SELECT * FROM menu_items WHERE restaurant_id = ? ORDER BY id'),
    menuItem: db.prepare('SELECT * FROM menu_items WHERE id = ?'),
    decStock: db.prepare('UPDATE menu_items SET stock = stock - ? WHERE id = ?'),
    incStock: db.prepare('UPDATE menu_items SET stock = stock + ? WHERE id = ?'),
    setRestaurantActive: db.prepare('UPDATE restaurants SET active = ? WHERE id = ?'),
    insCustomer: db.prepare('INSERT INTO customers (name, token, created_at) VALUES (?, ?, ?)'),
    customerByToken: db.prepare('SELECT * FROM customers WHERE token = ?'),
    insDriver: db.prepare('INSERT INTO drivers (name, token, status, created_at) VALUES (?, ?, \'available\', ?)'),
    driverByToken: db.prepare('SELECT * FROM drivers WHERE token = ?'),
    insMerchant: db.prepare('INSERT INTO merchants (name, token, created_at) VALUES (?, ?, ?)'),
    merchantByToken: db.prepare('SELECT * FROM merchants WHERE token = ?'),
    setDriverStatus: db.prepare('UPDATE drivers SET status = ? WHERE id = ?'),
    insCart: db.prepare('INSERT INTO carts (token, customer_id, restaurant_id, status, created_at) VALUES (?, ?, ?, \'open\', ?)'),
    cart: db.prepare('SELECT * FROM carts WHERE token = ?'),
    setCartStatus: db.prepare('UPDATE carts SET status = ? WHERE id = ?'),
    cartItems: db.prepare('SELECT ci.*, m.name, m.price_cents, m.stock, m.available, m.restaurant_id FROM cart_items ci JOIN menu_items m ON m.id = ci.menu_item_id WHERE ci.cart_id = ? ORDER BY ci.id'),
    cartItem: db.prepare('SELECT * FROM cart_items WHERE cart_id = ? AND menu_item_id = ?'),
    insCartItem: db.prepare('INSERT INTO cart_items (cart_id, menu_item_id, qty) VALUES (?, ?, ?)'),
    setCartItemQty: db.prepare('UPDATE cart_items SET qty = ? WHERE cart_id = ? AND menu_item_id = ?'),
    insOrder: db.prepare('INSERT INTO orders (customer_id, restaurant_id, subtotal_cents, delivery_fee_cents, total_cents, status, idempotency_key, created_at) VALUES (?, ?, ?, ?, ?, \'placed\', ?, ?)'),
    order: db.prepare('SELECT * FROM orders WHERE id = ?'),
    orderByKey: db.prepare('SELECT * FROM orders WHERE idempotency_key = ?'),
    ordersByRestaurant: db.prepare('SELECT * FROM orders WHERE restaurant_id = ? ORDER BY id'),
    allOrders: db.prepare('SELECT * FROM orders ORDER BY id'),
    offers: db.prepare("SELECT * FROM orders WHERE status = 'ready' AND driver_id IS NULL ORDER BY id"),
    insOrderItem: db.prepare('INSERT INTO order_items (order_id, menu_item_id, qty, price_cents) VALUES (?, ?, ?, ?)'),
    orderItems: db.prepare('SELECT * FROM order_items WHERE order_id = ? ORDER BY id'),
    setOrderStatus: db.prepare('UPDATE orders SET status = ? WHERE id = ?'),
    setOrderDriver: db.prepare('UPDATE orders SET driver_id = ? WHERE id = ?'),
    insEvent: db.prepare('INSERT INTO order_events (order_id, from_status, to_status, actor, created_at) VALUES (?, ?, ?, ?, ?)'),
    events: db.prepare('SELECT * FROM order_events WHERE order_id = ? ORDER BY id'),
    insLedger: db.prepare('INSERT INTO ledger (party_type, party_id, delta_cents, reason, order_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'),
    statusCounts: db.prepare('SELECT status, COUNT(*) AS n FROM orders GROUP BY status'),
    deliveredTotals: db.prepare("SELECT COALESCE(SUM(total_cents),0) AS revenue FROM orders WHERE status = 'delivered'"),
    ledgerBy: db.prepare("SELECT COALESCE(SUM(delta_cents),0) AS s FROM ledger WHERE reason = ?"),
  };

  const menuView = (m) => ({ id: m.id, restaurant_id: m.restaurant_id, name: m.name, category: m.category, price_cents: m.price_cents, price: money(m.price_cents), stock: m.stock, available: !!m.available && m.stock > 0 });
  const orderView = (o) => ({ id: o.id, customer_id: o.customer_id, restaurant_id: o.restaurant_id, driver_id: o.driver_id, subtotal_cents: o.subtotal_cents, delivery_fee_cents: o.delivery_fee_cents, total_cents: o.total_cents, status: o.status, items: q.orderItems.all(o.id).map((it) => ({ menu_item_id: it.menu_item_id, qty: it.qty, price_cents: it.price_cents })) });

  const tx = (fn) => { db.exec('BEGIN IMMEDIATE'); try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { db.exec('ROLLBACK'); throw e; } };
  function requireCustomer(req) { const m = /^Bearer\s+(\S+)$/i.exec(req.headers.authorization || ''); const c = m && q.customerByToken.get(m[1]); if (!c) throw new H.ApiError(401, 'unauthenticated', 'a customer Bearer token is required'); return c; }
  function requireDriver(req) { const m = /^Bearer\s+(\S+)$/i.exec(req.headers.authorization || ''); const d = m && q.driverByToken.get(m[1]); if (!d) throw new H.ApiError(401, 'unauthenticated', 'a driver Bearer token is required'); return d; }
  function requireMerchant(req) { const m = /^Bearer\s+(\S+)$/i.exec(req.headers.authorization || ''); const mer = m && q.merchantByToken.get(m[1]); if (!mer) throw new H.ApiError(401, 'unauthenticated', 'a merchant Bearer token is required'); return mer; }
  function isAdmin(req) { const m = /^Bearer\s+(\S+)$/i.exec(req.headers.authorization || ''); return !!m && m[1] === cfg.adminToken; }
  function requireAdmin(req) { if (!isAdmin(req)) throw new H.ApiError(401, 'unauthenticated', 'the admin token is required'); }
  /** The merchant that owns this restaurant must be the caller (or the admin). 401 if not authenticated, 403 if the wrong merchant. */
  function requireRestaurantOwner(req, restaurantId) {
    if (isAdmin(req)) return;
    const mer = requireMerchant(req);
    const r = q.restaurant.get(Number(restaurantId));
    if (!r || r.merchant_id !== mer.id) throw new H.ApiError(403, 'forbidden', 'this restaurant is not yours');
    return mer;
  }

  /** Apply a lifecycle transition to an order, or reject it. Inside a transaction. */
  function transition(order, action) {
    const t = TRANSITIONS[action];
    if (order.status !== t.from) throw new H.ApiError(409, 'bad_state', `cannot ${action} an order that is ${order.status}`, { status: order.status });
    q.setOrderStatus.run(t.to, order.id);
    q.insEvent.run(order.id, t.from, t.to, t.actor, now());
    if (t.restock) for (const it of q.orderItems.all(order.id)) q.incStock.run(it.qty, it.menu_item_id);
    if (action === 'deliver') settleDelivery(order);
  }
  /** On delivery: pay the restaurant (subtotal - commission), the driver (fee), the platform (commission). */
  function settleDelivery(order) {
    const commission = Math.floor((order.subtotal_cents * q.restaurant.get(order.restaurant_id).commission_bps) / 10000);
    q.insLedger.run('restaurant', order.restaurant_id, order.subtotal_cents - commission, 'payout', order.id, now());
    q.insLedger.run('platform', null, commission, 'commission', order.id, now());
    q.insLedger.run('driver', order.driver_id, order.delivery_fee_cents, 'delivery_fee', order.id, now());
    q.setDriverStatus.run('available', order.driver_id);
  }

  async function route(req, res, url) {
    const parts = url.pathname.replace(/\/+$/, '').split('/').filter(Boolean);
    const [a, b, c, d] = parts;

    // ---- app screens (HTML) ----
    if (req.method === 'GET' && parts.length === 0) return renderHome(res);
    if (req.method === 'GET' && a === 'restaurant' && b && !c) return renderMenu(res, b);
    if (req.method === 'GET' && a === 'order' && b) return renderOrder(res, b);
    if (req.method === 'GET' && a === 'merchant' && b) return renderMerchant(res, b);
    if (req.method === 'GET' && a === 'driver' && b) return renderDriver(res, b);
    if (req.method === 'GET' && a === 'admin' && !b) return renderAdmin(res);

    // ---- health ----
    if (req.method === 'GET' && a === 'health') {
      return json(res, 200, { ok: true, restaurants: q.restaurants.all().length, orders: q.allOrders.all().length, drivers: 2, ts: now() });
    }

    // ---- market data ----
    if (req.method === 'GET' && a === 'restaurants' && !b) return json(res, 200, { restaurants: q.restaurants.all().map((r) => ({ id: r.id, name: r.name, cuisine: r.cuisine, commission_bps: r.commission_bps })) });
    if (req.method === 'GET' && a === 'restaurants' && b && !c) { const r = q.restaurant.get(Number(b)); if (!r || !r.active) throw new H.ApiError(404, 'not_found', 'no such restaurant'); return json(res, 200, { id: r.id, name: r.name, cuisine: r.cuisine }); }
    if (req.method === 'GET' && a === 'restaurants' && b && c === 'menu') { const r = q.restaurant.get(Number(b)); if (!r) throw new H.ApiError(404, 'not_found', 'no such restaurant'); return json(res, 200, { restaurant_id: r.id, menu: q.menu.all(r.id).map(menuView) }); }
    if (req.method === 'GET' && a === 'restaurants' && b && c === 'orders') { requireRestaurantOwner(req, b); const status = url.searchParams.get('status'); let rows = q.ordersByRestaurant.all(Number(b)); if (status) rows = rows.filter((o) => o.status === status); return json(res, 200, { restaurant_id: Number(b), orders: rows.map(orderView) }); }

    // ---- customer ----
    if (req.method === 'POST' && a === 'customers' && !b) { const body = await readBody(req); const tok = H.token('cust'); const info = q.insCustomer.run(String(body.name || 'Diner'), tok, now()); return json(res, 201, { id: Number(info.lastInsertRowid), token: tok }); }
    if (req.method === 'POST' && a === 'carts' && !b) {
      const cust = requireCustomer(req); const body = await readBody(req);
      const r = q.restaurant.get(Number(body.restaurant_id));
      if (!r) throw new H.ApiError(404, 'not_found', 'no such restaurant');
      if (!r.active) throw new H.ApiError(409, 'restaurant_closed', 'the restaurant is closed');
      const tok = H.token('cart'); q.insCart.run(tok, cust.id, r.id, now());
      return json(res, 201, cartView(tok));
    }
    if (a === 'carts' && b && c === 'items' && req.method === 'POST') {
      const cust = requireCustomer(req); const cart = q.cart.get(b);
      if (!cart || cart.customer_id !== cust.id) throw new H.ApiError(404, 'not_found', 'no such cart');
      if (cart.status !== 'open') throw new H.ApiError(409, 'cart_closed', 'cart is not open');
      const body = await readBody(req); const item = q.menuItem.get(Number(body.menu_item_id)); const qty = Number(body.qty);
      if (!item || item.restaurant_id !== cart.restaurant_id) throw new H.ApiError(404, 'not_found', 'item is not on this cart\'s restaurant');
      if (!item.available) throw new H.ApiError(409, 'unavailable', 'item is unavailable');
      if (!Number.isInteger(qty) || qty < 1) throw new H.ApiError(400, 'bad_request', 'qty must be a positive integer');
      const existing = q.cartItem.get(cart.id, item.id); const total = (existing ? existing.qty : 0) + qty;
      if (total > item.stock) throw new H.ApiError(409, 'insufficient_stock', 'not enough stock', { available: item.stock });
      if (existing) q.setCartItemQty.run(total, cart.id, item.id); else q.insCartItem.run(cart.id, item.id, qty);
      return json(res, 200, cartView(b));
    }
    if (req.method === 'GET' && a === 'carts' && b && !c) return json(res, 200, cartView(b));
    if (req.method === 'POST' && a === 'orders' && !b) {
      const cust = requireCustomer(req); const body = await readBody(req);
      const key = body.idempotency_key ? String(body.idempotency_key) : null;
      if (key) { const prior = q.orderByKey.get(key); if (prior) return json(res, 200, { ...orderView(prior), idempotent_replay: true }); }
      const cart = q.cart.get(String(body.cart_token || ''));
      if (!cart || cart.customer_id !== cust.id) throw new H.ApiError(404, 'not_found', 'no such cart');
      if (cart.status !== 'open') throw new H.ApiError(409, 'cart_closed', 'cart is not open');
      const items = q.cartItems.all(cart.id);
      if (items.length === 0) throw new H.ApiError(400, 'empty_cart', 'the cart is empty');
      const subtotal = items.reduce((s, it) => s + it.qty * it.price_cents, 0);
      const id = tx(() => {
        for (const it of items) { const fresh = q.menuItem.get(it.menu_item_id); if (fresh.stock < it.qty) throw new H.ApiError(409, 'insufficient_stock', 'not enough stock at checkout', { menu_item_id: it.menu_item_id }); }
        const info = q.insOrder.run(cust.id, cart.restaurant_id, subtotal, DELIVERY_FEE, subtotal + DELIVERY_FEE, key, now());
        const oid = Number(info.lastInsertRowid);
        for (const it of items) { q.insOrderItem.run(oid, it.menu_item_id, it.qty, it.price_cents); q.decStock.run(it.qty, it.menu_item_id); }
        q.insEvent.run(oid, null, 'placed', 'customer', now());
        q.setCartStatus.run('ordered', cart.id);
        return oid;
      });
      return json(res, 201, orderView(q.order.get(id)));
    }
    if (req.method === 'GET' && a === 'orders' && b && !c) { const o = q.order.get(Number(b)); if (!o) throw new H.ApiError(404, 'not_found', 'no such order'); return json(res, 200, { ...orderView(o), events: q.events.all(o.id).map((e) => ({ from: e.from_status, to: e.to_status, actor: e.actor })) }); }

    // ---- order lifecycle actions ----
    if (req.method === 'POST' && a === 'orders' && b && c && ['accept', 'reject', 'prepare', 'ready', 'cancel', 'pickup', 'deliver', 'assign'].includes(c)) {
      const order = q.order.get(Number(b));
      if (!order) throw new H.ApiError(404, 'not_found', 'no such order');
      if (c === 'cancel') { const cust = requireCustomer(req); if (order.customer_id !== cust.id) throw new H.ApiError(403, 'forbidden', 'not your order'); tx(() => transition(order, 'cancel')); return json(res, 200, orderView(q.order.get(order.id))); }
      if (['accept', 'reject', 'prepare', 'ready'].includes(c)) { requireRestaurantOwner(req, order.restaurant_id); tx(() => transition(order, c)); return json(res, 200, orderView(q.order.get(order.id))); }  // merchant
      if (c === 'assign') { const drv = requireDriver(req); if (order.status !== 'ready') throw new H.ApiError(409, 'bad_state', 'order is not ready', { status: order.status }); if (order.driver_id) throw new H.ApiError(409, 'already_assigned', 'order already has a driver'); tx(() => { q.setOrderDriver.run(drv.id, order.id); q.setDriverStatus.run('busy', drv.id); q.insEvent.run(order.id, 'ready', 'assigned', 'driver', now()); }); return json(res, 200, orderView(q.order.get(order.id))); }
      if (c === 'pickup' || c === 'deliver') { const drv = requireDriver(req); if (order.driver_id !== drv.id) throw new H.ApiError(403, 'forbidden', 'not the assigned driver'); tx(() => transition(order, c)); return json(res, 200, orderView(q.order.get(order.id))); }
    }

    // ---- merchant ----
    if (req.method === 'POST' && a === 'merchants' && !b) { const body = await readBody(req); const tok = H.token('mch'); const info = q.insMerchant.run(String(body.name || 'Merchant'), tok, now()); return json(res, 201, { id: Number(info.lastInsertRowid), token: tok }); }

    // ---- driver ----
    if (req.method === 'POST' && a === 'drivers' && !b) { const body = await readBody(req); const tok = H.token('drv'); const info = q.insDriver.run(String(body.name || 'Driver'), tok, now()); return json(res, 201, { id: Number(info.lastInsertRowid), token: tok }); }
    if (req.method === 'GET' && a === 'offers') { requireDriver(req); return json(res, 200, { offers: q.offers.all().map(orderView) }); }

    // ---- admin ----
    if (req.method === 'GET' && a === 'admin' && b === 'overview') {
      requireAdmin(req);
      const counts = {}; for (const r of q.statusCounts.all()) counts[r.status] = r.n;
      return json(res, 200, { orders_by_status: counts, revenue_cents: q.deliveredTotals.get().revenue, commission_cents: q.ledgerBy.get('commission').s, payout_cents: q.ledgerBy.get('payout').s, delivery_fee_cents: q.ledgerBy.get('delivery_fee').s });
    }
    if (req.method === 'GET' && a === 'admin' && b === 'orders') { requireAdmin(req); const status = url.searchParams.get('status'); let rows = q.allOrders.all(); if (status) rows = rows.filter((o) => o.status === status); return json(res, 200, { orders: rows.map(orderView) }); }
    if (req.method === 'PATCH' && a === 'admin' && b === 'restaurants' && c) { requireAdmin(req); const body = await readBody(req); const r = q.restaurant.get(Number(c)); if (!r) throw new H.ApiError(404, 'not_found', 'no such restaurant'); q.setRestaurantActive.run(body.active ? 1 : 0, r.id); return json(res, 200, { id: r.id, active: !!body.active }); }

    if (['GET', 'POST', 'PATCH', 'DELETE'].includes(req.method)) throw new H.ApiError(404, 'not_found', 'no such route');
    throw new H.ApiError(405, 'method_not_allowed', 'method not allowed');
  }

  function cartView(tok) {
    const cart = q.cart.get(tok);
    if (!cart) throw new H.ApiError(404, 'not_found', 'no such cart');
    const items = q.cartItems.all(cart.id);
    const subtotal = items.reduce((s, it) => s + it.qty * it.price_cents, 0);
    return { token: cart.token, restaurant_id: cart.restaurant_id, status: cart.status, items: items.map((it) => ({ menu_item_id: it.menu_item_id, name: it.name, qty: it.qty, price_cents: it.price_cents, line_cents: it.qty * it.price_cents })), subtotal_cents: subtotal };
  }

  // ---- HTML renderers (labelled for Playwright) ----
  function renderHome(res) {
    const rows = q.restaurants.all().map((r) => `<li class="restaurant" data-id="${r.id}"><a href="/restaurant/${r.id}">${esc(r.name)}</a> <span class="cuisine">${esc(r.cuisine)}</span></li>`).join('');
    return html(res, 200, `<title>mini-eats</title><h1>mini-eats</h1><nav class="apps"><a href="/admin">Admin</a></nav><ul class="restaurants">${rows}</ul>`);
  }
  function renderMenu(res, id) {
    const r = q.restaurant.get(Number(id)); if (!r) return html(res, 404, '<title>not found</title><p>no such restaurant</p>');
    const rows = q.menu.all(r.id).map((m) => `<li class="item" data-id="${m.id}"><span class="name">${esc(m.name)}</span> <span class="price">${money(m.price_cents)}</span> <span class="status">${m.available && m.stock > 0 ? 'available' : 'unavailable'}</span></li>`).join('');
    return html(res, 200, `<title>${esc(r.name)}</title><h1 class="restaurant-name">${esc(r.name)}</h1><ul class="menu">${rows}</ul>`);
  }
  function renderOrder(res, id) {
    const o = q.order.get(Number(id)); if (!o) return html(res, 404, '<title>order</title><p>no such order</p>');
    return html(res, 200, `<title>order ${o.id}</title><h1 class="order-id">Order ${o.id}</h1><p class="status">${esc(o.status)}</p><p class="total">${money(o.total_cents)}</p>`);
  }
  function renderMerchant(res, rid) {
    const r = q.restaurant.get(Number(rid)); if (!r) return html(res, 404, '<title>merchant</title><p>no such restaurant</p>');
    const rows = q.ordersByRestaurant.all(r.id).map((o) => `<li class="order" data-id="${o.id}"><span class="status">${esc(o.status)}</span> <span class="total">${money(o.total_cents)}</span></li>`).join('');
    return html(res, 200, `<title>merchant ${esc(r.name)}</title><h1 class="restaurant-name">${esc(r.name)}</h1><ul class="orders">${rows}</ul>`);
  }
  function renderDriver(res, did) {
    const rows = q.offers.all().map((o) => `<li class="offer" data-id="${o.id}"><span class="total">${money(o.total_cents)}</span> <span class="fee">${money(o.delivery_fee_cents)}</span></li>`).join('');
    return html(res, 200, `<title>driver ${esc(did)}</title><h1 class="driver">Driver ${esc(did)}</h1><ul class="offers">${rows}</ul>`);
  }
  function renderAdmin(res) {
    const counts = {}; for (const r of q.statusCounts.all()) counts[r.status] = r.n;
    const rows = Object.entries(counts).map(([s, n]) => `<li class="count" data-status="${esc(s)}"><span class="s">${esc(s)}</span> <span class="n">${n}</span></li>`).join('');
    return html(res, 200, `<title>mini-eats admin</title><h1>Admin</h1><p class="revenue">${money(q.deliveredTotals.get().revenue)}</p><ul class="counts">${rows}</ul>`);
  }

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    try { await route(req, res, url); }
    catch (err) { if (err instanceof H.ApiError) json(res, err.status, H.errorBody(err)); else { console.error(err); json(res, 500, { error: 'internal error', code: 'internal' }); } }
  });
  server.listen(cfg.port, '127.0.0.1', () => console.error(`mini-eats on http://127.0.0.1:${cfg.port}  db ${cfg.dbFile}`));
  const shutdown = () => { server.close(); db.close(); process.exit(0); };
  process.on('SIGINT', shutdown); process.on('SIGTERM', shutdown);
}

if (require.main === module) main();
module.exports = { cfg };
