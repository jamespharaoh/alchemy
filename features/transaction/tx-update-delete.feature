Feature: Modify an existing row

  Scenario: Delete is visible in same transaction

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |
     When I begin a transaction
      And I perform the following updates:
        | key       | in | value |
        | row, name | a  |       |
     Then the following rows should exist:
        | key       | value |
        | row, name |       |

  Scenario: Delete is visible in subsequent transaction

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |
     When I begin a transaction
      And I perform the following updates:
        | key       | in | value |
        | row, name | a  |       |
      And I commit the transaction
      And I begin another transaction
     Then the following rows should exist:
        | key       | value |
        | row, name |       |

  Scenario: Delete row twice in same transaction fails

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |
     When I begin a transaction
      And I perform the following updates:
        | key       | in | value |
        | row, name | a  |       |
     Then I send an update message containing:
        | key       | in  | value |
        | row, name | a   |       |
     Then I receive an update-error message

  Scenario: Delete row twice in subsequent transaction fails

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |
     When I begin a transaction
      And I perform the following updates:
        | key       | in | value |
        | row, name | a  |       |
      And I commit the transaction
      And I begin another transaction
      And I send an update message containing:
        | key       | in  | value |
        | row, name | a   |       |
     Then I receive an update-error message
