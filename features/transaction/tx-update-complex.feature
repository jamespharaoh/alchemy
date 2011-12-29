Feature: Complex updates

  Background:

    Given the following rows:
        | key  | out | value   |
        | a    | a1  | val: a1 |
        | b    | b1  | val: b2 |

  Scenario: Same transaction

     When I begin a transaction
      And I perform the following updates:
        | key | in | value   |
        | a   | a1 | val: a2 |
        | b   | b1 |         |
        | c   |    | val: c2 |
     Then the following rows should exist:
        | key | value   |
        | a   | val: a2 |
        | b   |         |
        | c   | val: c2 |

  Scenario: Different transaction

     When I begin a transaction
      And I perform the following updates:
        | key | in | value   |
        | a   | a1 | val: a2 |
        | b   | b1 |         |
        | c   |    | val: c2 |
      And I commit the transaction
      And I begin another transaction
     Then the following rows should exist:
        | key | value   |
        | a   | val: a2 |
        | b   |         |
        | c   | val: c2 |
