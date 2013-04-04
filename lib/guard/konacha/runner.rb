require 'net/http'
require 'childprocess'
require 'capybara'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'
require 'konacha/reporter'
require 'konacha/formatter'
require 'konacha/runner'

module Guard
  class Konacha
    class Runner

      DEFAULT_OPTIONS = {
        :bundler  => true,
        :spec_dir => 'spec/javascripts',
        :run_all  => true,
        :all_on_start => true,
        :driver   => :selenium,
        :host     => 'localhost',
        :port     => 3500,
        :notification => true,
        :spawn_wait => 20
      }

      attr_reader :options

      def initialize(options={})
        @options = DEFAULT_OPTIONS.merge(options)
        UI.info "Guard::Konacha Initialized"
        @failing_paths = []
      end

      def launch_konacha(action)
        UI.info "#{action}ing Konacha", :reset => true
        spawn_konacha
      end

      def kill_konacha
        clear_session!
        if @process
          @process.stop(5)
          UI.info "Konacha Stopped", :reset => true
        end
      end

      def run(paths=[])
        return UI.info("Konacha server not running") unless konacha_running?
        @passed_previous_failing = false

        UI.info "Konacha Running: #{paths.empty? ? 'All tests' : paths.join(' ')}"

        urls = paths.map { |p| konacha_url(p) }
        urls = [konacha_url] if paths.empty?

        test_results = {
          :examples => 0,
          :failures => 0,
          :pending  => 0,
          :duration => 0
        }

        urls.each_with_index do |url, index|
          individual_result = run_tests(url, paths[index])

          if individual_result[:failures] > 0
            mark_url_as_failing paths[index]
          else
            mark_url_as_passing paths[index]
          end

          test_results[:examples] += individual_result[:examples]
          test_results[:failures] += individual_result[:failures]
          test_results[:pending]  += individual_result[:pending]
          test_results[:duration] += individual_result[:duration]
        end

        result_line = "#{test_results[:examples]} examples, #{test_results[:failures]} failures"
        result_line << ", #{test_results[:pending]} pending" if test_results[:pending] > 0
        text = [
          result_line,
          "in #{"%.2f" % test_results[:duration]} seconds"
        ].join "\n"

        UI.info text if urls.length > 1

        if @options[:notification]
          image = test_results[:failures] > 0 ? :failed : :success
          ::Guard::Notifier.notify(text, :title => 'Konacha Specs', :image => image )
        end

        if @passed_previous_failing
          run
        end
        test_results
      end

      EMPTY_RESULT = {
        :examples => 0,
        :failures => 0,
        :pending  => 0,
        :duration => 0,
      }

      def run_tests(url, path)
        session.reset!
        unless valid_spec? url
          UI.warning "No spec found for: #{path}"
          return EMPTY_RESULT
        end

        runner = ::Konacha::Runner.new session
        runner.run url
        return {
          :examples => runner.reporter.example_count,
          :failures => runner.reporter.failure_count,
          :pending  => runner.reporter.pending_count,
          :duration => runner.reporter.duration
        }
      rescue => e
        UI.error e.inspect
        @session = nil
      end

      def run_all
        run if @options[:run_all]
      end

      def run_all_on_start
         run_all if @options[:all_on_start]
      end

      private

      def mark_url_as_failing path
        @failing_paths << path
      end

      def mark_url_as_passing path
        if @failing_paths.include? path
          @failing_paths -= [path]
          @passed_previous_failing = true
        end
      end

      def konacha_url(path = nil)
        url_path = path.gsub(/^#{@options[:spec_dir]}\/?/, '').gsub(/\.coffee$/, '').gsub(/\.js$/, '') unless path.nil?
        "#{konacha_base_url}/#{url_path}?mode=runner&unique=#{unique_id}"
      end

      def unique_id
        "#{Time.now.to_i}#{rand(100)}"
      end

      def session
        UI.info "Starting Konacha-Capybara session using #{@options[:driver]} driver, this can take a few seconds..." if @session.nil?
        @session ||= Capybara::Session.new @options[:driver]
      end

      def clear_session!
        return unless @session
        @session.reset!
        @session = nil
      end

      def spawn_konacha_command
        cmd_parts = ''
        cmd_parts << "bundle exec " if bundler?
        cmd_parts << "rake konacha:serve"
        cmd_parts.split
      end

      def spawn_konacha
        unless @process
          @process = ChildProcess.build(*spawn_konacha_command)
          @process.io.inherit! if ::Guard.respond_to?(:options) && ::Guard.options && ::Guard.options[:verbose]
          @process.start

           Timeout::timeout(@options[:spawn_wait]) do
            until konacha_running?
              sleep(0.2)
            end
          end
        end
      end

      def konacha_base_url
        "http://#{@options[:host]}:#{@options[:port]}"
      end

      def konacha_running?
        Net::HTTP.get_response(URI.parse(konacha_base_url))
      rescue Errno::ECONNREFUSED
      end

      def bundler?
        @bundler ||= options[:bundler] != false && File.exist?("#{Dir.pwd}/Gemfile")
      end

      def valid_spec? url
        session.visit url
        konacha_spec = session.evaluate_script('typeof window.top.Konacha')
        konacha_spec == 'object'
      end

    end
  end
end
