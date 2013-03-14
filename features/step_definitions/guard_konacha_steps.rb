require 'guard/konacha'

Before do

  #module Guard::UI
    #class << self
      #def info(message, options = {})
      #end
    #end
  #end

  @guard_konacha = Guard::Konacha.new
  @session = double('session', :reset! => true, :visit => true)
  @guard_konacha.runner.stub(:konacha_running?).and_return true
  @guard_konacha.runner.stub(:session).and_return @session

  @konacha_reporter = double('konacha reporter')
  konacha_runner = double('konacha runner',
                          :run => true,
                          :reporter => @konacha_reporter)
  Konacha::Runner.should_receive(:new).any_number_of_times.with(@session).and_return konacha_runner
end

Given(/^I have a failing spec file$/) do
  @spec_file = 'failing_spec.rb'

  @session.should_receive(:evaluate_script).with('typeof window.top.Konacha').and_return 'object'
  @konacha_reporter.stub(:example_count => 1, :failure_count => 1, :pending_count => 0, :duration => 1.2)

  results = @guard_konacha.runner.run [@spec_file]

  results[:examples].should eql 1
  results[:failures].should eql 1
end

When(/^I make the spec file pass$/) do
  @session.should_receive(:evaluate_script).with('typeof window.top.Konacha').and_return 'object'
  @konacha_reporter.stub(:example_count => 1, :failure_count => 0, :pending_count => 0, :duration => 1.2)

  results = @guard_konacha.runner.run [@spec_file]

  results[:examples].should eql 1
  results[:failures].should eql 0
end

Then(/^I want all specs to run$/) do
  pending # express the regexp above with the code you wish you had
end


