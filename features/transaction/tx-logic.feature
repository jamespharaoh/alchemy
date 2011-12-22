
Feature: Transaction logic

  Scenario: Begin

     When I send a begin message
     Then I receive a begin-ok message

  Scenario: Begin twice

     When I send a begin message
      And I send another begin message
     Then I receive a begin-ok message
      And I receive a begin-ok message

  Scenario: Commit

     When I begin a transaction
      And I send a commit message
     Then I receive a commit-ok message

  Scenario: Commit twice

     When I begin a transaction
      And I send a commit message
      And I send another commit message
     Then I receive a commit-ok message
      And I receive a transaction-token-invalid message

  Scenario: Commit invalid

     When I send a commit message
     Then I receive a transaction-token-invalid message

  Scenario: Rollback

     When I begin a transaction
      And I send a rollback message
     Then I receive a rollback-ok message

  Scenario: Rollback twice

     When I begin a transaction
      And I send a rollback message
      And I send another rollback message
     Then I receive a rollback-ok message
      And I receive a transaction-token-invalid message

  Scenario: Rollback invalid

     When I send a rollback message
     Then I receive a transaction-token-invalid message

  Scenario: Commit then rollback

     When I begin a transaction
      And I send a commit message
      And I send a rollback message
     Then I receive a commit-ok message
      And I receive a transaction-token-invalid message

  Scenario: Rollback then commit

     When I begin a transaction
      And I send a rollback message
      And I send a commit message
     Then I receive a rollback-ok message
      And I receive a transaction-token-invalid message

  Scenario: Update with invalid transaction

     When I send an update message containing:
        | key | rev | value |
     Then I receive a transaction-token-invalid message

  Scenario: Update with committed transaction

    Given I begin and commit a transaction
     When I send an update message containing:
        | key | rev | value |
     Then I receive a transaction-token-invalid message

  Scenario: Update with rolled back transaction

    Given I begin and rollback a transaction
     When I send an update message containing:
        | key | rev | value |
     Then I receive a transaction-token-invalid message
