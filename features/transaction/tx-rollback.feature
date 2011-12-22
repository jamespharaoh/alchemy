Feature: Rollback transaction

  Scenario: Rollback transaction

     When I begin a transaction
      And I send a rollback message
     Then I receive a rollback-ok message

  Scenario: Rollback already committed transaction fails

    Given I begin and rollback a transaction
     When I send another rollback message
     Then I receive a transaction-token-invalid message

  Scenario: Rollback invalid transaction fails

     When I send a rollback message
     Then I receive a transaction-token-invalid message

  Scenario: Rollback committed transaction fails

    Given I begin and commit a transaction
     When I send a rollback message
      And I receive a transaction-token-invalid message
