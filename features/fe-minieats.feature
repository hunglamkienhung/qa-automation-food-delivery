@module:04-minieats-fe @fe @minieats
Feature: The mini-eats app surfaces, checked against their own data

  Playwright drives the four app surfaces the mini-eats service renders -- the
  customer's home and restaurant menu, the order tracker, the merchant board,
  the driver board and the admin overview. The figures on screen are compared
  with the rows behind them, read through the DB the FE never touches directly,
  so the FE branch checks the same invariants the BE branch does, one layer
  further out. A page that never loads is Blocked, never Failed.

  Background:
    Given the store is open and the service is reachable
    And the home page is open

  # ---------------------------------------------------------------- customer: home

  @case:107 @priority:high
  Scenario: The home page lists exactly the active restaurants
    Then the home page lists the active restaurants, once each

  @case:108 @priority:high
  Scenario: The inactive restaurant does not appear on the home page
    Then the home page does not list restaurant 4

  @case:109 @priority:medium
  Scenario: Each home row links to its restaurant page
    Then each home row links to its restaurant page

  @case:110 @priority:low
  Scenario: The home page is not empty
    Then the home page shows at least one restaurant

  # ---------------------------------------------------------------- customer: menu

  @case:111 @priority:high
  Scenario: A menu shows each item's price from its row
    When the menu for restaurant 1 is opened
    Then every menu price on screen equals the item row

  @case:112 @priority:high
  Scenario: The out-of-stock item is shown unavailable
    When the menu for restaurant 1 is opened
    Then menu item 3 is shown unavailable

  @case:113 @priority:medium
  Scenario: An in-stock item is shown available
    When the menu for restaurant 1 is opened
    Then menu item 1 is shown available

  @case:114 @priority:medium
  Scenario: Every menu price on screen is a dollar amount
    When the menu for restaurant 2 is opened
    Then every menu price on screen is a dollar amount

  @case:115 @priority:medium
  Scenario: Each menu name matches its item row
    When the menu for restaurant 3 is opened
    Then every menu name on screen equals the item row

  @case:116 @priority:medium
  Scenario: An unknown restaurant page is not found
    When the menu for restaurant 999 is opened
    Then the page reports not found

  Scenario Outline: The menu for restaurant <rid> is non-empty and priced from the rows
    When the menu for restaurant <rid> is opened
    Then every menu price on screen equals the item row

    @case:117
    Examples:
      | rid |
      | 1 |
    @case:118
    Examples:
      | rid |
      | 2 |
    @case:119
    Examples:
      | rid |
      | 3 |

  # ---------------------------------------------------------------- customer: order tracker

  @case:120 @priority:high
  Scenario: An order page shows the total the order was placed at
    Given a placed order of 2 of item 1 at restaurant 1
    When the order page is opened
    Then the order page total equals the stored order total

  @case:121 @priority:medium
  Scenario: An order page shows the order id and its status
    Given a placed order of 1 of item 1 at restaurant 1
    When the order page is opened
    Then the order page shows the order id and status "placed"

  @case:122 @priority:medium
  Scenario: The order page total is a dollar amount
    Given a placed order of 1 of item 5 at restaurant 2
    When the order page is opened
    Then the order page total is shown as a dollar amount

  @case:123 @priority:low
  Scenario: An unknown order page is not found
    When the order page for 999999 is opened
    Then the page reports not found

  @case:124 @priority:high
  Scenario: A delivered order shows a delivered status on its page
    Given a delivered order of 1 of item 8 at restaurant 3
    When the order page is opened
    Then the order page shows status "delivered"

  # ---------------------------------------------------------------- merchant board

  @case:125 @priority:high
  Scenario: A placed order appears on its restaurant's merchant board
    Given a placed order of 1 of item 1 at restaurant 1
    When the merchant board for restaurant 1 is opened
    Then the placed order appears on the merchant board with status "placed"

  @case:126 @priority:medium
  Scenario: Every order on the merchant board shows a dollar total
    Given a placed order of 1 of item 2 at restaurant 1
    When the merchant board for restaurant 1 is opened
    Then every order total on the board is a dollar amount

  # ---------------------------------------------------------------- driver board

  @case:127 @priority:high
  Scenario: A ready order is offered on the driver board with its fee
    Given a ready order of 1 of item 1 at restaurant 1
    When the driver board is opened
    Then the ready order is offered on the driver board

  @case:128 @priority:medium
  Scenario: The driver board offer count matches the API
    Given a ready order of 1 of item 5 at restaurant 2
    When the driver board is opened
    Then the driver board offer count equals the API offer count

  @case:129 @priority:low
  Scenario: Every offered delivery fee is a dollar amount
    Given a ready order of 1 of item 8 at restaurant 3
    When the driver board is opened
    Then every offered fee on the board is a dollar amount

  # ---------------------------------------------------------------- admin overview

  @case:130 @priority:high
  Scenario: The admin page shows the revenue as a dollar amount
    When the admin page is opened
    Then the admin revenue is shown as a dollar amount

  @case:131 @priority:high
  Scenario: The admin page counts a delivered order
    Given a delivered order of 1 of item 1 at restaurant 1
    When the admin page is opened
    Then the admin page shows at least one delivered order

  @case:132 @priority:medium
  Scenario: Every admin status count is a non-negative integer
    When the admin page is opened
    Then every admin status count is a non-negative integer
