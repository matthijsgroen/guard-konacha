require 'spec_helper'

describe Guard::Konacha::Runner do

  let(:runner) { Guard::Konacha::Runner.new }

  let(:status_code) { 200 }
  let(:fake_session) do
    double('capybara session',
           :reset! => true,
           :visit => true,
           :status_code => status_code)
  end
  let(:fake_reporter) do
    double('konacha reporter',
           :example_count => 5,
           :failure_count => 2,
           :pending_count => 1,
           :duration => 0.3
          )
  end
  let(:fake_runner) do
    double('konacha runner',
           :run => true,
           :reporter => fake_reporter)
  end

  before do
    # Silence Ui.info output
    ::Guard::UI.stub :info => true

    subject.stub(:konacha_running?) { true }
  end

  describe '#initialize' do
    subject { runner.options }

    context 'with default options' do
      it { should eq(Guard::Konacha::Runner::DEFAULT_OPTIONS) }
    end

    context 'with run_all => false' do
      let(:runner) { Guard::Konacha::Runner.new :run_all => false }
      it { should eq(Guard::Konacha::Runner::DEFAULT_OPTIONS.merge(:run_all => false)) }
    end

    context 'with specified port and host' do
      let(:runner) { Guard::Konacha::Runner.new :host => 'other_host', :port => 1234 }
      it "sets the default Capybara app_host to the correct value" do
        Capybara.app_host.should eql 'http://other_host:1234'
      end
    end
  end

  describe '.launch_konacha' do
    subject { Guard::Konacha::Runner.new }

    before do
      subject.should_receive(:bundler?).any_number_of_times.and_return(false)
    end

    it "launches spin server with cli options" do
      subject.should_receive(:spawn_konacha).once
      subject.launch_konacha('Start')
    end
  end

  describe '.kill_konacha' do
    it 'will not call Process#kill without spin_id' do
      Process.should_not_receive(:kill)
      subject.kill_konacha
    end

    it 'will stop the server process' do
      server_process = double('Konacha server process')
      server_process.should_receive(:stop)
      subject.instance_variable_set(:@process, server_process)

      subject.kill_konacha
    end

    it 'will reset the current capybara session' do
      subject.should_receive :clear_session!
      subject.kill_konacha
    end
  end

  describe '.run' do
    let(:failing_result) do
      {
        :examples => 3,
        :failures => 3,
        :pending  => 0,
        :duration => 2.5056
      }
    end

    let(:passing_result) do
      {
        :examples => 2,
        :failures => 0,
        :pending  => 0,
        :duration => 0.3056
      }
    end

    let(:pending_result) do
      {
        :examples => 2,
        :failures => 0,
        :pending  => 2,
        :duration => 2.8
      }
    end

    context 'without arguments' do
      let(:path) { '/' }

      it 'runs all the tests' do
        subject.should_receive(:run_tests) do |url, file_path|
          url.should match path
          file_path.should be_nil

          passing_result
        end
        ::Guard::UI.should_receive(:info).with('Konacha Running: All tests')
        subject.run
      end
    end

    context 'with arguments' do
      let(:path) { '/model/user_spec' }
      let(:file_path) { 'spec/javascripts/model/user_spec.js.coffee' }

      it 'runs specific tests' do
        subject.should_receive(:run_tests) do |url, file_path|
          url.should match path
          file_path.should eql file_path

          passing_result
        end
        ::Guard::UI.should_receive(:info).with("Konacha Running: #{file_path}")
        subject.run [file_path]
      end

    end

    it 'aggregates multiple test results' do
      files = [
        'spec/javascripts/model/user_spec.js.coffee',
        'spec/javascripts/model/profile_spec.js.coffee'
      ]
      subject.should_receive(:run_tests).twice.and_return(passing_result, failing_result)
      ::Guard::UI.should_receive(:info).with("Konacha Running: #{files.join(' ')}")
      ::Guard::UI.should_receive(:info).with("5 examples, 3 failures\nin 2.81 seconds")
      subject.run files
    end

    describe 'notifications' do
      subject { described_class.new :notifications => true }

      it 'sends text information to the Guard::Notifier' do
        subject.should_receive(:run_tests).exactly(3).times.and_return(passing_result, pending_result, failing_result)
        ::Guard::Notifier.should_receive(:notify).with(
          "7 examples, 3 failures, 2 pending\nin 5.61 seconds",
          :title => 'Konacha Specs',
          :image => :failed
        )
        subject.run ['a', 'b', 'c']
      end
    end

    describe 'Capybara session' do
      subject { described_class.new :driver => :other_driver }

      it 'can be configured to another driver' do
        ::Capybara::Session.should_receive(:new).with(:other_driver).and_return(fake_session)
        ::Konacha::Runner.should_receive(:new).with(fake_session).and_return(fake_runner)
        subject.run
      end
    end
  end

  describe '.run_all' do
    context 'with rspec' do
      it "calls Runner.run with 'spec'" do
        subject.should_receive(:run)
        subject.run_all
      end
    end

    context 'with :run_all set to false' do
      let(:runner) { Guard::Konacha::Runner.new :run_all => false }

      it 'not run all specs' do
        runner.should_not_receive(:run)
        runner.run_all
      end
    end
  end

  describe '.run_tests' do
    before do
      subject.stub :session => fake_session
    end

    it 'resets the capybara session' do
      # resetting the session between test runs is default policy. Cucumber::Rails does this aswell.
      fake_session.should_receive(:reset!).once
      ::Konacha::Runner.should_receive(:new).with(fake_session).and_return fake_runner
      subject.run_tests('dummy url', nil)
    end

    it 'never uses the same url twice' do
      session_url = nil
      runner_url = nil

      fake_session.stub(:visit) do |url|
        session_url = url
      end
      ::Konacha::Runner.stub :new => fake_runner
      fake_runner.stub(:run) do |url|
        runner_url = url
      end
      Timecop.freeze do
        subject.run_tests('/path_spec', 'file_path')
      end

      session_url.should_not eql runner_url
    end

    context 'with missing spec' do
      let(:status_code) { 404 }
      let(:missing_spec) { 'models/missing_spec' }

      it 'aborts the test with a missing result' do
        ::Guard::UI.should_receive(:warning).with("No spec found for: #{missing_spec}")
        ::Konacha::Runner.should_receive(:new).never
        subject.run_tests('dummy url', missing_spec).should eql described_class::EMPTY_RESULT
      end
    end

    context 'with runner raising exception' do
      let(:session) { double('capybara-session', :reset! => true) }
      before do
        subject.instance_variable_set(:@session, session)
        subject.stub :session => fake_session
        ::Guard::UI.stub :error => true
      end

      it 'resets the session' do
        ::Konacha::Runner.should_receive(:new) { throw :error }
        expect { subject.run_tests('dummy url', nil) }.to change { subject.instance_variable_get(:@session) }.from(session).to(nil)
      end

      it 'outputs the error to Guard' do
        ::Guard::UI.should_receive(:error) do |arg|
          arg.should match(/something_relevant/)
        end
        ::Konacha::Runner.should_receive(:new) { throw :something_relevant }

        subject.run_tests('dummy url', nil)
      end
    end
  end

  describe '.bundler?' do
    before do
      Dir.stub(:pwd).and_return("")
    end

    context 'with no bundler option' do
      subject { Guard::Konacha::Runner.new }

      context 'with Gemfile' do
        before do
          File.should_receive(:exist?).with('/Gemfile').and_return(true)
        end

        it 'return true' do
          subject.send(:bundler?).should be_true
        end
      end

      context 'with no Gemfile' do
        before do
          File.should_receive(:exist?).with('/Gemfile').and_return(false)
        end

        it 'return false' do
          subject.send(:bundler?).should be_false
        end
      end
    end

    context 'with :bundler => false' do
      subject { Guard::Konacha::Runner.new :bundler => false }

      context 'with Gemfile' do
        before do
          File.should_not_receive(:exist?)
        end

        it 'return false' do
          subject.send(:bundler?).should be_false
        end
      end

      context 'with no Gemfile' do
        before do
          File.should_not_receive(:exist?)
        end

        it 'return false' do
          subject.send(:bundler?).should be_false
        end
      end
    end

    context 'with :bundler => true' do
      subject { Guard::Konacha::Runner.new :bundler => true }

      context 'with Gemfile' do
        before do
          File.should_receive(:exist?).with('/Gemfile').and_return(true)
        end

        it 'return true' do
          subject.send(:bundler?).should be_true
        end
      end

      context 'with no Gemfile' do
        before do
          File.should_receive(:exist?).with('/Gemfile').and_return(false)
        end

        it 'return false' do
          subject.send(:bundler?).should be_false
        end
      end
    end
  end
end
