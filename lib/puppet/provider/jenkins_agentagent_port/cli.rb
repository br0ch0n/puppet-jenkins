require 'puppet_x/jenkins/util'
require 'puppet_x/jenkins/provider/cli'

Puppet::Type.type(:jenkins_agentagent_port).provide(:cli, :parent => PuppetX::Jenkins::Provider::Cli) do

  mk_resource_methods

  def self.instances(catalog = nil)
    n = get_agentagent_port(catalog)

    # there can be only one value
    Puppet.debug("#{sname} instances: #{n}")

    [new(:name => n, :ensure => :present)]
  end

  def flush
    case self.ensure
    when :present
      set_agentagent_port
    else
      fail("invalid :ensure value: #{self.ensure}")
    end
  end

  private

  def self.get_agentagent_port(catalog = nil)
    clihelper(['get_agentagent_port'], :catalog => catalog).to_i
  end
  private_class_method :get_agentagent_port

  def set_agentagent_port
    clihelper(['set_agentagent_port', name])
  end
end
