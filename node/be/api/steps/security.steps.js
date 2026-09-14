'use strict';

const { Given, When, Then } = require('@cucumber/cucumber');
const { MiniEats, ApiUnreachable } = require('../venues/minieats');
const { DbUnreachable } = require('../../db/store');

/**
 * Steps for features/be-minieats-security.feature. These probe the API's
 * authorization boundaries -- no token, the wrong actor, a forged token, a
 * resource that is not yours. The Background, the store, and the order-setup
 * Givens (a placed order, a registered customer) are shared from the other
 * @minieats steps; only the adversarial requests and a couple of assertions
 * are new here. `this.api` / `this.last` is always the last response.
 */

const eats = new MiniEats();
const UNREACHABLE = [ApiUnreachable, DbUnreachable];
const FORGED = 'cust_forged000000000000000000';

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

// ---------------------------------------------------------------- merchant gate

When('the order is accepted with no token', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/accept`); });
When('the order is accepted with a forged token', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/accept`, { token: FORGED }); });
When('a merchant who owns no restaurant accepts the order', { timeout: 30_000 }, async function () { const other = await eats.newMerchant(); await send(this, 'POST', `/orders/${this.orderId}/accept`, { token: other.token }); });
When('the customer tries to accept the order', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/accept`, { token: this.buyer.token }); });
When('a driver tries to accept the order', { timeout: 30_000 }, async function () { await send(this, 'POST', `/orders/${this.orderId}/accept`, { token: eats.seedDriver }); });

// ---------------------------------------------------------------- board

When('the admin reads restaurant {int}\'s board', { timeout: 30_000 }, async function (rid) { await send(this, 'GET', `/restaurants/${rid}/orders`, { token: eats.adminToken }); });

// ---------------------------------------------------------------- cross-role / forged / tampered

When('the admin overview is read with the customer\'s token', { timeout: 30_000 }, async function () { await send(this, 'GET', '/admin/overview', { token: this.buyer.token }); });
When('the offers are read with the customer\'s token', { timeout: 30_000 }, async function () { await send(this, 'GET', '/offers', { token: this.buyer.token }); });
When('the admin overview is read with a token that extends the admin token', { timeout: 30_000 }, async function () { await send(this, 'GET', '/admin/overview', { token: eats.adminToken + 'x' }); });
When('a cart is opened with a forged token', { timeout: 30_000 }, async function () { await send(this, 'POST', '/carts', { token: FORGED, body: { restaurant_id: 1 } }); });

// ---------------------------------------------------------------- onboarding / secret hygiene

When('a merchant registers', { timeout: 30_000 }, async function () { await send(this, 'POST', '/merchants', { body: { name: 'Sec Merchant' } }); });
Then('the response carries a token', async function () { await check(this, 'response carries a token', () => { const t = (this.api.body || {}).token; return { passed: typeof t === 'string' && t.length > 0, detail: 'token ' + (t ? 'present' : 'absent') }; }); });
Then('the order response body contains no bearer token', async function () {
  await check(this, 'no bearer token leaked', () => {
    const text = JSON.stringify((this.last && this.last.body) || {});
    const leaks = ['cust_', 'drv_', 'mch_', 'cart_', eats.adminToken].filter((p) => text.includes(p));
    return { passed: leaks.length === 0, detail: leaks.length ? 'leaked ' + leaks.join(',') : 'clean' };
  });
});
