Feature: Transactions

  Scenario: Begin

    When send a begin message
    Then I should receive a begin-ok message with a valid transaction id

  Scenario: Begin twice

    Given that I have begun a transaction
    When I send a begin message
    Then I should receive a begin-ok message with a valid transaction id

  Scenario: Commit

    Given that I have begun a transaction
    When I send a commit message
    Then I should receive a commit-ok message

  Scenario: Commit twice

    Given that I have begun a transaction
    When I send a commit message
    And I send another commit message
    Then I should receive a commit-error message

  Scenario: Rollback

    Given that I have begun a transaction
    When I send a rollback message
    Then I should receive a rollback-ok message

  Scenario: Rollback twice

    Given that I have begun a transaction
    When I Send a rollback message
    And I send another rollback message
    Then I should receive a rollback-error message

  Scenario: Commit then rollback

    Given that I have begun a transaction
    When I Send a commit message
    And I send a rollback message
    Then I should receive a rollback-error message

  Scenario: Rollback then commit

    Given that I have begun a transaction
    When I Send a rollback message
    And I send a commit message
    Then I should receive a commit-error message

