module GuardKonachaSpecHelpers

  def prepare_guard_konacha
    guard_konacha = Guard::Konacha.new :host => 'lh', :port => 3500
    @session = double('Capybara Session', :reset! => true, :visit => true)
    guard_konacha.runner.stub({
      :konacha_running? => true,
      :session => @session
    })

    @konacha_reporter = double('konacha reporter')
    konacha_runner = double('konacha runner', {
      :run => true,
      :reporter => @konacha_reporter
    })
    Konacha::Runner.should_receive(:new).any_number_of_times.with(@session).and_return konacha_runner

    @spec_exists = true
    @session.stub(:evaluate_script) do |arg|
      if arg == 'typeof window.top.Konacha'
        @spec_exists ? 'object' : 'undefined'
      end
    end
    guard_konacha
  end

  def spec_file_exists
    @spec_exists = true
  end

  def spec_file_is_missing
    @spec_exists = false
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
    @guard_konacha.runner.run_calls.select do |call|
      return true if call[:arguments] == []
    end
    false
  end

  def has_rerun_failing_spec?
    failing_spec = first_failing_spec

    failing_spec_runs = @guard_konacha.runner.run_calls.select do |call|
      call[:arguments].first == failing_spec
    end
    failing_spec_runs.length > 1
  end

  def first_failing_spec
    failing_spec = @guard_konacha.runner.run_calls.select do |call|
      call[:result][:failures] > 0
    end.map do |call|
      call[:arguments].first
    end.first
  end

end
World(GuardKonachaSpecHelpers)
