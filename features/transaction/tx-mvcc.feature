Feature: Multiple version concurrency control

  Scenario: Data from transaction committed before our begin is visible

     When I begin a transaction
      And I perform the following updates:
        | key | value   |
        | a   | val: a1 |
      And I commit the transaction
      And I begin another transaction
     Then the following rows exist:
        | key | value   |
        | a   | val: a1 |

  @wip
  Scenario: Data from transaction committed after our begin is not visible

     When I begin a transaction
      And I begin another transaction
      And I perform the following updates:
        | key | value   |
        | a   | val: a1 |
      And I commit the transaction
      And I return to the first transaction
     Then the following rows exist:
        | key | value |
        | a   |       |
