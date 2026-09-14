-- mini-eats: a small but real food-delivery backend over one SQLite file. The
-- tables are the object under test; every test stack opens this same file and
-- asserts on its rows, and the REST layer (serving the customer, merchant,
-- driver and admin apps) reads and writes it.
--
-- Money is stored in integer minor units (cents), never a float. The order
-- lifecycle -- placed -> accepted -> preparing -> ready -> picked_up ->
-- delivered, or cancelled/rejected -- is enforced by the service and audited in
-- order_events; the invariants a delivery platform must not break (a total that
-- equals its lines plus the delivery fee, one driver per order, stock that
-- never goes negative, a payout ledger that balances) are enforced here so a
-- bug surfaces as a constraint violation, not a quietly wrong number.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- A merchant owns one or more restaurants; its bearer token is the only thing
-- allowed to advance that restaurant's orders (accept -> ... -> ready) and to
-- read its order board. Without this, the "merchant app" is unauthenticated --
-- anyone could push any restaurant's orders, a privilege-escalation hole the
-- security tier closes.
CREATE TABLE IF NOT EXISTS merchants (
  id          INTEGER PRIMARY KEY,
  name        TEXT    NOT NULL,
  token       TEXT    UNIQUE,
  created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS restaurants (
  id             INTEGER PRIMARY KEY,
  name           TEXT    NOT NULL,
  cuisine        TEXT    NOT NULL,
  merchant_id    INTEGER REFERENCES merchants(id),   -- the owning merchant (NULL until claimed)
  commission_bps INTEGER NOT NULL DEFAULT 2000 CHECK (commission_bps >= 0 AND commission_bps <= 10000),
  active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))
);

CREATE TABLE IF NOT EXISTS menu_items (
  id            INTEGER PRIMARY KEY,
  restaurant_id INTEGER NOT NULL REFERENCES restaurants(id),
  name          TEXT    NOT NULL,
  category      TEXT    NOT NULL,
  price_cents   INTEGER NOT NULL CHECK (price_cents >= 0),
  stock         INTEGER NOT NULL DEFAULT 100 CHECK (stock >= 0),
  available     INTEGER NOT NULL DEFAULT 1 CHECK (available IN (0, 1)),
  UNIQUE (restaurant_id, name)
);
CREATE INDEX IF NOT EXISTS menu_restaurant ON menu_items(restaurant_id);

CREATE TABLE IF NOT EXISTS customers (
  id          INTEGER PRIMARY KEY,
  name        TEXT    NOT NULL,
  token       TEXT    UNIQUE,
  created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS drivers (
  id          INTEGER PRIMARY KEY,
  name        TEXT    NOT NULL,
  token       TEXT    UNIQUE,
  status      TEXT    NOT NULL DEFAULT 'available' CHECK (status IN ('offline', 'available', 'busy')),
  created_at  INTEGER NOT NULL
);

-- A cart is for one restaurant (you cannot mix restaurants in one order).
CREATE TABLE IF NOT EXISTS carts (
  id            INTEGER PRIMARY KEY,
  token         TEXT    NOT NULL UNIQUE,
  customer_id   INTEGER NOT NULL REFERENCES customers(id),
  restaurant_id INTEGER NOT NULL REFERENCES restaurants(id),
  status        TEXT    NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'ordered', 'abandoned')),
  created_at    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS cart_items (
  id           INTEGER PRIMARY KEY,
  cart_id      INTEGER NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id),
  qty          INTEGER NOT NULL CHECK (qty > 0),
  UNIQUE (cart_id, menu_item_id)
);

CREATE TABLE IF NOT EXISTS orders (
  id                 INTEGER PRIMARY KEY,
  customer_id        INTEGER NOT NULL REFERENCES customers(id),
  restaurant_id      INTEGER NOT NULL REFERENCES restaurants(id),
  driver_id          INTEGER REFERENCES drivers(id),         -- NULL until a driver takes it
  subtotal_cents     INTEGER NOT NULL CHECK (subtotal_cents >= 0),
  delivery_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee_cents >= 0),
  total_cents        INTEGER NOT NULL CHECK (total_cents >= 0),
  status             TEXT    NOT NULL DEFAULT 'placed'
                       CHECK (status IN ('placed', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'cancelled', 'rejected')),
  idempotency_key    TEXT    UNIQUE,
  created_at         INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS orders_restaurant ON orders(restaurant_id);
CREATE INDEX IF NOT EXISTS orders_status ON orders(status);

CREATE TABLE IF NOT EXISTS order_items (
  id           INTEGER PRIMARY KEY,
  order_id     INTEGER NOT NULL REFERENCES orders(id),
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id),
  qty          INTEGER NOT NULL CHECK (qty > 0),
  price_cents  INTEGER NOT NULL CHECK (price_cents >= 0),   -- captured at order time
  UNIQUE (order_id, menu_item_id)
);

-- The state-machine audit: one row per transition, who caused it.
CREATE TABLE IF NOT EXISTS order_events (
  id          INTEGER PRIMARY KEY,
  order_id    INTEGER NOT NULL REFERENCES orders(id),
  from_status TEXT,
  to_status   TEXT    NOT NULL,
  actor       TEXT    NOT NULL CHECK (actor IN ('customer', 'merchant', 'driver', 'system')),
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS order_events_order ON order_events(order_id);

-- Money owed out on delivery: the restaurant's payout (subtotal minus
-- commission), the driver's fee, and the platform's cut. The three sum to the
-- order total -- a ledger the DB tier checks.
CREATE TABLE IF NOT EXISTS ledger (
  id          INTEGER PRIMARY KEY,
  party_type  TEXT    NOT NULL CHECK (party_type IN ('restaurant', 'driver', 'platform')),
  party_id    INTEGER,
  delta_cents INTEGER NOT NULL CHECK (delta_cents <> 0),
  reason      TEXT    NOT NULL CHECK (reason IN ('payout', 'delivery_fee', 'commission')),
  order_id    INTEGER NOT NULL REFERENCES orders(id),
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS ledger_order ON ledger(order_id);
