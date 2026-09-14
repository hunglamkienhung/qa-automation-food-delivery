@module:02-minieats-api @be @api @minieats
Feature: The mini-eats REST layer -- the customer, merchant, driver and admin apps

  Every scenario compares an HTTP response with the rows behind it, so a
  divergence names the API. One service backs four apps: the customer browses
  and orders, the merchant advances the order, the driver delivers it, and the
  admin watches the money. The order lifecycle is a state machine whose
  transitions are gated by who you are and what state the order is in -- a
  driver cannot accept, a merchant cannot deliver, and nothing can skip a step.

  Background:
    Given the store is open and the service is reachable

  # ---------------------------------------------------------------- customer: catalogue

  @case:34 @priority:high
  Scenario: /restaurants lists the active restaurants only
    When GET /restaurants
    Then the response status is 200
    And every restaurant in the response is active
    And no inactive restaurant appears

  @case:35 @priority:high
  Scenario: /restaurants/:id/menu matches the rows, priced from them
    When GET /restaurants/1/menu
    Then the response status is 200
    And every menu item in the response matches its row

  @case:36 @priority:medium
  Scenario: The menu marks an out-of-stock item and an unavailable item as unavailable
    When GET /restaurants/1/menu
    Then menu item 3 is reported unavailable
    And menu item 4 is reported unavailable

  @case:37 @priority:medium
  Scenario: /restaurants/:id hides an inactive restaurant and 404s the unknown
    When GET /restaurants/1
    Then the response status is 200
    When GET /restaurants/4
    Then the response status is 404
    When GET /restaurants/999
    Then the response status is 404

  # ---------------------------------------------------------------- customer: cart

  @case:38 @priority:high
  Scenario: Opening a cart requires a customer token
    When a cart is opened at restaurant 1 with no token
    Then the response status is 401
    And the response is an error with code "unauthenticated"

  @case:39 @priority:high
  Scenario: A cart cannot be opened at a closed restaurant
    Given a registered customer
    When the customer opens a cart at restaurant 4
    Then the response status is 409
    And the response is an error with code "restaurant_closed"

  @case:40 @priority:high
  Scenario: Adding an item reflects the row and the line total
    Given a customer with a cart at restaurant 2
    When 2 of item 5 are added to the cart
    Then the cart holds 2 of item 5 priced from the row
    And the cart subtotal equals the sum of its line totals

  @case:41 @priority:medium
  Scenario: Adding the same item twice merges into one line
    Given a customer with a cart at restaurant 1
    When 1 of item 1 are added to the cart
    And 2 of item 1 are added to the cart
    Then the cart has 1 lines
    And the cart holds 3 of item 1 priced from the row

  @case:42 @priority:high
  Scenario: A quantity beyond stock is refused
    Given a customer with a cart at restaurant 2
    When 999 of item 6 are added to the cart
    Then the response status is 409
    And the response is an error with code "insufficient_stock"

  @case:43 @priority:medium
  Scenario: An item from another restaurant cannot be added
    Given a customer with a cart at restaurant 1
    When 1 of item 5 are added to the cart
    Then the response status is 404

  @case:44 @priority:medium
  Scenario: An out-of-stock item cannot be added
    Given a customer with a cart at restaurant 1
    When 1 of item 3 are added to the cart
    Then the response status is 409
    And the response is an error with code "insufficient_stock"

  @case:45 @priority:medium
  Scenario: An unavailable item cannot be added
    Given a customer with a cart at restaurant 1
    When 1 of item 4 are added to the cart
    Then the response status is 409
    And the response is an error with code "unavailable"

  @case:46 @priority:low
  Scenario: A non-positive quantity is rejected
    Given a customer with a cart at restaurant 1
    When 0 of item 1 are added to the cart
    Then the response status is 400

  @case:47 @priority:low
  Scenario: An unknown cart is 404
    When GET /carts/nope
    Then the response status is 404

  # ---------------------------------------------------------------- customer: checkout and track

  @case:48 @priority:high
  Scenario: Checkout requires a customer token
    Given a customer with a cart at restaurant 1
    And 1 of item 1 are added to the cart
    When checkout is posted with no token
    Then the response status is 401
    And the response is an error with code "unauthenticated"

  @case:49 @priority:high
  Scenario: A checkout returns an order equal to the stored order
    Given a customer with a cart at restaurant 1
    And 1 of item 1 are added to the cart
    And 1 of item 2 are added to the cart
    When the customer checks out
    Then the response status is 201
    And the order in the response equals the stored order

  @case:50 @priority:high
  Scenario: The order total in the response is its subtotal plus the delivery fee
    Given a customer with a cart at restaurant 2
    And 2 of item 5 are added to the cart
    When the customer checks out
    Then the order total in the response equals its subtotal plus the delivery fee

  @case:51 @priority:medium
  Scenario: An empty cart cannot be checked out
    Given a customer with a cart at restaurant 1
    When the customer checks out
    Then the response status is 400
    And the response is an error with code "empty_cart"

  @case:52 @priority:high
  Scenario: A tracked order carries its lifecycle events
    Given a placed order of 1 of item 1 at restaurant 1
    When the order is fetched
    Then the response status is 200
    And the tracked order reports status "placed"
    And the tracked order has an event to "placed"

  @case:53 @priority:medium
  Scenario: A retried checkout with the same idempotency key returns the same order
    Given a customer with a cart at restaurant 1
    And 1 of item 1 are added to the cart
    When the customer checks out with idempotency key "eats-api-1"
    And the customer checks out again with idempotency key "eats-api-1"
    Then both checkouts returned the same order id
    And the second checkout is flagged an idempotent replay

  @case:54 @priority:low
  Scenario: An unknown order is 404
    When GET /orders/999999
    Then the response status is 404

  # ---------------------------------------------------------------- the state machine: merchant

  @case:55 @priority:high
  Scenario: A merchant advances a placed order through to ready
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant accepts the order
    Then the response status is 200
    And the order in the response reports status "accepted"
    When the merchant prepares the order
    Then the order in the response reports status "preparing"
    When the merchant marks the order ready
    Then the order in the response reports status "ready"

  @case:56 @priority:high
  Scenario: A merchant cannot accept an order that is not placed
    Given a placed order of 1 of item 1 at restaurant 1
    And the merchant has accepted the order
    When the merchant accepts the order
    Then the response status is 409
    And the response is an error with code "bad_state"

  @case:57 @priority:high
  Scenario: A merchant cannot prepare an order that was never accepted
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant prepares the order
    Then the response status is 409
    And the response is an error with code "bad_state"

  @case:58 @priority:high
  Scenario: A merchant rejects a placed order
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant rejects the order
    Then the response status is 200
    And the order in the response reports status "rejected"

  # ---------------------------------------------------------------- the state machine: customer cancel

  @case:59 @priority:high
  Scenario: A customer can cancel a placed order but not one already accepted
    Given a placed order of 1 of item 1 at restaurant 1
    When the customer cancels the order
    Then the response status is 200
    And the order in the response reports status "cancelled"

  @case:60 @priority:high
  Scenario: A customer cannot cancel once the merchant has accepted
    Given a placed order of 1 of item 1 at restaurant 1
    And the merchant has accepted the order
    When the customer cancels the order
    Then the response status is 409
    And the response is an error with code "bad_state"

  @case:61 @priority:high
  Scenario: A customer cannot cancel another customer's order
    Given a placed order of 1 of item 1 at restaurant 1
    When another customer tries to cancel the order
    Then the response status is 403
    And the response is an error with code "forbidden"

  # ---------------------------------------------------------------- the state machine: driver

  @case:62 @priority:high
  Scenario: A ready order is offered to drivers; an unready one is not
    Given a placed order of 1 of item 1 at restaurant 1
    When the driver reads the offers
    Then the placed order is not among the offers
    Given the order has been made ready
    When the driver reads the offers
    Then the ready order is among the offers

  @case:63 @priority:high
  Scenario: Reading the offers requires a driver token
    When the offers are read with no token
    Then the response status is 401

  @case:64 @priority:high
  Scenario: A driver assigns, picks up and delivers a ready order
    Given a ready order of 1 of item 1 at restaurant 1
    When the driver assigns the order
    Then the response status is 200
    And the order in the response reports status "ready"
    And the order in the response is assigned to the driver
    When the driver picks up the order
    Then the order in the response reports status "picked_up"
    When the driver delivers the order
    Then the order in the response reports status "delivered"

  @case:65 @priority:high
  Scenario: An order cannot be assigned to a second driver
    Given a ready order of 1 of item 1 at restaurant 1
    And a driver has assigned the order
    When another driver assigns the order
    Then the response status is 409
    And the response is an error with code "already_assigned"

  @case:66 @priority:high
  Scenario: Only the assigned driver may pick up the order
    Given a ready order of 1 of item 1 at restaurant 1
    And a driver has assigned the order
    When another driver picks up the order
    Then the response status is 403
    And the response is an error with code "forbidden"

  @case:67 @priority:high
  Scenario: A ready order cannot be delivered before it is picked up
    Given a ready order of 1 of item 1 at restaurant 1
    And a driver has assigned the order
    When the assigned driver delivers the order
    Then the response status is 409
    And the response is an error with code "bad_state"

  @case:68 @priority:medium
  Scenario: An order cannot be assigned before it is ready
    Given a placed order of 1 of item 1 at restaurant 1
    When the driver assigns the order
    Then the response status is 409

  # ---------------------------------------------------------------- merchant: order board

  @case:69 @priority:medium
  Scenario: A merchant sees its own restaurant's orders
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant reads restaurant 1's board
    Then the response status is 200
    And the placed order appears on the restaurant's board

  @case:70 @priority:medium
  Scenario: A merchant can filter its board by status
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant reads restaurant 1's board with status "placed"
    Then every order on the board reports status "placed"

  # ---------------------------------------------------------------- admin

  @case:71 @priority:high
  Scenario: The admin overview requires the admin token
    When GET /admin/overview with no token
    Then the response status is 401

  @case:72 @priority:high
  Scenario: The admin overview counts a delivered order and its revenue
    Given a delivered order of 2 of item 5 at restaurant 2
    When the admin reads the overview
    Then the response status is 200
    And the overview counts at least one delivered order
    And the overview revenue is at least the order total

  @case:73 @priority:high
  Scenario: The admin overview's money balances -- revenue equals payouts plus commission plus fees
    Given a delivered order of 1 of item 8 at restaurant 3
    When the admin reads the overview
    Then the overview revenue equals payouts plus commission plus delivery fees

  @case:74 @priority:medium
  Scenario: The admin can list orders and filter them by status
    Given a delivered order of 1 of item 1 at restaurant 1
    When the admin lists orders with status "delivered"
    Then every listed order reports status "delivered"

  @case:75 @priority:high
  Scenario: The admin deactivates a restaurant and it disappears from the customer list
    Given the admin deactivates restaurant 3
    When GET /restaurants
    Then restaurant 3 is not in the response
    Given the admin reactivates restaurant 3
    When GET /restaurants
    Then restaurant 3 is in the response

  @case:76 @priority:low
  Scenario: Deactivating an unknown restaurant is 404
    When the admin deactivates restaurant 999
    Then the response status is 404

  # ---------------------------------------------------------------- shape

  @case:77 @priority:medium
  Scenario: A consistent error shape and a 404 for unknown routes
    When GET /nowhere
    Then the response status is 404
    And the response is an error with code "not_found"

  @case:78 @priority:low
  Scenario: The health endpoint reports the seeded restaurant count
    When GET /health
    Then the response status is 200
    And the response field "ok" is true

  # ---------------------------------------------------------------- parameterised: a full delivery per restaurant

  Scenario Outline: An order at restaurant <rid> can be driven to delivered
    Given a ready order of 1 of item <iid> at restaurant <rid>
    When the driver assigns the order
    And the driver picks up the order
    And the driver delivers the order
    Then the order in the response reports status "delivered"

    @case:79
    Examples:
      | rid | iid |
      | 1 | 1 |
    @case:80
    Examples:
      | rid | iid |
      | 2 | 5 |
    @case:81
    Examples:
      | rid | iid |
      | 3 | 8 |
