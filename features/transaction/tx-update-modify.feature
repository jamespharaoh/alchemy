Feature: Modify an existing row

  Scenario: Updates are visible in same transaction

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |

     When I begin a transaction

      And I perform the following updates:
        | key       | in | value                  |
        | row, name | a  | name: name, value: new |

     Then the following rows should exist:
        | key       | value                  |
        | row, name | name: name, value: new |

  Scenario: Updates are visible in subsequent transaction

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |

     When I begin a transaction

      And I perform the following updates:
        | key       | in | value                  |
        | row, name | a  | name: name, value: new |

      And I commit the transaction

      And I begin another transaction

     Then the following rows should exist:
        | key       | value                  |
        | row, name | name: name, value: new |

  Scenario: Modify row twice in transaction

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |

     When I begin a transaction

      And I perform the following updates:
        | key       | in | out | value                    |
        | row, name | a  | b   | name: name, value: value |

      And I send an update message containing:
        | key       | in  | value                    |
        | row, name | b   | name: name, value: value |

     Then I receive an update-ok message

  Scenario: Modify row twice in transaction with same rev fails

    Given the following rows:
        | key       | out | value                  |
        | row, name | a   | name: name, value: old |

     When I begin a transaction

      And I perform the following updates:
        | key       | in | value                    |
        | row, name | a  | name: name, value: value |

      And I send an update message containing:
        | key       | in | value                    |
        | row, name | a  | name: name, value: value |

     Then I receive an update-error message

  Scenario: Modify existing row fails if updated in other transaction

    Given the following rows:
        | key       | out | value                    |
        | row, name | a   | name: name, value: value |

      And I begin a transaction

      And I perform the following updates:
        | key       | in | value                    |
        | row, name | a  | name: name, value: value |

      And I commit the transaction

     When I begin a transaction

      And I send an update message containing:
        | key       | in | value                    |
        | row, name | a  | name: name, value: value |

     Then I receive an update-error message
