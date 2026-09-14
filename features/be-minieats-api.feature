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

  Scenario Outline: A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row
    Given a customer with a cart at restaurant <rid>
    When <qty> of item <iid> are added to the cart
    Then the cart holds <qty> of item <iid> priced from the row
    And the cart subtotal equals the sum of its line totals

    @case:147
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 1 |
    @case:148
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 1 |
    @case:149
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 1 |
    @case:150
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 1 |
    @case:151
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 1 |
    @case:152
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 1 |
    @case:153
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 1 |
    @case:154
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 1 |
    @case:155
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 2 |
    @case:156
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 2 |
    @case:157
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 2 |
    @case:158
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 2 |
    @case:159
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 2 |
    @case:160
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 2 |
    @case:161
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 2 |
    @case:162
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 2 |
    @case:163
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 3 |
    @case:164
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 3 |
    @case:165
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 3 |
    @case:166
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 3 |
    @case:167
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 3 |
    @case:168
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 3 |
    @case:169
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 3 |
    @case:170
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 3 |
    @case:171
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 4 |
    @case:172
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 4 |
    @case:173
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 4 |
    @case:174
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 4 |
    @case:175
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 4 |
    @case:176
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 4 |
    @case:177
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 4 |
    @case:178
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 4 |
    @case:179
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 5 |
    @case:180
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 5 |
    @case:181
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 5 |
    @case:182
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 5 |
    @case:183
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 5 |
    @case:184
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 5 |
    @case:185
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 5 |
    @case:186
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 5 |
    @case:187
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 6 |
    @case:188
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 6 |
    @case:189
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 6 |
    @case:190
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 6 |
    @case:191
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 6 |
    @case:192
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 6 |
    @case:193
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 6 |
    @case:194
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 6 |
    @case:195
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 7 |
    @case:196
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 7 |
    @case:197
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 7 |
    @case:198
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 7 |
    @case:199
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 7 |
    @case:200
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 7 |
    @case:201
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 7 |
    @case:202
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 7 |
    @case:203
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 8 |
    @case:204
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 8 |
    @case:205
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 8 |
    @case:206
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 8 |
    @case:207
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 8 |
    @case:208
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 8 |
    @case:209
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 8 |
    @case:210
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 8 |
    @case:211
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 9 |
    @case:212
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 9 |
    @case:213
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 9 |
    @case:214
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 9 |
    @case:215
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 9 |
    @case:216
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 9 |
    @case:217
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 9 |
    @case:218
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 9 |
    @case:219
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 10 |
    @case:220
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 10 |
    @case:221
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 10 |
    @case:222
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 10 |
    @case:223
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 10 |
    @case:224
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 10 |
    @case:225
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 10 |
    @case:226
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 10 |
    @case:227
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 11 |
    @case:228
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 11 |
    @case:229
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 11 |
    @case:230
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 11 |
    @case:231
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 11 |
    @case:232
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 11 |
    @case:233
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 11 |
    @case:234
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 11 |
    @case:235
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 12 |
    @case:236
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 12 |
    @case:237
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 12 |
    @case:238
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 12 |
    @case:239
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 12 |
    @case:240
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 12 |
    @case:241
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 12 |
    @case:242
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 12 |
    @case:243
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 13 |
    @case:244
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 13 |
    @case:245
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 13 |
    @case:246
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 13 |
    @case:247
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 13 |
    @case:248
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 13 |
    @case:249
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 13 |
    @case:250
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 13 |
    @case:251
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 14 |
    @case:252
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 14 |
    @case:253
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 14 |
    @case:254
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 14 |
    @case:255
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 14 |
    @case:256
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 14 |
    @case:257
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 14 |
    @case:258
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 14 |
    @case:259
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 15 |
    @case:260
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 15 |
    @case:261
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 15 |
    @case:262
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 15 |
    @case:263
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 15 |
    @case:264
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 15 |
    @case:265
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 15 |
    @case:266
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 15 |
    @case:267
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 16 |
    @case:268
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 16 |
    @case:269
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 16 |
    @case:270
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 16 |
    @case:271
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 16 |
    @case:272
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 16 |
    @case:273
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 16 |
    @case:274
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 16 |
    @case:275
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 17 |
    @case:276
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 17 |
    @case:277
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 17 |
    @case:278
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 17 |
    @case:279
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 17 |
    @case:280
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 17 |
    @case:281
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 17 |
    @case:282
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 17 |
    @case:283
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 18 |
    @case:284
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 18 |
    @case:285
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 18 |
    @case:286
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 18 |
    @case:287
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 18 |
    @case:288
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 18 |
    @case:289
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 18 |
    @case:290
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 18 |
    @case:291
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 19 |
    @case:292
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 19 |
    @case:293
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 19 |
    @case:294
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 19 |
    @case:295
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 19 |
    @case:296
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 19 |
    @case:297
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 19 |
    @case:298
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 19 |
    @case:299
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 20 |
    @case:300
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 20 |
    @case:301
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 20 |
    @case:302
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 20 |
    @case:303
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 20 |
    @case:304
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 20 |
    @case:305
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 20 |
    @case:306
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 20 |
    @case:307
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 21 |
    @case:308
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 21 |
    @case:309
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 21 |
    @case:310
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 21 |
    @case:311
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 21 |
    @case:312
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 21 |
    @case:313
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 21 |
    @case:314
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 21 |
    @case:315
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 22 |
    @case:316
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 22 |
    @case:317
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 22 |
    @case:318
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 22 |
    @case:319
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 22 |
    @case:320
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 22 |
    @case:321
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 22 |
    @case:322
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 22 |
    @case:323
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 23 |
    @case:324
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 23 |
    @case:325
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 23 |
    @case:326
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 23 |
    @case:327
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 23 |
    @case:328
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 23 |
    @case:329
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 23 |
    @case:330
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 23 |
    @case:331
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 24 |
    @case:332
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 24 |
    @case:333
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 24 |
    @case:334
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 24 |
    @case:335
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 24 |
    @case:336
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 24 |
    @case:337
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 24 |
    @case:338
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 24 |
    @case:339
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 25 |
    @case:340
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 25 |
    @case:341
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 25 |
    @case:342
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 25 |
    @case:343
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 25 |
    @case:344
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 25 |
    @case:345
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 25 |
    @case:346
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 25 |
    @case:347
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 26 |
    @case:348
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 26 |
    @case:349
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 26 |
    @case:350
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 26 |
    @case:351
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 26 |
    @case:352
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 26 |
    @case:353
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 26 |
    @case:354
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 26 |
    @case:355
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 27 |
    @case:356
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 27 |
    @case:357
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 27 |
    @case:358
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 27 |
    @case:359
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 27 |
    @case:360
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 27 |
    @case:361
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 27 |
    @case:362
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 27 |
    @case:363
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 28 |
    @case:364
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 28 |
    @case:365
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 28 |
    @case:366
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 28 |

  Scenario Outline: A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines
    Given a customer with a cart at restaurant <rid>
    When <qa> of item <ia> are added to the cart
    And <qb> of item <ib> are added to the cart
    Then the cart subtotal equals the sum of its line totals

    @case:367
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 1 | 2 | 3 |
    @case:368
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 1 | 6 | 3 |
    @case:369
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 1 | 7 | 3 |
    @case:370
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 1 | 7 | 3 |
    @case:371
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 1 | 9 | 3 |
    @case:372
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 1 | 10 | 3 |
    @case:373
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 1 | 10 | 3 |
    @case:374
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 2 | 2 | 5 |
    @case:375
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 2 | 6 | 5 |
    @case:376
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 2 | 7 | 5 |
    @case:377
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 2 | 7 | 5 |
    @case:378
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 2 | 9 | 5 |
    @case:379
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 2 | 10 | 5 |
    @case:380
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 2 | 10 | 5 |
    @case:381
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 3 | 2 | 7 |
    @case:382
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 3 | 6 | 7 |
    @case:383
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 3 | 7 | 7 |
    @case:384
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 3 | 7 | 7 |
    @case:385
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 3 | 9 | 7 |
    @case:386
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 3 | 10 | 7 |
    @case:387
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 3 | 10 | 7 |
    @case:388
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 4 | 2 | 9 |
    @case:389
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 4 | 6 | 9 |
    @case:390
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 4 | 7 | 9 |
    @case:391
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 4 | 7 | 9 |
    @case:392
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 4 | 9 | 9 |
    @case:393
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 4 | 10 | 9 |
    @case:394
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 4 | 10 | 9 |
    @case:395
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 5 | 2 | 2 |
    @case:396
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 5 | 6 | 2 |
    @case:397
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 5 | 7 | 2 |
    @case:398
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 5 | 7 | 2 |
    @case:399
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 5 | 9 | 2 |
    @case:400
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 5 | 10 | 2 |
    @case:401
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 5 | 10 | 2 |
    @case:402
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 6 | 2 | 4 |
    @case:403
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 6 | 6 | 4 |
    @case:404
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 6 | 7 | 4 |
    @case:405
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 6 | 7 | 4 |
    @case:406
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 6 | 9 | 4 |
    @case:407
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 6 | 10 | 4 |
    @case:408
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 6 | 10 | 4 |
    @case:409
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 7 | 2 | 6 |
    @case:410
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 7 | 6 | 6 |
    @case:411
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 7 | 7 | 6 |
    @case:412
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 7 | 7 | 6 |
    @case:413
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 7 | 9 | 6 |
    @case:414
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 7 | 10 | 6 |
    @case:415
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 7 | 10 | 6 |
    @case:416
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 8 | 2 | 8 |
    @case:417
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 8 | 6 | 8 |
    @case:418
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 8 | 7 | 8 |
    @case:419
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 8 | 7 | 8 |
    @case:420
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 8 | 9 | 8 |
    @case:421
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 8 | 10 | 8 |
    @case:422
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 8 | 10 | 8 |
    @case:423
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 9 | 2 | 1 |
    @case:424
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 9 | 6 | 1 |
    @case:425
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 9 | 7 | 1 |
    @case:426
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 9 | 7 | 1 |
    @case:427
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 9 | 9 | 1 |
    @case:428
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 9 | 10 | 1 |
    @case:429
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 9 | 10 | 1 |
    @case:430
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 10 | 2 | 3 |
    @case:431
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 10 | 6 | 3 |
    @case:432
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 10 | 7 | 3 |
    @case:433
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 10 | 7 | 3 |
    @case:434
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 10 | 9 | 3 |
    @case:435
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 10 | 10 | 3 |
    @case:436
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 10 | 10 | 3 |
    @case:437
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 11 | 2 | 5 |
    @case:438
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 11 | 6 | 5 |
    @case:439
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 11 | 7 | 5 |
    @case:440
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 11 | 7 | 5 |
    @case:441
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 11 | 9 | 5 |
    @case:442
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 11 | 10 | 5 |
    @case:443
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 11 | 10 | 5 |
    @case:444
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 12 | 2 | 7 |
    @case:445
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 12 | 6 | 7 |
    @case:446
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 12 | 7 | 7 |
    @case:447
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 12 | 7 | 7 |
    @case:448
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 12 | 9 | 7 |
    @case:449
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 12 | 10 | 7 |
    @case:450
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 12 | 10 | 7 |
    @case:451
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 13 | 2 | 9 |
    @case:452
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 13 | 6 | 9 |
    @case:453
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 13 | 7 | 9 |
    @case:454
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 13 | 7 | 9 |
    @case:455
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 13 | 9 | 9 |
    @case:456
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 13 | 10 | 9 |
    @case:457
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 13 | 10 | 9 |
    @case:458
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 14 | 2 | 2 |
    @case:459
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 14 | 6 | 2 |
    @case:460
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 14 | 7 | 2 |
    @case:461
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 14 | 7 | 2 |
    @case:462
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 14 | 9 | 2 |
    @case:463
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 14 | 10 | 2 |
    @case:464
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 14 | 10 | 2 |
    @case:465
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 15 | 2 | 4 |
    @case:466
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 15 | 6 | 4 |
    @case:467
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 15 | 7 | 4 |
    @case:468
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 15 | 7 | 4 |
    @case:469
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 15 | 9 | 4 |
    @case:470
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 15 | 10 | 4 |
    @case:471
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 15 | 10 | 4 |
    @case:472
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 16 | 2 | 6 |
    @case:473
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 16 | 6 | 6 |
    @case:474
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 16 | 7 | 6 |
    @case:475
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 16 | 7 | 6 |
    @case:476
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 16 | 9 | 6 |
    @case:477
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 16 | 10 | 6 |
    @case:478
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 16 | 10 | 6 |
    @case:479
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 17 | 2 | 8 |
    @case:480
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 17 | 6 | 8 |
    @case:481
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 17 | 7 | 8 |
    @case:482
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 17 | 7 | 8 |
    @case:483
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 17 | 9 | 8 |
    @case:484
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 17 | 10 | 8 |
    @case:485
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 17 | 10 | 8 |
    @case:486
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 18 | 2 | 1 |
    @case:487
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 18 | 6 | 1 |
    @case:488
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 18 | 7 | 1 |
    @case:489
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 18 | 7 | 1 |
    @case:490
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 18 | 9 | 1 |
    @case:491
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 18 | 10 | 1 |
    @case:492
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 18 | 10 | 1 |
    @case:493
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 19 | 2 | 3 |
    @case:494
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 19 | 6 | 3 |
    @case:495
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 19 | 7 | 3 |
    @case:496
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 19 | 7 | 3 |
    @case:497
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 19 | 9 | 3 |
    @case:498
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 19 | 10 | 3 |
    @case:499
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 19 | 10 | 3 |
    @case:500
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 20 | 2 | 5 |
    @case:501
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 20 | 6 | 5 |
    @case:502
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 20 | 7 | 5 |
    @case:503
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 20 | 7 | 5 |
    @case:504
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 20 | 9 | 5 |
    @case:505
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 20 | 10 | 5 |
    @case:506
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 20 | 10 | 5 |
    @case:507
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 21 | 2 | 7 |
    @case:508
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 21 | 6 | 7 |
    @case:509
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 21 | 7 | 7 |
    @case:510
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 21 | 7 | 7 |
    @case:511
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 21 | 9 | 7 |
    @case:512
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 21 | 10 | 7 |
    @case:513
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 21 | 10 | 7 |
    @case:514
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 22 | 2 | 9 |
    @case:515
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 22 | 6 | 9 |
    @case:516
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 22 | 7 | 9 |
    @case:517
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 22 | 7 | 9 |
    @case:518
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 22 | 9 | 9 |
    @case:519
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 22 | 10 | 9 |
    @case:520
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 22 | 10 | 9 |
    @case:521
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 23 | 2 | 2 |
    @case:522
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 23 | 6 | 2 |
    @case:523
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 23 | 7 | 2 |
    @case:524
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 23 | 7 | 2 |
    @case:525
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 23 | 9 | 2 |
    @case:526
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 23 | 10 | 2 |
    @case:527
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 23 | 10 | 2 |
    @case:528
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 24 | 2 | 4 |
    @case:529
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 24 | 6 | 4 |
    @case:530
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 24 | 7 | 4 |
    @case:531
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 24 | 7 | 4 |
    @case:532
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 24 | 9 | 4 |
    @case:533
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 24 | 10 | 4 |
    @case:534
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 24 | 10 | 4 |
    @case:535
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 25 | 2 | 6 |
    @case:536
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 25 | 6 | 6 |
    @case:537
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 25 | 7 | 6 |
    @case:538
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 25 | 7 | 6 |
    @case:539
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 25 | 9 | 6 |
    @case:540
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 25 | 10 | 6 |
    @case:541
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 25 | 10 | 6 |
    @case:542
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 26 | 2 | 8 |
    @case:543
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 26 | 6 | 8 |
    @case:544
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 26 | 7 | 8 |
    @case:545
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 26 | 7 | 8 |
    @case:546
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 26 | 9 | 8 |
    @case:547
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 26 | 10 | 8 |
    @case:548
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 26 | 10 | 8 |
    @case:549
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 27 | 2 | 1 |
    @case:550
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 27 | 6 | 1 |
    @case:551
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 5 | 27 | 7 | 1 |
    @case:552
    Examples:
      | rid | ia | qa | ib | qb |
      | 2 | 6 | 27 | 7 | 1 |
    @case:553
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 27 | 9 | 1 |
    @case:554
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 8 | 27 | 10 | 1 |
    @case:555
    Examples:
      | rid | ia | qa | ib | qb |
      | 3 | 9 | 27 | 10 | 1 |
    @case:556
    Examples:
      | rid | ia | qa | ib | qb |
      | 1 | 1 | 28 | 2 | 3 |

  Scenario Outline: Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused
    Given a customer with a cart at restaurant <rid>
    When <qty> of item <iid> are added to the cart
    Then the response status is 409

    @case:557
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 501 |
    @case:558
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 501 |
    @case:559
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 501 |
    @case:560
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 501 |
    @case:561
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 501 |
    @case:562
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 501 |
    @case:563
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 501 |
    @case:564
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 501 |
    @case:565
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 502 |
    @case:566
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 502 |
    @case:567
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 502 |
    @case:568
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 502 |
    @case:569
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 502 |
    @case:570
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 502 |
    @case:571
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 502 |
    @case:572
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 502 |
    @case:573
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 503 |
    @case:574
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 503 |
    @case:575
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 503 |
    @case:576
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 503 |
    @case:577
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 503 |
    @case:578
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 503 |
    @case:579
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 503 |
    @case:580
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 503 |
    @case:581
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 504 |
    @case:582
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 504 |
    @case:583
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 504 |
    @case:584
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 504 |
    @case:585
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 504 |
    @case:586
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 504 |
    @case:587
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 504 |
    @case:588
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 504 |
    @case:589
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 505 |
    @case:590
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 505 |
    @case:591
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 505 |
    @case:592
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 505 |
    @case:593
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 505 |
    @case:594
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 505 |
    @case:595
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 505 |
    @case:596
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 505 |
    @case:597
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 506 |
    @case:598
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 506 |
    @case:599
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 506 |
    @case:600
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 506 |
    @case:601
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 506 |
    @case:602
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 506 |
    @case:603
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 506 |
    @case:604
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 506 |
    @case:605
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 507 |
    @case:606
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 507 |
    @case:607
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 507 |
    @case:608
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 507 |
    @case:609
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 507 |
    @case:610
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 507 |
    @case:611
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 507 |
    @case:612
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 507 |
    @case:613
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 508 |
    @case:614
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 508 |
    @case:615
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 508 |
    @case:616
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 508 |
    @case:617
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 508 |
    @case:618
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 508 |
    @case:619
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 508 |
    @case:620
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 508 |
    @case:621
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 509 |
    @case:622
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 509 |
    @case:623
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 509 |
    @case:624
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 509 |
    @case:625
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 509 |
    @case:626
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 509 |
    @case:627
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 509 |
    @case:628
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 509 |
    @case:629
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 510 |
    @case:630
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 510 |
    @case:631
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 510 |
    @case:632
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 510 |
    @case:633
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 510 |
    @case:634
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 510 |
    @case:635
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 510 |
    @case:636
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 510 |
    @case:637
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 511 |
    @case:638
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 511 |
    @case:639
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 511 |
    @case:640
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 511 |
    @case:641
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 511 |
    @case:642
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 511 |
    @case:643
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 511 |
    @case:644
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 511 |
    @case:645
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 512 |
    @case:646
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 512 |
    @case:647
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 512 |
    @case:648
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 512 |
    @case:649
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 512 |
    @case:650
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 512 |
    @case:651
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 512 |
    @case:652
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 512 |
    @case:653
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 513 |
    @case:654
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 513 |
    @case:655
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 513 |
    @case:656
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 513 |
    @case:657
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 513 |
    @case:658
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 513 |
    @case:659
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 513 |
    @case:660
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 513 |
    @case:661
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 514 |
    @case:662
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 514 |
    @case:663
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 514 |
    @case:664
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 514 |
    @case:665
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 514 |
    @case:666
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 514 |
    @case:667
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 514 |
    @case:668
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 514 |
    @case:669
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 515 |
    @case:670
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 515 |
    @case:671
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 515 |
    @case:672
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 515 |
    @case:673
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 515 |
    @case:674
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 515 |
    @case:675
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 515 |
    @case:676
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 515 |
    @case:677
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 516 |
    @case:678
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 516 |
    @case:679
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 516 |
    @case:680
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 516 |
    @case:681
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 516 |
    @case:682
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 516 |
    @case:683
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 516 |
    @case:684
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 516 |
    @case:685
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 517 |
    @case:686
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 517 |
    @case:687
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 517 |
    @case:688
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 517 |
    @case:689
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 517 |
    @case:690
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 517 |
    @case:691
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 517 |
    @case:692
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 517 |
    @case:693
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 518 |
    @case:694
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 518 |
    @case:695
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 518 |
    @case:696
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 518 |
    @case:697
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 518 |
    @case:698
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 518 |
    @case:699
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 518 |
    @case:700
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 518 |
    @case:701
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 519 |
    @case:702
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 519 |
    @case:703
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 519 |
    @case:704
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 519 |
    @case:705
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 519 |
    @case:706
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 519 |
    @case:707
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 519 |
    @case:708
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 519 |
    @case:709
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 520 |
    @case:710
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 520 |
    @case:711
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 520 |
    @case:712
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 520 |
    @case:713
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 520 |
    @case:714
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 520 |
    @case:715
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 520 |
    @case:716
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 520 |
    @case:717
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 521 |
    @case:718
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 521 |
    @case:719
    Examples:
      | rid | iid | qty |
      | 2 | 5 | 521 |
    @case:720
    Examples:
      | rid | iid | qty |
      | 2 | 6 | 521 |
    @case:721
    Examples:
      | rid | iid | qty |
      | 2 | 7 | 521 |
    @case:722
    Examples:
      | rid | iid | qty |
      | 3 | 8 | 521 |
    @case:723
    Examples:
      | rid | iid | qty |
      | 3 | 9 | 521 |
    @case:724
    Examples:
      | rid | iid | qty |
      | 3 | 10 | 521 |
    @case:725
    Examples:
      | rid | iid | qty |
      | 1 | 1 | 522 |
    @case:726
    Examples:
      | rid | iid | qty |
      | 1 | 2 | 522 |

  Scenario Outline: At restaurant <rid>, adding <qty> of the foreign item <iid> is not found
    Given a customer with a cart at restaurant <rid>
    When <qty> of item <iid> are added to the cart
    Then the response status is 404

    @case:727
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 1 |
    @case:728
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 1 |
    @case:729
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 1 |
    @case:730
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 1 |
    @case:731
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 1 |
    @case:732
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 1 |
    @case:733
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 1 |
    @case:734
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 1 |
    @case:735
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 1 |
    @case:736
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 1 |
    @case:737
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 1 |
    @case:738
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 1 |
    @case:739
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 1 |
    @case:740
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 1 |
    @case:741
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 1 |
    @case:742
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 1 |
    @case:743
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 2 |
    @case:744
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 2 |
    @case:745
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 2 |
    @case:746
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 2 |
    @case:747
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 2 |
    @case:748
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 2 |
    @case:749
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 2 |
    @case:750
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 2 |
    @case:751
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 2 |
    @case:752
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 2 |
    @case:753
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 2 |
    @case:754
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 2 |
    @case:755
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 2 |
    @case:756
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 2 |
    @case:757
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 2 |
    @case:758
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 2 |
    @case:759
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 3 |
    @case:760
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 3 |
    @case:761
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 3 |
    @case:762
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 3 |
    @case:763
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 3 |
    @case:764
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 3 |
    @case:765
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 3 |
    @case:766
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 3 |
    @case:767
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 3 |
    @case:768
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 3 |
    @case:769
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 3 |
    @case:770
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 3 |
    @case:771
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 3 |
    @case:772
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 3 |
    @case:773
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 3 |
    @case:774
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 3 |
    @case:775
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 4 |
    @case:776
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 4 |
    @case:777
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 4 |
    @case:778
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 4 |
    @case:779
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 4 |
    @case:780
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 4 |
    @case:781
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 4 |
    @case:782
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 4 |
    @case:783
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 4 |
    @case:784
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 4 |
    @case:785
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 4 |
    @case:786
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 4 |
    @case:787
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 4 |
    @case:788
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 4 |
    @case:789
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 4 |
    @case:790
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 4 |
    @case:791
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 5 |
    @case:792
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 5 |
    @case:793
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 5 |
    @case:794
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 5 |
    @case:795
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 5 |
    @case:796
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 5 |
    @case:797
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 5 |
    @case:798
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 5 |
    @case:799
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 5 |
    @case:800
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 5 |
    @case:801
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 5 |
    @case:802
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 5 |
    @case:803
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 5 |
    @case:804
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 5 |
    @case:805
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 5 |
    @case:806
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 5 |
    @case:807
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 6 |
    @case:808
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 6 |
    @case:809
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 6 |
    @case:810
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 6 |
    @case:811
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 6 |
    @case:812
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 6 |
    @case:813
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 6 |
    @case:814
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 6 |
    @case:815
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 6 |
    @case:816
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 6 |
    @case:817
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 6 |
    @case:818
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 6 |
    @case:819
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 6 |
    @case:820
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 6 |
    @case:821
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 6 |
    @case:822
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 6 |
    @case:823
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 7 |
    @case:824
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 7 |
    @case:825
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 7 |
    @case:826
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 7 |
    @case:827
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 7 |
    @case:828
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 7 |
    @case:829
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 7 |
    @case:830
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 7 |
    @case:831
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 7 |
    @case:832
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 7 |
    @case:833
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 7 |
    @case:834
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 7 |
    @case:835
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 7 |
    @case:836
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 7 |
    @case:837
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 7 |
    @case:838
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 7 |
    @case:839
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 8 |
    @case:840
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 8 |
    @case:841
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 8 |
    @case:842
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 8 |
    @case:843
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 8 |
    @case:844
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 8 |
    @case:845
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 8 |
    @case:846
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 8 |
    @case:847
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 8 |
    @case:848
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 8 |
    @case:849
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 8 |
    @case:850
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 8 |
    @case:851
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 8 |
    @case:852
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 8 |
    @case:853
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 8 |
    @case:854
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 8 |
    @case:855
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 9 |
    @case:856
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 9 |
    @case:857
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 9 |
    @case:858
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 9 |
    @case:859
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 9 |
    @case:860
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 9 |
    @case:861
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 9 |
    @case:862
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 9 |
    @case:863
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 9 |
    @case:864
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 9 |
    @case:865
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 9 |
    @case:866
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 9 |
    @case:867
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 9 |
    @case:868
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 9 |
    @case:869
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 9 |
    @case:870
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 9 |
    @case:871
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 10 |
    @case:872
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 10 |
    @case:873
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 10 |
    @case:874
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 10 |
    @case:875
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 10 |
    @case:876
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 10 |
    @case:877
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 10 |
    @case:878
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 10 |
    @case:879
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 10 |
    @case:880
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 10 |
    @case:881
    Examples:
      | rid | iid | qty |
      | 2 | 10 | 10 |
    @case:882
    Examples:
      | rid | iid | qty |
      | 3 | 1 | 10 |
    @case:883
    Examples:
      | rid | iid | qty |
      | 3 | 2 | 10 |
    @case:884
    Examples:
      | rid | iid | qty |
      | 3 | 5 | 10 |
    @case:885
    Examples:
      | rid | iid | qty |
      | 3 | 6 | 10 |
    @case:886
    Examples:
      | rid | iid | qty |
      | 3 | 7 | 10 |
    @case:887
    Examples:
      | rid | iid | qty |
      | 1 | 5 | 11 |
    @case:888
    Examples:
      | rid | iid | qty |
      | 1 | 6 | 11 |
    @case:889
    Examples:
      | rid | iid | qty |
      | 1 | 7 | 11 |
    @case:890
    Examples:
      | rid | iid | qty |
      | 1 | 8 | 11 |
    @case:891
    Examples:
      | rid | iid | qty |
      | 1 | 9 | 11 |
    @case:892
    Examples:
      | rid | iid | qty |
      | 1 | 10 | 11 |
    @case:893
    Examples:
      | rid | iid | qty |
      | 2 | 1 | 11 |
    @case:894
    Examples:
      | rid | iid | qty |
      | 2 | 2 | 11 |
    @case:895
    Examples:
      | rid | iid | qty |
      | 2 | 8 | 11 |
    @case:896
    Examples:
      | rid | iid | qty |
      | 2 | 9 | 11 |

  Scenario Outline: Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused
    Given a customer with a cart at restaurant 1
    When <qty> of item 3 are added to the cart
    Then the response status is 409

    @case:897
    Examples:
      | qty |
      | 1 |
    @case:898
    Examples:
      | qty |
      | 2 |
    @case:899
    Examples:
      | qty |
      | 3 |
    @case:900
    Examples:
      | qty |
      | 4 |
    @case:901
    Examples:
      | qty |
      | 5 |
    @case:902
    Examples:
      | qty |
      | 6 |
    @case:903
    Examples:
      | qty |
      | 7 |
    @case:904
    Examples:
      | qty |
      | 8 |
    @case:905
    Examples:
      | qty |
      | 9 |
    @case:906
    Examples:
      | qty |
      | 10 |
    @case:907
    Examples:
      | qty |
      | 11 |
    @case:908
    Examples:
      | qty |
      | 12 |
    @case:909
    Examples:
      | qty |
      | 13 |
    @case:910
    Examples:
      | qty |
      | 14 |
    @case:911
    Examples:
      | qty |
      | 15 |
    @case:912
    Examples:
      | qty |
      | 16 |
    @case:913
    Examples:
      | qty |
      | 17 |
    @case:914
    Examples:
      | qty |
      | 18 |
    @case:915
    Examples:
      | qty |
      | 19 |
    @case:916
    Examples:
      | qty |
      | 20 |
    @case:917
    Examples:
      | qty |
      | 21 |
    @case:918
    Examples:
      | qty |
      | 22 |
    @case:919
    Examples:
      | qty |
      | 23 |
    @case:920
    Examples:
      | qty |
      | 24 |
    @case:921
    Examples:
      | qty |
      | 25 |
    @case:922
    Examples:
      | qty |
      | 26 |
    @case:923
    Examples:
      | qty |
      | 27 |
    @case:924
    Examples:
      | qty |
      | 28 |
    @case:925
    Examples:
      | qty |
      | 29 |
    @case:926
    Examples:
      | qty |
      | 30 |
    @case:927
    Examples:
      | qty |
      | 31 |
    @case:928
    Examples:
      | qty |
      | 32 |
    @case:929
    Examples:
      | qty |
      | 33 |
    @case:930
    Examples:
      | qty |
      | 34 |
    @case:931
    Examples:
      | qty |
      | 35 |
    @case:932
    Examples:
      | qty |
      | 36 |
    @case:933
    Examples:
      | qty |
      | 37 |
    @case:934
    Examples:
      | qty |
      | 38 |
    @case:935
    Examples:
      | qty |
      | 39 |
    @case:936
    Examples:
      | qty |
      | 40 |
    @case:937
    Examples:
      | qty |
      | 41 |
    @case:938
    Examples:
      | qty |
      | 42 |
    @case:939
    Examples:
      | qty |
      | 43 |
    @case:940
    Examples:
      | qty |
      | 44 |
    @case:941
    Examples:
      | qty |
      | 45 |
    @case:942
    Examples:
      | qty |
      | 46 |
    @case:943
    Examples:
      | qty |
      | 47 |
    @case:944
    Examples:
      | qty |
      | 48 |
    @case:945
    Examples:
      | qty |
      | 49 |
    @case:946
    Examples:
      | qty |
      | 50 |
    @case:947
    Examples:
      | qty |
      | 51 |
    @case:948
    Examples:
      | qty |
      | 52 |

  Scenario Outline: Adding <qty> of the unavailable item 4 at restaurant 1 is refused
    Given a customer with a cart at restaurant 1
    When <qty> of item 4 are added to the cart
    Then the response status is 409

    @case:949
    Examples:
      | qty |
      | 1 |
    @case:950
    Examples:
      | qty |
      | 2 |
    @case:951
    Examples:
      | qty |
      | 3 |
    @case:952
    Examples:
      | qty |
      | 4 |
    @case:953
    Examples:
      | qty |
      | 5 |
    @case:954
    Examples:
      | qty |
      | 6 |
    @case:955
    Examples:
      | qty |
      | 7 |
    @case:956
    Examples:
      | qty |
      | 8 |
    @case:957
    Examples:
      | qty |
      | 9 |
    @case:958
    Examples:
      | qty |
      | 10 |
    @case:959
    Examples:
      | qty |
      | 11 |
    @case:960
    Examples:
      | qty |
      | 12 |
    @case:961
    Examples:
      | qty |
      | 13 |
    @case:962
    Examples:
      | qty |
      | 14 |
    @case:963
    Examples:
      | qty |
      | 15 |
    @case:964
    Examples:
      | qty |
      | 16 |
    @case:965
    Examples:
      | qty |
      | 17 |
    @case:966
    Examples:
      | qty |
      | 18 |
    @case:967
    Examples:
      | qty |
      | 19 |
    @case:968
    Examples:
      | qty |
      | 20 |
    @case:969
    Examples:
      | qty |
      | 21 |
    @case:970
    Examples:
      | qty |
      | 22 |
    @case:971
    Examples:
      | qty |
      | 23 |
    @case:972
    Examples:
      | qty |
      | 24 |
    @case:973
    Examples:
      | qty |
      | 25 |
    @case:974
    Examples:
      | qty |
      | 26 |
    @case:975
    Examples:
      | qty |
      | 27 |
    @case:976
    Examples:
      | qty |
      | 28 |
    @case:977
    Examples:
      | qty |
      | 29 |
    @case:978
    Examples:
      | qty |
      | 30 |
    @case:979
    Examples:
      | qty |
      | 31 |
    @case:980
    Examples:
      | qty |
      | 32 |
    @case:981
    Examples:
      | qty |
      | 33 |
    @case:982
    Examples:
      | qty |
      | 34 |
    @case:983
    Examples:
      | qty |
      | 35 |
    @case:984
    Examples:
      | qty |
      | 36 |
    @case:985
    Examples:
      | qty |
      | 37 |
    @case:986
    Examples:
      | qty |
      | 38 |
    @case:987
    Examples:
      | qty |
      | 39 |
    @case:988
    Examples:
      | qty |
      | 40 |
    @case:989
    Examples:
      | qty |
      | 41 |
    @case:990
    Examples:
      | qty |
      | 42 |
    @case:991
    Examples:
      | qty |
      | 43 |
    @case:992
    Examples:
      | qty |
      | 44 |
    @case:993
    Examples:
      | qty |
      | 45 |
    @case:994
    Examples:
      | qty |
      | 46 |
    @case:995
    Examples:
      | qty |
      | 47 |
    @case:996
    Examples:
      | qty |
      | 48 |
    @case:997
    Examples:
      | qty |
      | 49 |
    @case:998
    Examples:
      | qty |
      | 50 |
    @case:999
    Examples:
      | qty |
      | 51 |
    @case:1000
    Examples:
      | qty |
      | 52 |
