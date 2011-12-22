Feature: Begin transaction

  Scenario: Begin

     When I send a begin message
     Then I receive a begin-ok message

  Scenario: Begin multiple times

     When I send a begin message
      And I send another begin message
     Then I receive a begin-ok message
      And I receive a begin-ok message
