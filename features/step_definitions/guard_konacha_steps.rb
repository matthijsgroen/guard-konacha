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


