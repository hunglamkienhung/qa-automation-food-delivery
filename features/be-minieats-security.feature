@module:05-minieats-security @be @api @minieats @security
Feature: The mini-eats authorization surface, probed like an attacker

  The four apps share one API, so the only thing keeping one actor out of
  another's data is the token check on each route. This tier probes those checks
  directly: a request with no token, the wrong actor's token, a forged token, or
  a valid token for a resource that is not yours must be refused -- 401 when the
  caller is not authenticated, 403 when they are authenticated but not allowed.
  The positive controls confirm the legitimate owner still gets through, so a
  refusal is a real gate and not a broken endpoint.

  Background:
    Given the store is open and the service is reachable

  # ---------------------------------------------------------------- the merchant gate (a closed privilege-escalation hole)

  @case:133 @priority:high
  Scenario: Advancing an order requires a merchant token
    Given a placed order of 1 of item 1 at restaurant 1
    When the order is accepted with no token
    Then the response status is 401
    And the response is an error with code "unauthenticated"

  @case:134 @priority:high
  Scenario: A merchant cannot advance an order at a restaurant it does not own
    Given a placed order of 1 of item 1 at restaurant 1
    When a merchant who owns no restaurant accepts the order
    Then the response status is 403
    And the response is an error with code "forbidden"

  @case:135 @priority:high
  Scenario: The owning merchant advances its own order
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant accepts the order
    Then the response status is 200
    And the order in the response reports status "accepted"

  @case:136 @priority:high
  Scenario: A customer token is not accepted as a merchant
    Given a placed order of 1 of item 1 at restaurant 1
    When the customer tries to accept the order
    Then the response status is 401

  @case:137 @priority:high
  Scenario: A driver token is not accepted as a merchant
    Given a placed order of 1 of item 1 at restaurant 1
    When a driver tries to accept the order
    Then the response status is 401

  # ---------------------------------------------------------------- the order board (a closed data-leak hole)

  @case:138 @priority:high
  Scenario: The order board requires authentication
    Given a placed order of 1 of item 1 at restaurant 1
    When the board of restaurant 1 is read with no token
    Then the response status is 401

  @case:139 @priority:high
  Scenario: A merchant cannot read another restaurant's board
    When another merchant reads restaurant 1's board
    Then the response status is 403
    And the response is an error with code "forbidden"

  @case:140 @priority:medium
  Scenario: The admin can read any restaurant's board
    Given a placed order of 1 of item 1 at restaurant 1
    When the admin reads restaurant 1's board
    Then the response status is 200
    And the placed order appears on the restaurant's board

  # ---------------------------------------------------------------- cross-role and forged tokens

  @case:141 @priority:high
  Scenario: The admin overview rejects a non-admin token
    Given a registered customer
    When the admin overview is read with the customer's token
    Then the response status is 401

  @case:142 @priority:high
  Scenario: The driver offers reject a non-driver token
    Given a registered customer
    When the offers are read with the customer's token
    Then the response status is 401

  @case:143 @priority:high
  Scenario: A token that only looks like the admin token is rejected
    When the admin overview is read with a token that extends the admin token
    Then the response status is 401

  @case:144 @priority:high
  Scenario: A forged bearer token is refused on both a customer and a merchant route
    Given a placed order of 1 of item 1 at restaurant 1
    When a cart is opened with a forged token
    Then the response status is 401
    When the order is accepted with a forged token
    Then the response status is 401

  # ---------------------------------------------------------------- onboarding and secret hygiene

  @case:145 @priority:medium
  Scenario: Merchant onboarding is open and issues a token
    When a merchant registers
    Then the response status is 201
    And the response carries a token

  @case:146 @priority:medium
  Scenario: An order response never carries a bearer token
    Given a placed order of 1 of item 1 at restaurant 1
    Then the order response body contains no bearer token
