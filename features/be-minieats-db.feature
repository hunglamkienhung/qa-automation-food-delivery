@module:01-minieats-db @be @db @minieats
Feature: The mini-eats store, read directly

  Both stacks open the SQLite file the mini-eats service writes and assert on
  its rows. The service is driven through its HTTP API to create state -- an
  order placed, accepted, delivered -- and the rows, events and ledger are then
  read straight from the file.

  The lifecycle is a state machine (placed -> accepted -> preparing -> ready ->
  picked_up -> delivered, or cancelled/rejected), audited row by row in
  order_events; on delivery the money owed out is posted to a ledger that must
  sum to the order total. Stock is shared global state, so those assertions are
  on DELTAS: note the stock before, act, and check what changed -- which keeps
  every scenario independent of the order they run in.

  Background:
    Given the store is open and the service is reachable

  # ---------------------------------------------------------------- schema (throwaway db)

  @case:1 @priority:high
  Scenario: The store has the documented tables
    Then the store has tables restaurants, menu_items, customers, drivers, carts, cart_items, orders, order_items, order_events, ledger

  @case:2 @priority:high
  Scenario: A menu item name is unique within its restaurant
    Given a throwaway database with the schema applied
    Then inserting two menu items with the same name on one restaurant fails on the second

  @case:3 @priority:high
  Scenario: Order lines reference a real order and a real menu item
    Given a throwaway database with the schema applied
    Then inserting an order_items row for a missing order fails a FOREIGN KEY
    And inserting an order_items row for a missing menu item fails a FOREIGN KEY

  @case:4 @priority:high
  Scenario: Amounts and quantities are bounded by CHECK
    Given a throwaway database with the schema applied
    Then inserting a menu item with negative price fails a CHECK
    And inserting a menu item with negative stock fails a CHECK
    And inserting a cart item with zero quantity fails a CHECK

  @case:5 @priority:high
  Scenario: An order status is one of the lifecycle states
    Given a throwaway database with the schema applied
    Then inserting an order with status "in_transit" fails a CHECK

  @case:6 @priority:high
  Scenario: An order event names a known actor
    Given a throwaway database with the schema applied
    Then inserting an order event with actor "robot" fails a CHECK

  @case:7 @priority:medium
  Scenario: A ledger entry is a real, non-zero amount with a known reason and party
    Given a throwaway database with the schema applied
    Then inserting a ledger row with zero delta fails a CHECK
    And inserting a ledger row with reason "tip" fails a CHECK
    And inserting a ledger row with party type "government" fails a CHECK

  @case:8 @priority:medium
  Scenario: A driver status is one of the known states
    Given a throwaway database with the schema applied
    Then inserting a driver with status "sleeping" fails a CHECK

  @case:9 @priority:medium
  Scenario: The commission rate is a fraction between nothing and everything
    Given a throwaway database with the schema applied
    Then inserting a restaurant with commission over 100 percent fails a CHECK

  @case:10 @priority:medium
  Scenario: Seeding twice leaves the same rows
    Given a throwaway database with the schema and seed applied
    Then applying the seed again changes no row counts

  # ---------------------------------------------------------------- checkout writes the right rows

  @case:11 @priority:high
  Scenario: A checkout creates an order whose total is its subtotal plus the delivery fee
    Given a customer with a cart at restaurant 2
    And the cart holds 2 of item 5 and 1 of item 7
    When the customer checks out
    Then the order total equals its subtotal plus the delivery fee

  @case:12 @priority:high
  Scenario: Order lines capture the price at order time
    Given a customer with a cart at restaurant 1
    And the cart holds 1 of item 2
    When the customer checks out
    Then each order line price equals the menu item's price at order time

  @case:13 @priority:high
  Scenario: Checkout decrements stock by the ordered quantity
    Given a customer with a cart at restaurant 1
    And the stock of item 1 is noted
    And the cart holds 3 of item 1
    When the customer checks out
    Then the stock of item 1 fell by 3

  @case:14 @priority:high
  Scenario: An oversell is refused and leaves the store untouched
    Given a customer with a cart at restaurant 2
    And the stock of item 6 is noted
    And the order count is noted
    When the customer tries to order 999 of item 6
    Then the checkout is refused with code "insufficient_stock"
    And the stock of item 6 is unchanged
    And no new order was created

  @case:15 @priority:medium
  Scenario: An empty cart cannot be checked out
    Given a customer with a cart at restaurant 1
    And the order count is noted
    When the customer checks out
    Then the checkout is refused with code "empty_cart"
    And no new order was created

  @case:16 @priority:medium
  Scenario: A checked-out cart is marked ordered
    Given a customer with a cart at restaurant 3
    And the cart holds 1 of item 8
    When the customer checks out
    Then the cart row status is "ordered"

  @case:17 @priority:medium
  Scenario: The order belongs to the customer who placed it
    Given a customer with a cart at restaurant 1
    And the cart holds 1 of item 1
    When the customer checks out
    Then the order's customer is the buyer

  @case:18 @priority:medium
  Scenario: One order line per distinct cart line
    Given a customer with a cart at restaurant 3
    And the cart holds 1 of item 8 and 2 of item 9 and 1 of item 10
    When the customer checks out
    Then the order has 3 order lines

  # ---------------------------------------------------------------- the state machine, audited

  @case:19 @priority:high
  Scenario: Placing an order writes the opening event
    Given a customer with a cart at restaurant 1
    And the cart holds 1 of item 1
    When the customer checks out
    Then the order's first event is placed by the customer

  @case:20 @priority:high
  Scenario: Accepting an order records the transition and moves the status
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant accepts the order
    Then the order status row is "accepted"
    And an event records placed to accepted by the merchant

  @case:21 @priority:high
  Scenario: Rejecting a placed order restocks it and records the transition
    Given the stock of item 1 is noted
    And a placed order of 2 of item 1 at restaurant 1
    When the merchant rejects the order
    Then the order status row is "rejected"
    And the stock of item 1 is unchanged from the note
    And an event records placed to rejected by the merchant

  @case:22 @priority:high
  Scenario: Cancelling a placed order restocks it and records the transition
    Given the stock of item 2 is noted
    And a placed order of 1 of item 2 at restaurant 1
    When the customer cancels the order
    Then the order status row is "cancelled"
    And the stock of item 2 is unchanged from the note
    And an event records placed to cancelled by the customer

  @case:23 @priority:high
  Scenario: A full lifecycle writes an event for every transition
    Given a delivered order of 1 of item 1 at restaurant 1
    Then the order's events run placed, accepted, preparing, ready, assigned, picked_up, delivered
    And each event names the actor responsible for that transition

  # ---------------------------------------------------------------- the delivery ledger

  @case:24 @priority:high
  Scenario: On delivery the restaurant is paid its subtotal less commission
    Given a delivered order of 2 of item 5 at restaurant 2
    Then the restaurant's payout equals the subtotal minus commission

  @case:25 @priority:high
  Scenario: On delivery the driver is paid the delivery fee and the platform takes the commission
    Given a delivered order of 1 of item 8 at restaurant 3
    Then the driver's ledger credit equals the delivery fee
    And the platform's ledger credit equals the commission

  @case:26 @priority:high
  Scenario: The delivery ledger sums to the order total
    Given a delivered order of 2 of item 6 at restaurant 2
    Then the order's ledger credits sum to the order total

  @case:27 @priority:medium
  Scenario: An undelivered order has posted nothing to the ledger
    Given a placed order of 1 of item 1 at restaurant 1
    Then the order has no ledger rows

  # ---------------------------------------------------------------- idempotency and integrity

  @case:28 @priority:high
  Scenario: A repeated checkout with the same idempotency key makes one order
    Given a customer with a cart at restaurant 1
    And the cart holds 1 of item 1
    And the order count is noted
    When the customer checks out with idempotency key "eats-abc-1"
    And the customer checks out again with idempotency key "eats-abc-1"
    Then exactly one new order was created
    And both checkouts returned the same order id

  @case:29 @priority:medium
  Scenario: No order line references a missing menu item
    Given a customer with a cart at restaurant 1
    And the cart holds 1 of item 1
    When the customer checks out
    Then no order_items row references a menu item missing from menu_items

  @case:30 @priority:medium
  Scenario: No order references a missing customer or restaurant
    Then no orders row references a customer missing from customers
    And no orders row references a restaurant missing from restaurants

  # ---------------------------------------------------------------- parameterised over menu items

  Scenario Outline: Checkout of <label> decrements its stock and captures its price
    Given a customer with a cart at restaurant <rid>
    And the stock of item <iid> is noted
    And the cart holds 2 of item <iid>
    When the customer checks out
    Then the stock of item <iid> fell by 2
    And each order line price equals the menu item's price at order time

    @case:31
    Examples:
      | label | rid | iid |
      | nigiri | 1 | 1 |
    @case:32
    Examples:
      | label | rid | iid |
      | pepperoni | 2 | 6 |
    @case:33
    Examples:
      | label | rid | iid |
      | burrito | 3 | 9 |
