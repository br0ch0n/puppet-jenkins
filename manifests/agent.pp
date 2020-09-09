# == Class: jenkins::agent
#
# This module setups up a swarm client for a jenkins server.  It requires the swarm plugin on the Jenkins master.
#
# https://wiki.jenkins-ci.org/display/JENKINS/Swarm+Plugin
#
# It allows users to add more workers to Jenkins without having to specifically add them on the Jenkins master.
#
# === Parameters
#
# [*agent_name*]
#   Specify the name of the agent.  Not required, by default it will use the fqdn.
#
# [*masterurl*]
#   Specify the URL of the master server.  Not required, the plugin will do a UDP autodiscovery. If specified, the autodiscovery will be skipped.
#
# [*autodiscoveryaddress*]
#   Use this addresss for udp-based auto-discovery (default: 255.255.255.255)
#
# [*ui_user*] & [*ui_pass*]
#   User name & password for the Jenkins UI.  Not required, but may be ncessary for your config, depending on your security model.
#
# [*version*]
#   The version of the swarm client code. Must match the pluging version on the master.  Typically it's the latest available.
#
# [*executors*]
#   Number of executors for this agent.  (How many jenkins jobs can run simultaneously on this host.)
#
# [*manage_agent_user*]
#   Should the class add a user to run the agent code?  1 is currently true
#   TODO: should be updated to use boolean.
#
# [*agent_user*]
#   Defaults to 'jenkins-agent'. Change it if you'd like..
#
# [*agent_groups*]
#   Not required.  Use to add the agent_user to other groups if you need to.  Defaults to undef.
#
# [*agent_uid*]
#   Not required.  Puppet will let your system add the user, with the new UID if necessary.
#
# [*agent_home*]
#   Defaults to '/home/jenkins-agent'.  This is where the code will be installed, and the workspace will end up.
#
# [*agent_mode*]
#   Defaults to 'normal'. Can be either 'normal' (utilize this agent as much as possible) or 'exclusive' (leave this machine for tied jobs only).
#
# [*disable_ssl_verification*]
#   Disable SSL certificate verification on Swarm clients. Not required, but is necessary if you're using a self-signed SSL cert. Defaults to false.
#
# [*labels*]
#   Not required.  String, or Array, that contains the list of labels to be assigned for this agent.
#
# [*tool_locations*]
#   Not required.  Single string of whitespace-separated list of tool locations to be defined on this agent. A tool location is specified as 'toolName:location'.
#
# [*java_version*]
#   Specified which version of java will be used.
#
# [*description*]
#   Not required.  Description which will appear on the jenkins master UI.
#
# [*manage_client_jar*]
#   Should the class download the client jar file from the web? Defaults to true.
#
# [*ensure*]
#   Service ensure control for jenkins-agent service. Default running
#
# [*enable*]
#   Service enable control for jenkins-agent service. Default true.
#
# [*source*]
#   File source for jenkins agent jar. Default pulls from http://maven.jenkins-ci.org
#
# [*java_args*]
#   Java arguments to add to agent command line. Allows configuration of heap, etc. This
#   can be a String, or an Array.
#
# [*proxy_server*]
#
#   Serves the same function as `::jenkins::proxy_server` but is an independent
#   parameter so the `::jenkins` class does not need to be the catalog for
#   agent only nodes.
#

# === Examples
#
#  class { 'jenkins::agent':
#    masterurl => 'http://jenkins-master1.example.com:8080',
#    ui_user => 'adminuser',
#    ui_pass => 'adminpass'
#  }
#
# === Authors
#
# Matthew Barr <mbarr@mbarr.net>
#
# === Copyright
#
# Copyright 2013 Matthew Barr , but can be used for anything by anyone..
class jenkins::agent (
  $agent_name               = undef,
  $description              = undef,
  $masterurl                = undef,
  $autodiscoveryaddress     = undef,
  $ui_user                  = undef,
  $ui_pass                  = undef,
  $version                  = $jenkins::params::swarm_version,
  $executors                = 2,
  $manage_agent_user        = true,
  $agent_user               = 'jenkins-agent',
  $agent_groups             = undef,
  $agent_uid                = undef,
  $agent_home               = '/home/jenkins-agent',
  $agent_mode               = 'normal',
  $disable_ssl_verification = false,
  $labels                   = undef,
  $tool_locations           = undef,
  $install_java             = $jenkins::params::install_java,
  $manage_client_jar        = true,
  $ensure                   = 'running',
  $enable                   = true,
  $source                   = undef,
  $jarname                  = undef,
  $java_args                = undef,
  $proxy_server             = undef,
) inherits jenkins::params {
  validate_string($agent_name)
  validate_string($description)
  validate_string($masterurl)
  validate_string($autodiscoveryaddress)
  validate_string($ui_user)
  validate_string($ui_pass)
  validate_string($version)
  validate_integer($executors)
  validate_bool($manage_agent_user)
  validate_string($agent_user)
  if $agent_groups { validate_string($agent_groups) }
  if $agent_uid { validate_integer($agent_uid) }
  validate_absolute_path($agent_home)
  validate_re($agent_mode, '^normal$|^exclusive$')
  validate_bool($disable_ssl_verification)
  validate_string($tool_locations)
  validate_bool($install_java)
  validate_bool($manage_client_jar)
  validate_re($ensure, '^running$|^stopped$')
  validate_bool($enable)
  validate_string($source)
  validate_string($jarname)
  validate_string($proxy_server)

  $client_jar = $jarname ? {
    undef   => "swarm-client-${version}.jar",
    default => $jarname,
  }
  $client_url = $source ? {
    undef   => "https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/${version}/",
    default => $source,
  }
  $jar_owner = $manage_agent_user? {
    true  => $agent_user,
    false => undef,
  }
  $quoted_ui_user = shellquote($ui_user)
  $quoted_ui_pass = shellquote($ui_pass)

  if $labels {
    if is_array($labels) {
      $_combined_labels = hiera_array('jenkins::agent::labels', $labels)
      $_real_labels = join($_combined_labels, ' ')
    }
    else {
      $_real_labels = $labels
    }
  }

  if $java_args {
    if is_array($java_args) {
      $_combined_java_args = hiera_array('jenkins::agent::java_args', $java_args)
      $_real_java_args = join($_combined_java_args, ' ')
    }
    else {
      $_real_java_args = $java_args
    }
  }

  if $install_java and ($::osfamily != 'Darwin') {
    # Currently the puppetlabs/java module doesn't support installing Java on
    # Darwin
    include ::java
    Class['java'] -> Service['jenkins-agent']
  }

  # customizations based on the OS family
  case $::osfamily {
    'Debian': {
      $defaults_location = '/etc/default'

      ensure_packages(['daemon'])
      Package['daemon'] -> Service['jenkins-agent']
    }
    'Darwin': {
      $defaults_location = $agent_home
    }
    default: {
      $defaults_location = '/etc/sysconfig'
    }
  }

  case $::kernel {
    'Linux': {
      $service_name   = 'jenkins-agent'
      $defaults_user  = 'root'
      $defaults_group = 'root'
      $manage_user_home = true

      file { '/etc/init.d/jenkins-agent':
        ensure => 'file',
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => "puppet:///modules/${module_name}/jenkins-agent.${::osfamily}",
        notify => Service['jenkins-agent'],
      }
    }
    'Darwin': {
      $service_name     = 'org.jenkins-ci.agent.jnlp'
      $defaults_user    = 'jenkins'
      $defaults_group   = 'wheel'
      $manage_user_home = false

      file { "${agent_home}/start-agent.sh":
        ensure  => 'file',
        content => template("${module_name}/start-agent.sh.erb"),
        mode    => '0755',
        owner   => 'root',
        group   => 'wheel',
      }

      file { '/Library/LaunchDaemons/org.jenkins-ci.agent.jnlp.plist':
        ensure  => 'file',
        content => template("${module_name}/org.jenkins-ci.agent.jnlp.plist.erb"),
        mode    => '0644',
        owner   => 'root',
        group   => 'wheel',
      } ->
      Service['jenkins-agent']

      file { '/var/log/jenkins':
        ensure => 'directory',
        owner  => $agent_user,
      } ->
      Service['jenkins-agent']

      if $manage_agent_user {
        # osx doesn't have managehome support, so create directory
        file { $agent_home:
          ensure  => directory,
          mode    => '0755',
          owner   => $agent_user,
          require => User['jenkins-agent_user'],
        }
      }
    }
    default: { }
  }

  #a Add jenkins agent user if necessary.
  if $manage_agent_user {
    user { 'jenkins-agent_user':
      ensure     => present,
      name       => $agent_user,
      comment    => 'Jenkins Agent user',
      home       => $agent_home,
      managehome => $manage_user_home,
      system     => true,
      uid        => $agent_uid,
      groups     => $agent_groups,
    }
  }

  file { "${defaults_location}/jenkins-agent":
    ensure  => 'file',
    mode    => '0600',
    owner   => $defaults_user,
    group   => $defaults_group,
    content => template("${module_name}/jenkins-agent-defaults.erb"),
    notify  => Service['jenkins-agent'],
  }

  if ($manage_client_jar) {
    archive { 'get_swarm_client':
      source       => "${client_url}/${client_jar}",
      path         => "${agent_home}/${client_jar}",
      proxy_server => $proxy_server,
      cleanup      => false,
      extract      => false,
      user         => $jar_owner,
    } ->
    Service['jenkins-agent']
  }

  service { 'jenkins-agent':
    ensure     => $ensure,
    name       => $service_name,
    enable     => $enable,
    hasstatus  => true,
    hasrestart => true,
  }

  if $manage_agent_user and $manage_client_jar {
    User['jenkins-agent_user']->
      Archive['get_swarm_client']
  }
}
