require 'guard/konacha'

module ::Guard::UI
  class << self
    def info(message, options = {})
    end
  end
end

Before do
  @guard_konacha = prepare_guard_konacha
end

Given(/^I have a failing spec file$/) do
  @spec_file = 'failing_spec.rb'

  spec_file_exists
  konacha_run_results :failure_count => 1
  run_spec @spec_file
end

When(/^I make the spec file pass$/) do
  spec_file_exists
  konacha_run_results
  run_spec @spec_file
end

Then(/^I want all specs to run$/) do
  should have_run_all_tests
end

Given(/^I have a passing spec file$/) do
  @spec_file = 'passing_spec.rb'

  spec_file_exists
  konacha_run_results
  run_spec @spec_file
end

When(/^I save a tracked file without a matching spec file$/) do
  konacha_run_results :example_count => 0
  run_spec 'something/somewhere.css'
end

Then(/^nothing happens$/) do
  # first run is the passing spec file
  # second run is the file without spec
  @guard_konacha.runner.run_calls.should have(2).calls
end

Then(/^the failing spec file is rerun$/) do
  pending # express the regexp above with the code you wish you had
end

