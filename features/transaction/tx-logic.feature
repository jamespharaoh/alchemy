
Feature: Transaction logic

  Scenario: Begin

    When I send a begin message
    Then I should receive a begin-ok message

  Scenario: Begin twice

    When I send a begin message
     And I send another begin message
    Then I should receive a begin-ok message
     And I should receive a begin-ok message

  Scenario: Commit

    Given I have begun a transaction
     When I send a commit message
     Then I should receive a commit-ok message

  Scenario: Commit twice

    Given I have begun a transaction
     When I send a commit message
      And I send another commit message
     Then I should receive a commit-ok message
      And I should receive a transaction-token-invalid message

  Scenario: Commit invalid

    Given I have not begun a transaction
     When I send a commit message
     Then I should receive a transaction-token-invalid message

  Scenario: Rollback

    Given I have begun a transaction
     When I send a rollback message
     Then I should receive a rollback-ok message

  Scenario: Rollback twice

    Given I have begun a transaction
     When I send a rollback message
      And I send another rollback message
     Then I should receive a rollback-ok message
      And I should receive a transaction-token-invalid message

  Scenario: Rollback invalid

    Given I have not begun a transaction
     When I send a rollback message
     Then I should receive a transaction-token-invalid message

  Scenario: Commit then rollback

    Given I have begun a transaction
     When I send a commit message
      And I send a rollback message
     Then I should receive a commit-ok message
      And I should receive a transaction-token-invalid message

  Scenario: Rollback then commit

    Given I have begun a transaction
     When I send a rollback message
      And I send a commit message
     Then I should receive a rollback-ok message
      And I should receive a transaction-token-invalid message
