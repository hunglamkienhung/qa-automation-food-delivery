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

  Scenario Outline: A cart of <qty> x item <item> at restaurant <rid> is priced from the row
    Given a customer with a cart at restaurant <rid>
    When <qty> of item <item> are added to the cart
    Then the cart holds <qty> of item <item> priced from the row
    And the cart subtotal equals the sum of its line totals

    @case:147
    Examples:
      | qty | item | rid |
      | 1 | 1 | 1 |
    @case:148
    Examples:
      | qty | item | rid |
      | 1 | 2 | 1 |
    @case:149
    Examples:
      | qty | item | rid |
      | 1 | 5 | 2 |
    @case:150
    Examples:
      | qty | item | rid |
      | 1 | 6 | 2 |
    @case:151
    Examples:
      | qty | item | rid |
      | 1 | 7 | 2 |
    @case:152
    Examples:
      | qty | item | rid |
      | 1 | 8 | 3 |
    @case:153
    Examples:
      | qty | item | rid |
      | 1 | 9 | 3 |
    @case:154
    Examples:
      | qty | item | rid |
      | 1 | 10 | 3 |
    @case:155
    Examples:
      | qty | item | rid |
      | 2 | 1 | 1 |
    @case:156
    Examples:
      | qty | item | rid |
      | 2 | 2 | 1 |
    @case:157
    Examples:
      | qty | item | rid |
      | 2 | 5 | 2 |
    @case:158
    Examples:
      | qty | item | rid |
      | 2 | 6 | 2 |
    @case:159
    Examples:
      | qty | item | rid |
      | 2 | 7 | 2 |
    @case:160
    Examples:
      | qty | item | rid |
      | 2 | 8 | 3 |
    @case:161
    Examples:
      | qty | item | rid |
      | 2 | 9 | 3 |
    @case:162
    Examples:
      | qty | item | rid |
      | 2 | 10 | 3 |
    @case:163
    Examples:
      | qty | item | rid |
      | 3 | 1 | 1 |
    @case:164
    Examples:
      | qty | item | rid |
      | 3 | 2 | 1 |
    @case:165
    Examples:
      | qty | item | rid |
      | 3 | 5 | 2 |
    @case:166
    Examples:
      | qty | item | rid |
      | 3 | 6 | 2 |
    @case:167
    Examples:
      | qty | item | rid |
      | 3 | 7 | 2 |
    @case:168
    Examples:
      | qty | item | rid |
      | 3 | 8 | 3 |
    @case:169
    Examples:
      | qty | item | rid |
      | 3 | 9 | 3 |
    @case:170
    Examples:
      | qty | item | rid |
      | 3 | 10 | 3 |
    @case:171
    Examples:
      | qty | item | rid |
      | 4 | 1 | 1 |
    @case:172
    Examples:
      | qty | item | rid |
      | 4 | 2 | 1 |
    @case:173
    Examples:
      | qty | item | rid |
      | 4 | 5 | 2 |
    @case:174
    Examples:
      | qty | item | rid |
      | 4 | 6 | 2 |
    @case:175
    Examples:
      | qty | item | rid |
      | 4 | 7 | 2 |
    @case:176
    Examples:
      | qty | item | rid |
      | 4 | 8 | 3 |
    @case:177
    Examples:
      | qty | item | rid |
      | 4 | 9 | 3 |
    @case:178
    Examples:
      | qty | item | rid |
      | 4 | 10 | 3 |
    @case:179
    Examples:
      | qty | item | rid |
      | 5 | 1 | 1 |
    @case:180
    Examples:
      | qty | item | rid |
      | 5 | 2 | 1 |
    @case:181
    Examples:
      | qty | item | rid |
      | 5 | 5 | 2 |
    @case:182
    Examples:
      | qty | item | rid |
      | 5 | 6 | 2 |
    @case:183
    Examples:
      | qty | item | rid |
      | 5 | 7 | 2 |
    @case:184
    Examples:
      | qty | item | rid |
      | 5 | 8 | 3 |
    @case:185
    Examples:
      | qty | item | rid |
      | 5 | 9 | 3 |
    @case:186
    Examples:
      | qty | item | rid |
      | 5 | 10 | 3 |
    @case:187
    Examples:
      | qty | item | rid |
      | 6 | 1 | 1 |
    @case:188
    Examples:
      | qty | item | rid |
      | 6 | 2 | 1 |
    @case:189
    Examples:
      | qty | item | rid |
      | 6 | 5 | 2 |
    @case:190
    Examples:
      | qty | item | rid |
      | 6 | 6 | 2 |
    @case:191
    Examples:
      | qty | item | rid |
      | 6 | 7 | 2 |
    @case:192
    Examples:
      | qty | item | rid |
      | 6 | 8 | 3 |
    @case:193
    Examples:
      | qty | item | rid |
      | 6 | 9 | 3 |
    @case:194
    Examples:
      | qty | item | rid |
      | 6 | 10 | 3 |
    @case:195
    Examples:
      | qty | item | rid |
      | 7 | 1 | 1 |
    @case:196
    Examples:
      | qty | item | rid |
      | 7 | 2 | 1 |
    @case:197
    Examples:
      | qty | item | rid |
      | 7 | 5 | 2 |
    @case:198
    Examples:
      | qty | item | rid |
      | 7 | 6 | 2 |
    @case:199
    Examples:
      | qty | item | rid |
      | 7 | 7 | 2 |
    @case:200
    Examples:
      | qty | item | rid |
      | 7 | 8 | 3 |
    @case:201
    Examples:
      | qty | item | rid |
      | 7 | 9 | 3 |
    @case:202
    Examples:
      | qty | item | rid |
      | 7 | 10 | 3 |
    @case:203
    Examples:
      | qty | item | rid |
      | 8 | 1 | 1 |
    @case:204
    Examples:
      | qty | item | rid |
      | 8 | 2 | 1 |
    @case:205
    Examples:
      | qty | item | rid |
      | 8 | 5 | 2 |
    @case:206
    Examples:
      | qty | item | rid |
      | 8 | 6 | 2 |
    @case:207
    Examples:
      | qty | item | rid |
      | 8 | 7 | 2 |
    @case:208
    Examples:
      | qty | item | rid |
      | 8 | 8 | 3 |
    @case:209
    Examples:
      | qty | item | rid |
      | 8 | 9 | 3 |
    @case:210
    Examples:
      | qty | item | rid |
      | 8 | 10 | 3 |
    @case:211
    Examples:
      | qty | item | rid |
      | 9 | 1 | 1 |
    @case:212
    Examples:
      | qty | item | rid |
      | 9 | 2 | 1 |
    @case:213
    Examples:
      | qty | item | rid |
      | 9 | 5 | 2 |
    @case:214
    Examples:
      | qty | item | rid |
      | 9 | 6 | 2 |
    @case:215
    Examples:
      | qty | item | rid |
      | 9 | 7 | 2 |
    @case:216
    Examples:
      | qty | item | rid |
      | 9 | 8 | 3 |
    @case:217
    Examples:
      | qty | item | rid |
      | 9 | 9 | 3 |
    @case:218
    Examples:
      | qty | item | rid |
      | 9 | 10 | 3 |
    @case:219
    Examples:
      | qty | item | rid |
      | 10 | 1 | 1 |
    @case:220
    Examples:
      | qty | item | rid |
      | 10 | 2 | 1 |
    @case:221
    Examples:
      | qty | item | rid |
      | 10 | 5 | 2 |
    @case:222
    Examples:
      | qty | item | rid |
      | 10 | 6 | 2 |
    @case:223
    Examples:
      | qty | item | rid |
      | 10 | 7 | 2 |
    @case:224
    Examples:
      | qty | item | rid |
      | 10 | 8 | 3 |
    @case:225
    Examples:
      | qty | item | rid |
      | 10 | 9 | 3 |
    @case:226
    Examples:
      | qty | item | rid |
      | 10 | 10 | 3 |
    @case:227
    Examples:
      | qty | item | rid |
      | 11 | 1 | 1 |
    @case:228
    Examples:
      | qty | item | rid |
      | 11 | 2 | 1 |
    @case:229
    Examples:
      | qty | item | rid |
      | 11 | 5 | 2 |
    @case:230
    Examples:
      | qty | item | rid |
      | 11 | 6 | 2 |
    @case:231
    Examples:
      | qty | item | rid |
      | 11 | 7 | 2 |
    @case:232
    Examples:
      | qty | item | rid |
      | 11 | 8 | 3 |
    @case:233
    Examples:
      | qty | item | rid |
      | 11 | 9 | 3 |
    @case:234
    Examples:
      | qty | item | rid |
      | 11 | 10 | 3 |
    @case:235
    Examples:
      | qty | item | rid |
      | 12 | 1 | 1 |
    @case:236
    Examples:
      | qty | item | rid |
      | 12 | 2 | 1 |
    @case:237
    Examples:
      | qty | item | rid |
      | 12 | 5 | 2 |
    @case:238
    Examples:
      | qty | item | rid |
      | 12 | 6 | 2 |
    @case:239
    Examples:
      | qty | item | rid |
      | 12 | 7 | 2 |
    @case:240
    Examples:
      | qty | item | rid |
      | 12 | 8 | 3 |
    @case:241
    Examples:
      | qty | item | rid |
      | 12 | 9 | 3 |
    @case:242
    Examples:
      | qty | item | rid |
      | 12 | 10 | 3 |
    @case:243
    Examples:
      | qty | item | rid |
      | 13 | 1 | 1 |
    @case:244
    Examples:
      | qty | item | rid |
      | 13 | 2 | 1 |
    @case:245
    Examples:
      | qty | item | rid |
      | 13 | 5 | 2 |
    @case:246
    Examples:
      | qty | item | rid |
      | 13 | 6 | 2 |
    @case:247
    Examples:
      | qty | item | rid |
      | 13 | 7 | 2 |
    @case:248
    Examples:
      | qty | item | rid |
      | 13 | 8 | 3 |
    @case:249
    Examples:
      | qty | item | rid |
      | 13 | 9 | 3 |
    @case:250
    Examples:
      | qty | item | rid |
      | 13 | 10 | 3 |
    @case:251
    Examples:
      | qty | item | rid |
      | 14 | 1 | 1 |
    @case:252
    Examples:
      | qty | item | rid |
      | 14 | 2 | 1 |
    @case:253
    Examples:
      | qty | item | rid |
      | 14 | 5 | 2 |
    @case:254
    Examples:
      | qty | item | rid |
      | 14 | 6 | 2 |
    @case:255
    Examples:
      | qty | item | rid |
      | 14 | 7 | 2 |
    @case:256
    Examples:
      | qty | item | rid |
      | 14 | 8 | 3 |
    @case:257
    Examples:
      | qty | item | rid |
      | 14 | 9 | 3 |
    @case:258
    Examples:
      | qty | item | rid |
      | 14 | 10 | 3 |
    @case:259
    Examples:
      | qty | item | rid |
      | 15 | 1 | 1 |
    @case:260
    Examples:
      | qty | item | rid |
      | 15 | 2 | 1 |
    @case:261
    Examples:
      | qty | item | rid |
      | 15 | 5 | 2 |
    @case:262
    Examples:
      | qty | item | rid |
      | 15 | 6 | 2 |
    @case:263
    Examples:
      | qty | item | rid |
      | 15 | 7 | 2 |
    @case:264
    Examples:
      | qty | item | rid |
      | 15 | 8 | 3 |
    @case:265
    Examples:
      | qty | item | rid |
      | 15 | 9 | 3 |
    @case:266
    Examples:
      | qty | item | rid |
      | 15 | 10 | 3 |
    @case:267
    Examples:
      | qty | item | rid |
      | 16 | 1 | 1 |
    @case:268
    Examples:
      | qty | item | rid |
      | 16 | 2 | 1 |
    @case:269
    Examples:
      | qty | item | rid |
      | 16 | 5 | 2 |
    @case:270
    Examples:
      | qty | item | rid |
      | 16 | 6 | 2 |
    @case:271
    Examples:
      | qty | item | rid |
      | 16 | 7 | 2 |
    @case:272
    Examples:
      | qty | item | rid |
      | 16 | 8 | 3 |
    @case:273
    Examples:
      | qty | item | rid |
      | 16 | 9 | 3 |
    @case:274
    Examples:
      | qty | item | rid |
      | 16 | 10 | 3 |
    @case:275
    Examples:
      | qty | item | rid |
      | 17 | 1 | 1 |
    @case:276
    Examples:
      | qty | item | rid |
      | 17 | 2 | 1 |
    @case:277
    Examples:
      | qty | item | rid |
      | 17 | 5 | 2 |
    @case:278
    Examples:
      | qty | item | rid |
      | 17 | 6 | 2 |
    @case:279
    Examples:
      | qty | item | rid |
      | 17 | 7 | 2 |
    @case:280
    Examples:
      | qty | item | rid |
      | 17 | 8 | 3 |
    @case:281
    Examples:
      | qty | item | rid |
      | 17 | 9 | 3 |
    @case:282
    Examples:
      | qty | item | rid |
      | 17 | 10 | 3 |
    @case:283
    Examples:
      | qty | item | rid |
      | 18 | 1 | 1 |
    @case:284
    Examples:
      | qty | item | rid |
      | 18 | 2 | 1 |
    @case:285
    Examples:
      | qty | item | rid |
      | 18 | 5 | 2 |
    @case:286
    Examples:
      | qty | item | rid |
      | 18 | 6 | 2 |
    @case:287
    Examples:
      | qty | item | rid |
      | 18 | 7 | 2 |
    @case:288
    Examples:
      | qty | item | rid |
      | 18 | 8 | 3 |
    @case:289
    Examples:
      | qty | item | rid |
      | 18 | 9 | 3 |
    @case:290
    Examples:
      | qty | item | rid |
      | 18 | 10 | 3 |
    @case:291
    Examples:
      | qty | item | rid |
      | 19 | 1 | 1 |
    @case:292
    Examples:
      | qty | item | rid |
      | 19 | 2 | 1 |
    @case:293
    Examples:
      | qty | item | rid |
      | 19 | 5 | 2 |
    @case:294
    Examples:
      | qty | item | rid |
      | 19 | 6 | 2 |
    @case:295
    Examples:
      | qty | item | rid |
      | 19 | 7 | 2 |
    @case:296
    Examples:
      | qty | item | rid |
      | 19 | 8 | 3 |
    @case:297
    Examples:
      | qty | item | rid |
      | 19 | 9 | 3 |
    @case:298
    Examples:
      | qty | item | rid |
      | 19 | 10 | 3 |
    @case:299
    Examples:
      | qty | item | rid |
      | 20 | 1 | 1 |
    @case:300
    Examples:
      | qty | item | rid |
      | 20 | 2 | 1 |
    @case:301
    Examples:
      | qty | item | rid |
      | 20 | 5 | 2 |
    @case:302
    Examples:
      | qty | item | rid |
      | 20 | 6 | 2 |
    @case:303
    Examples:
      | qty | item | rid |
      | 20 | 7 | 2 |
    @case:304
    Examples:
      | qty | item | rid |
      | 20 | 8 | 3 |
    @case:305
    Examples:
      | qty | item | rid |
      | 20 | 9 | 3 |
    @case:306
    Examples:
      | qty | item | rid |
      | 20 | 10 | 3 |
    @case:307
    Examples:
      | qty | item | rid |
      | 21 | 1 | 1 |
    @case:308
    Examples:
      | qty | item | rid |
      | 21 | 2 | 1 |
    @case:309
    Examples:
      | qty | item | rid |
      | 21 | 5 | 2 |
    @case:310
    Examples:
      | qty | item | rid |
      | 21 | 6 | 2 |
    @case:311
    Examples:
      | qty | item | rid |
      | 21 | 7 | 2 |
    @case:312
    Examples:
      | qty | item | rid |
      | 21 | 8 | 3 |
    @case:313
    Examples:
      | qty | item | rid |
      | 21 | 9 | 3 |
    @case:314
    Examples:
      | qty | item | rid |
      | 21 | 10 | 3 |
    @case:315
    Examples:
      | qty | item | rid |
      | 22 | 1 | 1 |
    @case:316
    Examples:
      | qty | item | rid |
      | 22 | 2 | 1 |
    @case:317
    Examples:
      | qty | item | rid |
      | 22 | 5 | 2 |
    @case:318
    Examples:
      | qty | item | rid |
      | 22 | 6 | 2 |
    @case:319
    Examples:
      | qty | item | rid |
      | 22 | 7 | 2 |
    @case:320
    Examples:
      | qty | item | rid |
      | 22 | 8 | 3 |
    @case:321
    Examples:
      | qty | item | rid |
      | 22 | 9 | 3 |
    @case:322
    Examples:
      | qty | item | rid |
      | 22 | 10 | 3 |
    @case:323
    Examples:
      | qty | item | rid |
      | 23 | 1 | 1 |
    @case:324
    Examples:
      | qty | item | rid |
      | 23 | 2 | 1 |
    @case:325
    Examples:
      | qty | item | rid |
      | 23 | 5 | 2 |
    @case:326
    Examples:
      | qty | item | rid |
      | 23 | 6 | 2 |
    @case:327
    Examples:
      | qty | item | rid |
      | 23 | 7 | 2 |
    @case:328
    Examples:
      | qty | item | rid |
      | 23 | 8 | 3 |
    @case:329
    Examples:
      | qty | item | rid |
      | 23 | 9 | 3 |
    @case:330
    Examples:
      | qty | item | rid |
      | 23 | 10 | 3 |
    @case:331
    Examples:
      | qty | item | rid |
      | 24 | 1 | 1 |
    @case:332
    Examples:
      | qty | item | rid |
      | 24 | 2 | 1 |
    @case:333
    Examples:
      | qty | item | rid |
      | 24 | 5 | 2 |
    @case:334
    Examples:
      | qty | item | rid |
      | 24 | 6 | 2 |
    @case:335
    Examples:
      | qty | item | rid |
      | 24 | 7 | 2 |
    @case:336
    Examples:
      | qty | item | rid |
      | 24 | 8 | 3 |
    @case:337
    Examples:
      | qty | item | rid |
      | 24 | 9 | 3 |
    @case:338
    Examples:
      | qty | item | rid |
      | 24 | 10 | 3 |
    @case:339
    Examples:
      | qty | item | rid |
      | 25 | 1 | 1 |
    @case:340
    Examples:
      | qty | item | rid |
      | 25 | 2 | 1 |
    @case:341
    Examples:
      | qty | item | rid |
      | 25 | 5 | 2 |
    @case:342
    Examples:
      | qty | item | rid |
      | 25 | 6 | 2 |
    @case:343
    Examples:
      | qty | item | rid |
      | 25 | 7 | 2 |
    @case:344
    Examples:
      | qty | item | rid |
      | 25 | 8 | 3 |
    @case:345
    Examples:
      | qty | item | rid |
      | 25 | 9 | 3 |
    @case:346
    Examples:
      | qty | item | rid |
      | 25 | 10 | 3 |
    @case:347
    Examples:
      | qty | item | rid |
      | 26 | 1 | 1 |
    @case:348
    Examples:
      | qty | item | rid |
      | 26 | 2 | 1 |
    @case:349
    Examples:
      | qty | item | rid |
      | 26 | 5 | 2 |
    @case:350
    Examples:
      | qty | item | rid |
      | 26 | 6 | 2 |
    @case:351
    Examples:
      | qty | item | rid |
      | 26 | 7 | 2 |
    @case:352
    Examples:
      | qty | item | rid |
      | 26 | 8 | 3 |
    @case:353
    Examples:
      | qty | item | rid |
      | 26 | 9 | 3 |
    @case:354
    Examples:
      | qty | item | rid |
      | 26 | 10 | 3 |
    @case:355
    Examples:
      | qty | item | rid |
      | 27 | 1 | 1 |
    @case:356
    Examples:
      | qty | item | rid |
      | 27 | 2 | 1 |
    @case:357
    Examples:
      | qty | item | rid |
      | 27 | 5 | 2 |
    @case:358
    Examples:
      | qty | item | rid |
      | 27 | 6 | 2 |
    @case:359
    Examples:
      | qty | item | rid |
      | 27 | 7 | 2 |
    @case:360
    Examples:
      | qty | item | rid |
      | 27 | 8 | 3 |
    @case:361
    Examples:
      | qty | item | rid |
      | 27 | 9 | 3 |
    @case:362
    Examples:
      | qty | item | rid |
      | 27 | 10 | 3 |
    @case:363
    Examples:
      | qty | item | rid |
      | 28 | 1 | 1 |
    @case:364
    Examples:
      | qty | item | rid |
      | 28 | 2 | 1 |
    @case:365
    Examples:
      | qty | item | rid |
      | 28 | 5 | 2 |
    @case:366
    Examples:
      | qty | item | rid |
      | 28 | 6 | 2 |
    @case:367
    Examples:
      | qty | item | rid |
      | 28 | 7 | 2 |
    @case:368
    Examples:
      | qty | item | rid |
      | 28 | 8 | 3 |
    @case:369
    Examples:
      | qty | item | rid |
      | 28 | 9 | 3 |
    @case:370
    Examples:
      | qty | item | rid |
      | 28 | 10 | 3 |
    @case:371
    Examples:
      | qty | item | rid |
      | 29 | 1 | 1 |
    @case:372
    Examples:
      | qty | item | rid |
      | 29 | 2 | 1 |
    @case:373
    Examples:
      | qty | item | rid |
      | 29 | 5 | 2 |
    @case:374
    Examples:
      | qty | item | rid |
      | 29 | 6 | 2 |
    @case:375
    Examples:
      | qty | item | rid |
      | 29 | 7 | 2 |
    @case:376
    Examples:
      | qty | item | rid |
      | 29 | 8 | 3 |
    @case:377
    Examples:
      | qty | item | rid |
      | 29 | 9 | 3 |
    @case:378
    Examples:
      | qty | item | rid |
      | 29 | 10 | 3 |
    @case:379
    Examples:
      | qty | item | rid |
      | 30 | 1 | 1 |
    @case:380
    Examples:
      | qty | item | rid |
      | 30 | 2 | 1 |
    @case:381
    Examples:
      | qty | item | rid |
      | 30 | 5 | 2 |
    @case:382
    Examples:
      | qty | item | rid |
      | 30 | 6 | 2 |
    @case:383
    Examples:
      | qty | item | rid |
      | 30 | 7 | 2 |
    @case:384
    Examples:
      | qty | item | rid |
      | 30 | 8 | 3 |
    @case:385
    Examples:
      | qty | item | rid |
      | 30 | 9 | 3 |
    @case:386
    Examples:
      | qty | item | rid |
      | 30 | 10 | 3 |
    @case:387
    Examples:
      | qty | item | rid |
      | 31 | 1 | 1 |
    @case:388
    Examples:
      | qty | item | rid |
      | 31 | 2 | 1 |
    @case:389
    Examples:
      | qty | item | rid |
      | 31 | 5 | 2 |
    @case:390
    Examples:
      | qty | item | rid |
      | 31 | 6 | 2 |
    @case:391
    Examples:
      | qty | item | rid |
      | 31 | 7 | 2 |
    @case:392
    Examples:
      | qty | item | rid |
      | 31 | 8 | 3 |
    @case:393
    Examples:
      | qty | item | rid |
      | 31 | 9 | 3 |
    @case:394
    Examples:
      | qty | item | rid |
      | 31 | 10 | 3 |
    @case:395
    Examples:
      | qty | item | rid |
      | 32 | 1 | 1 |
    @case:396
    Examples:
      | qty | item | rid |
      | 32 | 2 | 1 |
    @case:397
    Examples:
      | qty | item | rid |
      | 32 | 5 | 2 |
    @case:398
    Examples:
      | qty | item | rid |
      | 32 | 6 | 2 |
    @case:399
    Examples:
      | qty | item | rid |
      | 32 | 7 | 2 |
    @case:400
    Examples:
      | qty | item | rid |
      | 32 | 8 | 3 |
    @case:401
    Examples:
      | qty | item | rid |
      | 32 | 9 | 3 |
    @case:402
    Examples:
      | qty | item | rid |
      | 32 | 10 | 3 |
    @case:403
    Examples:
      | qty | item | rid |
      | 33 | 1 | 1 |
    @case:404
    Examples:
      | qty | item | rid |
      | 33 | 2 | 1 |
    @case:405
    Examples:
      | qty | item | rid |
      | 33 | 5 | 2 |
    @case:406
    Examples:
      | qty | item | rid |
      | 33 | 6 | 2 |
    @case:407
    Examples:
      | qty | item | rid |
      | 33 | 7 | 2 |
    @case:408
    Examples:
      | qty | item | rid |
      | 33 | 8 | 3 |
    @case:409
    Examples:
      | qty | item | rid |
      | 33 | 9 | 3 |
    @case:410
    Examples:
      | qty | item | rid |
      | 33 | 10 | 3 |
    @case:411
    Examples:
      | qty | item | rid |
      | 34 | 1 | 1 |
    @case:412
    Examples:
      | qty | item | rid |
      | 34 | 2 | 1 |
    @case:413
    Examples:
      | qty | item | rid |
      | 34 | 5 | 2 |
    @case:414
    Examples:
      | qty | item | rid |
      | 34 | 6 | 2 |
    @case:415
    Examples:
      | qty | item | rid |
      | 34 | 7 | 2 |
    @case:416
    Examples:
      | qty | item | rid |
      | 34 | 8 | 3 |
    @case:417
    Examples:
      | qty | item | rid |
      | 34 | 9 | 3 |
    @case:418
    Examples:
      | qty | item | rid |
      | 34 | 10 | 3 |
    @case:419
    Examples:
      | qty | item | rid |
      | 35 | 1 | 1 |
    @case:420
    Examples:
      | qty | item | rid |
      | 35 | 2 | 1 |
    @case:421
    Examples:
      | qty | item | rid |
      | 35 | 5 | 2 |
    @case:422
    Examples:
      | qty | item | rid |
      | 35 | 6 | 2 |
    @case:423
    Examples:
      | qty | item | rid |
      | 35 | 7 | 2 |
    @case:424
    Examples:
      | qty | item | rid |
      | 35 | 8 | 3 |
    @case:425
    Examples:
      | qty | item | rid |
      | 35 | 9 | 3 |
    @case:426
    Examples:
      | qty | item | rid |
      | 35 | 10 | 3 |
    @case:427
    Examples:
      | qty | item | rid |
      | 36 | 1 | 1 |
    @case:428
    Examples:
      | qty | item | rid |
      | 36 | 2 | 1 |
    @case:429
    Examples:
      | qty | item | rid |
      | 36 | 5 | 2 |
    @case:430
    Examples:
      | qty | item | rid |
      | 36 | 6 | 2 |
    @case:431
    Examples:
      | qty | item | rid |
      | 36 | 7 | 2 |
    @case:432
    Examples:
      | qty | item | rid |
      | 36 | 8 | 3 |
    @case:433
    Examples:
      | qty | item | rid |
      | 36 | 9 | 3 |
    @case:434
    Examples:
      | qty | item | rid |
      | 36 | 10 | 3 |
    @case:435
    Examples:
      | qty | item | rid |
      | 37 | 1 | 1 |
    @case:436
    Examples:
      | qty | item | rid |
      | 37 | 2 | 1 |
    @case:437
    Examples:
      | qty | item | rid |
      | 37 | 5 | 2 |
    @case:438
    Examples:
      | qty | item | rid |
      | 37 | 6 | 2 |
    @case:439
    Examples:
      | qty | item | rid |
      | 37 | 7 | 2 |
    @case:440
    Examples:
      | qty | item | rid |
      | 37 | 8 | 3 |
    @case:441
    Examples:
      | qty | item | rid |
      | 37 | 9 | 3 |
    @case:442
    Examples:
      | qty | item | rid |
      | 37 | 10 | 3 |
    @case:443
    Examples:
      | qty | item | rid |
      | 38 | 1 | 1 |
    @case:444
    Examples:
      | qty | item | rid |
      | 38 | 2 | 1 |
    @case:445
    Examples:
      | qty | item | rid |
      | 38 | 5 | 2 |
    @case:446
    Examples:
      | qty | item | rid |
      | 38 | 6 | 2 |
    @case:447
    Examples:
      | qty | item | rid |
      | 38 | 7 | 2 |
    @case:448
    Examples:
      | qty | item | rid |
      | 38 | 8 | 3 |
    @case:449
    Examples:
      | qty | item | rid |
      | 38 | 9 | 3 |
    @case:450
    Examples:
      | qty | item | rid |
      | 38 | 10 | 3 |
    @case:451
    Examples:
      | qty | item | rid |
      | 39 | 1 | 1 |
    @case:452
    Examples:
      | qty | item | rid |
      | 39 | 2 | 1 |
    @case:453
    Examples:
      | qty | item | rid |
      | 39 | 5 | 2 |
    @case:454
    Examples:
      | qty | item | rid |
      | 39 | 6 | 2 |
    @case:455
    Examples:
      | qty | item | rid |
      | 39 | 7 | 2 |
    @case:456
    Examples:
      | qty | item | rid |
      | 39 | 8 | 3 |
    @case:457
    Examples:
      | qty | item | rid |
      | 39 | 9 | 3 |
    @case:458
    Examples:
      | qty | item | rid |
      | 39 | 10 | 3 |
    @case:459
    Examples:
      | qty | item | rid |
      | 40 | 1 | 1 |
    @case:460
    Examples:
      | qty | item | rid |
      | 40 | 2 | 1 |
    @case:461
    Examples:
      | qty | item | rid |
      | 40 | 5 | 2 |
    @case:462
    Examples:
      | qty | item | rid |
      | 40 | 6 | 2 |
    @case:463
    Examples:
      | qty | item | rid |
      | 40 | 7 | 2 |
    @case:464
    Examples:
      | qty | item | rid |
      | 40 | 8 | 3 |
    @case:465
    Examples:
      | qty | item | rid |
      | 40 | 9 | 3 |
    @case:466
    Examples:
      | qty | item | rid |
      | 40 | 10 | 3 |
    @case:467
    Examples:
      | qty | item | rid |
      | 41 | 1 | 1 |
    @case:468
    Examples:
      | qty | item | rid |
      | 41 | 2 | 1 |
    @case:469
    Examples:
      | qty | item | rid |
      | 41 | 5 | 2 |
    @case:470
    Examples:
      | qty | item | rid |
      | 41 | 6 | 2 |
    @case:471
    Examples:
      | qty | item | rid |
      | 41 | 7 | 2 |
    @case:472
    Examples:
      | qty | item | rid |
      | 41 | 8 | 3 |
    @case:473
    Examples:
      | qty | item | rid |
      | 41 | 9 | 3 |
    @case:474
    Examples:
      | qty | item | rid |
      | 41 | 10 | 3 |
    @case:475
    Examples:
      | qty | item | rid |
      | 42 | 1 | 1 |
    @case:476
    Examples:
      | qty | item | rid |
      | 42 | 2 | 1 |
    @case:477
    Examples:
      | qty | item | rid |
      | 42 | 5 | 2 |
    @case:478
    Examples:
      | qty | item | rid |
      | 42 | 6 | 2 |
    @case:479
    Examples:
      | qty | item | rid |
      | 42 | 7 | 2 |
    @case:480
    Examples:
      | qty | item | rid |
      | 42 | 8 | 3 |
    @case:481
    Examples:
      | qty | item | rid |
      | 42 | 9 | 3 |
    @case:482
    Examples:
      | qty | item | rid |
      | 42 | 10 | 3 |
    @case:483
    Examples:
      | qty | item | rid |
      | 43 | 1 | 1 |
    @case:484
    Examples:
      | qty | item | rid |
      | 43 | 2 | 1 |
    @case:485
    Examples:
      | qty | item | rid |
      | 43 | 5 | 2 |
    @case:486
    Examples:
      | qty | item | rid |
      | 43 | 6 | 2 |
    @case:487
    Examples:
      | qty | item | rid |
      | 43 | 7 | 2 |
    @case:488
    Examples:
      | qty | item | rid |
      | 43 | 8 | 3 |
    @case:489
    Examples:
      | qty | item | rid |
      | 43 | 9 | 3 |
    @case:490
    Examples:
      | qty | item | rid |
      | 43 | 10 | 3 |
    @case:491
    Examples:
      | qty | item | rid |
      | 44 | 1 | 1 |
    @case:492
    Examples:
      | qty | item | rid |
      | 44 | 2 | 1 |
    @case:493
    Examples:
      | qty | item | rid |
      | 44 | 5 | 2 |
    @case:494
    Examples:
      | qty | item | rid |
      | 44 | 6 | 2 |
    @case:495
    Examples:
      | qty | item | rid |
      | 44 | 7 | 2 |
    @case:496
    Examples:
      | qty | item | rid |
      | 44 | 8 | 3 |
    @case:497
    Examples:
      | qty | item | rid |
      | 44 | 9 | 3 |
    @case:498
    Examples:
      | qty | item | rid |
      | 44 | 10 | 3 |
    @case:499
    Examples:
      | qty | item | rid |
      | 45 | 1 | 1 |
    @case:500
    Examples:
      | qty | item | rid |
      | 45 | 2 | 1 |
    @case:501
    Examples:
      | qty | item | rid |
      | 45 | 5 | 2 |
    @case:502
    Examples:
      | qty | item | rid |
      | 45 | 6 | 2 |
    @case:503
    Examples:
      | qty | item | rid |
      | 45 | 7 | 2 |
    @case:504
    Examples:
      | qty | item | rid |
      | 45 | 8 | 3 |
    @case:505
    Examples:
      | qty | item | rid |
      | 45 | 9 | 3 |
    @case:506
    Examples:
      | qty | item | rid |
      | 45 | 10 | 3 |
    @case:507
    Examples:
      | qty | item | rid |
      | 46 | 1 | 1 |
    @case:508
    Examples:
      | qty | item | rid |
      | 46 | 2 | 1 |
    @case:509
    Examples:
      | qty | item | rid |
      | 46 | 5 | 2 |
    @case:510
    Examples:
      | qty | item | rid |
      | 46 | 6 | 2 |
    @case:511
    Examples:
      | qty | item | rid |
      | 46 | 7 | 2 |
    @case:512
    Examples:
      | qty | item | rid |
      | 46 | 8 | 3 |
    @case:513
    Examples:
      | qty | item | rid |
      | 46 | 9 | 3 |
    @case:514
    Examples:
      | qty | item | rid |
      | 46 | 10 | 3 |
    @case:515
    Examples:
      | qty | item | rid |
      | 47 | 1 | 1 |
    @case:516
    Examples:
      | qty | item | rid |
      | 47 | 2 | 1 |
    @case:517
    Examples:
      | qty | item | rid |
      | 47 | 5 | 2 |
    @case:518
    Examples:
      | qty | item | rid |
      | 47 | 6 | 2 |
    @case:519
    Examples:
      | qty | item | rid |
      | 47 | 7 | 2 |
    @case:520
    Examples:
      | qty | item | rid |
      | 47 | 8 | 3 |
    @case:521
    Examples:
      | qty | item | rid |
      | 47 | 9 | 3 |
    @case:522
    Examples:
      | qty | item | rid |
      | 47 | 10 | 3 |
    @case:523
    Examples:
      | qty | item | rid |
      | 48 | 1 | 1 |
    @case:524
    Examples:
      | qty | item | rid |
      | 48 | 2 | 1 |
    @case:525
    Examples:
      | qty | item | rid |
      | 48 | 5 | 2 |
    @case:526
    Examples:
      | qty | item | rid |
      | 48 | 6 | 2 |
    @case:527
    Examples:
      | qty | item | rid |
      | 48 | 7 | 2 |
    @case:528
    Examples:
      | qty | item | rid |
      | 48 | 8 | 3 |
    @case:529
    Examples:
      | qty | item | rid |
      | 48 | 9 | 3 |
    @case:530
    Examples:
      | qty | item | rid |
      | 48 | 10 | 3 |
    @case:531
    Examples:
      | qty | item | rid |
      | 49 | 1 | 1 |
    @case:532
    Examples:
      | qty | item | rid |
      | 49 | 2 | 1 |
    @case:533
    Examples:
      | qty | item | rid |
      | 49 | 5 | 2 |
    @case:534
    Examples:
      | qty | item | rid |
      | 49 | 6 | 2 |
    @case:535
    Examples:
      | qty | item | rid |
      | 49 | 7 | 2 |
    @case:536
    Examples:
      | qty | item | rid |
      | 49 | 8 | 3 |
    @case:537
    Examples:
      | qty | item | rid |
      | 49 | 9 | 3 |
    @case:538
    Examples:
      | qty | item | rid |
      | 49 | 10 | 3 |
    @case:539
    Examples:
      | qty | item | rid |
      | 50 | 1 | 1 |
    @case:540
    Examples:
      | qty | item | rid |
      | 50 | 2 | 1 |
    @case:541
    Examples:
      | qty | item | rid |
      | 50 | 5 | 2 |
    @case:542
    Examples:
      | qty | item | rid |
      | 50 | 6 | 2 |
    @case:543
    Examples:
      | qty | item | rid |
      | 50 | 7 | 2 |
    @case:544
    Examples:
      | qty | item | rid |
      | 50 | 8 | 3 |
    @case:545
    Examples:
      | qty | item | rid |
      | 50 | 9 | 3 |
    @case:546
    Examples:
      | qty | item | rid |
      | 50 | 10 | 3 |
    @case:547
    Examples:
      | qty | item | rid |
      | 51 | 1 | 1 |
    @case:548
    Examples:
      | qty | item | rid |
      | 51 | 2 | 1 |
    @case:549
    Examples:
      | qty | item | rid |
      | 51 | 5 | 2 |
    @case:550
    Examples:
      | qty | item | rid |
      | 51 | 6 | 2 |
    @case:551
    Examples:
      | qty | item | rid |
      | 51 | 7 | 2 |
    @case:552
    Examples:
      | qty | item | rid |
      | 51 | 8 | 3 |
    @case:553
    Examples:
      | qty | item | rid |
      | 51 | 9 | 3 |
    @case:554
    Examples:
      | qty | item | rid |
      | 51 | 10 | 3 |
    @case:555
    Examples:
      | qty | item | rid |
      | 52 | 1 | 1 |
    @case:556
    Examples:
      | qty | item | rid |
      | 52 | 2 | 1 |
    @case:557
    Examples:
      | qty | item | rid |
      | 52 | 5 | 2 |
    @case:558
    Examples:
      | qty | item | rid |
      | 52 | 6 | 2 |
    @case:559
    Examples:
      | qty | item | rid |
      | 52 | 7 | 2 |
    @case:560
    Examples:
      | qty | item | rid |
      | 52 | 8 | 3 |
    @case:561
    Examples:
      | qty | item | rid |
      | 52 | 9 | 3 |
    @case:562
    Examples:
      | qty | item | rid |
      | 52 | 10 | 3 |
    @case:563
    Examples:
      | qty | item | rid |
      | 53 | 1 | 1 |
    @case:564
    Examples:
      | qty | item | rid |
      | 53 | 2 | 1 |
    @case:565
    Examples:
      | qty | item | rid |
      | 53 | 5 | 2 |
    @case:566
    Examples:
      | qty | item | rid |
      | 53 | 6 | 2 |
    @case:567
    Examples:
      | qty | item | rid |
      | 53 | 7 | 2 |
    @case:568
    Examples:
      | qty | item | rid |
      | 53 | 8 | 3 |
    @case:569
    Examples:
      | qty | item | rid |
      | 53 | 9 | 3 |
    @case:570
    Examples:
      | qty | item | rid |
      | 53 | 10 | 3 |
    @case:571
    Examples:
      | qty | item | rid |
      | 54 | 1 | 1 |
    @case:572
    Examples:
      | qty | item | rid |
      | 54 | 2 | 1 |
    @case:573
    Examples:
      | qty | item | rid |
      | 54 | 5 | 2 |
    @case:574
    Examples:
      | qty | item | rid |
      | 54 | 6 | 2 |
    @case:575
    Examples:
      | qty | item | rid |
      | 54 | 7 | 2 |
    @case:576
    Examples:
      | qty | item | rid |
      | 54 | 8 | 3 |
    @case:577
    Examples:
      | qty | item | rid |
      | 54 | 9 | 3 |
    @case:578
    Examples:
      | qty | item | rid |
      | 54 | 10 | 3 |
    @case:579
    Examples:
      | qty | item | rid |
      | 55 | 1 | 1 |
    @case:580
    Examples:
      | qty | item | rid |
      | 55 | 2 | 1 |
    @case:581
    Examples:
      | qty | item | rid |
      | 55 | 5 | 2 |
    @case:582
    Examples:
      | qty | item | rid |
      | 55 | 6 | 2 |
    @case:583
    Examples:
      | qty | item | rid |
      | 55 | 7 | 2 |
    @case:584
    Examples:
      | qty | item | rid |
      | 55 | 8 | 3 |
    @case:585
    Examples:
      | qty | item | rid |
      | 55 | 9 | 3 |
    @case:586
    Examples:
      | qty | item | rid |
      | 55 | 10 | 3 |
    @case:587
    Examples:
      | qty | item | rid |
      | 56 | 1 | 1 |
    @case:588
    Examples:
      | qty | item | rid |
      | 56 | 2 | 1 |
    @case:589
    Examples:
      | qty | item | rid |
      | 56 | 5 | 2 |
    @case:590
    Examples:
      | qty | item | rid |
      | 56 | 6 | 2 |
    @case:591
    Examples:
      | qty | item | rid |
      | 56 | 7 | 2 |
    @case:592
    Examples:
      | qty | item | rid |
      | 56 | 8 | 3 |
    @case:593
    Examples:
      | qty | item | rid |
      | 56 | 9 | 3 |
    @case:594
    Examples:
      | qty | item | rid |
      | 56 | 10 | 3 |
    @case:595
    Examples:
      | qty | item | rid |
      | 57 | 1 | 1 |
    @case:596
    Examples:
      | qty | item | rid |
      | 57 | 2 | 1 |
    @case:597
    Examples:
      | qty | item | rid |
      | 57 | 5 | 2 |
    @case:598
    Examples:
      | qty | item | rid |
      | 57 | 6 | 2 |
    @case:599
    Examples:
      | qty | item | rid |
      | 57 | 7 | 2 |
    @case:600
    Examples:
      | qty | item | rid |
      | 57 | 8 | 3 |
    @case:601
    Examples:
      | qty | item | rid |
      | 57 | 9 | 3 |
    @case:602
    Examples:
      | qty | item | rid |
      | 57 | 10 | 3 |
    @case:603
    Examples:
      | qty | item | rid |
      | 58 | 1 | 1 |
    @case:604
    Examples:
      | qty | item | rid |
      | 58 | 2 | 1 |
    @case:605
    Examples:
      | qty | item | rid |
      | 58 | 5 | 2 |
    @case:606
    Examples:
      | qty | item | rid |
      | 58 | 6 | 2 |
    @case:607
    Examples:
      | qty | item | rid |
      | 58 | 7 | 2 |
    @case:608
    Examples:
      | qty | item | rid |
      | 58 | 8 | 3 |
    @case:609
    Examples:
      | qty | item | rid |
      | 58 | 9 | 3 |
    @case:610
    Examples:
      | qty | item | rid |
      | 58 | 10 | 3 |
    @case:611
    Examples:
      | qty | item | rid |
      | 59 | 1 | 1 |
    @case:612
    Examples:
      | qty | item | rid |
      | 59 | 2 | 1 |
    @case:613
    Examples:
      | qty | item | rid |
      | 59 | 5 | 2 |
    @case:614
    Examples:
      | qty | item | rid |
      | 59 | 6 | 2 |
    @case:615
    Examples:
      | qty | item | rid |
      | 59 | 7 | 2 |
    @case:616
    Examples:
      | qty | item | rid |
      | 59 | 8 | 3 |
    @case:617
    Examples:
      | qty | item | rid |
      | 59 | 9 | 3 |
    @case:618
    Examples:
      | qty | item | rid |
      | 59 | 10 | 3 |
    @case:619
    Examples:
      | qty | item | rid |
      | 60 | 1 | 1 |
    @case:620
    Examples:
      | qty | item | rid |
      | 60 | 2 | 1 |
    @case:621
    Examples:
      | qty | item | rid |
      | 60 | 5 | 2 |
    @case:622
    Examples:
      | qty | item | rid |
      | 60 | 6 | 2 |
    @case:623
    Examples:
      | qty | item | rid |
      | 60 | 7 | 2 |
    @case:624
    Examples:
      | qty | item | rid |
      | 60 | 8 | 3 |
    @case:625
    Examples:
      | qty | item | rid |
      | 60 | 9 | 3 |
    @case:626
    Examples:
      | qty | item | rid |
      | 60 | 10 | 3 |
    @case:627
    Examples:
      | qty | item | rid |
      | 61 | 1 | 1 |
    @case:628
    Examples:
      | qty | item | rid |
      | 61 | 2 | 1 |
    @case:629
    Examples:
      | qty | item | rid |
      | 61 | 5 | 2 |
    @case:630
    Examples:
      | qty | item | rid |
      | 61 | 6 | 2 |
    @case:631
    Examples:
      | qty | item | rid |
      | 61 | 7 | 2 |
    @case:632
    Examples:
      | qty | item | rid |
      | 61 | 8 | 3 |
    @case:633
    Examples:
      | qty | item | rid |
      | 61 | 9 | 3 |
    @case:634
    Examples:
      | qty | item | rid |
      | 61 | 10 | 3 |
    @case:635
    Examples:
      | qty | item | rid |
      | 62 | 1 | 1 |
    @case:636
    Examples:
      | qty | item | rid |
      | 62 | 2 | 1 |
    @case:637
    Examples:
      | qty | item | rid |
      | 62 | 5 | 2 |
    @case:638
    Examples:
      | qty | item | rid |
      | 62 | 6 | 2 |
    @case:639
    Examples:
      | qty | item | rid |
      | 62 | 7 | 2 |
    @case:640
    Examples:
      | qty | item | rid |
      | 62 | 8 | 3 |
    @case:641
    Examples:
      | qty | item | rid |
      | 62 | 9 | 3 |
    @case:642
    Examples:
      | qty | item | rid |
      | 62 | 10 | 3 |
    @case:643
    Examples:
      | qty | item | rid |
      | 63 | 1 | 1 |
    @case:644
    Examples:
      | qty | item | rid |
      | 63 | 2 | 1 |
    @case:645
    Examples:
      | qty | item | rid |
      | 63 | 5 | 2 |
    @case:646
    Examples:
      | qty | item | rid |
      | 63 | 6 | 2 |
    @case:647
    Examples:
      | qty | item | rid |
      | 63 | 7 | 2 |
    @case:648
    Examples:
      | qty | item | rid |
      | 63 | 8 | 3 |
    @case:649
    Examples:
      | qty | item | rid |
      | 63 | 9 | 3 |
    @case:650
    Examples:
      | qty | item | rid |
      | 63 | 10 | 3 |
    @case:651
    Examples:
      | qty | item | rid |
      | 64 | 1 | 1 |
    @case:652
    Examples:
      | qty | item | rid |
      | 64 | 2 | 1 |
    @case:653
    Examples:
      | qty | item | rid |
      | 64 | 5 | 2 |
    @case:654
    Examples:
      | qty | item | rid |
      | 64 | 6 | 2 |
    @case:655
    Examples:
      | qty | item | rid |
      | 64 | 7 | 2 |
    @case:656
    Examples:
      | qty | item | rid |
      | 64 | 8 | 3 |
    @case:657
    Examples:
      | qty | item | rid |
      | 64 | 9 | 3 |
    @case:658
    Examples:
      | qty | item | rid |
      | 64 | 10 | 3 |
    @case:659
    Examples:
      | qty | item | rid |
      | 65 | 1 | 1 |
    @case:660
    Examples:
      | qty | item | rid |
      | 65 | 2 | 1 |
    @case:661
    Examples:
      | qty | item | rid |
      | 65 | 5 | 2 |
    @case:662
    Examples:
      | qty | item | rid |
      | 65 | 6 | 2 |
    @case:663
    Examples:
      | qty | item | rid |
      | 65 | 7 | 2 |
    @case:664
    Examples:
      | qty | item | rid |
      | 65 | 8 | 3 |
    @case:665
    Examples:
      | qty | item | rid |
      | 65 | 9 | 3 |
    @case:666
    Examples:
      | qty | item | rid |
      | 65 | 10 | 3 |
    @case:667
    Examples:
      | qty | item | rid |
      | 66 | 1 | 1 |
    @case:668
    Examples:
      | qty | item | rid |
      | 66 | 2 | 1 |
    @case:669
    Examples:
      | qty | item | rid |
      | 66 | 5 | 2 |
    @case:670
    Examples:
      | qty | item | rid |
      | 66 | 6 | 2 |
    @case:671
    Examples:
      | qty | item | rid |
      | 66 | 7 | 2 |
    @case:672
    Examples:
      | qty | item | rid |
      | 66 | 8 | 3 |
    @case:673
    Examples:
      | qty | item | rid |
      | 66 | 9 | 3 |
    @case:674
    Examples:
      | qty | item | rid |
      | 66 | 10 | 3 |
    @case:675
    Examples:
      | qty | item | rid |
      | 67 | 1 | 1 |
    @case:676
    Examples:
      | qty | item | rid |
      | 67 | 2 | 1 |
    @case:677
    Examples:
      | qty | item | rid |
      | 67 | 5 | 2 |
    @case:678
    Examples:
      | qty | item | rid |
      | 67 | 6 | 2 |
    @case:679
    Examples:
      | qty | item | rid |
      | 67 | 7 | 2 |
    @case:680
    Examples:
      | qty | item | rid |
      | 67 | 8 | 3 |
    @case:681
    Examples:
      | qty | item | rid |
      | 67 | 9 | 3 |
    @case:682
    Examples:
      | qty | item | rid |
      | 67 | 10 | 3 |
    @case:683
    Examples:
      | qty | item | rid |
      | 68 | 1 | 1 |
    @case:684
    Examples:
      | qty | item | rid |
      | 68 | 2 | 1 |
    @case:685
    Examples:
      | qty | item | rid |
      | 68 | 5 | 2 |
    @case:686
    Examples:
      | qty | item | rid |
      | 68 | 6 | 2 |
    @case:687
    Examples:
      | qty | item | rid |
      | 68 | 7 | 2 |
    @case:688
    Examples:
      | qty | item | rid |
      | 68 | 8 | 3 |
    @case:689
    Examples:
      | qty | item | rid |
      | 68 | 9 | 3 |
    @case:690
    Examples:
      | qty | item | rid |
      | 68 | 10 | 3 |
    @case:691
    Examples:
      | qty | item | rid |
      | 69 | 1 | 1 |
    @case:692
    Examples:
      | qty | item | rid |
      | 69 | 2 | 1 |
    @case:693
    Examples:
      | qty | item | rid |
      | 69 | 5 | 2 |
    @case:694
    Examples:
      | qty | item | rid |
      | 69 | 6 | 2 |
    @case:695
    Examples:
      | qty | item | rid |
      | 69 | 7 | 2 |
    @case:696
    Examples:
      | qty | item | rid |
      | 69 | 8 | 3 |
    @case:697
    Examples:
      | qty | item | rid |
      | 69 | 9 | 3 |
    @case:698
    Examples:
      | qty | item | rid |
      | 69 | 10 | 3 |
    @case:699
    Examples:
      | qty | item | rid |
      | 70 | 1 | 1 |
    @case:700
    Examples:
      | qty | item | rid |
      | 70 | 2 | 1 |
    @case:701
    Examples:
      | qty | item | rid |
      | 70 | 5 | 2 |
    @case:702
    Examples:
      | qty | item | rid |
      | 70 | 6 | 2 |
    @case:703
    Examples:
      | qty | item | rid |
      | 70 | 7 | 2 |
    @case:704
    Examples:
      | qty | item | rid |
      | 70 | 8 | 3 |
    @case:705
    Examples:
      | qty | item | rid |
      | 70 | 9 | 3 |
    @case:706
    Examples:
      | qty | item | rid |
      | 70 | 10 | 3 |
    @case:707
    Examples:
      | qty | item | rid |
      | 71 | 1 | 1 |
    @case:708
    Examples:
      | qty | item | rid |
      | 71 | 2 | 1 |
    @case:709
    Examples:
      | qty | item | rid |
      | 71 | 5 | 2 |
    @case:710
    Examples:
      | qty | item | rid |
      | 71 | 6 | 2 |
    @case:711
    Examples:
      | qty | item | rid |
      | 71 | 7 | 2 |
    @case:712
    Examples:
      | qty | item | rid |
      | 71 | 8 | 3 |
    @case:713
    Examples:
      | qty | item | rid |
      | 71 | 9 | 3 |
    @case:714
    Examples:
      | qty | item | rid |
      | 71 | 10 | 3 |
    @case:715
    Examples:
      | qty | item | rid |
      | 72 | 1 | 1 |
    @case:716
    Examples:
      | qty | item | rid |
      | 72 | 2 | 1 |
    @case:717
    Examples:
      | qty | item | rid |
      | 72 | 5 | 2 |
    @case:718
    Examples:
      | qty | item | rid |
      | 72 | 6 | 2 |
    @case:719
    Examples:
      | qty | item | rid |
      | 72 | 7 | 2 |
    @case:720
    Examples:
      | qty | item | rid |
      | 72 | 8 | 3 |
    @case:721
    Examples:
      | qty | item | rid |
      | 72 | 9 | 3 |
    @case:722
    Examples:
      | qty | item | rid |
      | 72 | 10 | 3 |
    @case:723
    Examples:
      | qty | item | rid |
      | 73 | 1 | 1 |
    @case:724
    Examples:
      | qty | item | rid |
      | 73 | 2 | 1 |
    @case:725
    Examples:
      | qty | item | rid |
      | 73 | 5 | 2 |
    @case:726
    Examples:
      | qty | item | rid |
      | 73 | 6 | 2 |
    @case:727
    Examples:
      | qty | item | rid |
      | 73 | 7 | 2 |
    @case:728
    Examples:
      | qty | item | rid |
      | 73 | 8 | 3 |
    @case:729
    Examples:
      | qty | item | rid |
      | 73 | 9 | 3 |
    @case:730
    Examples:
      | qty | item | rid |
      | 73 | 10 | 3 |
    @case:731
    Examples:
      | qty | item | rid |
      | 74 | 1 | 1 |
    @case:732
    Examples:
      | qty | item | rid |
      | 74 | 2 | 1 |
    @case:733
    Examples:
      | qty | item | rid |
      | 74 | 5 | 2 |
    @case:734
    Examples:
      | qty | item | rid |
      | 74 | 6 | 2 |
    @case:735
    Examples:
      | qty | item | rid |
      | 74 | 7 | 2 |
    @case:736
    Examples:
      | qty | item | rid |
      | 74 | 8 | 3 |
    @case:737
    Examples:
      | qty | item | rid |
      | 74 | 9 | 3 |
    @case:738
    Examples:
      | qty | item | rid |
      | 74 | 10 | 3 |
    @case:739
    Examples:
      | qty | item | rid |
      | 75 | 1 | 1 |
    @case:740
    Examples:
      | qty | item | rid |
      | 75 | 2 | 1 |
    @case:741
    Examples:
      | qty | item | rid |
      | 75 | 5 | 2 |
    @case:742
    Examples:
      | qty | item | rid |
      | 75 | 6 | 2 |
    @case:743
    Examples:
      | qty | item | rid |
      | 75 | 7 | 2 |
    @case:744
    Examples:
      | qty | item | rid |
      | 75 | 8 | 3 |
    @case:745
    Examples:
      | qty | item | rid |
      | 75 | 9 | 3 |
    @case:746
    Examples:
      | qty | item | rid |
      | 75 | 10 | 3 |
    @case:747
    Examples:
      | qty | item | rid |
      | 76 | 1 | 1 |
    @case:748
    Examples:
      | qty | item | rid |
      | 76 | 2 | 1 |
    @case:749
    Examples:
      | qty | item | rid |
      | 76 | 5 | 2 |
    @case:750
    Examples:
      | qty | item | rid |
      | 76 | 6 | 2 |
    @case:751
    Examples:
      | qty | item | rid |
      | 76 | 7 | 2 |
    @case:752
    Examples:
      | qty | item | rid |
      | 76 | 8 | 3 |
    @case:753
    Examples:
      | qty | item | rid |
      | 76 | 9 | 3 |
    @case:754
    Examples:
      | qty | item | rid |
      | 76 | 10 | 3 |
    @case:755
    Examples:
      | qty | item | rid |
      | 77 | 1 | 1 |
    @case:756
    Examples:
      | qty | item | rid |
      | 77 | 2 | 1 |
    @case:757
    Examples:
      | qty | item | rid |
      | 77 | 5 | 2 |
    @case:758
    Examples:
      | qty | item | rid |
      | 77 | 6 | 2 |
    @case:759
    Examples:
      | qty | item | rid |
      | 77 | 7 | 2 |
    @case:760
    Examples:
      | qty | item | rid |
      | 77 | 8 | 3 |
    @case:761
    Examples:
      | qty | item | rid |
      | 77 | 9 | 3 |
    @case:762
    Examples:
      | qty | item | rid |
      | 77 | 10 | 3 |
    @case:763
    Examples:
      | qty | item | rid |
      | 78 | 1 | 1 |
    @case:764
    Examples:
      | qty | item | rid |
      | 78 | 2 | 1 |
    @case:765
    Examples:
      | qty | item | rid |
      | 78 | 5 | 2 |
    @case:766
    Examples:
      | qty | item | rid |
      | 78 | 6 | 2 |
    @case:767
    Examples:
      | qty | item | rid |
      | 78 | 7 | 2 |
    @case:768
    Examples:
      | qty | item | rid |
      | 78 | 8 | 3 |
    @case:769
    Examples:
      | qty | item | rid |
      | 78 | 9 | 3 |
    @case:770
    Examples:
      | qty | item | rid |
      | 78 | 10 | 3 |
    @case:771
    Examples:
      | qty | item | rid |
      | 79 | 1 | 1 |
    @case:772
    Examples:
      | qty | item | rid |
      | 79 | 2 | 1 |
    @case:773
    Examples:
      | qty | item | rid |
      | 79 | 5 | 2 |
    @case:774
    Examples:
      | qty | item | rid |
      | 79 | 6 | 2 |
    @case:775
    Examples:
      | qty | item | rid |
      | 79 | 7 | 2 |
    @case:776
    Examples:
      | qty | item | rid |
      | 79 | 8 | 3 |
    @case:777
    Examples:
      | qty | item | rid |
      | 79 | 9 | 3 |
    @case:778
    Examples:
      | qty | item | rid |
      | 79 | 10 | 3 |
    @case:779
    Examples:
      | qty | item | rid |
      | 80 | 1 | 1 |
    @case:780
    Examples:
      | qty | item | rid |
      | 80 | 2 | 1 |
    @case:781
    Examples:
      | qty | item | rid |
      | 80 | 5 | 2 |
    @case:782
    Examples:
      | qty | item | rid |
      | 80 | 6 | 2 |
    @case:783
    Examples:
      | qty | item | rid |
      | 80 | 7 | 2 |
    @case:784
    Examples:
      | qty | item | rid |
      | 80 | 8 | 3 |
    @case:785
    Examples:
      | qty | item | rid |
      | 80 | 9 | 3 |
    @case:786
    Examples:
      | qty | item | rid |
      | 80 | 10 | 3 |
    @case:787
    Examples:
      | qty | item | rid |
      | 81 | 1 | 1 |
    @case:788
    Examples:
      | qty | item | rid |
      | 81 | 2 | 1 |
    @case:789
    Examples:
      | qty | item | rid |
      | 81 | 5 | 2 |
    @case:790
    Examples:
      | qty | item | rid |
      | 81 | 6 | 2 |
    @case:791
    Examples:
      | qty | item | rid |
      | 81 | 7 | 2 |
    @case:792
    Examples:
      | qty | item | rid |
      | 81 | 8 | 3 |
    @case:793
    Examples:
      | qty | item | rid |
      | 81 | 9 | 3 |
    @case:794
    Examples:
      | qty | item | rid |
      | 81 | 10 | 3 |
    @case:795
    Examples:
      | qty | item | rid |
      | 82 | 1 | 1 |
    @case:796
    Examples:
      | qty | item | rid |
      | 82 | 2 | 1 |
    @case:797
    Examples:
      | qty | item | rid |
      | 82 | 5 | 2 |
    @case:798
    Examples:
      | qty | item | rid |
      | 82 | 6 | 2 |
    @case:799
    Examples:
      | qty | item | rid |
      | 82 | 7 | 2 |
    @case:800
    Examples:
      | qty | item | rid |
      | 82 | 8 | 3 |
    @case:801
    Examples:
      | qty | item | rid |
      | 82 | 9 | 3 |
    @case:802
    Examples:
      | qty | item | rid |
      | 82 | 10 | 3 |
    @case:803
    Examples:
      | qty | item | rid |
      | 83 | 1 | 1 |
    @case:804
    Examples:
      | qty | item | rid |
      | 83 | 2 | 1 |
    @case:805
    Examples:
      | qty | item | rid |
      | 83 | 5 | 2 |
    @case:806
    Examples:
      | qty | item | rid |
      | 83 | 6 | 2 |
    @case:807
    Examples:
      | qty | item | rid |
      | 83 | 7 | 2 |
    @case:808
    Examples:
      | qty | item | rid |
      | 83 | 8 | 3 |
    @case:809
    Examples:
      | qty | item | rid |
      | 83 | 9 | 3 |
    @case:810
    Examples:
      | qty | item | rid |
      | 83 | 10 | 3 |
    @case:811
    Examples:
      | qty | item | rid |
      | 84 | 1 | 1 |
    @case:812
    Examples:
      | qty | item | rid |
      | 84 | 2 | 1 |
    @case:813
    Examples:
      | qty | item | rid |
      | 84 | 5 | 2 |
    @case:814
    Examples:
      | qty | item | rid |
      | 84 | 6 | 2 |
    @case:815
    Examples:
      | qty | item | rid |
      | 84 | 7 | 2 |
    @case:816
    Examples:
      | qty | item | rid |
      | 84 | 8 | 3 |
    @case:817
    Examples:
      | qty | item | rid |
      | 84 | 9 | 3 |
    @case:818
    Examples:
      | qty | item | rid |
      | 84 | 10 | 3 |
    @case:819
    Examples:
      | qty | item | rid |
      | 85 | 1 | 1 |
    @case:820
    Examples:
      | qty | item | rid |
      | 85 | 2 | 1 |
    @case:821
    Examples:
      | qty | item | rid |
      | 85 | 5 | 2 |
    @case:822
    Examples:
      | qty | item | rid |
      | 85 | 6 | 2 |
    @case:823
    Examples:
      | qty | item | rid |
      | 85 | 7 | 2 |
    @case:824
    Examples:
      | qty | item | rid |
      | 85 | 8 | 3 |
    @case:825
    Examples:
      | qty | item | rid |
      | 85 | 9 | 3 |
    @case:826
    Examples:
      | qty | item | rid |
      | 85 | 10 | 3 |
    @case:827
    Examples:
      | qty | item | rid |
      | 86 | 1 | 1 |
    @case:828
    Examples:
      | qty | item | rid |
      | 86 | 2 | 1 |
    @case:829
    Examples:
      | qty | item | rid |
      | 86 | 5 | 2 |
    @case:830
    Examples:
      | qty | item | rid |
      | 86 | 6 | 2 |
    @case:831
    Examples:
      | qty | item | rid |
      | 86 | 7 | 2 |
    @case:832
    Examples:
      | qty | item | rid |
      | 86 | 8 | 3 |
    @case:833
    Examples:
      | qty | item | rid |
      | 86 | 9 | 3 |
    @case:834
    Examples:
      | qty | item | rid |
      | 86 | 10 | 3 |
    @case:835
    Examples:
      | qty | item | rid |
      | 87 | 1 | 1 |
    @case:836
    Examples:
      | qty | item | rid |
      | 87 | 2 | 1 |
    @case:837
    Examples:
      | qty | item | rid |
      | 87 | 5 | 2 |
    @case:838
    Examples:
      | qty | item | rid |
      | 87 | 6 | 2 |
    @case:839
    Examples:
      | qty | item | rid |
      | 87 | 7 | 2 |
    @case:840
    Examples:
      | qty | item | rid |
      | 87 | 8 | 3 |
    @case:841
    Examples:
      | qty | item | rid |
      | 87 | 9 | 3 |
    @case:842
    Examples:
      | qty | item | rid |
      | 87 | 10 | 3 |
    @case:843
    Examples:
      | qty | item | rid |
      | 88 | 1 | 1 |
    @case:844
    Examples:
      | qty | item | rid |
      | 88 | 2 | 1 |
    @case:845
    Examples:
      | qty | item | rid |
      | 88 | 5 | 2 |
    @case:846
    Examples:
      | qty | item | rid |
      | 88 | 6 | 2 |
    @case:847
    Examples:
      | qty | item | rid |
      | 88 | 7 | 2 |
    @case:848
    Examples:
      | qty | item | rid |
      | 88 | 8 | 3 |
    @case:849
    Examples:
      | qty | item | rid |
      | 88 | 9 | 3 |
    @case:850
    Examples:
      | qty | item | rid |
      | 88 | 10 | 3 |
    @case:851
    Examples:
      | qty | item | rid |
      | 89 | 1 | 1 |
    @case:852
    Examples:
      | qty | item | rid |
      | 89 | 2 | 1 |
    @case:853
    Examples:
      | qty | item | rid |
      | 89 | 5 | 2 |
    @case:854
    Examples:
      | qty | item | rid |
      | 89 | 6 | 2 |
    @case:855
    Examples:
      | qty | item | rid |
      | 89 | 7 | 2 |
    @case:856
    Examples:
      | qty | item | rid |
      | 89 | 8 | 3 |
    @case:857
    Examples:
      | qty | item | rid |
      | 89 | 9 | 3 |
    @case:858
    Examples:
      | qty | item | rid |
      | 89 | 10 | 3 |
    @case:859
    Examples:
      | qty | item | rid |
      | 90 | 1 | 1 |
    @case:860
    Examples:
      | qty | item | rid |
      | 90 | 2 | 1 |
    @case:861
    Examples:
      | qty | item | rid |
      | 90 | 5 | 2 |
    @case:862
    Examples:
      | qty | item | rid |
      | 90 | 6 | 2 |
    @case:863
    Examples:
      | qty | item | rid |
      | 90 | 7 | 2 |
    @case:864
    Examples:
      | qty | item | rid |
      | 90 | 8 | 3 |
    @case:865
    Examples:
      | qty | item | rid |
      | 90 | 9 | 3 |
    @case:866
    Examples:
      | qty | item | rid |
      | 90 | 10 | 3 |
    @case:867
    Examples:
      | qty | item | rid |
      | 91 | 1 | 1 |
    @case:868
    Examples:
      | qty | item | rid |
      | 91 | 2 | 1 |
    @case:869
    Examples:
      | qty | item | rid |
      | 91 | 5 | 2 |
    @case:870
    Examples:
      | qty | item | rid |
      | 91 | 6 | 2 |
    @case:871
    Examples:
      | qty | item | rid |
      | 91 | 7 | 2 |
    @case:872
    Examples:
      | qty | item | rid |
      | 91 | 8 | 3 |
    @case:873
    Examples:
      | qty | item | rid |
      | 91 | 9 | 3 |
    @case:874
    Examples:
      | qty | item | rid |
      | 91 | 10 | 3 |
    @case:875
    Examples:
      | qty | item | rid |
      | 92 | 1 | 1 |
    @case:876
    Examples:
      | qty | item | rid |
      | 92 | 2 | 1 |
    @case:877
    Examples:
      | qty | item | rid |
      | 92 | 5 | 2 |
    @case:878
    Examples:
      | qty | item | rid |
      | 92 | 6 | 2 |
    @case:879
    Examples:
      | qty | item | rid |
      | 92 | 7 | 2 |
    @case:880
    Examples:
      | qty | item | rid |
      | 92 | 8 | 3 |
    @case:881
    Examples:
      | qty | item | rid |
      | 92 | 9 | 3 |
    @case:882
    Examples:
      | qty | item | rid |
      | 92 | 10 | 3 |
    @case:883
    Examples:
      | qty | item | rid |
      | 93 | 1 | 1 |
    @case:884
    Examples:
      | qty | item | rid |
      | 93 | 2 | 1 |
    @case:885
    Examples:
      | qty | item | rid |
      | 93 | 5 | 2 |
    @case:886
    Examples:
      | qty | item | rid |
      | 93 | 6 | 2 |
    @case:887
    Examples:
      | qty | item | rid |
      | 93 | 7 | 2 |
    @case:888
    Examples:
      | qty | item | rid |
      | 93 | 8 | 3 |
    @case:889
    Examples:
      | qty | item | rid |
      | 93 | 9 | 3 |
    @case:890
    Examples:
      | qty | item | rid |
      | 93 | 10 | 3 |
    @case:891
    Examples:
      | qty | item | rid |
      | 94 | 1 | 1 |
    @case:892
    Examples:
      | qty | item | rid |
      | 94 | 2 | 1 |
    @case:893
    Examples:
      | qty | item | rid |
      | 94 | 5 | 2 |
    @case:894
    Examples:
      | qty | item | rid |
      | 94 | 6 | 2 |
    @case:895
    Examples:
      | qty | item | rid |
      | 94 | 7 | 2 |
    @case:896
    Examples:
      | qty | item | rid |
      | 94 | 8 | 3 |
    @case:897
    Examples:
      | qty | item | rid |
      | 94 | 9 | 3 |
    @case:898
    Examples:
      | qty | item | rid |
      | 94 | 10 | 3 |
    @case:899
    Examples:
      | qty | item | rid |
      | 95 | 1 | 1 |
    @case:900
    Examples:
      | qty | item | rid |
      | 95 | 2 | 1 |
    @case:901
    Examples:
      | qty | item | rid |
      | 95 | 5 | 2 |
    @case:902
    Examples:
      | qty | item | rid |
      | 95 | 6 | 2 |
    @case:903
    Examples:
      | qty | item | rid |
      | 95 | 7 | 2 |
    @case:904
    Examples:
      | qty | item | rid |
      | 95 | 8 | 3 |
    @case:905
    Examples:
      | qty | item | rid |
      | 95 | 9 | 3 |
    @case:906
    Examples:
      | qty | item | rid |
      | 95 | 10 | 3 |
    @case:907
    Examples:
      | qty | item | rid |
      | 96 | 1 | 1 |
    @case:908
    Examples:
      | qty | item | rid |
      | 96 | 2 | 1 |
    @case:909
    Examples:
      | qty | item | rid |
      | 96 | 5 | 2 |
    @case:910
    Examples:
      | qty | item | rid |
      | 96 | 6 | 2 |
    @case:911
    Examples:
      | qty | item | rid |
      | 96 | 7 | 2 |
    @case:912
    Examples:
      | qty | item | rid |
      | 96 | 8 | 3 |
    @case:913
    Examples:
      | qty | item | rid |
      | 96 | 9 | 3 |
    @case:914
    Examples:
      | qty | item | rid |
      | 96 | 10 | 3 |
    @case:915
    Examples:
      | qty | item | rid |
      | 97 | 1 | 1 |
    @case:916
    Examples:
      | qty | item | rid |
      | 97 | 2 | 1 |
    @case:917
    Examples:
      | qty | item | rid |
      | 97 | 5 | 2 |
    @case:918
    Examples:
      | qty | item | rid |
      | 97 | 6 | 2 |
    @case:919
    Examples:
      | qty | item | rid |
      | 97 | 7 | 2 |
    @case:920
    Examples:
      | qty | item | rid |
      | 97 | 8 | 3 |
    @case:921
    Examples:
      | qty | item | rid |
      | 97 | 9 | 3 |
    @case:922
    Examples:
      | qty | item | rid |
      | 97 | 10 | 3 |
    @case:923
    Examples:
      | qty | item | rid |
      | 98 | 1 | 1 |
    @case:924
    Examples:
      | qty | item | rid |
      | 98 | 2 | 1 |
    @case:925
    Examples:
      | qty | item | rid |
      | 98 | 5 | 2 |
    @case:926
    Examples:
      | qty | item | rid |
      | 98 | 6 | 2 |
    @case:927
    Examples:
      | qty | item | rid |
      | 98 | 7 | 2 |
    @case:928
    Examples:
      | qty | item | rid |
      | 98 | 8 | 3 |
    @case:929
    Examples:
      | qty | item | rid |
      | 98 | 9 | 3 |
    @case:930
    Examples:
      | qty | item | rid |
      | 98 | 10 | 3 |
    @case:931
    Examples:
      | qty | item | rid |
      | 99 | 1 | 1 |
    @case:932
    Examples:
      | qty | item | rid |
      | 99 | 2 | 1 |
    @case:933
    Examples:
      | qty | item | rid |
      | 99 | 5 | 2 |
    @case:934
    Examples:
      | qty | item | rid |
      | 99 | 6 | 2 |
    @case:935
    Examples:
      | qty | item | rid |
      | 99 | 7 | 2 |
    @case:936
    Examples:
      | qty | item | rid |
      | 99 | 8 | 3 |
    @case:937
    Examples:
      | qty | item | rid |
      | 99 | 9 | 3 |
    @case:938
    Examples:
      | qty | item | rid |
      | 99 | 10 | 3 |
    @case:939
    Examples:
      | qty | item | rid |
      | 100 | 1 | 1 |
    @case:940
    Examples:
      | qty | item | rid |
      | 100 | 2 | 1 |
    @case:941
    Examples:
      | qty | item | rid |
      | 100 | 5 | 2 |
    @case:942
    Examples:
      | qty | item | rid |
      | 100 | 6 | 2 |
    @case:943
    Examples:
      | qty | item | rid |
      | 100 | 7 | 2 |
    @case:944
    Examples:
      | qty | item | rid |
      | 100 | 8 | 3 |
    @case:945
    Examples:
      | qty | item | rid |
      | 100 | 9 | 3 |
    @case:946
    Examples:
      | qty | item | rid |
      | 100 | 10 | 3 |
    @case:947
    Examples:
      | qty | item | rid |
      | 101 | 1 | 1 |
    @case:948
    Examples:
      | qty | item | rid |
      | 101 | 2 | 1 |
    @case:949
    Examples:
      | qty | item | rid |
      | 101 | 5 | 2 |
    @case:950
    Examples:
      | qty | item | rid |
      | 101 | 6 | 2 |
    @case:951
    Examples:
      | qty | item | rid |
      | 101 | 7 | 2 |
    @case:952
    Examples:
      | qty | item | rid |
      | 101 | 8 | 3 |
    @case:953
    Examples:
      | qty | item | rid |
      | 101 | 9 | 3 |
    @case:954
    Examples:
      | qty | item | rid |
      | 101 | 10 | 3 |
    @case:955
    Examples:
      | qty | item | rid |
      | 102 | 1 | 1 |
    @case:956
    Examples:
      | qty | item | rid |
      | 102 | 2 | 1 |
    @case:957
    Examples:
      | qty | item | rid |
      | 102 | 5 | 2 |
    @case:958
    Examples:
      | qty | item | rid |
      | 102 | 6 | 2 |
    @case:959
    Examples:
      | qty | item | rid |
      | 102 | 7 | 2 |
    @case:960
    Examples:
      | qty | item | rid |
      | 102 | 8 | 3 |
    @case:961
    Examples:
      | qty | item | rid |
      | 102 | 9 | 3 |
    @case:962
    Examples:
      | qty | item | rid |
      | 102 | 10 | 3 |
    @case:963
    Examples:
      | qty | item | rid |
      | 103 | 1 | 1 |
    @case:964
    Examples:
      | qty | item | rid |
      | 103 | 2 | 1 |
    @case:965
    Examples:
      | qty | item | rid |
      | 103 | 5 | 2 |
    @case:966
    Examples:
      | qty | item | rid |
      | 103 | 6 | 2 |
    @case:967
    Examples:
      | qty | item | rid |
      | 103 | 7 | 2 |
    @case:968
    Examples:
      | qty | item | rid |
      | 103 | 8 | 3 |
    @case:969
    Examples:
      | qty | item | rid |
      | 103 | 9 | 3 |
    @case:970
    Examples:
      | qty | item | rid |
      | 103 | 10 | 3 |
    @case:971
    Examples:
      | qty | item | rid |
      | 104 | 1 | 1 |
    @case:972
    Examples:
      | qty | item | rid |
      | 104 | 2 | 1 |
    @case:973
    Examples:
      | qty | item | rid |
      | 104 | 5 | 2 |
    @case:974
    Examples:
      | qty | item | rid |
      | 104 | 6 | 2 |
    @case:975
    Examples:
      | qty | item | rid |
      | 104 | 7 | 2 |
    @case:976
    Examples:
      | qty | item | rid |
      | 104 | 8 | 3 |
    @case:977
    Examples:
      | qty | item | rid |
      | 104 | 9 | 3 |
    @case:978
    Examples:
      | qty | item | rid |
      | 104 | 10 | 3 |
    @case:979
    Examples:
      | qty | item | rid |
      | 105 | 1 | 1 |
    @case:980
    Examples:
      | qty | item | rid |
      | 105 | 2 | 1 |
    @case:981
    Examples:
      | qty | item | rid |
      | 105 | 5 | 2 |
    @case:982
    Examples:
      | qty | item | rid |
      | 105 | 6 | 2 |
    @case:983
    Examples:
      | qty | item | rid |
      | 105 | 7 | 2 |
    @case:984
    Examples:
      | qty | item | rid |
      | 105 | 8 | 3 |
    @case:985
    Examples:
      | qty | item | rid |
      | 105 | 9 | 3 |
    @case:986
    Examples:
      | qty | item | rid |
      | 105 | 10 | 3 |
    @case:987
    Examples:
      | qty | item | rid |
      | 106 | 1 | 1 |
    @case:988
    Examples:
      | qty | item | rid |
      | 106 | 2 | 1 |
    @case:989
    Examples:
      | qty | item | rid |
      | 106 | 5 | 2 |
    @case:990
    Examples:
      | qty | item | rid |
      | 106 | 6 | 2 |
    @case:991
    Examples:
      | qty | item | rid |
      | 106 | 7 | 2 |
    @case:992
    Examples:
      | qty | item | rid |
      | 106 | 8 | 3 |
    @case:993
    Examples:
      | qty | item | rid |
      | 106 | 9 | 3 |
    @case:994
    Examples:
      | qty | item | rid |
      | 106 | 10 | 3 |
    @case:995
    Examples:
      | qty | item | rid |
      | 107 | 1 | 1 |
    @case:996
    Examples:
      | qty | item | rid |
      | 107 | 2 | 1 |
    @case:997
    Examples:
      | qty | item | rid |
      | 107 | 5 | 2 |
    @case:998
    Examples:
      | qty | item | rid |
      | 107 | 6 | 2 |
    @case:999
    Examples:
      | qty | item | rid |
      | 107 | 7 | 2 |
    @case:1000
    Examples:
      | qty | item | rid |
      | 107 | 8 | 3 |
