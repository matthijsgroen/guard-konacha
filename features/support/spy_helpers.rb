require 'guard/konacha'

module Guard
  class Konacha
    class Runner

      attr_reader :full_runs, :run_calls
      alias :test_run :run
      def run(args=[])
        @run_calls ||= []
        call_info = {
          :time => Time.now,
          :arguments => args,
        }
        @run_calls << call_info

        result = test_run(args)
        call_info[:result] = result
        result
      end

    end
  end
end

