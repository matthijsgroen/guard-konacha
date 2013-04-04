require 'guard/konacha'

module Guard
  class Konacha
    class Runner

      attr_reader :full_runs, :run_calls
      alias :test_run :run
      def run(args=[])
        @run_calls ||= []
        @run_calls << {
          :time => Time.now,
          :arguments => args
        }

        @full_runs ||= 0
        if args == []
          @full_runs += 1
        end
        test_run(args)
      end

    end
  end
end

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
    @guard_konacha.runner.full_runs > 0
  end

end
World(GuardKonachaSpecHelpers)
