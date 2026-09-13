@module:03-mealdb-api @be @api @mealdb
Feature: TheMealDB's public API, read-only

  HTTPS against themealdb.com's free JSON API. No key, no browser. It is a live
  third party -- a recipe catalogue -- so these scenarios assert its own
  invariants: categories have ids and names, a lookup returns the meal you asked
  for, a filter's meals are real. A meal a restaurant might cook is the live
  counterpart of the mini-eats menu.

  On a transport failure -- the API unreachable, timing out, or serving a
  challenge page -- these scenarios report Blocked, never Failed: the catalogue
  being unreachable is not the catalogue being wrong.

  # ---------------------------------------------------------------- categories

  @case:82 @priority:high
  Scenario: The category list answers and is non-empty
    When the meal categories are fetched
    Then there are at least 5 categories

  @case:83 @priority:high
  Scenario: Every category has an id and a name
    When the meal categories are fetched
    Then every category has an id and a name

  @case:84 @priority:high
  Scenario: Every category id is unique
    When the meal categories are fetched
    Then no category id appears more than once

  @case:85 @priority:medium
  Scenario: Every category name is non-empty when trimmed
    When the meal categories are fetched
    Then every category name is non-empty when trimmed

  @case:86 @priority:medium
  Scenario: Every category thumbnail is an http(s) URL
    When the meal categories are fetched
    Then every category thumbnail is an http URL

  @case:87 @priority:low
  Scenario: The categories are stable across two reads
    When the meal categories are fetched
    And the meal categories are fetched again
    Then both category reads return the same ids

  # ---------------------------------------------------------------- filter by category

  @case:88 @priority:high
  Scenario: Filtering by a category returns a non-empty list
    When meals are filtered by category "Seafood"
    Then the filtered meals are non-empty

  @case:89 @priority:high
  Scenario: Every filtered meal has an id, a name and a thumbnail
    When meals are filtered by category "Seafood"
    Then every filtered meal has an id, a name and a thumbnail

  @case:90 @priority:medium
  Scenario: No filtered meal id repeats
    When meals are filtered by category "Vegetarian"
    Then no filtered meal id appears more than once

  @case:91 @priority:medium
  Scenario: Every filtered meal id is a positive integer
    When meals are filtered by category "Dessert"
    Then every filtered meal id is a positive integer

  @case:92 @priority:low
  Scenario: Every filtered meal thumbnail is an http(s) URL
    When meals are filtered by category "Seafood"
    Then every filtered meal thumbnail is an http URL

  Scenario Outline: Filtering by "<cat>" returns a non-empty list of real meals
    When meals are filtered by category "<cat>"
    Then the filtered meals are non-empty
    And every filtered meal has an id, a name and a thumbnail

    @case:93
    Examples:
      | cat |
      | Beef |
    @case:94
    Examples:
      | cat |
      | Chicken |
    @case:95
    Examples:
      | cat |
      | Pasta |

  # ---------------------------------------------------------------- lookup

  @case:96 @priority:high
  Scenario: Looking up a meal by id returns that meal
    When the meal with id 52772 is looked up
    Then the looked-up meal has id 52772

  @case:97 @priority:high
  Scenario: A looked-up meal carries instructions, a category and an area
    When the meal with id 52772 is looked up
    Then the looked-up meal has instructions, a category and an area

  @case:98 @priority:medium
  Scenario: A looked-up meal lists at least one ingredient
    When the meal with id 52772 is looked up
    Then the looked-up meal lists at least one ingredient

  @case:99 @priority:medium
  Scenario: An unknown meal id returns no meal
    When the meal with id 99999999 is looked up
    Then no meal is returned

  # ---------------------------------------------------------------- search

  @case:100 @priority:high
  Scenario: Searching by name returns the named meal
    When meals are searched by name "Arrabiata"
    Then a meal named "Spicy Arrabiata Penne" is returned

  @case:101 @priority:medium
  Scenario: A search that matches nothing returns no meals
    When meals are searched by name "zzqqxx-no-such-meal"
    Then no meal is returned

  @case:102 @priority:medium
  Scenario: Searching by first letter returns meals that start with it
    When meals are searched by first letter "b"
    Then every returned meal name starts with "b"

  @case:103 @priority:low
  Scenario: A common ingredient name search returns at least one meal
    When meals are searched by name "chicken"
    Then at least one meal is returned

  # ---------------------------------------------------------------- consistency

  @case:104 @priority:medium
  Scenario: A filtered meal, looked up, reports the same category
    When meals are filtered by category "Seafood"
    And the first filtered meal is looked up
    Then the looked-up meal reports category "Seafood"

  @case:105 @priority:medium
  Scenario: The category-name list agrees with the categories endpoint
    When the meal category names are listed
    And the meal categories are fetched
    Then every listed category name is a known category

  @case:106 @priority:low
  Scenario: The area list is non-empty
    When the meal areas are listed
    Then the area list is non-empty
