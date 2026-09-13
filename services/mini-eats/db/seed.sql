-- Deterministic seed. Idempotent: INSERT OR IGNORE by primary key. Prices in
-- cents. One item is out of stock and one is unavailable on purpose (negative
-- cases); one restaurant is inactive on purpose. Customers are created through
-- the API, so those rows never collide between runs; two drivers are seeded so
-- the driver flow has someone to take an order.

INSERT OR IGNORE INTO restaurants (id, name, cuisine, commission_bps, active) VALUES
  (1, 'Sakura Sushi',  'Japanese', 2000, 1),
  (2, 'Bella Pizza',   'Italian',  1500, 1),
  (3, 'Taco Fiesta',   'Mexican',  2500, 1),
  (4, 'Closed Diner',  'American', 2000, 0);   -- inactive on purpose

-- Stock is generous so a whole run (many scenarios each place fresh orders that
-- decrement it) never exhausts a hot item -- the suite stays robust as it grows
-- and when tiers run back-to-back without a reseed. Two items are deliberate
-- negative cases and keep their special values: id 3 is out of stock (0), id 4
-- is unavailable (available 0).
INSERT OR IGNORE INTO menu_items (id, restaurant_id, name, category, price_cents, stock, available) VALUES
  (1, 1, 'Salmon Nigiri',   'Sushi',   650, 500, 1),
  (2, 1, 'Tuna Roll',       'Sushi',   850, 500, 1),
  (3, 1, 'Miso Soup',       'Soup',    300,   0, 1),   -- out of stock
  (4, 1, 'Seasonal Special','Special', 1200,  5, 0),   -- unavailable
  (5, 2, 'Margherita',      'Pizza',   1100, 500, 1),
  (6, 2, 'Pepperoni',       'Pizza',   1300, 500, 1),
  (7, 2, 'Garlic Bread',    'Side',    500, 500, 1),
  (8, 3, 'Beef Taco',       'Taco',    350, 500, 1),
  (9, 3, 'Chicken Burrito', 'Burrito', 900, 500, 1),
  (10, 3, 'Guacamole',      'Side',    450, 500, 1),
  (11, 4, 'Cheeseburger',   'Burger',  800,  10, 1);   -- on an inactive restaurant

INSERT OR IGNORE INTO drivers (id, name, token, status, created_at) VALUES
  (1, 'Alex Rider', 'drv_seed_alex', 'available', 1700000000),
  (2, 'Sam Wheels', 'drv_seed_sam',  'available', 1700000000);
