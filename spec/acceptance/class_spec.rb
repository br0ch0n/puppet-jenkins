require 'spec_helper_acceptance'

describe 'jenkins class' do
  include_context 'jenkins'

  context 'default parameters' do
    it 'should work with no errors' do
      pp = <<-EOS
      class {'jenkins':
        cli => true,
      }
      EOS

      # Run it twice and test for idempotency
      apply(pp, :catch_failures => true)
      apply(pp, :catch_changes => true)
    end

    describe port(8080) do
      it {
        sleep(10) # Jenkins takes a while to start up
        should be_listening
      }
    end

    describe file("#{$libdir}/jenkins-cli.jar") do
      it { should be_file }
    end

    describe service('jenkins') do
      it { should be_running }
      it { should be_enabled }
    end

  end

  context 'executors' do
    it 'should work with no errors' do
      pp = <<-EOS
      class {'jenkins':
        executors => 42,
      }
      EOS

      # Run it twice and test for idempotency
      apply(pp, :catch_failures => true)
      apply(pp, :catch_changes => true)
    end

    describe port(8080) do
      # jenkins should already have been running so we shouldn't have to
      # sleep
      it { should be_listening }
    end

    describe service('jenkins') do
      it { should be_running }
      it { should be_enabled }
    end

    describe file('/var/lib/jenkins/config.xml') do
      it { should contain '  <numExecutors>42</numExecutors>' }
    end
  end # executors

  context 'agentagentport' do
      it 'should work with no errors' do
        pp = <<-EOS
        class {'jenkins':
          agentagentport => 7777,
        }
        EOS

        # Run it twice and test for idempotency
        apply(pp, :catch_failures => true)
        apply(pp, :catch_changes => true)
      end

      describe port(8080) do
        # jenkins should already have been running so we shouldn't have to
        # sleep
        it { should be_listening }
      end

      describe service('jenkins') do
        it { should be_running }
        it { should be_enabled }
      end

      describe file('/var/lib/jenkins/config.xml') do
        it { should contain '  <agentAgentPort>7777</agentAgentPort>' }
      end
    end # agentagentport
end
