Feature: Insertions

  Scenario: Insert a row

    Given I have begun a transaction
     When I send an update message containing:
        | key       | rev | value                    |
        | row, name |     | name: name, value: value |
     Then I should receive an update-ok message
      And the following rows should exist:
        | key       | value                    |
        | row, name | name: name, value: value |
