Feature: Commit transaction

  Scenario: Commit

     When I begin a transaction
      And I send a commit message
     Then I receive a commit-ok message

  Scenario: Commit already committed tansaction fails

    Given I begin and commit a transaction
     When I send another commit message
     Then I receive a transaction-token-invalid message

  Scenario: Commit invalid transaction fails

     When I send a commit message
     Then I receive a transaction-token-invalid message

  Scenario: Commit rolled back transaction fails

    Given I begin and rollback a transaction
     When I send a commit message
      And I receive a transaction-token-invalid message
