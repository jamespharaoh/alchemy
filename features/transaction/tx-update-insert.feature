Feature: Update data by inserting new rows

  Scenario: Insert a row, can read back in same transaction

     When I begin a transaction
      And I send an update message containing:
        | key       | rev | value                    |
        | row, name |     | name: name, value: value |
     Then I receive an update-ok message
      And the following rows exist:
        | key       | value                    |
        | row, name | name: name, value: value |

  Scenario: Insert a row fails if already exists in transaction

     When I begin a transaction
      And I send an update message containing:
        | key       | rev | value                    |
        | row, name |     | name: name, value: value |
      And I send an update message containing:
        | key       | rev | value                    |
        | row, name |     | name: name, value: value |
     Then I receive an update-ok message
      And I receive an update-error message

  Scenario: Insert a row fails if already exists

    Given the following rows:
        | key       | rev | value                    |
        | row, name |     | name: name, value: value |
     When I begin a transaction
      And I send an update message containing:
        | key       | rev | value                    |
        | row, name |     | name: name, value: value |
     Then I receive an update-error message
