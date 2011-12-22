Feature: Update data

  Scenario: Update invalid transaction fails

     When I send an update message
     Then I receive a transaction-token-invalid message

  Scenario: Update committed transaction fails

    Given I begin and commit a transaction
     When I send an update message
     Then I receive a transaction-token-invalid message

  Scenario: Update rolled back transaction fails

    Given I begin and rollback a transaction
     When I send an update message
     Then I receive a transaction-token-invalid message
