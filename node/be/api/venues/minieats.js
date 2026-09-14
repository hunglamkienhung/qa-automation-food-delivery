'use strict';

/**
 * HTTP client for the mini-eats service. Node's built-in fetch; no library.
 *
 * A response is returned whole -- status, lower-cased headers, parsed body --
 * so a step can assert on any of them. Only a transport failure is
 * ApiUnreachable (grades Blocked); a 4xx/5xx is an answer, often the one
 * under test.
 *
 * The convenience methods drive the four apps end to end -- a customer places
 * an order, a merchant advances it, a driver delivers it -- so a step can set
 * up whatever lifecycle state it needs to assert on.
 */

const BASE = (process.env.MINI_EATS_URL || 'http://127.0.0.1:8130').replace(/\/+$/, '');
const ADMIN_TOKEN = process.env.MINI_EATS_ADMIN_TOKEN || 'admin-token';
const SEED_DRIVER = 'drv_seed_alex';       // seeded, always present
const SEED_MERCHANT = 'mch_seed_owner';    // seeded; owns restaurants 1, 2, 3

class ApiUnreachable extends Error {}

class MiniEats {
  constructor(base = BASE) { this.base = base; this.adminToken = ADMIN_TOKEN; this.seedDriver = SEED_DRIVER; this.seedMerchant = SEED_MERCHANT; }

  async request(method, path, { token, body, headers = {} } = {}) {
    const h = { ...headers };
    if (token) h.authorization = 'Bearer ' + token;
    const init = { method, headers: h };
    if (body !== undefined) { h['content-type'] = 'application/json'; init.body = JSON.stringify(body); }
    let res;
    try { res = await fetch(this.base + path, init); } catch (err) {
      throw new ApiUnreachable('mini-eats at ' + this.base + ' did not answer ' + method + ' ' + path + ': ' + (err.cause && err.cause.message ? err.cause.message : err.message));
    }
    const text = await res.text();
    let parsed = null; try { parsed = text ? JSON.parse(text) : null; } catch { parsed = null; }
    return { status: res.status, headers: Object.fromEntries([...res.headers.entries()].map(([k, v]) => [k.toLowerCase(), v])), body: parsed, text };
  }
  get(p, o) { return this.request('GET', p, o); }
  post(p, body, o = {}) { return this.request('POST', p, { ...o, body }); }
  patch(p, body, o = {}) { return this.request('PATCH', p, { ...o, body }); }

  /** Register a fresh customer; returns { id, token }. */
  async newCustomer(name = 'Diner') {
    const r = await this.post('/customers', { name });
    if (r.status !== 201) throw new Error('create customer failed: HTTP ' + r.status + ' ' + r.text);
    return r.body;
  }
  /** Register a fresh driver; returns { id, token }. */
  async newDriver(name = 'Courier') {
    const r = await this.post('/drivers', { name });
    if (r.status !== 201) throw new Error('create driver failed: HTTP ' + r.status + ' ' + r.text);
    return r.body;
  }
  async openCart(token, restaurantId) {
    const r = await this.post('/carts', { restaurant_id: restaurantId }, { token });
    if (r.status !== 201) throw new Error('open cart failed: HTTP ' + r.status + ' ' + r.text);
    return r.body.token;
  }
  addItem(token, cartToken, itemId, qty) { return this.post(`/carts/${cartToken}/items`, { menu_item_id: itemId, qty }, { token }); }
  checkout(token, body) { return this.post('/orders', body, { token }); }
  /** Register a fresh merchant (owns no restaurant); returns { id, token }. */
  async newMerchant(name = 'Merchant') {
    const r = await this.post('/merchants', { name });
    if (r.status !== 201) throw new Error('create merchant failed: HTTP ' + r.status + ' ' + r.text);
    return r.body;
  }

  /** Place a delivered order end to end, returning the order id. Used to set up
   *  ledger/admin state. `lines` is [[qty, itemId], ...] on `restaurantId`. */
  async placeDelivered(restaurantId, lines) {
    const cust = await this.newCustomer();
    const cart = await this.openCart(cust.token, restaurantId);
    for (const [qty, itemId] of lines) { const a = await this.addItem(cust.token, cart, itemId, qty); if (a.status !== 200) throw new Error('add item: ' + a.text); }
    const o = await this.checkout(cust.token, { cart_token: cart });
    if (o.status !== 201) throw new Error('checkout: ' + o.text);
    const id = o.body.id;
    await this.post(`/orders/${id}/accept`, undefined, { token: this.seedMerchant });
    await this.post(`/orders/${id}/prepare`, undefined, { token: this.seedMerchant });
    await this.post(`/orders/${id}/ready`, undefined, { token: this.seedMerchant });
    await this.post(`/orders/${id}/assign`, undefined, { token: this.seedDriver });
    await this.post(`/orders/${id}/pickup`, undefined, { token: this.seedDriver });
    await this.post(`/orders/${id}/deliver`, undefined, { token: this.seedDriver });
    return id;
  }
}

module.exports = { MiniEats, ApiUnreachable, BASE, ADMIN_TOKEN };
