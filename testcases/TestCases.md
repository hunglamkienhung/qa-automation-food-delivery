# Food delivery — test cases

146 cases across a self-written mini-eats service (a real SQLite store behind the customer, merchant, driver and admin apps) and the live TheMealDB API. Generated from `../features/*.feature` by `build.js`; do not edit by hand.

## minieats-db (33)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 1 | BE/DB | High | The store has the documented tables |
| 2 | BE/DB | High | A menu item name is unique within its restaurant |
| 3 | BE/DB | High | Order lines reference a real order and a real menu item |
| 4 | BE/DB | High | Amounts and quantities are bounded by CHECK |
| 5 | BE/DB | High | An order status is one of the lifecycle states |
| 6 | BE/DB | High | An order event names a known actor |
| 7 | BE/DB | Medium | A ledger entry is a real, non-zero amount with a known reason and party |
| 8 | BE/DB | Medium | A driver status is one of the known states |
| 9 | BE/DB | Medium | The commission rate is a fraction between nothing and everything |
| 10 | BE/DB | Medium | Seeding twice leaves the same rows |
| 11 | BE/DB | High | A checkout creates an order whose total is its subtotal plus the delivery fee |
| 12 | BE/DB | High | Order lines capture the price at order time |
| 13 | BE/DB | High | Checkout decrements stock by the ordered quantity |
| 14 | BE/DB | High | An oversell is refused and leaves the store untouched |
| 15 | BE/DB | Medium | An empty cart cannot be checked out |
| 16 | BE/DB | Medium | A checked-out cart is marked ordered |
| 17 | BE/DB | Medium | The order belongs to the customer who placed it |
| 18 | BE/DB | Medium | One order line per distinct cart line |
| 19 | BE/DB | High | Placing an order writes the opening event |
| 20 | BE/DB | High | Accepting an order records the transition and moves the status |
| 21 | BE/DB | High | Rejecting a placed order restocks it and records the transition |
| 22 | BE/DB | High | Cancelling a placed order restocks it and records the transition |
| 23 | BE/DB | High | A full lifecycle writes an event for every transition |
| 24 | BE/DB | High | On delivery the restaurant is paid its subtotal less commission |
| 25 | BE/DB | High | On delivery the driver is paid the delivery fee and the platform takes the commission |
| 26 | BE/DB | High | The delivery ledger sums to the order total |
| 27 | BE/DB | Medium | An undelivered order has posted nothing to the ledger |
| 28 | BE/DB | High | A repeated checkout with the same idempotency key makes one order |
| 29 | BE/DB | Medium | No order line references a missing menu item |
| 30 | BE/DB | Medium | No order references a missing customer or restaurant |
| 31 | BE/DB | Medium | Checkout of <label> decrements its stock and captures its price |
| 32 | BE/DB | Medium | Checkout of <label> decrements its stock and captures its price |
| 33 | BE/DB | Medium | Checkout of <label> decrements its stock and captures its price |

## minieats-api (48)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 34 | BE/API | High | /restaurants lists the active restaurants only |
| 35 | BE/API | High | /restaurants/:id/menu matches the rows, priced from them |
| 36 | BE/API | Medium | The menu marks an out-of-stock item and an unavailable item as unavailable |
| 37 | BE/API | Medium | /restaurants/:id hides an inactive restaurant and 404s the unknown |
| 38 | BE/API | High | Opening a cart requires a customer token |
| 39 | BE/API | High | A cart cannot be opened at a closed restaurant |
| 40 | BE/API | High | Adding an item reflects the row and the line total |
| 41 | BE/API | Medium | Adding the same item twice merges into one line |
| 42 | BE/API | High | A quantity beyond stock is refused |
| 43 | BE/API | Medium | An item from another restaurant cannot be added |
| 44 | BE/API | Medium | An out-of-stock item cannot be added |
| 45 | BE/API | Medium | An unavailable item cannot be added |
| 46 | BE/API | Low | A non-positive quantity is rejected |
| 47 | BE/API | Low | An unknown cart is 404 |
| 48 | BE/API | High | Checkout requires a customer token |
| 49 | BE/API | High | A checkout returns an order equal to the stored order |
| 50 | BE/API | High | The order total in the response is its subtotal plus the delivery fee |
| 51 | BE/API | Medium | An empty cart cannot be checked out |
| 52 | BE/API | High | A tracked order carries its lifecycle events |
| 53 | BE/API | Medium | A retried checkout with the same idempotency key returns the same order |
| 54 | BE/API | Low | An unknown order is 404 |
| 55 | BE/API | High | A merchant advances a placed order through to ready |
| 56 | BE/API | High | A merchant cannot accept an order that is not placed |
| 57 | BE/API | High | A merchant cannot prepare an order that was never accepted |
| 58 | BE/API | High | A merchant rejects a placed order |
| 59 | BE/API | High | A customer can cancel a placed order but not one already accepted |
| 60 | BE/API | High | A customer cannot cancel once the merchant has accepted |
| 61 | BE/API | High | A customer cannot cancel another customer's order |
| 62 | BE/API | High | A ready order is offered to drivers; an unready one is not |
| 63 | BE/API | High | Reading the offers requires a driver token |
| 64 | BE/API | High | A driver assigns, picks up and delivers a ready order |
| 65 | BE/API | High | An order cannot be assigned to a second driver |
| 66 | BE/API | High | Only the assigned driver may pick up the order |
| 67 | BE/API | High | A ready order cannot be delivered before it is picked up |
| 68 | BE/API | Medium | An order cannot be assigned before it is ready |
| 69 | BE/API | Medium | A merchant sees its own restaurant's orders |
| 70 | BE/API | Medium | A merchant can filter its board by status |
| 71 | BE/API | High | The admin overview requires the admin token |
| 72 | BE/API | High | The admin overview counts a delivered order and its revenue |
| 73 | BE/API | High | The admin overview's money balances -- revenue equals payouts plus commission plus fees |
| 74 | BE/API | Medium | The admin can list orders and filter them by status |
| 75 | BE/API | High | The admin deactivates a restaurant and it disappears from the customer list |
| 76 | BE/API | Low | Deactivating an unknown restaurant is 404 |
| 77 | BE/API | Medium | A consistent error shape and a 404 for unknown routes |
| 78 | BE/API | Low | The health endpoint reports the seeded restaurant count |
| 79 | BE/API | Medium | An order at restaurant <rid> can be driven to delivered |
| 80 | BE/API | Medium | An order at restaurant <rid> can be driven to delivered |
| 81 | BE/API | Medium | An order at restaurant <rid> can be driven to delivered |

## mealdb-api (25)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 82 | BE/API | High | The category list answers and is non-empty |
| 83 | BE/API | High | Every category has an id and a name |
| 84 | BE/API | High | Every category id is unique |
| 85 | BE/API | Medium | Every category name is non-empty when trimmed |
| 86 | BE/API | Medium | Every category thumbnail is an http(s) URL |
| 87 | BE/API | Low | The categories are stable across two reads |
| 88 | BE/API | High | Filtering by a category returns a non-empty list |
| 89 | BE/API | High | Every filtered meal has an id, a name and a thumbnail |
| 90 | BE/API | Medium | No filtered meal id repeats |
| 91 | BE/API | Medium | Every filtered meal id is a positive integer |
| 92 | BE/API | Low | Every filtered meal thumbnail is an http(s) URL |
| 93 | BE/API | Medium | Filtering by "<cat>" returns a non-empty list of real meals |
| 94 | BE/API | Medium | Filtering by "<cat>" returns a non-empty list of real meals |
| 95 | BE/API | Medium | Filtering by "<cat>" returns a non-empty list of real meals |
| 96 | BE/API | High | Looking up a meal by id returns that meal |
| 97 | BE/API | High | A looked-up meal carries instructions, a category and an area |
| 98 | BE/API | Medium | A looked-up meal lists at least one ingredient |
| 99 | BE/API | Medium | An unknown meal id returns no meal |
| 100 | BE/API | High | Searching by name returns the named meal |
| 101 | BE/API | Medium | A search that matches nothing returns no meals |
| 102 | BE/API | Medium | Searching by first letter returns meals that start with it |
| 103 | BE/API | Low | A common ingredient name search returns at least one meal |
| 104 | BE/API | Medium | A filtered meal, looked up, reports the same category |
| 105 | BE/API | Medium | The category-name list agrees with the categories endpoint |
| 106 | BE/API | Low | The area list is non-empty |

## minieats-fe (26)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 107 | FE/UI | High | The home page lists exactly the active restaurants |
| 108 | FE/UI | High | The inactive restaurant does not appear on the home page |
| 109 | FE/UI | Medium | Each home row links to its restaurant page |
| 110 | FE/UI | Low | The home page is not empty |
| 111 | FE/UI | High | A menu shows each item's price from its row |
| 112 | FE/UI | High | The out-of-stock item is shown unavailable |
| 113 | FE/UI | Medium | An in-stock item is shown available |
| 114 | FE/UI | Medium | Every menu price on screen is a dollar amount |
| 115 | FE/UI | Medium | Each menu name matches its item row |
| 116 | FE/UI | Medium | An unknown restaurant page is not found |
| 117 | FE/UI | Medium | The menu for restaurant <rid> is non-empty and priced from the rows |
| 118 | FE/UI | Medium | The menu for restaurant <rid> is non-empty and priced from the rows |
| 119 | FE/UI | Medium | The menu for restaurant <rid> is non-empty and priced from the rows |
| 120 | FE/UI | High | An order page shows the total the order was placed at |
| 121 | FE/UI | Medium | An order page shows the order id and its status |
| 122 | FE/UI | Medium | The order page total is a dollar amount |
| 123 | FE/UI | Low | An unknown order page is not found |
| 124 | FE/UI | High | A delivered order shows a delivered status on its page |
| 125 | FE/UI | High | A placed order appears on its restaurant's merchant board |
| 126 | FE/UI | Medium | Every order on the merchant board shows a dollar total |
| 127 | FE/UI | High | A ready order is offered on the driver board with its fee |
| 128 | FE/UI | Medium | The driver board offer count matches the API |
| 129 | FE/UI | Low | Every offered delivery fee is a dollar amount |
| 130 | FE/UI | High | The admin page shows the revenue as a dollar amount |
| 131 | FE/UI | High | The admin page counts a delivered order |
| 132 | FE/UI | Medium | Every admin status count is a non-negative integer |

## minieats-security (14)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 133 | BE/API | High | Advancing an order requires a merchant token |
| 134 | BE/API | High | A merchant cannot advance an order at a restaurant it does not own |
| 135 | BE/API | High | The owning merchant advances its own order |
| 136 | BE/API | High | A customer token is not accepted as a merchant |
| 137 | BE/API | High | A driver token is not accepted as a merchant |
| 138 | BE/API | High | The order board requires authentication |
| 139 | BE/API | High | A merchant cannot read another restaurant's board |
| 140 | BE/API | Medium | The admin can read any restaurant's board |
| 141 | BE/API | High | The admin overview rejects a non-admin token |
| 142 | BE/API | High | The driver offers reject a non-driver token |
| 143 | BE/API | High | A token that only looks like the admin token is rejected |
| 144 | BE/API | High | A forged bearer token is refused on both a customer and a merchant route |
| 145 | BE/API | Medium | Merchant onboarding is open and issues a token |
| 146 | BE/API | Medium | An order response never carries a bearer token |
