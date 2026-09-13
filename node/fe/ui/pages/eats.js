'use strict';

/**
 * Page objects for the mini-eats app surfaces. The server renders small,
 * labelled HTML pages -- one per app: the customer's home and restaurant menu,
 * the order tracker, the merchant board, the driver board, the admin overview.
 * Each page object reads by label so the assertions are about the food-delivery
 * platform, not the markup.
 *
 * The base URL is the running service; a page that never loads (service down)
 * surfaces as ScreenNotReady, which the steps turn into Blocked.
 */

const BASE = (process.env.MINI_EATS_URL || 'http://127.0.0.1:8130').replace(/\/+$/, '');

class ScreenNotReady extends Error {}

class EatsPage {
  constructor(page) { this.page = page; this.base = BASE; }

  async open(path) {
    try { await this.page.goto(this.base + path, { waitUntil: 'domcontentloaded', timeout: 15_000 }); }
    catch (err) { throw new ScreenNotReady('mini-eats page ' + path + ' did not load: ' + err.message); }
  }

  async restaurants() {
    await this.page.waitForSelector('ul.restaurants li.restaurant', { timeout: 15_000 }).catch(() => { throw new ScreenNotReady('home never rendered'); });
    return this.page.$$eval('ul.restaurants li.restaurant', (els) => els.map((el) => ({
      id: Number(el.getAttribute('data-id')),
      name: el.querySelector('a') ? el.querySelector('a').textContent.trim() : '',
      href: el.querySelector('a') ? el.querySelector('a').getAttribute('href') : '',
    })));
  }

  async menu() {
    await this.page.waitForSelector('ul.menu li.item', { timeout: 15_000 }).catch(() => { throw new ScreenNotReady('menu never rendered'); });
    return this.page.$$eval('ul.menu li.item', (els) => els.map((el) => ({
      id: Number(el.getAttribute('data-id')),
      name: el.querySelector('.name') ? el.querySelector('.name').textContent.trim() : '',
      priceText: el.querySelector('.price') ? el.querySelector('.price').textContent.trim() : '',
      statusText: el.querySelector('.status') ? el.querySelector('.status').textContent.trim() : '',
    })));
  }

  async order() {
    await this.page.waitForSelector('h1.order-id', { timeout: 15_000 }).catch(() => { throw new ScreenNotReady('order page never rendered'); });
    return { idText: await this.page.$eval('h1.order-id', (e) => e.textContent.trim()), statusText: await this.page.$eval('.status', (e) => e.textContent.trim()), totalText: await this.page.$eval('.total', (e) => e.textContent.trim()) };
  }

  async board() {
    await this.page.waitForSelector('ul.orders', { timeout: 15_000 }).catch(() => { throw new ScreenNotReady('merchant board never rendered'); });
    return this.page.$$eval('ul.orders li.order', (els) => els.map((el) => ({
      id: Number(el.getAttribute('data-id')),
      statusText: el.querySelector('.status') ? el.querySelector('.status').textContent.trim() : '',
      totalText: el.querySelector('.total') ? el.querySelector('.total').textContent.trim() : '',
    })));
  }

  async offers() {
    await this.page.waitForSelector('ul.offers', { timeout: 15_000 }).catch(() => { throw new ScreenNotReady('driver board never rendered'); });
    return this.page.$$eval('ul.offers li.offer', (els) => els.map((el) => ({
      id: Number(el.getAttribute('data-id')),
      totalText: el.querySelector('.total') ? el.querySelector('.total').textContent.trim() : '',
      feeText: el.querySelector('.fee') ? el.querySelector('.fee').textContent.trim() : '',
    })));
  }

  async admin() {
    await this.page.waitForSelector('ul.counts', { timeout: 15_000 }).catch(() => { throw new ScreenNotReady('admin page never rendered'); });
    const revenueText = await this.page.$eval('.revenue', (e) => e.textContent.trim());
    const counts = await this.page.$$eval('ul.counts li.count', (els) => els.map((el) => ({
      status: el.getAttribute('data-status'),
      n: el.querySelector('.n') ? el.querySelector('.n').textContent.trim() : '',
    })));
    return { revenueText, counts };
  }
}

module.exports = { EatsPage, ScreenNotReady, BASE };
