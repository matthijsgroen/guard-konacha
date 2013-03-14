require 'guard/konacha'

Before do

  module Guard::UI
    class << self
      def info(message, options = {})
      end
    end
  end

  @guard_konacha = Guard::Konacha.new
end

Given(/^I have a failing spec file$/) do
  @guard_konacha.runner.stub(:session).and_return(
    double('session',
           :reset! => true,
           :visit => true,
           :evaluate_script => 'object'
          )
  )
  @guard_konacha.runner.run [
    'failing_spec.rb'
  ]
  pending
end

When(/^I make the spec file pass$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^I want all specs to run$/) do
  pending # express the regexp above with the code you wish you had
end


