module GuardKonachaSpecHelpers

  def prepare_guard_konacha
    guard_konacha = Guard::Konacha.new :host => 'lh', :port => 3500
    @session = double('Capybara Session', :reset! => true, :visit => true)
    guard_konacha.runner.stub({
      :konacha_running? => true,
      :session => @session,
      :run => default_result
    })

    @konacha_reporter = double('konacha reporter')
    konacha_runner = double('konacha runner', {
      :run => true,
      :reporter => @konacha_reporter
    })
    Konacha::Runner.should_receive(:new).any_number_of_times.with(@session).and_return konacha_runner

    @run_all = 0
    guard_konacha.runner.stub(:run).with(no_args()) do
      @run_all += 1
    end
    guard_konacha
  end

  def spec_file_exists
    @session.should_receive(:evaluate_script).any_number_of_times.with('typeof window.top.Konacha').and_return 'object'
  end

  def default_result
    {
      :example_count => 1,
      :failure_count => 0,
      :pending_count => 0,
      :duration => 1.2
    }
  end

  def konacha_run_results results = {}
    stub_values = default_result.merge results
    @konacha_reporter.stub stub_values
  end

  def run_spec filename
    @guard_konacha.runner.run [filename]
  end

  def has_run_all_tests?
    @run_all.should be > 0
  end

end
World(GuardKonachaSpecHelpers)
