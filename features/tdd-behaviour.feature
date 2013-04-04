Feature:
  As a developer I want Guard to anticipate my TDD workflow
  so that I can do my work more efficiently

  Scenario: Completing a failing spec
    Given I have a failing spec file
    When I make the spec file pass
    Then I want all specs to run

  Scenario: Saving a file after passing spec
    Given I have a passing spec file
    When I save a tracked file without a matching spec file
    Then nothing happens

  Scenario: Saving a file after a failing spec
    Given I have a failing spec file
    When I save a tracked file without a matching spec file
    Then the failing spec file is rerun

  Scenario: Saving a passing file after a failing spec
    Given I have a failing spec file
    When I make a different spec file pass
    Then I do not want all specs to run


